const std = @import("std");

pub const Level = enum {
    info,
    warn,
    err,
    success,
    debug,
};

const c = @cImport({
    @cInclude("time.h");
});

pub const Logger = struct {
    alloc: std.mem.Allocator,
    name: []const u8 = "zippy",
    use_color: bool = true,

    // ANSI
    const Reset = "\x1b[0m";
    const Dim = "\x1b[2m";
    const Red = "\x1b[31m";
    const Yellow = "\x1b[33m";
    const Green = "\x1b[32m";
    const Cyan = "\x1b[36m";

    pub fn init(alloc: std.mem.Allocator, name: []const u8) Logger {
        const stderr_is_tty = std.posix.isatty(std.fs.File.stderr().handle);
        return .{
            .alloc = alloc,
            .name = name,
            .use_color = stderr_is_tty,
        };
    }

    pub fn setColor(self: *Logger, enabled: bool) void {
        self.use_color = enabled;
    }

    pub fn info(self: *Logger, comptime fmt: []const u8, args: anytype) !void {
        try self.log(.info, fmt, args);
    }
    pub fn warn(self: *Logger, comptime fmt: []const u8, args: anytype) !void {
        try self.log(.warn, fmt, args);
    }
    pub fn err(self: *Logger, comptime fmt: []const u8, args: anytype) !void {
        try self.log(.err, fmt, args);
    }
    pub fn success(self: *Logger, comptime fmt: []const u8, args: anytype) !void {
        try self.log(.success, fmt, args);
    }
    pub fn debug(self: *Logger, comptime fmt: []const u8, args: anytype) !void {
        try self.log(.debug, fmt, args);
    }

    pub fn log(self: *Logger, level: Level, comptime fmt: []const u8, args: anytype) !void {
        var arena = std.heap.ArenaAllocator.init(self.alloc);
        defer arena.deinit();
        const a = arena.allocator();

        const ts = try formatTimestamp(a);

        const tag = levelTag(level);
        const tag_color = levelColor(level);

        const msg = try std.fmt.allocPrint(a, fmt, args);

        const errf = std.fs.File.stderr();

        if (self.use_color) {
            const line = try std.fmt.allocPrint(
                a,
                "{s}{s}{s} {s}[{s}]{s} {s}{s}{s} {s}\n",
                .{
                    Dim, ts, Reset, // timestamp
                    tag_color, tag, Reset, // [LEVEL]
                    Cyan, self.name, Reset, // name
                    msg,
                },
            );
            try errf.writeAll(line);
        } else {
            const line = try std.fmt.allocPrint(
                a,
                "{s} [{s}] {s} {s}\n",
                .{ ts, tag, self.name, msg },
            );
            try errf.writeAll(line);
        }
    }

    fn levelTag(level: Level) []const u8 {
        return switch (level) {
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .success => "SUCCESS",
            .debug => "DEBUG",
        };
    }

    fn levelColor(level: Level) []const u8 {
        return switch (level) {
            .info => Cyan,
            .warn => Yellow,
            .err => Red,
            .success => Green,
            .debug => Dim,
        };
    }

    fn formatTimestamp(allocator: std.mem.Allocator) ![]const u8 {
        const ms = std.time.milliTimestamp();
        const sec: i64 = @divTrunc(ms, 1000);
        const msec: i64 = ms - sec * 1000;

        var now: c.time_t = @intCast(sec);
        var parts: c.struct_tm = undefined;

        if (c.localtime_r(&now, &parts) == null) {
            return std.fmt.allocPrint(allocator, "{d}.{d:0>3}", .{ sec, msec });
        }

        var buffer: [32]u8 = undefined;
        const count = c.strftime(&buffer, buffer.len, "%Y-%m-%d %H:%M:%S", &parts);
        if (count == 0) {
            return std.fmt.allocPrint(allocator, "{d}.{d:0>3}", .{ sec, msec });
        }

        return std.fmt.allocPrint(allocator, "{s}.{d:0>3}", .{ buffer[0..@intCast(count)], msec });
    }
};
