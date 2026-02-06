const std = @import("std");

const commands = @import("commands.zig");
const settings_mod = @import("settings.zig");
const generate = @import("generate.zig");

const Colors = commands.Colors;
const projectName = "[HaskMate]";

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

fn spawnShell(alloc: std.mem.Allocator, cmd: []const u8) !std.process.Child {
    var child = std.process.Child.init(&[_][]const u8{ "sh", "-c", cmd }, alloc);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    return child;
}

fn waitAndReport(child: *std.process.Child) !void {
    const term = try child.wait();
    switch (term) {
        .Exited => |code| {
            if (code != 0) try outPrint("{s}{s}{s} Command exited with code {d}\n", .{
                Colors.red, projectName, Colors.white, code,
            });
        },
        else => {},
    }
}

fn replaceAllAlloc(
    alloc: std.mem.Allocator,
    input: []const u8,
    needle: []const u8,
    replacement: []const u8,
) ![]u8 {
    var count: usize = 0;
    var i: usize = 0;
    while (i + needle.len <= input.len) : (i += 1) {
        if (std.mem.eql(u8, input[i .. i + needle.len], needle)) {
            count += 1;
            i += needle.len - 1;
        }
    }
    if (count == 0) return try alloc.dupe(u8, input);

    const new_len = input.len + count * (replacement.len - needle.len);
    var out = try alloc.alloc(u8, new_len);

    var in_idx: usize = 0;
    var out_idx: usize = 0;

    while (in_idx < input.len) {
        if (in_idx + needle.len <= input.len and std.mem.eql(u8, input[in_idx .. in_idx + needle.len], needle)) {
            std.mem.copyForwards(u8, out[out_idx .. out_idx + replacement.len], replacement);
            out_idx += replacement.len;
            in_idx += needle.len;
        } else {
            out[out_idx] = input[in_idx];
            out_idx += 1;
            in_idx += 1;
        }
    }

    return out;
}

fn expandPlaceholders(
    alloc: std.mem.Allocator,
    cmd: []const u8,
    file_path: []const u8,
    dir_path: []const u8,
) ![]u8 {
    const step1 = try replaceAllAlloc(alloc, cmd, "{file}", file_path);
    defer alloc.free(step1);
    return try replaceAllAlloc(alloc, step1, "{dir}", dir_path);
}

fn runConfiguredCommand(
    alloc: std.mem.Allocator,
    maybe_settings: ?*const settings_mod.Settings,
    fullPath: []const u8,
) !void {
    if (maybe_settings == null) {
        try outWriteAll(
            "No HaskMate.json found.\n" ++
                "Create one with:\n" ++
                "{\n" ++
                "  \"delay\": 1000000,\n" ++
                "  \"ignore\": [],\n" ++
                "  \"cmd\": \"<your command here>\"\n" ++
                "}\n" ++
                "Placeholders: {file} (absolute path), {dir} (directory)\n",
        );
        return;
    }

    const s = maybe_settings.?;
    if (s.cmd.len == 0) {
        try outWriteAll(
            "HaskMate.json loaded but \"cmd\" is empty.\n" ++
                "Set \"cmd\" to what you want to run.\n" ++
                "You can use {file} and {dir} placeholders.\n",
        );
        return;
    }

    const dir_path = std.fs.path.dirname(fullPath) orelse ".";
    const expanded = try expandPlaceholders(alloc, s.cmd, fullPath, dir_path);
    defer alloc.free(expanded);

    try outPrint("{s}{s}{s} Running: {s}\n", .{
        Colors.green, projectName, Colors.white, expanded,
    });

    var child = try spawnShell(alloc, expanded);
    try waitAndReport(&child);
}

fn monitorScript(
    alloc: std.mem.Allocator,
    delay_us: u64,
    fullPath: []const u8,
    maybe_settings: ?*const settings_mod.Settings,
) !void {
    try runConfiguredCommand(alloc, maybe_settings, fullPath);
    var last = try getLastModifiedNs(fullPath);

    while (true) {
        std.Thread.sleep(delay_us * std.time.ns_per_us);

        const current = try getLastModifiedNs(fullPath);
        if (current > last) {
            try outPrint("{s}{s}{s} Detected file modification. Running command...\n", .{
                Colors.yellow, projectName, Colors.white,
            });

            try runConfiguredCommand(alloc, maybe_settings, fullPath);
            last = try getLastModifiedNs(fullPath);
        }
    }
}

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const alloc = gpa_state.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len == 1) {
        try outWriteAll("Please provide a file to monitor as an argument.\nExample: haskmate ../test/app/test.hs\n");
        return;
    }

    const arg1 = args[1];

    if (std.mem.eql(u8, arg1, "--help") or std.mem.eql(u8, arg1, "--h")) {
        try commands.displayHelpData(alloc);
        return;
    }
    if (std.mem.eql(u8, arg1, "--generate") or std.mem.eql(u8, arg1, "--gen")) {
        try generate.generateConfig();
        return;
    }
    if (std.mem.eql(u8, arg1, "--version") or std.mem.eql(u8, arg1, "--v")) {
        try commands.displayVersionData();
        return;
    }
    if (std.mem.eql(u8, arg1, "--commands")) {
        try commands.displayCommands();
        return;
    }
    if (std.mem.eql(u8, arg1, "--config")) {
        try commands.displayConfigData();
        return;
    }
    if (std.mem.eql(u8, arg1, "--log")) {
        try commands.displayLogData();
        return;
    }
    if (std.mem.eql(u8, arg1, "--clear")) {
        try commands.displayClearData();
        return;
    }
    if (std.mem.eql(u8, arg1, "--credits")) {
        try commands.displayCreditsData();
        return;
    }

    const jsonPath = "HaskMate.json";

    var loaded: ?settings_mod.Settings = null;
    var loaded_ptr: ?*settings_mod.Settings = null;

    const maybe_s = try settings_mod.loadSettings(alloc, jsonPath);
    if (maybe_s) |s| {
        loaded = s;
        loaded_ptr = &loaded.?;
        try outPrint("{s}{s}{s} Loaded settings from HaskMate.json\n", .{
            Colors.green, projectName, Colors.white,
        });
    } else {
        try outPrint("{s}{s}{s} No HaskMate.json file found. Using default settings.\n", .{
            Colors.yellow, projectName, Colors.white,
        });
    }
    defer if (loaded_ptr) |p| settings_mod.freeSettings(alloc, p);

    const delay_us: u64 = if (loaded_ptr) |p| (p.delay orelse 1_000_000) else 1_000_000;

    const cwd = try std.fs.cwd().realpathAlloc(alloc, ".");
    defer alloc.free(cwd);

    const fullPath = try std.fs.path.join(alloc, &[_][]const u8{ cwd, arg1 });
    defer alloc.free(fullPath);

    try outPrint("{s}{s}{s} Starting HaskMate v1.3.0...\n", .{ Colors.green, projectName, Colors.white });
    try outPrint("{s}{s}{s} Watching: {s}\n", .{ Colors.green, projectName, Colors.white, fullPath });
    try outPrint("{s}{s}{s} Press {s}Ctrl+C{s} to exit.\n", .{
        Colors.green, projectName, Colors.white, Colors.red, Colors.white,
    });

    try monitorScript(alloc, delay_us, fullPath, loaded_ptr);
}
