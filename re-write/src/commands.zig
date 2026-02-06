const std = @import("std");

pub const Colors = struct {
    pub const red = "\x1b[31m";
    pub const white = "\x1b[37m";
    pub const yellow = "\x1b[33m";
    pub const green = "\x1b[32m";
};

fn spr(comptime fmt: []const u8, args: anytype) !void {
    const alloc = std.heap.page_allocator;
    const s = try std.fmt.allocPrint(alloc, fmt, args);
    defer alloc.free(s);
    try std.fs.File.stdout().writeAll(s);
}

fn repeatChar(alloc: std.mem.Allocator, c: u8, count: usize) ![]u8 {
    const buf = try alloc.alloc(u8, count);
    @memset(buf, c);
    return buf;
}

pub fn displayHelpData(alloc: std.mem.Allocator) !void {
    const message = "Welcome to HaskMate!";
    const boxWidth: usize = message.len + 4;
    const dash_count = boxWidth - 2;

    const line_bytes = try alloc.alloc(u8, dash_count * 3);
    defer alloc.free(line_bytes);
    for (0..dash_count) |i| {
        const off = i * 3;
        line_bytes[off + 0] = 0xE2;
        line_bytes[off + 1] = 0x94;
        line_bytes[off + 2] = 0x80;
    }
    const line = line_bytes;

    const padding_count = (boxWidth - message.len - 1) / 2;
    const padding = try repeatChar(alloc, ' ', padding_count);
    defer alloc.free(padding);

    try spr("{s}┌{s}┐\n", .{ Colors.red, line });
    try spr("{s}│{s}{s}{s}{s}{s}│\n", .{ Colors.red, padding, Colors.green, message, Colors.red, padding });
    try spr("{s}└{s}┘\n", .{ Colors.red, line });

    try spr("{s}Arguments:\n", .{Colors.yellow});
    try spr("{s}  scriptPath  Path to the Haskell script you want to monitor\n", .{Colors.white});
    try spr("{s}Example:\n", .{Colors.green});
    try spr("{s}  haskmate app/Main.hs\n", .{Colors.white});
}

pub fn displayCommands() !void {
    try spr("{s}Commands:\n", .{Colors.yellow});
    try spr("{s}  --help      Display help information\n", .{Colors.white});
    try spr("{s}  --version   Display version information/Check for updates\n", .{Colors.white});
    try spr("{s}  --config    Configure HaskMate\n", .{Colors.white});
    try spr("{s}  --log       Display HaskMate log\n", .{Colors.white});
    try spr("{s}  --clear     Clear HaskMate log\n", .{Colors.white});
    try spr("{s}  --credits   Display credits\n", .{Colors.white});
}

pub fn displayConfigData() !void {
    try spr("{s}Configuration:\n", .{Colors.yellow});
    try spr("{s}  --SaveLog=true/false      Save the log to a file\n", .{Colors.white});
}

pub fn displayLogData() !void {
    try spr("{s}Log:\n", .{Colors.yellow});
    try spr("{s}  --logPath=path/to/log      Path to the log file\n", .{Colors.white});
}

pub fn displayClearData() !void {
    try spr("{s}Clear:\n", .{Colors.yellow});
    try spr("{s}  --clearLog=true/false      Clear the log file\n", .{Colors.white});
}

pub fn displayCreditsData() !void {
    try spr("{s}Credits:\n", .{Colors.yellow});
    try spr("{s}Developed by: Voyrox | Ewen MacCulloch\n", .{Colors.green});
    try spr("{s}GitHub: Voyrox\n", .{Colors.green});
    try spr("{s}\n", .{Colors.white});
}

const Release = struct {
    tag_name: []const u8,
};

pub fn displayVersionData() !void {
    try spr("{s}HaskMate version: {s}{s}\n", .{ Colors.green, "v1.3.0", Colors.white });
    try spr("{s}  https://github.com/Voyrox/HaskMate/releases/latest\n", .{Colors.white});
}
