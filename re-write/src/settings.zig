const std = @import("std");

pub const Settings = struct {
    ignore: [][]const u8,
    delay: ?u64,
    cmd: []const u8,
};

const SettingsJson = struct {
    ignore: ?[]const []const u8 = null,
    delay: ?u64 = null,
    cmd: ?[]const u8 = null,
};

pub fn loadSettings(alloc: std.mem.Allocator, path: []const u8) !?Settings {
    var cwd = std.fs.cwd();

    const file = cwd.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close();

    const bytes = try file.readToEndAlloc(alloc, 1024 * 1024);
    defer alloc.free(bytes);

    var parsed = std.json.parseFromSlice(SettingsJson, alloc, bytes, .{ .ignore_unknown_fields = true }) catch |e| {
        std.debug.print("Error decoding settings: {any}\n", .{e});
        return null;
    };
    defer parsed.deinit();

    const pj = parsed.value;

    const ignore_list = pj.ignore orelse &[_][]const u8{};
    const delay_val: ?u64 = pj.delay; // microseconds
    const cmd_val = pj.cmd orelse "";

    var ignore_out = try alloc.alloc([]const u8, ignore_list.len);
    for (ignore_list, 0..) |s, i| ignore_out[i] = try alloc.dupe(u8, s);

    return Settings{
        .ignore = ignore_out,
        .delay = delay_val,
        .cmd = try alloc.dupe(u8, cmd_val),
    };
}

pub fn freeSettings(alloc: std.mem.Allocator, s: *Settings) void {
    for (s.ignore) |it| alloc.free(it);
    alloc.free(s.ignore);
    alloc.free(s.cmd);
}
