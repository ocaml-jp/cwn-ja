import { readFile, writeFile } from "fs/promises";
import { join } from "path";

const ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const PROMPT_PATH = join(ROOT, "scripts/prompt.md");

const MAX_RETRIES = 3;

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

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function callClaudeAPI(systemPrompt: string, content: string): Promise<string> {
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY environment variable is not set");
  }
  const model = process.env.CLAUDE_MODEL || "claude-sonnet-4-6";

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
          max_tokens: 16384,
          stream: true,
          system: systemPrompt,
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

async function main() {
  const [inputPath, outputPath] = process.argv.slice(2);
  if (!inputPath || !outputPath) {
    console.error("Usage: translate.ts <input.xml> <output.xml>");
    process.exit(1);
  }

  const [systemPrompt, content] = await Promise.all([
    readFile(PROMPT_PATH, "utf-8"),
    readFile(inputPath, "utf-8"),
  ]);
  console.log(`Translating ${inputPath} → ${outputPath}...`);
  const translated = await callClaudeAPI(systemPrompt, content);
  await writeFile(outputPath, translated, "utf-8");
  console.log(`Done: ${outputPath}`);
}

main();
