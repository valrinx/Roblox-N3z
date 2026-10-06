"""Emit a Luau regression runner for the production avatar UI and loader chunks."""
import json
from pathlib import Path


def section(source, start, end):
    begin = source.index(start)
    return source[begin:source.index(end, begin)]


def lua_string(value):
    # Lua long strings preserve source newlines and do not interpret escapes.
    equals = "="
    while f"]{equals}]" in value:
        equals += "="
    return f"[{equals}[{value}]{equals}]"


root = Path(__file__).resolve().parent.parent
dock = (root / "n3z-dock.lua").read_text(encoding="utf-8")
hub = (root / "n3z.lua").read_text(encoding="utf-8")
avatar_ui = section(dock, "        if L.showAvatar then", "    end\n\n    -- menu key")
sources = {
    "constructor": dock[:dock.index("function Dock.new(opts)")]
        + "\nreturn function(self, utilityZone, L)\n" + avatar_ui + "\nend",
    "methods": "local Dock = {}\n"
        + section(dock, "function Dock:SetAvatar(content)", "function Dock:SetMenuKeyName(name)")
        + "\nreturn Dock",
    "loader": "return function(Players, localPlayer, dock, task, Enum)\n"
        + section(hub, "-- avatar (async", "-- ---------- MODULES tab") + "\nend",
}
tests = (root / "tools/test_avatar.lua").read_text(encoding="utf-8")
payload = "local run = assert(loadstring(" + lua_string(tests) + ", '@test-avatar'))()\nreturn run({\n"
payload += ",\n".join(f"{key} = {lua_string(value)}" for key, value in sources.items())
payload += "\n})"
print(json.dumps({"code": payload}, ensure_ascii=True))
