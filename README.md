# cwn-ja

Japanese translations of [OCaml Weekly News](https://alan.petitepomme.net/cwn/) (CWN).

Published at <https://ocaml.jp/cwn-ja/>.

## Structure

```
cwn-data/          # upstream CWN org files (git submodule)
ja/                # translated org + generated HTML
scripts/
  translate.ts     # single-file org-to-org translator (Claude API)
  pipeline.ts      # orchestration: file discovery, translate loop, make
  prompt.md        # system prompt for translation
  org-export.el    # emacs config for org-to-HTML export (CJK fixes)
Makefile           # ja/%.html from ja/%.org via emacs
```

## Requirements

- Node.js 22+
- Emacs (for org-to-HTML export)
- `ANTHROPIC_API_KEY` environment variable

## Usage

```bash
# translate all untranslated files
npm run translate

# translate a single file
node --experimental-strip-types scripts/pipeline.ts --file 2026.03.31

# re-translate files from a date onward
node --experimental-strip-types scripts/pipeline.ts --since 2026.03.01

# translate files changed between two submodule commits
node --experimental-strip-types scripts/pipeline.ts --from-ref abc123 --to-ref def456

# regenerate HTML only (no translation)
make
```

The pipeline translates each `cwn-data/DATE.org` to `ja/DATE.org` via the Claude API, then runs `make` to generate HTML.
