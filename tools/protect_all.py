#!/usr/bin/env python3
"""
N3Z Multi-File Project Protector & Obfuscator
Encrypts all project modules and entrypoints into protected payloads.
"""

import os
import sys
from obfuscator import obfuscate_code

def protect_file(file_path):
    print(f"[*] Protecting: {file_path}")
    with open(file_path, "r", encoding="utf-8") as f:
        src = f.read()

    # Skip already obfuscated files
    if "Protected by N3Z Shield" in src:
        print(f"    [!] Already protected, skipping: {file_path}")
        return

    obf = obfuscate_code(src)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(obf)
    print(f"    [+] Done: {len(src)} bytes -> {len(obf)} bytes")

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    print(f"[N3Z Shield] Target root: {root_dir}")

    # Files to protect
    targets = [
        os.path.join(root_dir, "n3z.lua"),
        os.path.join(root_dir, "n3z-dock.lua"),
        os.path.join(root_dir, "n3z-compat.lua"),
    ]

    # Modules
    modules_dir = os.path.join(root_dir, "modules")
    if os.path.exists(modules_dir):
        for fname in os.listdir(modules_dir):
            if fname.endswith(".lua"):
                targets.append(os.path.join(modules_dir, fname))

    for t in targets:
        if os.path.exists(t):
            protect_file(t)

    print("\n[✓] All target files successfully protected!")

if __name__ == "__main__":
    main()
