# 100 Million Row Challenge - Zig

Process 100 million rows of web analytics data as fast as possible using Zig.

## Input Format

```
https://stitcher.io/blog/php-enums,2024-01-24T01:16:58+00:00
https://stitcher.io/blog/11-million-rows-in-seconds,2026-01-24T01:12:11+00:00
```

## Output Format

```json
{
    "\/blog\/php-enums": {
        "2024-01-24": 1
    },
    "\/blog\/11-million-rows-in-seconds": {
        "2026-01-24": 2
    }
}
```

## How It Works

- Memory-mapped file I/O via `std.posix.mmap` for zero-copy reads
- File is split into chunks aligned to newline boundaries (one chunk per CPU core)
- Each chunk is processed in parallel using `std.Thread`
- Thread-local HashMap results are merged at the end
- Output is sorted alphabetically by path and date
- Zero external dependencies

## Build

```
./build.sh
```

## Run

Generate data and process it:
```
./run.sh
```

Or step by step:
```
./zig-out/bin/row-challenge generate 100_000_000
./zig-out/bin/row-challenge process
```

Data files are stored in `zig-out/data/`.
