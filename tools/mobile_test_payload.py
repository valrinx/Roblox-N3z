"""Emit mobile regression tests to execute on Roblox through Raven MCP."""
import json
from pathlib import Path


def lua_string(value):
    equals = "="
    while f"]{equals}]" in value:
        equals += "="
    return f"[{equals}[{value}]{equals}]"


root = Path(__file__).resolve().parent.parent
tests = (root / "tools/test_mobile_support.lua").read_text(encoding="utf-8")
sources = {
    "dock": (root / "n3z-dock.lua").read_text(encoding="utf-8"),
    "mobile": (root / "modules/warz_pvp/mobile.lua").read_text(encoding="utf-8"),
    "pc": (root / "modules/warz_pvp/pc.lua").read_text(encoding="utf-8"),
    "core": (root / "modules/warz_pvp/core.lua").read_text(encoding="utf-8"),
    "router": (root / "modules/warz_pvp.lua").read_text(encoding="utf-8"),
    "compat": (root / "n3z-compat.lua").read_text(encoding="utf-8"),
}
code = "local run = assert(loadstring(" + lua_string(tests) + ", '@test-mobile'))()\nreturn run({\n"
code += ",\n".join(f"{key} = {lua_string(value)}" for key, value in sources.items())
code += "\n})"
print(json.dumps({"code": code}))
