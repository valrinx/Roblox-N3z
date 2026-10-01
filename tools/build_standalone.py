#!/usr/bin/env python3
"""Build Standalone Protected N3Z Script with N3Z Shield v3.

Embeds dock engine, compat layer, and game module into a single,
self-contained, obfuscated script with zero external HTTP dependencies.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

# Add tools directory to path
TOOLS_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOLS_DIR.parent
LIBRARY_HUB = Path(r"c:\Users\teens\OneDrive\Documents\GitHub\Roblox--Library\N3z HUB")

sys.path.insert(0, str(TOOLS_DIR))
from obfuscator import PROFILES, obfuscate_code  # noqa: E402


def read_source_file(filename: str) -> str:
    # Try reading from clean source in Roblox--Library first
    lib_path = LIBRARY_HUB / filename
    if lib_path.exists():
        text = lib_path.read_text(encoding="utf-8")
        if "Protected by N3Z Shield" not in text:
            return text

    # Fallback to git in Roblox-N3z
    try:
        data = subprocess.check_output(
            ["git", "-C", str(REPO_ROOT), "show", f"806abb4:{filename}"],
            stderr=subprocess.DEVNULL,
        )
        return data.decode("utf-8")
    except Exception:
        pass

    local_path = REPO_ROOT / filename
    if local_path.exists():
        text = local_path.read_text(encoding="utf-8")
        if "Protected by N3Z Shield" not in text:
            return text

    raise FileNotFoundError(f"Clean source for {filename} not found!")


def build_standalone_source(target_module: str = "warz_pvp.lua") -> str:
    dock_src = read_source_file("n3z-dock.lua")
    compat_src = read_source_file("n3z-compat.lua")
    module_src = read_source_file(f"modules/{target_module}")

    bundle = f"""-- [[ N3Z HUB STANDALONE BUNDLE ]]
local function __loadDock()
{dock_src}
end

local function __loadCompat()
{compat_src}
end

local function __loadModule()
{module_src}
end

local env = (type(getgenv) == "function" and getgenv()) or _G
if env.__N3Z_WINDOW and type(env.__N3Z_WINDOW.Destroy) == "function" then
    pcall(function() env.__N3Z_WINDOW:Destroy() end)
end
if env.__RAVEN_WINDOW and type(env.__RAVEN_WINDOW.Destroy) == "function" then
    pcall(function() env.__RAVEN_WINDOW:Destroy() end)
end

local Dock = __loadDock()
local makeWindow = __loadCompat()
local dock = Dock.new({{ menuKey = Enum.KeyCode.RightShift }})
local Window = makeWindow(dock)

env.__N3Z_WINDOW = Window
env.__RAVEN_WINDOW = Window

local modFn = __loadModule()
if type(modFn) == "function" then
    modFn(Window, {{
        game = "WarZPVP OPEN BETA",
        placeId = game.PlaceId,
        dock = dock,
    }})
end

return Window
"""
    return bundle


def main():
    parser = argparse.ArgumentParser(description="N3Z Shield v3 Standalone Builder")
    parser.add_argument("--profile", choices=sorted(PROFILES), default="performance")
    parser.add_argument("--module", default="warz_pvp.lua", help="Game module to bundle")
    parser.add_argument(
        "--output",
        default=str(TOOLS_DIR / "n3z_standalone.lua"),
        help="Output standalone file path",
    )
    parser.add_argument("--no-clip", action="store_true", help="Do not copy to clipboard")
    args = parser.parse_args()

    print(f"[N3Z Standalone v3] Building with profile: {args.profile}")
    print(f"[N3Z Standalone v3] Module: {args.module}")

    source_bundle = build_standalone_source(args.module)
    print(f"[N3Z Standalone v3] Source bundle size: {len(source_bundle.encode('utf-8'))} bytes")

    print("[N3Z Standalone v3] Encrypting with N3Z Shield v3...")
    protected = obfuscate_code(source_bundle, profile=args.profile)
    out_path = Path(args.output).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(protected, encoding="utf-8", newline="\n")

    out_size = len(protected.encode("utf-8"))
    ratio = out_size / len(source_bundle.encode("utf-8"))
    print(f"[OK] Standalone created at: {out_path}")
    print(f"     Size: {out_size} bytes ({ratio:.2f}x expansion)")

    if not args.no_clip:
        try:
            subprocess.run(
                [
                    "powershell",
                    "-Command",
                    f"Get-Content -Path '{out_path}' -Raw | Set-Clipboard",
                ],
                check=True,
                capture_output=True,
            )
            print("[OK] Standalone code copied to Windows Clipboard! (Paste into executor with Ctrl+V)")
        except Exception as e:
            print(f"[!] Clipboard copy failed: {e}")


if __name__ == "__main__":
    main()
