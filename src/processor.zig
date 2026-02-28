const std = @import("std");

const DateKey = [10]u8;

const DateMap = std.AutoArrayHashMap(DateKey, u64);

const PathMap = std.StringArrayHashMap(DateMap);

fn parseLine(line: []const u8) ?struct { path: []const u8, date: DateKey } {
    if (line.len == 0) return null;

    const comma_pos = std.mem.lastIndexOfScalar(u8, line, ',') orelse return null;
    const url = line[0..comma_pos];
    const datetime = line[comma_pos + 1 ..];

    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return null;
    const after_scheme = url[scheme_end + 3 ..];
    const path_start = std.mem.indexOfScalar(u8, after_scheme, '/') orelse return null;
    const path = after_scheme[path_start..];

    if (datetime.len < 10) return null;
    var date: DateKey = undefined;
    @memcpy(&date, datetime[0..10]);

    return .{ .path = path, .date = date };
}

fn processChunk(allocator: std.mem.Allocator, chunk: []const u8) !PathMap {
    var map = PathMap.init(allocator);

    var start: usize = 0;
    while (start < chunk.len) {
        const end = std.mem.indexOfScalarPos(u8, chunk, start, '\n') orelse chunk.len;
        const line = chunk[start..end];

        if (parseLine(line)) |parsed| {
            const gop = try map.getOrPut(parsed.path);
            if (!gop.found_existing) {
                gop.key_ptr.* = parsed.path;
                gop.value_ptr.* = DateMap.init(allocator);
            }
            const date_gop = try gop.value_ptr.getOrPut(parsed.date);
            if (!date_gop.found_existing) {
                date_gop.value_ptr.* = 0;
            }
            date_gop.value_ptr.* += 1;
        }

        start = end + 1;
    }

    return map;
}

fn mergeMaps(dest: *PathMap, source: *PathMap) !void {
    var it = source.iterator();
    while (it.next()) |entry| {
        const gop = try dest.getOrPut(entry.key_ptr.*);
        if (!gop.found_existing) {
            gop.key_ptr.* = entry.key_ptr.*;
            gop.value_ptr.* = DateMap.init(dest.allocator);
        }
        var date_it = entry.value_ptr.iterator();
        while (date_it.next()) |date_entry| {
            const date_gop = try gop.value_ptr.getOrPut(date_entry.key_ptr.*);
            if (!date_gop.found_existing) {
                date_gop.value_ptr.* = 0;
            }
            date_gop.value_ptr.* += date_entry.value_ptr.*;
        }
        entry.value_ptr.deinit();
    }
    source.deinit();
}

const ThreadResult = struct {
    map: PathMap,
    err: ?anyerror,
};

fn threadWorker(allocator: std.mem.Allocator, chunk: []const u8, result: *ThreadResult) void {
    result.map = processChunk(allocator, chunk) catch |err| {
        result.err = err;
        result.map = PathMap.init(allocator);
        return;
    };
    result.err = null;
}

fn compareStrings(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}

fn compareDateKeys(_: void, a: DateKey, b: DateKey) bool {
    return std.mem.order(u8, &a, &b) == .lt;
}

fn formatJson(allocator: std.mem.Allocator, map: *PathMap) ![]u8 {
    var keys = try allocator.alloc([]const u8, map.count());
    defer allocator.free(keys);

    var i: usize = 0;
    var kit = map.iterator();
    while (kit.next()) |entry| {
        keys[i] = entry.key_ptr.*;
        i += 1;
    }
    std.mem.sort([]const u8, keys, {}, compareStrings);

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    try out.appendSlice(allocator, "{\n");

    for (keys, 0..) |key, ki| {
        try out.appendSlice(allocator, "    \"");
        for (key) |c| {
            if (c == '/') {
                try out.appendSlice(allocator, "\\/");
            } else {
                try out.append(allocator, c);
            }
        }
        try out.appendSlice(allocator, "\": {\n");

        const dates = map.getPtr(key).?;
        var date_keys = try allocator.alloc(DateKey, dates.count());
        defer allocator.free(date_keys);

        var di: usize = 0;
        var dit = dates.iterator();
        while (dit.next()) |entry| {
            date_keys[di] = entry.key_ptr.*;
            di += 1;
        }
        std.mem.sort(DateKey, date_keys, {}, compareDateKeys);

        for (date_keys, 0..) |dk, dki| {
            const count = dates.get(dk).?;
            var buf: [128]u8 = undefined;
            const line = std.fmt.bufPrint(&buf, "        \"{s}\": {}", .{ dk, count }) catch continue;
            try out.appendSlice(allocator, line);
            if (dki < date_keys.len - 1) {
                try out.appendSlice(allocator, ",\n");
            } else {
                try out.appendSlice(allocator, "\n");
            }
        }

        try out.appendSlice(allocator, "    }");
        if (ki < keys.len - 1) {
            try out.appendSlice(allocator, ",\n");
        } else {
            try out.appendSlice(allocator, "\n");
        }
    }

    try out.appendSlice(allocator, "}\n");

    return out.toOwnedSlice(allocator);
}

pub fn process(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    const file = try std.fs.cwd().openFile(input_path, .{});
    defer file.close();

    const stat = try file.stat();
    const file_size = stat.size;

    const data = try std.posix.mmap(null, file_size, std.posix.PROT.READ, .{ .TYPE = .SHARED }, file.handle, 0);
    defer std.posix.munmap(data);

    std.posix.madvise(@alignCast(data.ptr), data.len, std.posix.MADV.SEQUENTIAL) catch {};

    const num_threads = std.Thread.getCpuCount() catch 4;
    const chunk_size = file_size / num_threads;

    var boundaries = try allocator.alloc(usize, num_threads + 1);
    defer allocator.free(boundaries);
    boundaries[0] = 0;

    for (1..num_threads) |t| {
        var pos = t * chunk_size;
        while (pos < file_size and data[pos] != '\n') {
            pos += 1;
        }
        if (pos < file_size) pos += 1;
        boundaries[t] = pos;
    }
    boundaries[num_threads] = file_size;

    var results = try allocator.alloc(ThreadResult, num_threads);
    defer allocator.free(results);

    var threads = try allocator.alloc(std.Thread, num_threads);
    defer allocator.free(threads);

    for (0..num_threads) |t| {
        const chunk = data[boundaries[t]..boundaries[t + 1]];
        threads[t] = try std.Thread.spawn(.{}, threadWorker, .{ allocator, chunk, &results[t] });
    }

    for (0..num_threads) |t| {
        threads[t].join();
    }

    var merged = results[0].map;
    for (1..num_threads) |t| {
        try mergeMaps(&merged, &results[t].map);
    }

    std.debug.print("Processed {} unique paths to {s}\n", .{ merged.count(), output_path });

    const json = try formatJson(allocator, &merged);
    defer allocator.free(json);

    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();
    try out_file.writeAll(json);

    var mit = merged.iterator();
    while (mit.next()) |entry| {
        entry.value_ptr.deinit();
    }
    merged.deinit();
}
