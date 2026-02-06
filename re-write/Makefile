ZIG ?= zig
OPT ?= ReleaseFast
WINDOWS_TARGET ?= x86_64-windows-gnu

ifeq ($(OS),Windows_NT)
  HOST_OS := Windows
else
  HOST_OS := $(shell uname -s 2>/dev/null)
endif

ifeq ($(HOST_OS),Windows)
  DEFAULT_PREFIX ?= $(LOCALAPPDATA)/Programs/zippy
else
  DEFAULT_PREFIX ?= /usr/local
endif

PREFIX ?= $(DEFAULT_PREFIX)
PREFIX_FLAG = $(if $(PREFIX),-p $(PREFIX),)

.PHONY: build build-linux build-windows install clean help

build:
	$(ZIG) build -Doptimize=$(OPT)

build-linux: build

build-windows:
	$(ZIG) build -Doptimize=$(OPT) -Dtarget=$(WINDOWS_TARGET)

install:
	$(ZIG) build -Doptimize=$(OPT) install $(PREFIX_FLAG)
	@echo "Installed to $(PREFIX)/bin (ensure this is on PATH)."
	@if [ "$(HOST_OS)" = "Windows" ]; then \
	  printf "Add to PATH (PowerShell): [Environment]::SetEnvironmentVariable(\"Path\", \"%s;$(PREFIX)/bin\", \"User\")\n" "$$(powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','User')")"; \
	else \
	  echo "Add to PATH (bash): export PATH=\"$(PREFIX)/bin:\$$PATH\""; \
	fi

clean:
	$(ZIG) build --clean

help:
	@echo "Targets:"
	@echo "  build           Build for host (Arch/Linux)"
	@echo "  build-windows   Cross-compile for Windows (x86_64)"
	@echo "  install         Install to host-appropriate prefix (override with PREFIX)"
	@echo "  clean           Remove build artifacts"
	@echo "  help            Show this message"
	@echo
	@echo "Vars: ZIG, OPT (Debug/ReleaseSafe/ReleaseFast/ReleaseSmall), WINDOWS_TARGET, PREFIX"
