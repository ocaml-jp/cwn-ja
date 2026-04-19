import { readdir, readFile, writeFile } from "fs/promises";
import { join } from "path";

const ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const JA_DIR = join(ROOT, "ja");
const OUTPUT = join(JA_DIR, "cwn.rss");

// Upstream keeps a sliding window of ~10 most recent items.
const MAX_ITEMS = 10;

async function main() {
  const rssFragments = (await readdir(JA_DIR))
    .filter((f) => /^\d{4}\.\d{2}\.\d{2}\.rss$/.test(f))
    .sort()
    .reverse()
    .slice(0, MAX_ITEMS);

  const items = await Promise.all(
    rssFragments.map(async (f) => {
      const raw = await readFile(join(JA_DIR, f), "utf-8");
      // Each fragment is `<?xml ... ?>\n<item>...</item>`; drop the
      // per-fragment XML declaration before splicing into the channel.
      return raw.replace(/^<\?xml[^?]*\?>\s*/, "").trimEnd();
    }),
  );

  const feed = `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
<channel>
<title>OCaml Weekly News (日本語訳)</title>
<link>https://ocaml.jp/cwn-ja/</link>
<description>OCaml Weekly News の日本語訳</description>
${items.join("\n")}
</channel>
</rss>
`;

  await writeFile(OUTPUT, feed, "utf-8");
  console.log(`Generated ${OUTPUT} with ${items.length} item(s)`);
}

main();
