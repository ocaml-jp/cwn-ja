# cwn-ja

Japanese translations of [OCaml Weekly News](https://alan.petitepomme.net/cwn/) (CWN).

Published at <https://ocaml.jp/cwn-ja/>.

## Pipeline

For each weekly issue, translation flows:

```
cwn-data/DATE.xml   (upstream XML — hand-authored)
      │
      ▼   [scripts/translate.ts: Claude API, XML-in, XML-out]
ja/DATE.xml         (translated XML)
      │
      ▼   [cwn_ja -japanese: OCaml tool]
ja/DATE.org         (org-mode, Japanese boilerplate + nav)
ja/DATE.rss         (per-issue <item> fragment)
      │
      ▼   [emacs batch: org-export.el]
ja/DATE.html
```

Plus two aggregators that run after any per-issue rebuild:

- `scripts/gen-index.ts` → `ja/index.html` (calendar view of all weeks)
- `scripts/gen-rss.ts` → `ja/cwn.rss` (RSS 2.0 envelope wrapping the ~10 most recent fragments)

## Structure

```
cwn-data/          # upstream CWN XML + org files (git submodule)
ja/                # per-week xml/org/rss/html + cwn.rss + index.html
lib/               # cwn_ja OCaml library (Xmltree, Cwn, Language, Cli)
bin/cwn_ja.ml      # thin CLI wrapping Cwn_ja_lib.Cli.command
test/              # ppx_expect tests
scripts/
  translate.ts     # XML-to-XML translator (Claude API, SSE streaming)
  pipeline.ts      # orchestration: file discovery, translate loop, make
  prompt.md        # system prompt for translation
  gen-index.ts     # builds ja/index.html
  gen-rss.ts       # builds ja/cwn.rss (sliding window of 10 latest)
  org-export.el    # emacs config for org-to-HTML export (CJK fixes)
Makefile           # xml → org (cwn_ja) → html (emacs); + cwn.rss + index.html
dune-project       # OCaml project; deps locked in dune.lock/ via (pkg enabled)
```

## Requirements

- Node.js 22+
- Dune 3.22+ (pulls the OCaml compiler and deps from `dune.lock/` — no separate opam setup needed)
- Emacs (for org-to-HTML export)
- `ANTHROPIC_API_KEY` environment variable (for translation)

## Usage

```bash
# translate any untranslated weeks (candidate = upstream has both .xml and .org)
npm run translate

# translate one specific date
npm run translate -- --file 2026.03.31

# force-retranslate everything from a date onward (bypasses the skip check)
npm run translate -- --since 2026.03.01

# translate weeks whose upstream files changed between two submodule commits
npm run translate -- --from-ref abc123 --to-ref def456

# rebuild derived artefacts only — no translation, no API calls
make
```

`npm run translate` always finishes with a `make` so `.org`, `.rss`, `.html`, `ja/index.html`, and `ja/cwn.rss` are all up to date.

## Development

The OCaml tool lives in `lib/` + `bin/`:

```bash
dune build           # build the library and cwn_ja binary
dune runtest         # run the expect tests in test/
dune promote         # accept expect-test diffs after an intentional change
```

Invoke the CLI directly:

```bash
# English output (upstream alan.petitepomme.net URLs, both .org and .rss)
dune exec cwn_ja -- path/to/DATE.xml

# Japanese output (ocaml.jp URLs, Japanese boilerplate, both .org and .rss)
dune exec cwn_ja -- -japanese path/to/DATE.xml
```

Outputs land beside the input.
