const std = @import("std");
const generator = @import("generator.zig");
const processor = @import("processor.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <generate|process> [options]\n", .{args[0]});
        std.debug.print("  generate [count]  - Generate test data (default: 1000000)\n", .{});
        std.debug.print("  process           - Process measurements.txt -> output.json\n", .{});
        std.process.exit(1);
    }

    const data_dir = "zig-out/data";
    std.fs.cwd().makePath(data_dir) catch |err| {
        std.debug.print("Failed to create data directory: {}\n", .{err});
        std.process.exit(1);
    };

    const input_file = data_dir ++ "/measurements.txt";
    const output_file = data_dir ++ "/output.json";

    if (std.mem.eql(u8, args[1], "generate")) {
        var count: usize = 1_000_000;
        if (args.len > 2) {
            const cleaned = try std.mem.replaceOwned(u8, allocator, args[2], "_", "");
            defer allocator.free(cleaned);
            count = std.fmt.parseInt(usize, cleaned, 10) catch 1_000_000;
        }
        try generator.generate(input_file, count);
    } else if (std.mem.eql(u8, args[1], "process")) {
        var timer = try std.time.Timer.start();
        try processor.process(allocator, input_file, output_file);
        const elapsed_ns = timer.read();
        const elapsed_s: f64 = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
        std.debug.print("Completed in {d:.3}s\n", .{elapsed_s});
    } else {
        std.debug.print("Unknown command: {s}\n", .{args[1]});
        std.process.exit(1);
    }
}
