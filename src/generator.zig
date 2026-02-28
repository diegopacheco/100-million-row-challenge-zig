const std = @import("std");

const PATHS = [_][]const u8{
    "/blog/php-enums",
    "/blog/11-million-rows-in-seconds",
    "/blog/laravel-beyond-crud",
    "/blog/php-81-enums",
    "/blog/a-project-at-stitcher",
    "/blog/php-what-i-dont-like",
    "/blog/new-in-php-81",
    "/blog/new-in-php-82",
    "/blog/new-in-php-83",
    "/blog/new-in-php-84",
    "/blog/generics-in-php",
    "/blog/readonly-classes-in-php-82",
    "/blog/fibers-with-a-grain-of-salt",
    "/blog/php-enum-style-guide",
    "/blog/constructor-promotion-in-php-8",
    "/blog/php-match-or-switch",
    "/blog/named-arguments-in-php-80",
    "/blog/php-enums-and-static-analysis",
    "/blog/short-closures-in-php",
    "/blog/attributes-in-php-8",
    "/blog/typed-properties-in-php-74",
    "/blog/a-letter-to-the-php-community",
    "/blog/union-types-in-php-80",
    "/blog/what-is-new-in-php",
    "/blog/readonly-properties-in-php-82",
    "/blog/nullsafe-operator-in-php",
    "/blog/php-deprecations-84",
    "/blog/property-hooks-in-php-84",
    "/blog/asymmetric-visibility-in-php-84",
    "/blog/crafting-quality-code",
    "/blog/object-oriented-programming",
    "/blog/design-patterns-explained",
    "/blog/functional-programming-in-php",
    "/blog/testing-best-practices",
    "/blog/clean-architecture",
    "/blog/domain-driven-design",
    "/blog/event-sourcing-patterns",
    "/blog/cqrs-explained",
    "/blog/microservices-patterns",
    "/blog/api-design-principles",
    "/blog/rest-vs-graphql",
    "/blog/database-optimization",
    "/blog/caching-strategies",
    "/blog/message-queues-explained",
    "/blog/security-best-practices",
    "/blog/ci-cd-pipelines",
    "/blog/docker-for-developers",
    "/blog/kubernetes-basics",
    "/blog/serverless-architecture",
    "/blog/web-performance-tips",
    "/blog/frontend-frameworks-comparison",
};

const DOMAIN = "https://stitcher.io";
const YEARS = [_]u16{ 2024, 2025, 2026 };
const BUF_SIZE = 8 * 1024 * 1024;

pub fn generate(path: []const u8, count: usize) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var rng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    var random = rng.random();

    var buf: [BUF_SIZE]u8 = undefined;
    var pos: usize = 0;
    var line_buf: [512]u8 = undefined;

    for (0..count) |i| {
        const path_idx = random.intRangeLessThan(usize, 0, PATHS.len);
        const year = YEARS[random.intRangeLessThan(usize, 0, YEARS.len)];
        const month: u8 = random.intRangeAtMost(u8, 1, 12);
        const day: u8 = random.intRangeAtMost(u8, 1, 28);
        const hour: u8 = random.intRangeLessThan(u8, 0, 24);
        const minute: u8 = random.intRangeLessThan(u8, 0, 60);
        const second: u8 = random.intRangeLessThan(u8, 0, 60);

        const line = try std.fmt.bufPrint(&line_buf, "{s}{s},{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}+00:00\n", .{
            DOMAIN,
            PATHS[path_idx],
            year,
            month,
            day,
            hour,
            minute,
            second,
        });

        if (pos + line.len > BUF_SIZE) {
            try file.writeAll(buf[0..pos]);
            pos = 0;
        }
        @memcpy(buf[pos .. pos + line.len], line);
        pos += line.len;

        if (i > 0 and i % 10_000_000 == 0) {
            std.debug.print("Generated {} rows...\n", .{i});
        }
    }

    if (pos > 0) {
        try file.writeAll(buf[0..pos]);
    }

    std.debug.print("Generated {} rows to {s}\n", .{ count, path });
}
