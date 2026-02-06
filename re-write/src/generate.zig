const std = @import("std");

fn spr(comptime fmt: []const u8, args: anytype) !void {
    const alloc = std.heap.page_allocator;
    const s = try std.fmt.allocPrint(alloc, fmt, args);
    defer alloc.free(s);
    try std.fs.File.stdout().writeAll(s);
}

pub fn generateConfig() !void {
    const text =
        "{\n" ++
        "  \"delay\": 1000000,\n" ++
        "  \"ignore\": [],\n" ++
        "  \"cmd\": \"stack ghc -- {file} && {dir}/test\"\n" ++
        "}\n";

    try std.fs.cwd().writeFile(.{ .sub_path = "HaskMate.json", .data = text });
    try spr("Configuration file generated successfully!\n", .{});
}
