import { readdir, access, mkdir } from "fs/promises";
import { execFile, execFileSync } from "child_process";
import { join, basename } from "path";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

const ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const CWN_DATA = join(ROOT, "cwn-data");
const JA_DIR = join(ROOT, "ja");

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
      case "--file":     result.file = args[++i]; break;
      case "--since":    result.since = args[++i]; break;
      case "--from-ref": result.fromRef = args[++i]; break;
      case "--to-ref":   result.toRef = args[++i]; break;
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

function dateFromFilename(filename: string): string {
  return basename(filename).replace(/\.(xml|org)$/, "");
}

async function listDates(args: Args): Promise<string[]> {
  let dates: string[];

  if (args.file) {
    const date = args.file.replace(/\.(xml|org)$/, "");
    const xmlPath = join(CWN_DATA, `${date}.xml`);
    try {
      await access(xmlPath);
    } catch {
      console.error(`File not found: ${xmlPath}`);
      process.exit(1);
    }
    dates = [date];
  } else if (args.fromRef && args.toRef) {
    const { stdout } = await execFileAsync(
      "git", ["diff", "--name-only", args.fromRef, args.toRef, "--", "*.xml", "*.org"],
      { cwd: CWN_DATA, encoding: "utf-8" }
    );
    const output = stdout.trim();
    dates = output
      ? [...new Set(output.split("\n").map(dateFromFilename))]
      : [];
  } else {
    // Candidate set = dates upstream has published an org for (i.e. post-cutover
    // publishable weeks). We feed the corresponding .xml to the translator.
    const cwnFiles = await readdir(CWN_DATA);
    const published = new Set(
      cwnFiles.filter((f) => f.endsWith(".org")).map(dateFromFilename)
    );
    const xmlDates = cwnFiles
      .filter((f) => f.endsWith(".xml"))
      .map(dateFromFilename)
      .filter((d) => published.has(d));
    if (args.since) {
      // --since implies force: include all files on or after the date
      dates = xmlDates;
    } else {
      // Default: skip dates already translated (ja/DATE.xml exists)
      const translated = new Set(
        (await readdir(JA_DIR).catch(() => []))
          .filter((f: string) => f.endsWith(".xml"))
          .map((f: string) => dateFromFilename(f))
      );
      dates = xmlDates.filter((d) => !translated.has(d));
    }
  }

  if (args.since) {
    dates = dates.filter((d) => d >= args.since!);
  }

  return dates.sort();
}

async function translate(date: string): Promise<boolean> {
  const input = join(CWN_DATA, `${date}.xml`);
  const output = join(JA_DIR, `${date}.xml`);
  console.log(`--- Translating ${date} ---`);
  try {
    execFileSync(
      "node",
      ["--experimental-strip-types", join(ROOT, "scripts/translate.ts"), input, output],
      { stdio: "inherit" }
    );
    return true;
  } catch {
    console.error(`FAILED: ${date}`);
    return false;
  }
}

async function main() {
  const args = parseArgs();
  const dates = await listDates(args);

  if (dates.length === 0) {
    console.log("No files to translate.");
    process.exit(0);
  }

  console.log(`Found ${dates.length} file(s) to translate: ${dates.join(", ")}`);
  await mkdir(JA_DIR, { recursive: true });

  let succeeded = 0;
  let failed = 0;
  for (const date of dates) {
    if (await translate(date)) succeeded++;
    else failed++;
  }

  console.log(`\nTranslation: ${succeeded} succeeded, ${failed} failed.`);

  // make handles ja/%.xml -> ja/%.org (via the cwn_ja binary) and
  // ja/%.org -> ja/%.html (via emacs), plus the index.
  console.log("Running make to generate org and HTML...");
  execFileSync("make", ["-C", ROOT], { stdio: "inherit" });

  if (failed > 0) process.exit(1);
}

main();
