# Zippy

Zippy is a lightweight Linux CLI that watches a file or directory and reruns your command the moment you save. It’s ideal for C++ development, letting you see the impact of your changes immediately without waiting for a full build.

## Quick start

```bash
# Build from source
make build

# Run from the local build
./build/zippy ./path/to/file-or-dir

# Install it globally
sudo make install

# Or install for your user only
make install PREFIX=$HOME/.local

# Run zippy after install
zippy ./path
```

## Configuration

Zippy loads `Zippy.json` from the current working directory:

```json
{
  "delay": 1000000,
  "ignore": [],
  "save_log": false,
  "log_path": "zippy.log",
  "cmd": "make && ./build/out"
}
```

- `delay` (microseconds): debounce between checks. Default: `1000000`.
- `ignore`: parsed for compatibility and future use; currently not applied.
- `cmd`: command to run when a change is detected. Placeholders: `{file}` and `{dir}`.
- `save_log`: when `true`, append Zippy logs and child output to `log_path`.
- `log_path`: log file path used when `save_log=true`. Default: `zippy.log`.

Generate a starter config with `zippy --generate`.

## CLI commands

- `--help` show help
- `--version` print version
- `--config` print the active config summary
- `--log` print the configured log file when `save_log=true`
- `--clear` truncate the configured log file when `save_log=true`
- `--credits` show credits
- `--generate` write `Zippy.json`

## Example session

```text
2026-03-11 12:45:28.038 [INFO] zippy Starting Zippy v1.3.0
2026-03-11 12:45:28.039 [INFO] zippy Watching file: /home/user/project/src/main.cpp
2026-03-11 12:45:29.201 [INFO] zippy Running: make && ./build/out
2026-03-11 12:45:33.812 [WARN] zippy File changed; re-running command...
Your program output here...
```

## Build and install

Prereqs:

- CMake 3.16+
- A C++20 compiler such as GCC or Clang
- Linux or a Linux-compatible environment

Commands:

- `make build` configures and builds the project
- `make run ARGS="./path"` runs the local build
- `make install PREFIX=/path` installs `zippy` into `PREFIX/bin`
- `make clean` removes the CMake build directory

After install, ensure `PREFIX/bin` is on your `PATH`.
