import { readdir, writeFile, mkdir, access } from "fs/promises";
import { execFile } from "child_process";
import { join, basename } from "path";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

const ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const CWN_DATA = join(ROOT, "cwn-data");
const JA_DIR = join(ROOT, "ja");

const SYSTEM_PROMPT = `You are a professional translator specializing in technical content about OCaml
and functional programming. Translate the following Markdown document from English
to Japanese.

Rules:
- Preserve ALL Markdown formatting exactly (headings, links, code blocks, lists, etc.)
- Do NOT translate: code blocks, inline code, URLs, author names, package/library names,
  OCaml identifiers, or technical terms that are commonly left in English in Japanese
  technical writing (e.g., "OCaml", "opam", "dune", "Merlin")
- Translate: prose text, headings, navigation labels, list descriptions
- Maintain the same document structure and line breaks
- Use natural, fluent Japanese suitable for a technical audience
- Output ONLY the translated Markdown — no explanations or commentary`;

const MAX_RETRIES = 3;
const SECTION_CHAR_LIMIT = 30_000;

interface Args {
  file?: string;
  since?: string;
  fromRef?: string;
  toRef?: string;
}

function parseArgs(): Args {
  const args = process.argv.slice(2);
  const result: Args = {};
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--file":
        result.file = args[++i];
        break;
      case "--since":
        result.since = args[++i];
        break;
      case "--from-ref":
        result.fromRef = args[++i];
        break;
      case "--to-ref":
        result.toRef = args[++i];
        break;
      default:
        console.error(`Unknown argument: ${args[i]}`);
        process.exit(1);
    }
  }
  if ((result.fromRef && !result.toRef) || (!result.fromRef && result.toRef)) {
    console.error("--from-ref and --to-ref must be used together");
    process.exit(1);
  }
  return result;
}

/** Extract date string from a filename like "2026.03.31.org" → "2026.03.31" */
function dateFromFilename(filename: string): string {
  return basename(filename).replace(/\.org$/, "").replace(/\.md$/, "");
}

/** Check if a date string is >= the since filter */
function isOnOrAfter(date: string, since: string): boolean {
  return date >= since;
}

async function listFiles(args: Args): Promise<string[]> {
  let dates: string[];

  if (args.file) {
    // Single file mode
    const date = args.file.replace(/\.org$/, "");
    const orgPath = join(CWN_DATA, `${date}.org`);
    try {
      await access(orgPath);
    } catch {
      console.error(`File not found: ${orgPath}`);
      process.exit(1);
    }
    dates = [date];
  } else if (args.fromRef && args.toRef) {
    // Diff-based mode
    const { stdout } = await execFileAsync(
      "git", ["diff", "--name-only", args.fromRef, args.toRef, "--", "*.org"],
      { cwd: CWN_DATA, encoding: "utf-8" }
    );
    const output = stdout.trim();
    if (!output) {
      dates = [];
    } else {
      dates = output.split("\n").map((f) => dateFromFilename(f));
    }
  } else {
    // Default: list all .org files; skip already-translated unless --since is set
    const orgFiles = (await readdir(CWN_DATA))
      .filter((f) => f.endsWith(".org"))
      .map((f) => dateFromFilename(f));
    if (args.since) {
      dates = orgFiles;
    } else {
      const translated = new Set(
        (await readdir(JA_DIR).catch(() => []))
          .filter((f: string) => f.endsWith(".md"))
          .map((f: string) => dateFromFilename(f))
      );
      dates = orgFiles.filter((d) => !translated.has(d));
    }
  }

  // Apply --since filter
  if (args.since) {
    dates = dates.filter((d) => isOnOrAfter(d, args.since!));
  }

  return dates.sort();
}

async function orgToMarkdown(orgPath: string): Promise<string> {
  const { stdout } = await execFileAsync(
    "pandoc", [orgPath, "-f", "org", "-t", "markdown"],
    { encoding: "utf-8" }
  );
  return stdout;
}

/** Split markdown by ## headings if it exceeds the character limit */
function splitSections(markdown: string): string[] {
  if (markdown.length <= SECTION_CHAR_LIMIT) {
    return [markdown];
  }
  const sections: string[] = [];
  const lines = markdown.split("\n");
  let current: string[] = [];

  for (const line of lines) {
    if (line.startsWith("# ") && current.length > 0) {
      sections.push(current.join("\n"));
      current = [];
    }
    current.push(line);
  }
  if (current.length > 0) {
    sections.push(current.join("\n"));
  }
  return sections;
}

async function readSSEStream(body: ReadableStream<Uint8Array>): Promise<string> {
  const decoder = new TextDecoder();
  const reader = body.getReader();
  let buffer = "";
  let result = "";
  let lastReportedChars = 0;
  const startTime = Date.now();

  function writeProgress(final: boolean) {
    const elapsed = (Date.now() - startTime) / 1000;
    const cps = elapsed > 0 ? Math.round(result.length / elapsed) : 0;
    let line: string;
    if (final) {
      line = `  ${result.length} chars in ${elapsed.toFixed(1)}s (${cps} chars/sec)`;
    } else {
      line = `  ${result.length} chars received (${cps} chars/sec)...`;
    }
    if (process.stderr.isTTY) {
      process.stderr.write(`\r\x1b[K${line}${final ? "\n" : ""}`);
    } else if (final || result.length - lastReportedChars >= 500) {
      process.stderr.write(`${line}\n`);
      lastReportedChars = result.length;
    }
  }

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    const lines = buffer.split("\n");
    buffer = lines.pop()!;

    for (const line of lines) {
      if (!line.startsWith("data: ")) continue;
      const data = line.slice(6);
      if (data === "[DONE]") continue;

      let event: {
        type: string;
        delta?: { type: string; text?: string };
      };
      try {
        event = JSON.parse(data);
      } catch {
        continue;
      }

      if (event.type === "content_block_delta" && event.delta?.type === "text_delta") {
        result += event.delta.text ?? "";
        writeProgress(false);
      }
    }
  }

  writeProgress(true);
  return result;
}

async function callClaudeAPI(content: string): Promise<string> {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY environment variable is not set");
  }
  const model = process.env.CLAUDE_MODEL || "claude-sonnet-4-5-20250929";

  let lastError: Error | null = null;
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "x-api-key": apiKey,
          "anthropic-version": "2023-06-01",
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model,
          max_tokens: 8192,
          stream: true,
          system: SYSTEM_PROMPT,
          messages: [{ role: "user", content }],
        }),
      });

      if (response.status === 429) {
        const retryAfter = response.headers.get("retry-after");
        const waitMs = retryAfter ? parseInt(retryAfter, 10) * 1000 : Math.pow(4, attempt) * 1000;
        console.warn(`Rate limited, waiting ${waitMs}ms...`);
        await sleep(waitMs);
        continue;
      }

      if (!response.ok) {
        const body = await response.text();
        throw new Error(`API error ${response.status}: ${body}`);
      }

      return await readSSEStream(response.body!);
    } catch (err) {
      lastError = err as Error;
      if (attempt < MAX_RETRIES - 1) {
        const waitMs = Math.pow(4, attempt) * 1000;
        console.warn(`Attempt ${attempt + 1} failed: ${lastError.message}. Retrying in ${waitMs}ms...`);
        await sleep(waitMs);
      }
    }
  }
  throw lastError!;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function translate(markdown: string): Promise<string> {
  const sections = splitSections(markdown);
  if (sections.length === 1) {
    return callClaudeAPI(markdown);
  }

  console.log(`  Large file: splitting into ${sections.length} sections`);
  const translated: string[] = [];
  for (let i = 0; i < sections.length; i++) {
    console.log(`  Translating section ${i + 1}/${sections.length}...`);
    translated.push(await callClaudeAPI(sections[i]));
  }
  return translated.join("\n");
}

async function markdownToHtml(mdPath: string, htmlPath: string): Promise<void> {
  await execFileAsync(
    "pandoc", [mdPath, "-f", "markdown", "-t", "html", "-o", htmlPath],
    { encoding: "utf-8" }
  );
}

async function processFile(date: string): Promise<boolean> {
  const orgPath = join(CWN_DATA, `${date}.org`);
  const mdPath = join(JA_DIR, `${date}.md`);
  const htmlPath = join(JA_DIR, `${date}.html`);

  try {
    // Step 1: org → markdown
    console.log(`Converting ${date}.org → markdown...`);
    const markdown = await orgToMarkdown(orgPath);

    // Step 2: translate markdown → Japanese
    console.log(`Translating ${date}...`);
    const translated = await translate(markdown);

    // Step 3: write translated markdown
    await mkdir(JA_DIR, { recursive: true });
    await writeFile(mdPath, translated, "utf-8");

    // Step 4: markdown → html
    console.log(`Converting ${date}.md → HTML...`);
    await markdownToHtml(mdPath, htmlPath);

    console.log(`Translated ${date}`);
    return true;
  } catch (err) {
    console.error(`Failed to translate ${date}: ${(err as Error).message}`);
    return false;
  }
}

async function main() {
  const args = parseArgs();
  const dates = await listFiles(args);

  if (dates.length === 0) {
    console.log("No files to translate.");
    process.exit(0);
  }

  console.log(`Found ${dates.length} file(s) to translate: ${dates.join(", ")}`);

  let succeeded = 0;
  let failed = 0;
  for (const date of dates) {
    const ok = await processFile(date);
    if (ok) succeeded++;
    else failed++;
  }

  console.log(`\nDone: ${succeeded} succeeded, ${failed} failed.`);
  if (failed > 0) process.exit(1);
}

main();
