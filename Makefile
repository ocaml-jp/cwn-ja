ORG_FILES := $(wildcard ja/*.org)
HTML_FILES := $(ORG_FILES:.org=.html)

all: $(HTML_FILES) ja/index.html

ja/%.html: ja/%.org
	emacs --batch -l scripts/org-export.el --visit=$< --eval "(princ (org-export-as 'html))" --kill > $@

ja/index.html: $(HTML_FILES)
	node --experimental-strip-types scripts/gen-index.ts
