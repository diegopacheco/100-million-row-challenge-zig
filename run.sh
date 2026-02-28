#!/bin/bash
zig build -Doptimize=ReleaseFast

echo "=== Generating 100,000,000 rows ==="
./zig-out/bin/row-challenge generate 100_000_000

echo ""
echo "=== Processing measurements.txt ==="
./zig-out/bin/row-challenge process

echo ""
echo "=== Done ==="
echo "Output written to zig-out/data/output.json"
head -20 zig-out/data/output.json
