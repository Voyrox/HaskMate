const std = @import("std");

pub const Settings = struct {
    ignore: [][]const u8,
    delay: ?u64,
    cmd: []const u8,
    saveLog: bool,
    logPath: []const u8,
};

const SettingsFile = struct {
    ignore: ?[]const []const u8 = null,
    delay: ?u64 = null,
    cmd: ?[]const u8 = null,
    @"save_log": ?bool = null,
    @"log_path": ?[]const u8 = null,
};

pub const defaultDelayUs: u64 = 1_000_000;
pub const defaultSaveLog: bool = false;
pub const defaultLogPath: []const u8 = "zippy.log";

pub fn defaultSettings(allocator: std.mem.Allocator) !Settings {
    return Settings{
        .ignore = try allocator.alloc([]const u8, 0),
        .delay = defaultDelayUs,
        .cmd = try allocator.dupe(u8, ""),
        .saveLog = defaultSaveLog,
        .logPath = try allocator.dupe(u8, defaultLogPath),
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
    const saveLogValue = parsedValue.@"save_log" orelse defaultSaveLog;
    const logPathValue = parsedValue.@"log_path" orelse defaultLogPath;

    var ignoreOut = try allocator.alloc([]const u8, ignoreList.len);
    for (ignoreList, 0..) |entry, index| ignoreOut[index] = try allocator.dupe(u8, entry);

    return Settings{
        .ignore = ignoreOut,
        .delay = delayValue,
        .cmd = try allocator.dupe(u8, cmdValue),
        .saveLog = saveLogValue,
        .logPath = try allocator.dupe(u8, logPathValue),
    };
}

pub fn freeSettings(allocator: std.mem.Allocator, settings: *Settings) void {
    for (settings.ignore) |item| allocator.free(item);
    allocator.free(settings.ignore);
    allocator.free(settings.cmd);
    allocator.free(settings.logPath);
}
