CWN_JA := _build/default/bin/cwn_ja.exe

XML_FILES  := $(wildcard ja/*.xml)
ORG_FILES  := $(XML_FILES:.xml=.org)
HTML_FILES := $(ORG_FILES:.org=.html)

all: $(HTML_FILES) ja/index.html

$(CWN_JA):
	dune build bin/cwn_ja.exe

# Also writes ja/%.rss as a side effect of the same invocation.
ja/%.org: ja/%.xml $(CWN_JA)
	$(CWN_JA) -japanese $<

ja/%.html: ja/%.org scripts/org-export.el
	emacs --batch -l scripts/org-export.el --visit=$< --eval "(princ (org-export-as 'html))" --kill > $@

ja/index.html: $(HTML_FILES) scripts/gen-index.ts
	node --experimental-strip-types scripts/gen-index.ts
