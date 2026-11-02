PYTHON ?= python3
VENV_PYTHON := .venv/bin/python
ORIGINAL_DIR ?= ../originals
VERSION ?= 1.0
OPENMSX ?= openmsx
MACHINE_MSX2 ?= Philips_NMS_8250
MACHINE_TURBOR ?= Panasonic_FS-A1GT
OPENMSX_EXTRA ?=
export ORIGINAL_DIR VERSION
.PHONY: all build originals cheat-rom manual release run turbor opl4 cheat cheat-opl4 music clean help
all: build
originals:
	$(PYTHON) tools/check_originals.py
.venv/.deps-installed: requirements.txt
	$(PYTHON) -m venv .venv
	$(VENV_PYTHON) -m pip install -r requirements.txt
	touch $@
build: originals .venv/.deps-installed
	$(VENV_PYTHON) tools/build_rom.py
cheat-rom: originals .venv/.deps-installed
	$(VENV_PYTHON) tools/build_rom.py --cheat
manual: .venv/.deps-installed
	$(MAKE) -C docs/manual
release: build cheat-rom manual
	$(VENV_PYTHON) tools/prepare_release.py
run:
	@test -f release/heroquest.rom -o -f build/heroquest.rom || { echo 'Download heroquest.rom into release/ or run make build first.'; exit 1; }
	$(OPENMSX) -machine $(MACHINE_MSX2) -carta $(if $(wildcard release/heroquest.rom),release/heroquest.rom,build/heroquest.rom) -romtype ASCII16 $(OPENMSX_EXTRA)
turbor:
	$(MAKE) run MACHINE_MSX2=$(MACHINE_TURBOR)
opl4:
	$(MAKE) run OPENMSX_EXTRA='-ext moonsound $(OPENMSX_EXTRA)'
cheat:
	@test -f release/extras/heroquest-cheat.rom -o -f build/heroquest-cheat.rom || { echo 'Download the release ZIP or run make cheat-rom first.'; exit 1; }
	$(OPENMSX) -machine $(MACHINE_MSX2) -carta $(if $(wildcard release/extras/heroquest-cheat.rom),release/extras/heroquest-cheat.rom,build/heroquest-cheat.rom) -romtype ASCII16 $(OPENMSX_EXTRA)
cheat-opl4:
	$(MAKE) cheat OPENMSX_EXTRA='-ext moonsound $(OPENMSX_EXTRA)'
music: .venv/.deps-installed
	$(VENV_PYTHON) tools/build_music.py
clean:
	rm -rf build
	$(MAKE) -C docs/manual clean
help:
	@echo 'make [build]      Build the normal ROM using your original game data'
	@echo 'make cheat-rom    Build the optional cheat ROM'
	@echo 'make manual       Rebuild both PDF manuals'
	@echo 'make release      Package ROMs, manuals, ZIP and checksums'
	@echo 'make run|opl4|turbor|cheat|cheat-opl4  Play a downloaded or built ROM'
	@echo 'make music        Convert user-supplied Amiga modules (optional)'
	@echo 'make clean        Remove generated build files'
	@echo 'See docs/BUILDING.md for original media and ORIGINAL_DIR.'
