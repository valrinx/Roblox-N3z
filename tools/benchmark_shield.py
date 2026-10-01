#!/usr/bin/env python3
"""Benchmark N3Z Shield v3 build/decode cost and emit Luau decode benchmarks."""

from __future__ import annotations

import argparse
import json
import random
import statistics
import subprocess
import time
import tracemalloc
from pathlib import Path

from obfuscator import (
    PROFILES,
    _decode_block_for_test,
    _encode_blocks,
    checksum,
    obfuscate_code,
)


def read_source(root: Path, relative: str, source_ref: str | None) -> str:
    path = root / relative
    if source_ref is None:
        return path.read_text(encoding="utf-8")
    raw = subprocess.check_output(
        ["git", "-C", str(root), "show", f"{source_ref}:{relative}"]
    )
    return raw.decode("utf-8")


def median(values):
    return float(statistics.median(values))


def benchmark_host(source: str, profile: str, iterations: int) -> dict:
    build_ms, build_peak_kib, output_sizes = [], [], []
    for i in range(iterations):
        tracemalloc.start()
        start = time.perf_counter()
        protected = obfuscate_code(source, profile=profile, seed=1000 + i)
        elapsed = (time.perf_counter() - start) * 1000
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        build_ms.append(elapsed)
        build_peak_kib.append(peak / 1024)
        output_sizes.append(len(protected.encode("utf-8")))

    cfg = PROFILES[profile]
    raw, blocks = _encode_blocks(source, cfg, random.Random(777))
    decode_ms = []
    for _ in range(iterations):
        start = time.perf_counter()
        restored = bytearray()
        for block in sorted(blocks, key=lambda item: item["index"]):
            part = _decode_block_for_test(
                block["data"], block["seed"], block["mul"], block["inc"], cfg.rounds
            )
            if checksum(part) != block["checksum"]:
                raise AssertionError("block checksum mismatch")
            restored.extend(part)
        elapsed = (time.perf_counter() - start) * 1000
        if bytes(restored) != raw:
            raise AssertionError("roundtrip mismatch")
        decode_ms.append(elapsed)

    input_bytes = len(raw)
    med_decode = median(decode_ms)
    mib_s = (input_bytes / (1024 * 1024)) / max(med_decode / 1000, 1e-9)
    return {
        "profile": profile,
        "input_bytes": input_bytes,
        "blocks": len(blocks),
        "rounds": cfg.rounds,
        "output_bytes_median": int(median(output_sizes)),
        "output_ratio": median(output_sizes) / max(1, input_bytes),
        "build_ms_median": median(build_ms),
        "build_peak_kib_median": median(build_peak_kib),
        "python_decode_ms_median": med_decode,
        "python_decode_mib_s": mib_s,
    }


def make_luau_benchmark(source: str, profile: str, iterations: int) -> str:
    cfg = PROFILES[profile]
    raw, blocks = _encode_blocks(source, cfg, random.Random(777))
    literals = []
    for block in blocks:
        data = ",".join(str(v) for v in block["data"])
        literals.append(
            "{" + ",".join(
                [
                    str(block["index"]),
                    str(block["seed"]),
                    str(block["mul"]),
                    str(block["inc"]),
                    str(block["checksum"]),
                    "{" + data + "}",
                ]
            ) + "}"
        )
    block_table = ",\n".join(literals)
    aggregate = checksum(raw)
    return f"""local bxor = bit32.bxor
local MOD = 65521
local rounds = {cfg.rounds}
local iterations = {iterations}
local blocks = {{
{block_table}
}}
local sorted = {{}}
for i = 1, #blocks do sorted[blocks[i][1]] = blocks[i] end

local function sum(s)
    local a, b = 1, 0
    for i = 1, #s do
        a = (a + string.byte(s, i)) % MOD
        b = (b + a) % MOD
    end
    return b * 65536 + a
end

local function decode(block)
    local current = block[6]
    local seed, mul, inc = block[2], block[3], block[4]
    for round = rounds - 1, 0, -1 do
        local reversed = {{}}
        for i = #current, 1, -1 do reversed[#reversed + 1] = current[i] end
        local key = (seed + round * 73) % 256
        local prev = bxor(seed, round * 41) % 256
        local decoded = {{}}
        for i = 1, #reversed do
            local cipher = reversed[i]
            key = (key * mul + inc) % 256
            decoded[i] = (bxor(cipher, key) - ((key + (i - 1) + prev) % 256)) % 256
            prev = cipher
        end
        current = decoded
    end
    local chars = table.create(#current)
    for i = 1, #current do chars[i] = string.char(current[i]) end
    local result = table.concat(chars)
    assert(sum(result) == block[5], "block checksum")
    return result
end

local decodeSamples = table.create(iterations)
local compileSamples = table.create(iterations)
local startupSamples = table.create(iterations)
local beforeKb = type(gcinfo) == "function" and gcinfo() or 0
for run = 1, iterations do
    local t0 = os.clock()
    local parts = table.create(#sorted)
    for i = 1, #sorted do parts[i] = decode(sorted[i]) end
    local output = table.concat(parts)
    assert(#output == {len(raw)}, "size mismatch")
    assert(sum(output) == {aggregate}, "aggregate checksum")
    local decodedAt = os.clock()
    local fn, err = loadstring(output, "@N3ZBenchPayload")
    local compiledAt = os.clock()
    assert(fn, tostring(err))
    decodeSamples[run] = (decodedAt - t0) * 1000
    compileSamples[run] = (compiledAt - decodedAt) * 1000
    startupSamples[run] = (compiledAt - t0) * 1000
end
local afterKb = type(gcinfo) == "function" and gcinfo() or 0
local decodeTotal, compileTotal, startupTotal = 0, 0, 0
local decodeMin, startupMin = math.huge, math.huge
for i = 1, iterations do
    decodeTotal += decodeSamples[i]
    compileTotal += compileSamples[i]
    startupTotal += startupSamples[i]
    if decodeSamples[i] < decodeMin then decodeMin = decodeSamples[i] end
    if startupSamples[i] < startupMin then startupMin = startupSamples[i] end
end
return {{
    profile = "{profile}",
    inputBytes = {len(raw)},
    blocks = #blocks,
    rounds = rounds,
    iterations = iterations,
    decodeMsAvg = decodeTotal / iterations,
    decodeMsMin = decodeMin,
    payloadCompileMsAvg = compileTotal / iterations,
    startupMsAvg = startupTotal / iterations,
    startupMsMin = startupMin,
    gcNetDeltaKb = afterKb - beforeKb,
    checksum = {aggregate},
}}
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="Benchmark N3Z Shield v3")
    parser.add_argument("--file", default="n3z-dock.lua")
    parser.add_argument("--source-ref", default=None)
    parser.add_argument("--iterations", type=int, default=7)
    parser.add_argument("--json-out", default=None)
    parser.add_argument("--emit-luau-dir", default=None)
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    source = read_source(root, args.file, args.source_ref)
    results = [
        benchmark_host(source, profile, args.iterations)
        for profile in ("performance", "max")
    ]

    print(json.dumps(results, indent=2))
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(results, indent=2), encoding="utf-8")

    if args.emit_luau_dir:
        out_dir = Path(args.emit_luau_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        for profile in ("performance", "max"):
            code = make_luau_benchmark(source, profile, args.iterations)
            (out_dir / f"benchmark_{profile}.luau").write_text(
                code, encoding="utf-8", newline="\n"
            )


if __name__ == "__main__":
    main()
