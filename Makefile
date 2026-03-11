BUILD_DIR ?= src/build
PREFIX ?= /usr/local
CMAKE ?= cmake
CMAKE_BUILD_TYPE ?= Release
ARGS ?=

.PHONY: build run install clean help

build:
	$(CMAKE) -S src -B $(BUILD_DIR) -DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE)
	$(CMAKE) --build $(BUILD_DIR)

run: build
	$(BUILD_DIR)/zippy $(ARGS)

install: build
	install -d $(PREFIX)/bin
	install $(BUILD_DIR)/zippy $(PREFIX)/bin/zippy
	@echo "Installed to $(PREFIX)/bin/zippy"
	@echo "Add to PATH (bash): export PATH=\"$(PREFIX)/bin:\$$PATH\""

clean:
	rm -rf $(BUILD_DIR)

help:
	@echo "Targets:"
	@echo "  build           Configure and build the C++ src in src/"
	@echo "  run             Build and run locally (set ARGS=\"./path\")"
	@echo "  install         Install to PREFIX/bin (default: /usr/local/bin)"
	@echo "  clean           Remove the CMake build directory"
	@echo "  help            Show this message"
	@echo
	@echo "Vars: CMAKE, BUILD_DIR, CMAKE_BUILD_TYPE, PREFIX, ARGS"
