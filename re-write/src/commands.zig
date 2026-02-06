const std = @import("std");

pub const Colors = struct {
    pub const red = "\x1b[31m";
    pub const white = "\x1b[37m";
    pub const yellow = "\x1b[33m";
    pub const green = "\x1b[32m";
};

fn printFmt(comptime fmt: []const u8, args: anytype) !void {
    const allocator = std.heap.page_allocator;
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try std.fs.File.stdout().writeAll(text);
}

fn repeatByte(allocator: std.mem.Allocator, byte: u8, count: usize) ![]u8 {
    const buffer = try allocator.alloc(u8, count);
    @memset(buffer, byte);
    return buffer;
}

pub fn displayHelpData(alloc: std.mem.Allocator) !void {
    const message = "Welcome to Zippy!";
    const boxWidth: usize = message.len + 4;
    const dash_count = boxWidth - 2;

    const lineBytes = try alloc.alloc(u8, dash_count * 3);
    defer alloc.free(lineBytes);
    for (0..dash_count) |i| {
        const offset = i * 3;
        lineBytes[offset + 0] = 0xE2;
        lineBytes[offset + 1] = 0x94;
        lineBytes[offset + 2] = 0x80;
    }
    const line = lineBytes;

    const padding_count = (boxWidth - message.len - 1) / 2;
    const padding = try repeatByte(alloc, ' ', padding_count);
    defer alloc.free(padding);

    try printFmt("{s}┌{s}┐\n", .{ Colors.red, line });
    try printFmt("{s}│{s}{s}{s}{s}{s}│\n", .{ Colors.red, padding, Colors.green, message, Colors.red, padding });
    try printFmt("{s}└{s}┘\n", .{ Colors.red, line });

    try printFmt("{s}Example:\n", .{Colors.green});
    try printFmt("{s}  zippy app/Main.hs\n\n", .{Colors.white});

    try printFmt("{s}Commands:\n", .{Colors.yellow});
    try printFmt("{s}  --help      Display help information\n", .{Colors.white});
    try printFmt("{s}  --version   Display version information/Check for updates\n", .{Colors.white});
    try printFmt("{s}  --config    Configure Zippy\n", .{Colors.white});
    try printFmt("{s}  --log       Display Zippy log\n", .{Colors.white});
    try printFmt("{s}  --clear     Clear Zippy log\n", .{Colors.white});
    try printFmt("{s}  --credits   Display credits\n", .{Colors.white});
}

pub fn displayConfigData() !void {
    try printFmt("{s}Configuration:\n", .{Colors.yellow});
    try printFmt("{s}  --SaveLog=true/false      Save the log to a file\n", .{Colors.white});
}

pub fn displayLogData() !void {
    try printFmt("{s}Log:\n", .{Colors.yellow});
    try printFmt("{s}  --logPath=path/to/log      Path to the log file\n", .{Colors.white});
}

pub fn displayClearData() !void {
    try printFmt("{s}Clear:\n", .{Colors.yellow});
    try printFmt("{s}  --clearLog=true/false      Clear the log file\n", .{Colors.white});
}

pub fn displayCreditsData() !void {
    try printFmt("{s}Credits:\n", .{Colors.yellow});
    try printFmt("{s}Developed by: Voyrox | Ewen MacCulloch\n", .{Colors.green});
    try printFmt("{s}GitHub: Voyrox\n", .{Colors.green});
    try printFmt("{s}\n", .{Colors.white});
}

const Release = struct {
    tag_name: []const u8,
};

pub fn getLatestRelease() !Release {
    const allocator = std.heap.page_allocator;
    const client = std.net.StreamingClient(.{});
    const response = try client.get("https://api.github.com/repos/Voyrox/Zippy/releases/latest", .{});
    defer response.close();

    const body = try response.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(body);

    const json = try std.json.parse(allocator, body);
    defer json.deinit();

    const tag_name = try json.get("tag_name").andThen(std.json.asString);
    return Release{ .tag_name = tag_name };
}

pub fn displayVersionData() !void {
    const latest = try getLatestRelease();
    if (std.mem.eql(u8, latest.tag_name, "v1.3.0")) {
        try printFmt("{s}You are running the latest version: {s}{s}\n", .{ Colors.green, "v1.3.0", Colors.white });
    } else {
        try printFmt("{s}A new version is available: {s}{s}\n", .{ Colors.yellow, latest.tag_name, Colors.white });
        try printFmt("{s}Please update to the latest version for new features and bug fixes.\n", .{Colors.white});
    }
    try printFmt("{s}  https://github.com/Voyrox/Zippy/releases/latest\n", .{Colors.white});
}
