# cwn-ja

Japanese translations of [OCaml Weekly News](https://alan.petitepomme.net/cwn/) (CWN).

Published at <https://ocaml.jp/cwn-ja/>.

## Pipeline

For each weekly issue, translation flows:

```
cwn-data/DATE.xml   (upstream XML — hand-authored)
      │
      ▼   [bin/translate.ml: OpenRouter API, XML-in, XML-out]
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

- `bin/gen_index.ml` → `ja/index.html` (calendar view of all weeks)
- `bin/gen_cwn_rss.ml` → `ja/cwn.rss` (RSS 2.0 envelope wrapping the ~10 most recent fragments)

The xml→org→html pipeline and aggregators are driven by per-date dune rules.
`bin/gen_dune_inc.ml` regenerates `ja/dune.inc` from the current set of
`ja/*.xml` inputs; `dune build` builds and promotes everything else into the
source tree.

## Structure

```
cwn-data/          # upstream CWN XML + org files (git submodule)
ja/                # per-week xml/org/rss/html + cwn.rss + index.html
ja/dune.inc        # generated per-date rules + aggregators (committed)
lib/               # cwn_ja_lib OCaml library
                   #   Xmltree, Cwn, Language, Cli   — xml → org/rss
                   #   Translator, Source_set         — translation flow
                   #   Index_page, Cwn_rss            — site aggregators
bin/cwn_ja.ml      # CLI wrapping Cwn_ja_lib.Cli.command
bin/translate.ml   # OpenRouter-driven translator
bin/gen_index.ml   # writes ja/index.html
bin/gen_cwn_rss.ml # writes ja/cwn.rss
bin/gen_dune_inc.ml# writes ja/dune.inc
scripts/
  prompt.md        # system prompt for translation
  org-export.el    # emacs config for org-to-HTML export (CJK fixes)
test/              # ppx_expect tests
dune-project       # OCaml project; deps locked in dune.lock/ via (pkg enabled)
```

## Requirements

- Dune 3.22+ (pulls the OCaml compiler and deps from `dune.lock/` — no separate opam setup needed)
- Emacs (for org-to-HTML export)
- `OPENROUTER_API_KEY` environment variable (for translation)

## Usage

```bash
# translate any untranslated weeks (candidate = upstream has both .xml and .org)
dune exec ./bin/translate.exe

# translate one specific date
dune exec ./bin/translate.exe -- -file 2026.03.31

# force-retranslate everything from a date onward (bypasses the skip check)
dune exec ./bin/translate.exe -- -since 2026.03.01

# translate weeks whose upstream files changed between two submodule commits
dune exec ./bin/translate.exe -- -from-ref abc123 -to-ref def456

# rebuild derived artefacts only — no translation, no API calls
dune build && dune build
```

The double `dune build` is intentional: when a new translation lands,
the first pass refreshes `ja/dune.inc` from the new `*.xml` glob, and
the second pass uses the refreshed rules to build the new `.org`, `.rss`,
and `.html` outputs and the `index.html` + `cwn.rss` aggregators. All
outputs are auto-promoted back into `ja/`.

The model defaults to `anthropic/claude-sonnet-4.6`; override via
`OPENROUTER_MODEL=...`.

## Development

```bash
dune build           # build the library and binaries
dune runtest         # run the expect tests in test/
dune promote         # accept expect-test diffs after an intentional change
```

Invoke the conversion CLI directly:

```bash
# English output (upstream alan.petitepomme.net URLs, both .org and .rss)
dune exec cwn_ja -- path/to/DATE.xml

# Japanese output (ocaml.jp URLs, Japanese boilerplate, both .org and .rss)
dune exec cwn_ja -- -japanese path/to/DATE.xml
```

Outputs land beside the input.
