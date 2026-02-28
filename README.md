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
- Thread-local `StringArrayHashMap` results are merged at the end
- Output is sorted alphabetically by path and date
- 8MB write buffer for fast data generation
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

## Result

```
❯ ./run.sh
=== Generating 100,000,000 rows ===
Generated 10000000 rows...
Generated 20000000 rows...
Generated 30000000 rows...
Generated 40000000 rows...
Generated 50000000 rows...
Generated 60000000 rows...
Generated 70000000 rows...
Generated 80000000 rows...
Generated 90000000 rows...
Generated 100000000 rows to zig-out/data/measurements.txt

=== Processing measurements.txt ===
Processed 51 unique paths to zig-out/data/output.json
Completed in 0.765s

=== Done ===
Output written to zig-out/data/output.json
{
    "\/blog\/11-million-rows-in-seconds": {
        "2024-01-01": 2029,
        "2024-01-02": 2030,
        "2024-01-03": 1944,
        "2024-01-04": 1887,
        "2024-01-05": 1938,
        "2024-01-06": 1988,
        "2024-01-07": 2027,
        "2024-01-08": 1984,
        "2024-01-09": 1939,
        "2024-01-10": 1976,
        "2024-01-11": 1927,
        "2024-01-12": 1896,
        "2024-01-13": 2014,
        "2024-01-14": 1928,
        "2024-01-15": 1951,
        "2024-01-16": 2024,
        "2024-01-17": 1948,
        "2024-01-18": 1881,
```

### Related POC

* 100MRC Rust -> https://github.com/diegopacheco/100-million-row-challenge-rust
* 100MRC Zig -> https://github.com/diegopacheco/100-million-row-challenge-zig
* 1000RC Java 25 -> https://github.com/diegopacheco/100-million-row-challenge-java
