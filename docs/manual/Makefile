# HeroQuest manuals, styled after Sol Negro (A4), Spanish and English.
# make builds both language editions.
PYTHON ?= ../../.venv/bin/python
LANGS := es en
PDFS := $(addprefix manual-,$(addsuffix .pdf,$(LANGS)))
TEXFILES := $(wildcard *.tex)
ART := img/cover.jpg img/montage-es.png img/montage-en.png img/sticker.png

.PHONY: all pdf images clean
all: pdf
pdf: $(PDFS)
images: $(ART)

$(ART) &: manual.json ../../tools/manual_images.py $(wildcard images/*) img/msx-logo.png
	$(PYTHON) ../../tools/manual_images.py . ../..

manual-%.pdf: $(TEXFILES) $(ART)
	@if command -v pdflatex >/dev/null 2>&1; then \
	  for pass in 1 2 3; do \
	    pdflatex -interaction=nonstopmode -halt-on-error -jobname=manual-$* '\def\manlang{$*}\input{manual}' || exit $$?; \
	  done; \
	else \
	  trap 'rm -f .manual-$*.tex .manual-$*.pdf' EXIT; \
	  printf '%s\n' '\def\manlang{$*}\input{manual}' > .manual-$*.tex; \
	  tectonic .manual-$*.tex && mv .manual-$*.pdf $@; \
	fi

clean:
	rm -f *.aux *.log *.toc *.out *.fls *.fdb_latexmk
