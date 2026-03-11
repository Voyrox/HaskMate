const std = @import("std");

const commands = @import("commands.zig");
const settingsMod = @import("settings.zig");
const generate = @import("generate.zig");
const loggerMod = @import("logger.zig");
const Colors = commands.Colors;
const projectName = "[Zippy]";
const Logger = loggerMod.Logger;

fn outWriteAll(s: []const u8) !void {
    try std.fs.File.stdout().writeAll(s);
}

fn outPrint(comptime fmt: []const u8, args: anytype) !void {
    const alloc = std.heap.page_allocator;
    const s = try std.fmt.allocPrint(alloc, fmt, args);
    defer alloc.free(s);
    try std.fs.File.stdout().writeAll(s);
}

fn getLastModifiedNs(path: []const u8) !i128 {
    const st = std.fs.cwd().statFile(path) catch |err| switch (err) {
        error.FileNotFound => return std.time.nanoTimestamp(),
        else => return err,
    };
    return st.mtime;
}

fn spawnShell(alloc: std.mem.Allocator, cmd: []const u8, cwd: []const u8) !std.process.Child {
    var child = std.process.Child.init(&[_][]const u8{ "sh", "-c", cmd }, alloc);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    child.cwd = cwd;
    try child.spawn();
    return child;
}

fn replaceAll(
    allocator: std.mem.Allocator,
    source: []const u8,
    needle: []const u8,
    replacement: []const u8,
) ![]u8 {
    var matchCount: usize = 0;
    var cursor: usize = 0;

    while (cursor + needle.len <= source.len) : (cursor += 1) {
        if (std.mem.eql(u8, source[cursor .. cursor + needle.len], needle)) {
            matchCount += 1;
            cursor += needle.len - 1;
        }
    }

    if (matchCount == 0) return try allocator.dupe(u8, source);

    const newLen = source.len + matchCount * (replacement.len - needle.len);
    var result = try allocator.alloc(u8, newLen);

    var srcIndex: usize = 0;
    var dstIndex: usize = 0;

    while (srcIndex < source.len) {
        const remaining = source.len - srcIndex;
        const isMatch = remaining >= needle.len and std.mem.eql(u8, source[srcIndex .. srcIndex + needle.len], needle);

        if (isMatch) {
            std.mem.copyForwards(u8, result[dstIndex .. dstIndex + replacement.len], replacement);
            dstIndex += replacement.len;
            srcIndex += needle.len;
        } else {
            result[dstIndex] = source[srcIndex];
            dstIndex += 1;
            srcIndex += 1;
        }
    }

    return result;
}

fn expandPlaceholders(
    alloc: std.mem.Allocator,
    cmd: []const u8,
    filePath: []const u8,
    dirPath: []const u8,
) ![]u8 {
    const step1 = try replaceAll(alloc, cmd, "{file}", filePath);
    defer alloc.free(step1);
    return try replaceAll(alloc, step1, "{dir}", dirPath);
}

fn printSettingsSummary(
    settings: *const settingsMod.Settings,
    hasFile: bool,
) !void {
    const effectiveDelay = settings.delay orelse settingsMod.defaultDelayUs;
    try outPrint(
        "Zippy configuration ({s}):\n",
        .{if (hasFile) "from Zippy.json" else "defaults"},
    );
    try outPrint("  delay (us): {d}\n", .{effectiveDelay});
    try outPrint("  cmd      : {s}\n", .{settings.cmd});
    try outPrint("  save_log : {s}\n", .{if (settings.saveLog) "true" else "false"});
    try outPrint("  log_path : {s}\n", .{settings.logPath});
}

fn runConfiguredCommand(
    alloc: std.mem.Allocator,
    log: *Logger,
    maybeSettings: ?*const settingsMod.Settings,
    dirPath: []const u8,
    filePath: []const u8,
) !std.process.Child {
    if (maybeSettings == null) {
        try log.warn("No Zippy.json found. Create one with --generate", .{});
        try std.fs.File.stderr().writeAll(
            "{\n" ++
                "  \"delay\": 1000000,\n" ++
                "  \"ignore\": [],\n" ++
                "  \"cmd\": \"<your command here>\"\n" ++
                "}\n" ++
                "Placeholders: {file} (absolute path), {dir} (directory)\n",
        );
        return error.Invalid;
    }

    const s = maybeSettings.?;
    if (s.cmd.len == 0) {
        try log.err("Zippy.json loaded but \"cmd\" is empty", .{});
        return error.Invalid;
    }

    const expanded = try expandPlaceholders(alloc, s.cmd, filePath, dirPath);
    defer alloc.free(expanded);

    try log.info("Running: {s}", .{expanded});

    if (!s.saveLog) {
        return try spawnShell(alloc, expanded, dirPath);
    }

    // When save_log is enabled, capture stdout/stderr and mirror to both stdout and the log file.
    var child = std.process.Child.init(&[_][]const u8{ "sh", "-c", expanded }, alloc);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.cwd = dirPath;
    try child.spawn();

    // Stream stdout (and merged stderr when possible).
    if (child.stdout) |*outp| {
        var buffer: [4096]u8 = undefined;
        while (true) {
            const n = try outp.read(&buffer);
            if (n == 0) break;
            const slice = buffer[0..n];
            _ = std.fs.File.stdout().writeAll(slice) catch {};
            log.writeRaw(slice);
        }
    }

    if (child.stderr) |*errp| {
        var buffer: [4096]u8 = undefined;
        while (true) {
            const n = try errp.read(&buffer);
            if (n == 0) break;
            const slice = buffer[0..n];
            _ = std.fs.File.stderr().writeAll(slice) catch {};
            log.writeRaw(slice);
        }
    }

    return child;
}

const WatchState = struct {
    mtime: i128,
    filePath: []const u8,
    owns: bool,
};

fn freeWatchState(alloc: std.mem.Allocator, state: *WatchState) void {
    if (state.owns) alloc.free(state.filePath);
    state.owns = false;
}

fn computeWatchState(
    alloc: std.mem.Allocator,
    watchDir: []const u8,
    maybeFile: ?[]const u8,
) !WatchState {
    if (maybeFile) |filePath| {
        const st = try std.fs.cwd().statFile(filePath);
        return .{ .mtime = st.mtime, .filePath = filePath, .owns = false };
    }

    var dir = try std.fs.cwd().openDir(watchDir, .{ .iterate = true });
    defer dir.close();

    const dirStat = try dir.stat();
    var bestMtime: i128 = dirStat.mtime;
    var bestPath: []const u8 = watchDir;
    var owns: bool = false;

    var it = dir.iterate();
    while (try it.next()) |entry| {
        const entryStat = try dir.statFile(entry.name);
        if (entryStat.mtime > bestMtime) {
            if (owns) alloc.free(bestPath);
            bestMtime = entryStat.mtime;
            bestPath = try std.fs.path.join(alloc, &[_][]const u8{ watchDir, entry.name });
            owns = true;
        }
    }

    return .{ .mtime = bestMtime, .filePath = bestPath, .owns = owns };
}

fn monitorScript(
    alloc: std.mem.Allocator,
    log: *Logger,
    delayUs: u64,
    watchDir: []const u8,
    watchFile: ?[]const u8,
    maybeSettings: ?*const settingsMod.Settings,
) !void {
    var state = try computeWatchState(alloc, watchDir, watchFile);
    defer freeWatchState(alloc, &state);

    var currentChild = try runConfiguredCommand(alloc, log, maybeSettings, watchDir, state.filePath);

    while (true) {
        std.Thread.sleep(delayUs * std.time.ns_per_us);

        var next = try computeWatchState(alloc, watchDir, watchFile);
        defer freeWatchState(alloc, &next);

        if (next.mtime > state.mtime) {
            try log.warn("File changed; re-running command…", .{});
            _ = currentChild.kill() catch |e| switch (e) {
                error.ProcessNotFound => {},
                else => return e,
            };
            _ = currentChild.wait() catch {};

            currentChild = try runConfiguredCommand(alloc, log, maybeSettings, watchDir, next.filePath);

            freeWatchState(alloc, &state);
            state = next;
            next.owns = false;
        }
    }
}

pub fn main() !void {
    var gpaState = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpaState.deinit();
    const alloc = gpaState.allocator();
    var log = Logger.init(alloc, "zippy");

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len == 1) {
        try log.err("No path provided. Examples: zippy ./Main.hs or zippy .", .{});
        return;
    }

    const arg1 = args[1];
    const memory = std.mem;

    if (memory.eql(u8, arg1, "--help") or memory.eql(u8, arg1, "--h")) {
        try commands.displayHelpData(alloc);
        return;
    }
    if (memory.eql(u8, arg1, "--generate") or memory.eql(u8, arg1, "--gen")) {
        try generate.generateConfig();
        return;
    }
    if (memory.eql(u8, arg1, "--version") or memory.eql(u8, arg1, "--v")) {
        try commands.displayVersionData();
        return;
    }

    if (memory.eql(u8, arg1, "--credits")) {
        try commands.displayCreditsData();
        return;
    }

    const jsonPath = "Zippy.json";

    var loaded: ?settingsMod.Settings = null;
    var loadedPtr: ?*settingsMod.Settings = null;

    const maybeSettings = try settingsMod.loadSettings(alloc, jsonPath);
    if (maybeSettings) |s| {
        loaded = s;
        loadedPtr = &loaded.?;
        try log.success("Loaded settings from Zippy.json", .{});
    } else {
        loaded = try settingsMod.defaultSettings(alloc);
        loadedPtr = &loaded.?;
        try log.warn("No Zippy.json found; using defaults", .{});
    }

    defer if (loadedPtr) |p| settingsMod.freeSettings(alloc, p);

    const delayUs: u64 = if (loadedPtr) |p| (p.delay orelse settingsMod.defaultDelayUs) else settingsMod.defaultDelayUs;

    if (loadedPtr) |p| {
        if (p.saveLog) {
            log.enableFileLogging(p.logPath) catch |err| {
                try log.warn("Could not open log file {s}: {s}", .{ p.logPath, @errorName(err) });
            };
        }
    }

    if (memory.eql(u8, arg1, "--config")) {
        try printSettingsSummary(loadedPtr.?, maybeSettings != null);
        return;
    }
    if (memory.eql(u8, arg1, "--log")) {
        if (loadedPtr.?.saveLog) {
            const logFile = std.fs.cwd().openFile(loadedPtr.?.logPath, .{}) catch |err| switch (err) {
                error.FileNotFound => {
                    try log.warn("Log file not found: {s}", .{loadedPtr.?.logPath});
                    return;
                },
                else => return err,
            };
            defer logFile.close();
            const contents = try logFile.readToEndAlloc(alloc, 10 * 1024 * 1024);
            defer alloc.free(contents);
            try outWriteAll(contents);
        } else {
            try log.warn("Logging is disabled (save_log=false)", .{});
        }
        return;
    }
    if (memory.eql(u8, arg1, "--clear")) {
        if (loadedPtr.?.saveLog) {
            if (log.file) |*f| {
                f.seekTo(0) catch {};
                f.setEndPos(0) catch {};
            } else {
                std.fs.cwd().writeFile(.{ .sub_path = loadedPtr.?.logPath, .data = "" }) catch |err| switch (err) {
                    error.FileNotFound => try log.warn("Log file not found: {s}", .{loadedPtr.?.logPath}),
                    else => return err,
                };
            }
            try log.info("Log cleared: {s}", .{loadedPtr.?.logPath});
        } else {
            try log.warn("Logging is disabled (save_log=false)", .{});
        }
        return;
    }

    const cwd = try std.fs.cwd().realpathAlloc(alloc, ".");
    defer alloc.free(cwd);

    const targetPath = try std.fs.path.join(alloc, &[_][]const u8{ cwd, arg1 });
    defer alloc.free(targetPath);

    const st = try std.fs.cwd().statFile(targetPath);
    const isDir = st.kind == .directory;

    const watchDir: []const u8 = if (isDir) targetPath else (std.fs.path.dirname(targetPath) orelse cwd);
    const watchFile: ?[]const u8 = if (isDir) null else targetPath;

    try log.info("Starting Zippy v1.3.0", .{});
    if (loadedPtr) |p| {
        if (p.saveLog) {
            try log.info("Logging to: {s}", .{p.logPath});
        }
    }
    if (watchFile) |watchedFile| {
        try log.info("Watching file: {s}", .{watchedFile});
    } else {
        try log.info("Watching directory: {s}", .{watchDir});
    }
    try log.info("Press Ctrl+C to exit", .{});

    defer log.deinit();

    try monitorScript(alloc, &log, delayUs, watchDir, watchFile, loadedPtr);
}
