const std = @import("std");

fn printFmt(comptime fmt: []const u8, args: anytype) !void {
    const allocator = std.heap.page_allocator;
    const text = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(text);
    try std.fs.File.stdout().writeAll(text);
}

pub fn generateConfig() !void {
    const configTemplate =
        "{\n" ++
        "  \"delay\": 1000000,\n" ++
        "  \"ignore\": [],\n" ++
        "  \"cmd\": \"stack ghc -- {file} && {dir}/test\"\n" ++
        "}\n";

    try std.fs.cwd().writeFile(.{ .sub_path = "Zippy.json", .data = configTemplate });
    try printFmt("Configuration file generated successfully!\n", .{});
}
