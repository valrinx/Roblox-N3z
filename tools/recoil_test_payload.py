"""Run extracted production recoil code with detached weapon/config tables."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent.parent
core = (root / "modules/warz_pvp/core.lua").read_text(encoding="utf-8")

def quote(value):
    equals = "="
    while f"]{equals}]" in value:
        equals += "="
    return f"[{equals}[{value}]{equals}]"

start = core.index("    local function applyNoRecoil(cachedOnly)")
body = core[start:core.index("    _G.__WZP_ApplyNoRecoil", start)]
start = core.index('        Name = "No Recoil",')
start = core.rfind("    CombatTab:CreateToggle({", 0, start)
end = core.index('        Name = "Instant Pickup",', start)
controls = core[start:core.rfind("    CombatTab:CreateToggle({", start, end)]
patch = "return function(deps)\nlocal settings, peekLazy, getCombatSettings, getSharedConfig = deps.settings, deps.peekLazy, deps.getCombatSettings, deps.getSharedConfig\nlocal running = true\n" + body + "\nreturn applyNoRecoil, requestNoRecoilApply, function() running = false end\nend"
ui = "return function(deps)\nlocal settings, CombatTab, applyNoRecoil, requestNoRecoilApply = deps.settings, deps.CombatTab, deps.applyNoRecoil, deps.requestNoRecoilApply\nlocal recoilTime = 7\n" + controls + "\nreturn recoilTime\nend"
tests = (root / "tools/test_recoil_strength.lua").read_text(encoding="utf-8")
code = "return assert(loadstring(" + quote(tests) + ", '@recoil-tests'))()({patch=" + quote(patch) + ",controls=" + quote(ui) + "})"
print(json.dumps({"code": code}))
