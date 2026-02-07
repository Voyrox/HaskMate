const std = @import("std");

pub const Settings = struct {
    ignore: [][]const u8,
    delay: ?u64,
    cmd: []const u8,
    save_log: bool,
    log_path: []const u8,
};

const SettingsFile = struct {
    ignore: ?[]const []const u8 = null,
    delay: ?u64 = null,
    cmd: ?[]const u8 = null,
    save_log: ?bool = null,
    log_path: ?[]const u8 = null,
};

pub const default_delay_us: u64 = 1_000_000;
pub const default_save_log: bool = false;
pub const default_log_path: []const u8 = "zippy.log";

pub fn defaultSettings(allocator: std.mem.Allocator) !Settings {
    return Settings{
        .ignore = try allocator.alloc([]const u8, 0),
        .delay = default_delay_us,
        .cmd = try allocator.dupe(u8, ""),
        .save_log = default_save_log,
        .log_path = try allocator.dupe(u8, default_log_path),
    };
}

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
    const saveLogValue = parsedValue.save_log orelse default_save_log;
    const logPathValue = parsedValue.log_path orelse default_log_path;

    var ignoreOut = try allocator.alloc([]const u8, ignoreList.len);
    for (ignoreList, 0..) |entry, index| ignoreOut[index] = try allocator.dupe(u8, entry);

    return Settings{
        .ignore = ignoreOut,
        .delay = delayValue,
        .cmd = try allocator.dupe(u8, cmdValue),
        .save_log = saveLogValue,
        .log_path = try allocator.dupe(u8, logPathValue),
    };
}

pub fn freeSettings(allocator: std.mem.Allocator, settings: *Settings) void {
    for (settings.ignore) |item| allocator.free(item);
    allocator.free(settings.ignore);
    allocator.free(settings.cmd);
    allocator.free(settings.log_path);
}
