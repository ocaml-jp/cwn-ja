ORG_FILES := $(wildcard ja/*.org)
HTML_FILES := $(ORG_FILES:.org=.html)

all: $(HTML_FILES)

ja/%.html: ja/%.org
	emacs --batch --visit=$< --eval "(princ (org-export-as 'html))" --kill > $@
