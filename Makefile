xml2rfc ?= xml2rfc
kramdown-rfc2629 ?= kramdown-rfc2629

drafts := draft-cheshire-sbm.xml draft-cheshire-sbm.txt draft-cheshire-sbm.html

all: $(drafts)

%.xml: %.md
	@echo "Converting MD to XML"
	$(kramdown-rfc2629) $< > $@

%.txt: %.xml
	@echo "Converting XML to TXT"
	$(xml2rfc) $< > $@

%.html: %.xml
	@echo "Converting XML to HTML"
	$(xml2rfc) --html $<  > $@

clean:
	@echo "Cleaning"
	rm -rf $(drafts)
