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
            if (code != 0) try outPrint("{s}{s}{s} Process exited with code {d}\n", .{
                Colors.red, projectName, Colors.white, code,
            });
        },
        else => {},
    }
}

fn exePathFromHs(alloc: std.mem.Allocator, hs_path: []const u8) ![]u8 {
    if (hs_path.len >= 3 and std.mem.eql(u8, hs_path[hs_path.len - 3 ..], ".hs")) {
        return try alloc.dupe(u8, hs_path[0 .. hs_path.len - 3]);
    }
    return try alloc.dupe(u8, hs_path);
}

fn runScriptOrCmd(
    alloc: std.mem.Allocator,
    maybe_settings: ?*const settings_mod.Settings,
    fullPath: []const u8,
) !void {
    const rootPath = std.fs.path.dirname(fullPath) orelse ".";
    const exe_path = try exePathFromHs(alloc, fullPath);
    defer alloc.free(exe_path);

    if (maybe_settings) |s| {
        if (s.cmd.len != 0) {
            var c = try spawnShell(alloc, s.cmd);
            try waitAndReport(&c);
            return;
        }

        if (std.mem.eql(u8, s.script, "runghc") or std.mem.eql(u8, s.script, "runhaskell")) {
            const cmd = try std.fmt.allocPrint(alloc, "{s} {s}", .{ s.script, fullPath });
            defer alloc.free(cmd);
            var c = try spawnShell(alloc, cmd);
            try waitAndReport(&c);
            return;
        }

        if (std.mem.eql(u8, s.script, "ghc") or std.mem.eql(u8, s.script, "stack") or std.mem.eql(u8, s.script, "cabal")) {
            if (std.mem.eql(u8, s.script, "cabal")) {
                const cmd = try std.fmt.allocPrint(alloc, "cd {s} && cabal build && cabal run", .{rootPath});
                defer alloc.free(cmd);
                var c = try spawnShell(alloc, cmd);
                try waitAndReport(&c);
                return;
            }

            if (std.mem.eql(u8, s.script, "stack")) {
                const build_cmd = try std.fmt.allocPrint(alloc, "stack ghc -- {s}", .{fullPath});
                defer alloc.free(build_cmd);
                var c1 = try spawnShell(alloc, build_cmd);
                try waitAndReport(&c1);

                const run_cmd = try std.fmt.allocPrint(alloc, "{s}", .{exe_path});
                defer alloc.free(run_cmd);
                var c2 = try spawnShell(alloc, run_cmd);
                try waitAndReport(&c2);
                return;
            }

            const build_cmd = try std.fmt.allocPrint(alloc, "ghc {s}", .{fullPath});
            defer alloc.free(build_cmd);
            var c1 = try spawnShell(alloc, build_cmd);
            try waitAndReport(&c1);

            const run_cmd = try std.fmt.allocPrint(alloc, "{s}", .{exe_path});
            defer alloc.free(run_cmd);
            var c2 = try spawnShell(alloc, run_cmd);
            try waitAndReport(&c2);
            return;
        }

        if (s.script.len != 0) {
            var c = try spawnShell(alloc, s.script);
            try waitAndReport(&c);
            return;
        }
    }

    const build_cmd = try std.fmt.allocPrint(alloc, "stack ghc -- {s}", .{fullPath});
    defer alloc.free(build_cmd);
    var c1 = try spawnShell(alloc, build_cmd);
    try waitAndReport(&c1);

    var c2 = try spawnShell(alloc, exe_path);
    try waitAndReport(&c2);
}

fn monitorScript(
    alloc: std.mem.Allocator,
    delay_us: u64,
    fullPath: []const u8,
    maybe_settings: ?*const settings_mod.Settings,
) !void {
    try runScriptOrCmd(alloc, maybe_settings, fullPath);
    var last = try getLastModifiedNs(fullPath);

    while (true) {
        std.Thread.sleep(delay_us * std.time.ns_per_us);

        const current = try getLastModifiedNs(fullPath);
        if (current > last) {
            try outPrint("{s}{s}{s} Detected file modification. Rebuilding and running...\n", .{
                Colors.yellow, projectName, Colors.white,
            });

            try runScriptOrCmd(alloc, maybe_settings, fullPath);

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
        try outWriteAll("Please provide a file to monitor as an argument.\nExample: HaskMate app/Main.hs\n");
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
    try outPrint("{s}{s}{s} Running script path: {s}\n", .{ Colors.green, projectName, Colors.white, fullPath });
    try outPrint("{s}{s}{s} Watching for file modifications. Press {s}Ctrl+C{s} to exit.\n", .{
        Colors.green, projectName, Colors.white, Colors.red, Colors.white,
    });

    try monitorScript(alloc, delay_us, fullPath, loaded_ptr);
}
