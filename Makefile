CWN_JA := _build/default/bin/cwn_ja.exe

XML_FILES  := $(wildcard ja/*.xml)
ORG_FILES  := $(XML_FILES:.xml=.org)
HTML_FILES := $(ORG_FILES:.org=.html)

# Dune handles incremental compilation internally, but make needs to know the
# binary can become stale — without these prereqs, make thinks `_build/.../cwn_ja.exe`
# is fresh just because the file exists, and skips `dune build` when sources change.
CWN_JA_SOURCES := dune-project \
                  $(wildcard lib/*.ml lib/*.mli) lib/dune \
                  $(wildcard bin/*.ml) bin/dune

all: $(HTML_FILES) ja/index.html ja/cwn.rss

$(CWN_JA): $(CWN_JA_SOURCES)
	dune build bin/cwn_ja.exe

# Also writes ja/%.rss as a side effect of the same invocation.
ja/%.org: ja/%.xml $(CWN_JA)
	$(CWN_JA) -japanese $<

ja/%.html: ja/%.org scripts/org-export.el
	emacs --batch -l scripts/org-export.el --visit=$< --eval "(princ (org-export-as 'html))" --kill > $@

ja/index.html: $(HTML_FILES) scripts/gen-index.ts
	node --experimental-strip-types scripts/gen-index.ts

# Depends on $(ORG_FILES) — the .org rule produces .rss as a side effect, so
# when any org is rebuilt the rss beside it is fresh and cwn.rss regenerates.
ja/cwn.rss: $(ORG_FILES) scripts/gen-rss.ts
	node --experimental-strip-types scripts/gen-rss.ts
