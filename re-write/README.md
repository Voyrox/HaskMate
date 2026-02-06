# Zippy: fast feedback for Haskell

Zippy is a lightweight Zig-built CLI that watches a single Haskell source file and reruns your command the moment you save. It keeps your stdout clean, logs to stderr with levels, and stays out of your way during the edit–compile–run loop.

## Quick start

```bash
# Run from source (Linux/Arch):
make build
zig build run -- path/to/Main.hs

# Install it globally
make install          # (Recommended) /usr/local on Linux | %LOCALAPPDATA%/Programs/zippy on Windows
make install PREFIX=$HOME/.local   # user-local
zippy ./Main.hs
```

## Configuration

Zippy loads `Zippy.json` from the current working directory:

```json
{
  "delay": 1000000,
  "ignore": [],
  "cmd": "stack ghc -- {file} && {dir}/Main"
}
```

- `delay` (microseconds): debounce between change checks (default: 1_000_000).
- `ignore`: reserved for future ignore patterns.
- `cmd`: command to execute when the watched file changes. Placeholders: `{file}` (absolute path), `{dir}` (containing directory).

Generate a starter config: `zippy --generate`.

## CLI commands

- `--help` show help
- `--version` print version
- `--commands` list commands
- `--config` show config help
- `--log` log options
- `--clear` clear log (future)
- `--credits` show credits
- `--generate` write `Zippy.json`

## Example session

```text
2026-02-06 16:22:11.104 [INFO] Zippy Starting Zippy v1.3.0
2026-02-06 16:22:11.105 [INFO] Zippy Watching: /home/user/project/app/Main.hs
2026-02-06 16:22:13.412 [INFO] Zippy Running: stack ghc -- /home/user/project/app/Main.hs && ./app/Main
2026-02-06 16:22:17.998 [WARN] Zippy File changed; re-running command…
```

## Features

- File watcher tuned for a single Haskell entry point
- Instant rebuild + re-run with configurable commands
- Structured, TTY-aware logging to stderr (INFO/WARN/ERROR/SUCCESS/DEBUG)
- Placeholder expansion `{file}` and `{dir}` in commands
- Zero runtime deps beyond Zig + your Haskell toolchain

## Build & install

Prereqs: Zig 0.15.2+

- Linux/Arch (native):
  - `make build`
  - `make install` (defaults to `/usr/local`; override with `PREFIX=/path`)
- Windows cross (from Linux host):
  - `make build-windows`
  - `make install PREFIX="$LOCALAPPDATA/Programs/zippy"`
- Add `$(PREFIX)/bin` to your `PATH` if it isn’t already.

Run after install:

```bash
zippy app/Main.hs
```
