# Zippy: A file-watching CLI for faster edit–build–run loops

Zippy is a lightweight CLI that watches a file or directory and reruns your command the moment you save. It keeps your stdout clean, logs to stderr with levels, and stays out of your way during the edit–build–run loop.

## Quick start

```bash
# Run from source (Linux/Arch):
make build
zig build run -- path/to/file-or-dir

# Install it globally
sudo make install                   # /usr/local on Linux | %LOCALAPPDATA%/Programs/zippy on Windows
sudo make install PREFIX=$HOME/.local  # user-local

# Run zippy!
zippy ./path
```

## Configuration

Zippy loads `Zippy.json` from the current working directory:

```json
{
  "delay": 1000000,
  "ignore": [],
  "save_log": false,
  "cmd": "make && ./build/out"
  // OR
  "cmd": "node index.js"
}
```

- `delay` (microseconds): debounce between change checks (default: 1_000_000).
- `ignore`: reserved for future ignore patterns.
- `cmd`: command to execute when changes occur. Placeholders: `{file}` (changed file or watched dir), `{dir}` (watched directory).
- `save_log` (bool): when true, also write logs to `log_path` (default: `false`).
- `log_path` (string): path to the log file when `save_log` is true (default: `zippy.log`).
  When `save_log=true`, child command stdout/stderr is tee’d into the same log.

Generate a starter config: `zippy --generate`.

## CLI commands

- `--help` show help
- `--version` print version
- `--commands` list commands
- `--config` show config help
- `--log` print the configured log file (when `save_log=true`; includes child output)
- `--clear` truncate the configured log file (when `save_log=true`)
- `--credits` show credits
- `--generate` write `Zippy.json`

## Example session

```text
2026-02-06 16:22:11.104 [INFO] Zippy Starting Zippy v1.3.0
2026-02-06 16:22:11.105 [INFO] Zippy Watching: /home/user/project/src
2026-02-06 16:22:13.412 [INFO] Zippy Running: make && ./build/out
2026-02-06 16:22:17.998 [WARN] Zippy File changed; re-running command…
Your program output here...
```

## Build & install

Prereqs: Zig 0.15.2+

- Linux/Arch (native):
  - `make build`
  - `sudo make install` (defaults to `/usr/local`; override with `PREFIX=/path`)
- Windows cross (from Linux host):
  - `make build-windows`
  - `make install PREFIX="$LOCALAPPDATA/Programs/zippy"`
- Add `$(PREFIX)/bin` to your `PATH` if it isn’t already.
