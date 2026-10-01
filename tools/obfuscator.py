#!/usr/bin/env python3
"""N3Z Shield v3 - profile-based Luau source protector.

This is a source-protection layer, not a security boundary. Any client-side
payload can ultimately be inspected by the machine that executes it.
"""

from __future__ import annotations

import argparse
import os
import random
import sys
from dataclasses import dataclass
from typing import Iterable

HEADER_BANNER = """-- [[ Protected by N3Z Shield v3.0 - All Rights Reserved ]]
-- [[ Profile: {profile} | Per-build diversified payload ]]
"""

MOD = 65521


@dataclass(frozen=True)
class Profile:
    name: str
    block_size: int
    rounds: int
    chunk_flush: int


PROFILES = {
    "performance": Profile("performance", block_size=1536, rounds=1, chunk_flush=6000),
    "max": Profile("max", block_size=640, rounds=3, chunk_flush=3000),
}


def generate_var_name(rng: random.Random, length: int = 12) -> str:
    chars = "Il1O0"
    return "_" + "".join(rng.choice(chars) for _ in range(length))


def checksum(data: Iterable[int]) -> int:
    a, b = 1, 0
    for value in data:
        a = (a + int(value)) % MOD
        b = (b + a) % MOD
    return b * 65536 + a


def _step(key: int, mul: int, inc: int) -> int:
    return (key * mul + inc) & 0xFF


def _encode_block(raw: bytes, seed: int, mul: int, inc: int, rounds: int) -> list[int]:
    out = list(raw)
    for round_index in range(rounds):
        key = (seed + round_index * 73) & 0xFF
        prev = (seed ^ (round_index * 41)) & 0xFF
        for i, value in enumerate(out):
            key = _step(key, mul, inc)
            mixed = (value + ((key + i + prev) & 0xFF)) & 0xFF
            mixed ^= key
            out[i] = mixed
            prev = mixed
        out.reverse()
    return out

def _decode_block_for_test(data: list[int], seed: int, mul: int, inc: int, rounds: int) -> bytes:
    out = list(data)
    for round_index in range(rounds - 1, -1, -1):
        out.reverse()
        key = (seed + round_index * 73) & 0xFF
        prev = (seed ^ (round_index * 41)) & 0xFF
        decoded: list[int] = []
        for i, value in enumerate(out):
            key = _step(key, mul, inc)
            plain = ((value ^ key) - ((key + i + prev) & 0xFF)) & 0xFF
            decoded.append(plain)
            prev = value
        out = decoded
    return bytes(out)


def _choose_lcg(rng: random.Random) -> tuple[int, int]:
    # Only low 8 bits matter. Odd multipliers avoid collapsing the byte state.
    mul = rng.choice([13, 29, 61, 109, 141, 173, 205, 237])
    inc = rng.choice([17, 57, 93, 123, 157, 193, 221, 249])
    return mul, inc


def _format_ints(values: list[int], width: int = 48) -> str:
    lines = []
    for i in range(0, len(values), width):
        lines.append(",".join(str(v) for v in values[i : i + width]))
    return ",\n            ".join(lines)


def _encode_blocks(source: str, profile: Profile, rng: random.Random):
    raw = source.encode("utf-8")
    blocks = []
    for logical_index, start in enumerate(range(0, len(raw), profile.block_size), start=1):
        part = raw[start : start + profile.block_size]
        seed = rng.randint(1, 255)
        mul, inc = _choose_lcg(rng)
        encoded = _encode_block(part, seed, mul, inc, profile.rounds)
        blocks.append(
            {
                "index": logical_index,
                "seed": seed,
                "mul": mul,
                "inc": inc,
                "checksum": checksum(part),
                "data": encoded,
            }
        )
    physical = blocks[:]
    rng.shuffle(physical)
    return raw, physical


def obfuscate_code(source: str, profile: str = "performance", seed: int | None = None) -> str:
    if profile not in PROFILES:
        raise ValueError(f"unknown profile: {profile}")
    cfg = PROFILES[profile]
    rng = random.Random(seed if seed is not None else int.from_bytes(os.urandom(16), "big"))
    raw, blocks = _encode_blocks(source, cfg, rng)

    v_blocks = generate_var_name(rng)
    v_sorted = generate_var_name(rng)
    v_bxor = generate_var_name(rng)
    v_check = generate_var_name(rng)
    v_decode = generate_var_name(rng)
    v_out = generate_var_name(rng)
    v_parts = generate_var_name(rng)
    v_fn = generate_var_name(rng)
    v_err = generate_var_name(rng)

    block_literals = []
    for block in blocks:
        block_literals.append(
            "{"
            f"{block['index']},{block['seed']},{block['mul']},{block['inc']},{block['checksum']},"
            "{"
            + _format_ints(block["data"])
            + "}}"
        )
    block_table = ",\n        ".join(block_literals)

    banner = HEADER_BANNER.format(profile=profile)
    return f"""{banner}local function _n3z_run(...)
    local {v_bxor} = bit32 and bit32.bxor or function(x, y)
        local p, c = 1, 0
        while x > 0 or y > 0 do
            local a, b = x % 2, y % 2
            if a ~= b then c = c + p end
            x, y, p = math.floor(x / 2), math.floor(y / 2), p * 2
        end
        return c
    end

    local function {v_check}(bytes)
        local a, b = 1, 0
        for i = 1, #bytes do
            a = (a + string.byte(bytes, i)) % {MOD}
            b = (b + a) % {MOD}
        end
        return b * 65536 + a
    end

    local {v_blocks} = {{
        {block_table}
    }}
    local {v_sorted} = {{}}
    for i = 1, #{v_blocks} do
        local block = {v_blocks}[i]
        {v_sorted}[block[1]] = block
    end

    local function {v_decode}(block)
        local data = block[6]
        local seed, mul, inc = block[2], block[3], block[4]
        local current = data
        for round = {cfg.rounds - 1}, 0, -1 do
            local reversed = {{}}
            for i = #current, 1, -1 do
                reversed[#reversed + 1] = current[i]
            end
            local key = (seed + round * 73) % 256
            local prev = {v_bxor}(seed, round * 41) % 256
            local decoded = {{}}
            for i = 1, #reversed do
                local cipher = reversed[i]
                key = (key * mul + inc) % 256
                local plain = ({v_bxor}(cipher, key) - ((key + (i - 1) + prev) % 256)) % 256
                decoded[i] = plain
                prev = cipher
            end
            current = decoded
        end
        local chars, count = {{}}, 0
        for i = 1, #current do
            count = count + 1
            chars[count] = string.char(current[i])
        end
        local result = table.concat(chars)
        if {v_check}(result) ~= block[5] then
            error("[N3Z Shield] payload integrity check failed")
        end
        return result
    end

    local {v_parts} = {{}}
    for i = 1, #{v_sorted} do
        {v_parts}[i] = {v_decode}({v_sorted}[i])
    end
    local {v_out} = table.concat({v_parts})
    if {v_check}({v_out}) ~= {checksum(raw)} then
        error("[N3Z Shield] aggregate integrity check failed")
    end
    local {v_fn}, {v_err} = loadstring({v_out}, "@N3Z")
    if not {v_fn} then
        error("[N3Z Shield] compile failed: " .. tostring({v_err}))
    end
    return {v_fn}(...)
end
return _n3z_run(...)
"""


def deobfuscation_roundtrip_for_test(source: str, profile: str, seed: int = 1) -> bytes:
    cfg = PROFILES[profile]
    rng = random.Random(seed)
    raw, blocks = _encode_blocks(source, cfg, rng)
    restored = bytearray()
    for block in sorted(blocks, key=lambda item: item["index"]):
        part = _decode_block_for_test(
            block["data"], block["seed"], block["mul"], block["inc"], cfg.rounds
        )
        if checksum(part) != block["checksum"]:
            raise AssertionError("block checksum mismatch")
        restored.extend(part)
    if bytes(restored) != raw:
        raise AssertionError("roundtrip mismatch")
    return bytes(restored)

def main() -> None:
    parser = argparse.ArgumentParser(description="N3Z Shield v3 Luau protector")
    parser.add_argument("input_file")
    parser.add_argument("output_file", nargs="?")
    parser.add_argument("--profile", choices=sorted(PROFILES), default="performance")
    parser.add_argument("--seed", type=int, default=None, help="deterministic build seed (testing only)")
    args = parser.parse_args()

    input_path = args.input_file
    output_path = args.output_file or input_path
    if not os.path.exists(input_path):
        print(f"Error: input file {input_path} not found", file=sys.stderr)
        raise SystemExit(1)

    with open(input_path, "r", encoding="utf-8") as handle:
        source = handle.read()

    protected = obfuscate_code(source, profile=args.profile, seed=args.seed)
    with open(output_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(protected)

    ratio = len(protected.encode("utf-8")) / max(1, len(source.encode("utf-8")))
    print(
        f"Protected [{args.profile}]: {input_path} -> {output_path} "
        f"({len(source)} chars, {ratio:.2f}x output)"
    )


if __name__ == "__main__":
    main()
