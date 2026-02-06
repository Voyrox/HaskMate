const std = @import("std");

const commands = @import("commands.zig");
const settings_mod = @import("settings.zig");
const generate = @import("generate.zig");
const logger_mod = @import("logger.zig");
const Colors = commands.Colors;
const projectName = "[Zippy]";
const Logger = logger_mod.Logger;

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
    file_path: []const u8,
    dir_path: []const u8,
) ![]u8 {
    const step1 = try replaceAll(alloc, cmd, "{file}", file_path);
    defer alloc.free(step1);
    return try replaceAll(alloc, step1, "{dir}", dir_path);
}

fn runConfiguredCommand(
    alloc: std.mem.Allocator,
    log: *Logger,
    maybe_settings: ?*const settings_mod.Settings,
    dir_path: []const u8,
    file_path: []const u8,
) !std.process.Child {
    if (maybe_settings == null) {
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

    const s = maybe_settings.?;
    if (s.cmd.len == 0) {
        try log.err("Zippy.json loaded but \"cmd\" is empty", .{});
        return error.Invalid;
    }

    const expanded = try expandPlaceholders(alloc, s.cmd, file_path, dir_path);
    defer alloc.free(expanded);

    try log.info("Running: {s}", .{expanded});

    return try spawnShell(alloc, expanded, dir_path);
}

const WatchState = struct {
    mtime: i128,
    file_path: []const u8,
    owns: bool,
};

fn freeWatchState(alloc: std.mem.Allocator, state: *WatchState) void {
    if (state.owns) alloc.free(state.file_path);
    state.owns = false;
}

fn computeWatchState(
    alloc: std.mem.Allocator,
    watch_dir: []const u8,
    maybe_file: ?[]const u8,
) !WatchState {
    if (maybe_file) |file_path| {
        const st = try std.fs.cwd().statFile(file_path);
        return .{ .mtime = st.mtime, .file_path = file_path, .owns = false };
    }

    var dir = try std.fs.cwd().openDir(watch_dir, .{ .iterate = true });
    defer dir.close();

    const dir_stat = try dir.stat();
    var best_mtime: i128 = dir_stat.mtime;
    var best_path: []const u8 = watch_dir;
    var owns: bool = false;

    var it = dir.iterate();
    while (try it.next()) |entry| {
        const entry_stat = try dir.statFile(entry.name);
        if (entry_stat.mtime > best_mtime) {
            if (owns) alloc.free(best_path);
            best_mtime = entry_stat.mtime;
            best_path = try std.fs.path.join(alloc, &[_][]const u8{ watch_dir, entry.name });
            owns = true;
        }
    }

    return .{ .mtime = best_mtime, .file_path = best_path, .owns = owns };
}

fn monitorScript(
    alloc: std.mem.Allocator,
    log: *Logger,
    delay_us: u64,
    watch_dir: []const u8,
    watch_file: ?[]const u8,
    maybe_settings: ?*const settings_mod.Settings,
) !void {
    var state = try computeWatchState(alloc, watch_dir, watch_file);
    defer freeWatchState(alloc, &state);

    var current_child = try runConfiguredCommand(alloc, log, maybe_settings, watch_dir, state.file_path);

    while (true) {
        std.Thread.sleep(delay_us * std.time.ns_per_us);

        var next = try computeWatchState(alloc, watch_dir, watch_file);
        defer freeWatchState(alloc, &next);

        if (next.mtime > state.mtime) {
            try log.warn("File changed; re-running command…", .{});
            _ = current_child.kill() catch |e| switch (e) {
                error.ProcessNotFound => {},
                else => return e,
            };
            _ = current_child.wait() catch {};

            current_child = try runConfiguredCommand(alloc, log, maybe_settings, watch_dir, next.file_path);

            freeWatchState(alloc, &state);
            state = next;
            next.owns = false;
        }
    }
}

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const alloc = gpa_state.allocator();
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

    if (memory.eql(u8, arg1, "--config")) {
        try commands.displayConfigData();
        return;
    }
    if (memory.eql(u8, arg1, "--log")) {
        try commands.displayLogData();
        return;
    }
    if (memory.eql(u8, arg1, "--clear")) {
        try commands.displayClearData();
        return;
    }
    if (memory.eql(u8, arg1, "--credits")) {
        try commands.displayCreditsData();
        return;
    }

    const jsonPath = "Zippy.json";

    var loaded: ?settings_mod.Settings = null;
    var loaded_ptr: ?*settings_mod.Settings = null;

    const maybe_s = try settings_mod.loadSettings(alloc, jsonPath);
    if (maybe_s) |s| {
        loaded = s;
        loaded_ptr = &loaded.?;
        try log.success("Loaded settings from Zippy.json", .{});
    } else {
        try log.warn("No Zippy.json found; using defaults", .{});
    }

    defer if (loaded_ptr) |p| settings_mod.freeSettings(alloc, p);

    const delay_us: u64 = if (loaded_ptr) |p| (p.delay orelse 1_000_000) else 1_000_000;

    const cwd = try std.fs.cwd().realpathAlloc(alloc, ".");
    defer alloc.free(cwd);

    const targetPath = try std.fs.path.join(alloc, &[_][]const u8{ cwd, arg1 });
    defer alloc.free(targetPath);

    const st = try std.fs.cwd().statFile(targetPath);
    const is_dir = st.kind == .directory;

    const watch_dir: []const u8 = if (is_dir) targetPath else (std.fs.path.dirname(targetPath) orelse cwd);
    const watch_file: ?[]const u8 = if (is_dir) null else targetPath;

    try log.info("Starting Zippy v1.3.0", .{});
    if (watch_file) |_f| {
        try log.info("Watching file: {s}", .{_f});
    } else {
        try log.info("Watching directory: {s}", .{watch_dir});
    }
    try log.info("Press Ctrl+C to exit", .{});

    try monitorScript(alloc, &log, delay_us, watch_dir, watch_file, loaded_ptr);
}
