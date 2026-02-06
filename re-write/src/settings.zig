const std = @import("std");

pub const Settings = struct {
    ignore: [][]const u8,
    delay: ?u64,
    cmd: []const u8,
};

const SettingsFile = struct {
    ignore: ?[]const []const u8 = null,
    delay: ?u64 = null,
    cmd: ?[]const u8 = null,
};

pub fn loadSettings(allocator: std.mem.Allocator, path: []const u8) !?Settings {
    var cwd = std.fs.cwd();

    const file = cwd.openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(bytes);

    var parsed = std.json.parseFromSlice(SettingsFile, allocator, bytes, .{ .ignore_unknown_fields = true }) catch {
        return null;
    };
    defer parsed.deinit();

    const parsedValue = parsed.value;

    const ignoreList = parsedValue.ignore orelse &[_][]const u8{};
    const delayValue: ?u64 = parsedValue.delay;
    const cmdValue = parsedValue.cmd orelse "";

    var ignoreOut = try allocator.alloc([]const u8, ignoreList.len);
    for (ignoreList, 0..) |entry, index| ignoreOut[index] = try allocator.dupe(u8, entry);

    return Settings{
        .ignore = ignoreOut,
        .delay = delayValue,
        .cmd = try allocator.dupe(u8, cmdValue),
    };
}

pub fn freeSettings(allocator: std.mem.Allocator, settings: *Settings) void {
    for (settings.ignore) |item| allocator.free(item);
    allocator.free(settings.ignore);
    allocator.free(settings.cmd);
}
