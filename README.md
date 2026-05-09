# Zippy

<div align="center">

<img src="./image.png" alt="Zippy code exec" width="50%">

_A modern file watcher for fast edit-build-run loops_

[![C++ Version](https://img.shields.io/badge/C++-20-blue.svg)](https://en.cppreference.com/w/cpp/20)
[![License](https://img.shields.io/badge/License-Apache_2.0-green.svg)](LICENSE)

</div>

Zippy is a lightweight Linux CLI that watches a file or directory and reruns your command the moment you save. It is designed for C++ development, but works well anywhere you want quick feedback without manually restarting commands.

## Why Zippy

- Watches a file or directory for changes.
- Reruns your command immediately after a save.
- Supports simple configuration through `Zippy.json`.
- Can keep logs for later inspection.

## Quick Start

```bash
make build
./build/zippy ./path/to/file-or-dir
```

Install it globally:

```bash
sudo make install
```

Or install for your user only:

```bash
make install PREFIX=$HOME/.local
```

After install:

```bash
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

- `delay` is the debounce interval in microseconds. Default: `1000000`.
- `ignore` is parsed for compatibility and future use, but is not currently applied.
- `cmd` is the command to run when a change is detected. Placeholders: `{file}` and `{dir}`.
- `save_log` appends Zippy logs and child output to `log_path` when enabled.
- `log_path` sets the log file name used when `save_log=true`. Default: `zippy.log`.

Generate a starter config with:

```bash
zippy --generate
```

## CLI Reference

- `--help` shows help.
- `--version` prints the version.
- `--config` prints the active config summary.
- `--log` prints the configured log file when `save_log=true`.
- `--clear` truncates the configured log file when `save_log=true`.
- `--credits` shows credits.
- `--generate` writes `Zippy.json`.

## Example Output

```text
2026-03-11 12:45:28.038 [INFO] zippy Starting Zippy v1.3.0
2026-03-11 12:45:28.039 [INFO] zippy Watching file: /home/user/project/src/main.cpp
2026-03-11 12:45:29.201 [INFO] zippy Running: make && ./build/out
2026-03-11 12:45:33.812 [WARN] zippy File changed; re-running command...
Your program output here...
```

## Build And Install

Requirements:

- CMake 3.16+
- A C++20 compiler such as GCC or Clang
- Linux or a Linux-compatible environment

Common commands:

- `make build` configures and builds the project.
- `make run ARGS="./path"` runs the local build.
- `make install PREFIX=/path` installs `zippy` into `PREFIX/bin`.
- `make clean` removes the CMake build directory.

After install, make sure `PREFIX/bin` is on your `PATH`.
