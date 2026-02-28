# 100 Million Row Challenge - Zig Solution

## Problem Statement

Parse 100 million CSV rows of website visit data (`URL,datetime`) and produce a JSON file
that maps each URL path to its daily visit counts, sorted by date ascending.

## Input Format

```
https://stitcher.io/blog/some-post,2026-01-24T01:16:58+00:00
https://stitcher.io/blog/another-post,2024-01-24T01:16:58+00:00
```

## Output Format

Pretty-printed JSON with URL paths as keys and date-count maps as values:

```json
{
    "\/blog\/some-post": {
        "2025-01-24": 1,
        "2026-01-24": 2
    }
}
```

- Keys are URL paths (without the domain), with forward slashes escaped as `\/`
- Dates sorted ascending
- Pretty JSON output

## Architecture

### Generator (`src/generator.zig`)
- Predefined list of 51 blog URL paths
- Random dates within a 3-year range (2024-2026)
- Writes CSV rows to `measurements.txt`
- 8MB write buffer for batched I/O
- Configurable row count (default 1M, supports 100M)

### Processor (`src/processor.zig`)
- Memory-mapped file via `std.posix.mmap` for zero-copy reads
- Splits file into chunks aligned to newline boundaries
- Uses `std.Thread` for parallel chunk processing
- Each thread builds a local `StringArrayHashMap(AutoArrayHashMap([10]u8, u64))`
- Merges all thread-local maps
- Sorts paths and dates alphabetically
- Writes pretty JSON to `output.json`

## Multi-Threading Strategy

1. Memory-map the input file
2. Determine chunk boundaries (one per CPU core), aligned to newline boundaries
3. Each thread processes its chunk independently, building a local hashmap
4. Merge all hashmaps sequentially after all threads join
5. Sort keys and serialize to JSON

## Performance Considerations

- `madvise(MADV_SEQUENTIAL)` hints the OS for better prefetching of mmap'd data
- Memory-mapped I/O avoids buffered read overhead
- Parallel chunk processing saturates all CPU cores
- Thread-local hashmaps avoid contention
- Manual date extraction (first 10 chars of ISO datetime) avoids full datetime parsing
- Manual URL path extraction avoids URL parsing libraries
- Fixed-size `[10]u8` date keys avoid heap allocations for dates
- Zero-copy slices into mmap'd data for URL paths (no string copies)
- `StringArrayHashMap` provides cache-friendly iteration vs tree-based maps
- 8MB write buffer in generator reduces syscall overhead

## Dependencies

None. Zero external dependencies, only Zig standard library.
