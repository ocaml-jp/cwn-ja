import { readdir, writeFile } from "fs/promises";
import { join } from "path";

const ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const JA_DIR = join(ROOT, "ja");

async function main() {
  const files = (await readdir(JA_DIR))
    .filter((f) => /^\d{4}\.\d{2}\.\d{2}\.html$/.test(f))
    .sort()
    .reverse();

  // Group by year, then by month
  const years = new Map<string, Map<string, string[]>>();
  for (const f of files) {
    const [year, month, day] = f.replace(".html", "").split(".");
    if (!years.has(year)) years.set(year, new Map());
    const months = years.get(year)!;
    if (!months.has(month)) months.set(month, []);
    months.get(month)!.push(day);
  }

  // Build calendar view
  let calendar = "";
  for (const [year, months] of years) {
    calendar += `\n${year}\n`;
    for (const [month, days] of months) {
      const links = days
        .map((d) => `<a href="${year}.${month}.${d}.html">${d}</a>`)
        .join("    ");
      calendar += `${month}    ${links}\n`;
    }
  }

  const html = `<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>OCaml Weekly News (日本語訳)</title>
<style>
  body { font-family: sans-serif; max-width: 60em; margin: 2em auto; padding: 0 1em; }
  h1 { font-size: 1.4em; }
  pre { line-height: 1.6; }
  pre a { text-decoration: none; }
  pre a:hover { text-decoration: underline; }
</style>
</head>
<body>
<h1>OCaml Weekly News (日本語訳)</h1>
<p><a href="https://alan.petitepomme.net/cwn/">OCaml Weekly News</a> の日本語訳アーカイブです。翻訳はOCaml.jpのメンバーが LLM の支援を元に行っています。 </p>
<p><a href="https://github.com/ocaml-jp/cwn-ja">GitHub リポジトリ</a></p>
<h2>アーカイブ</h2>
<pre>${calendar}</pre>
</body>
</html>
`;

  const outPath = join(JA_DIR, "index.html");
  await writeFile(outPath, html, "utf-8");
  console.log(`Generated ${outPath}`);
}

main();
