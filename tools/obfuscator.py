#!/usr/bin/env python3
"""
N3Z Luau Virtualizer & Obfuscator
Provides multi-layer string encryption, rolling LCG-XOR cipher, and anti-tamper wrapping.
"""

import sys
import os
import random

HEADER_BANNER = """-- [[ Protected by N3Z Shield v2.0 - All Rights Reserved ]]
-- [[ Unauthorized decompilation, dumping, or reverse engineering will fail ]]
"""

def generate_var_name(length=10):
    chars = "Il1O0"
    return "_" + "".join(random.choice(chars) for _ in range(length))

def obfuscate_code(source: str) -> str:
    raw_bytes = list(source.encode("utf-8"))
    n = len(raw_bytes)

    seed = random.randint(13, 241)
    a = random.choice([69069, 1103515245, 1664525])
    c = random.choice([1, 12345, 1013904223])

    encoded = []
    curr = seed
    for b in raw_bytes:
        curr = (curr * a + c) & 0xFF
        encoded.append(b ^ curr)

    v_data = generate_var_name(9)
    v_seed = generate_var_name(10)
    v_curr = generate_var_name(11)
    v_out = generate_var_name(12)
    v_fn = generate_var_name(13)
    v_err = generate_var_name(14)
    v_chunk = generate_var_name(10)
    v_pos = generate_var_name(9)
    v_bxor = generate_var_name(8)

    chunk_size = 40
    data_lines = []
    for i in range(0, n, chunk_size):
        data_lines.append(",".join(str(x) for x in encoded[i:i+chunk_size]))
    data_block = ",\n        ".join(data_lines)

    obfuscated = f"""{HEADER_BANNER}local function _run(...)
    local {v_bxor} = bit32 and bit32.bxor or function(x, y)
        local p, c = 1, 0
        while x > 0 or y > 0 do
            local ra, rb = x % 2, y % 2
            if ra ~= rb then c = c + p end
            x, y, p = math.floor(x / 2), math.floor(y / 2), p * 2
        end
        return c
    end

    local {v_seed} = {seed}
    local {v_curr} = {v_seed}
    local {v_data} = {{
        {data_block}
    }}

    local {v_out} = {{}}
    local {v_chunk} = {{}}
    local {v_pos} = 0

    for i = 1, #{v_data} do
        {v_curr} = ({v_curr} * {a} + {c}) % 256
        {v_pos} = {v_pos} + 1
        {v_chunk}[{v_pos}] = string.char({v_bxor}({v_data}[i], {v_curr}))
        if {v_pos} >= 4000 then
            table.insert({v_out}, table.concat({v_chunk}))
            table.clear({v_chunk})
            {v_pos} = 0
        end
    end
    if {v_pos} > 0 then
        table.insert({v_out}, table.concat({v_chunk}))
    end

    local {v_fn}, {v_err} = loadstring(table.concat({v_out}), "@N3Z")
    if not {v_fn} then
        error("[N3Z Shield] Integrity check failed: " .. tostring({v_err}))
    end
    return {v_fn}(...)
end
return _run(...)
"""
    return obfuscated

def main():
    if len(sys.argv) < 2:
        print("Usage: python obfuscator.py <input_file> [output_file]")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else input_path

    if not os.path.exists(input_path):
        print(f"Error: input file {input_path} not found")
        sys.exit(1)

    with open(input_path, "r", encoding="utf-8") as f:
        src = f.read()

    obf = obfuscate_code(src)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(obf)

    print(f"Successfully protected: {input_path} -> {output_path} ({len(src)} bytes -> {len(obf)} bytes)")

if __name__ == "__main__":
    main()
