"""Emit isolated Silent Aim behavior tests; no live remotes are sent."""
import json
from pathlib import Path


def section(source, start, end):
    begin = source.index(start)
    return source[begin:source.index(end, begin)]


def quote(value):
    equals = "="
    while f"]{equals}]" in value:
        equals += "="
    return f"[{equals}[{value}]{equals}]"


root = Path(__file__).resolve().parent.parent
core = (root / "modules/warz_pvp/core.lua").read_text(encoding="utf-8")
selection = section(core, "    local function getSilentAimPoint", "    local fovCircle =")
hook = section(core, "    -- Silent Aim metamethod hook", "    -- Loot Aura implementation")
prediction = section(core, "    local function applyAimPrediction", "    local aimRayParams =")
toggle_start = core.index('    trackSection(CombatTab, "Silent Aim")')
toggle = section(core[toggle_start:], "    CombatTab:CreateToggle({", "    CombatTab:CreateSlider({")


def fixture(body, dependencies, returns):
    declarations = "\n".join(f"local {name} = deps.{name}" for name in dependencies.split())
    return "return function(deps)\n" + declarations + "\n" + body + "\nreturn " + returns + "\nend"


sources = {
    "toggle": fixture(toggle, "settings CombatTab getWarzHitboxes getCurrentBallistics", "true"),
    "selection": fixture(selection, "Players localPlayer camera settings getWarzHitboxes "
        "isPartyMember isPlayerVulnerable isAlive canSeeAimPoint applyAimPrediction",
        "{point = getSilentAimPoint, target = getSilentAimTarget}"),
    "hook": fixture(hook, "running settings camera game ReplicatedStorage hookmetamethod "
        "getnamecallmethod setnamecallmethod checkcaller getSilentAimTarget Workspace", "true"),
    "prediction": fixture(prediction, "settings camera predictionState getCurrentBallistics "
        "targetLinearVelocity solveBallisticTime", "applyAimPrediction"),
}
tests = (root / "tools/test_silent_aim.lua").read_text(encoding="utf-8")
code = "local run = assert(loadstring(" + quote(tests) + ", '@test-silent'))()\nreturn run({\n"
code += ",\n".join(f"{key} = {quote(value)}" for key, value in sources.items())
code += "\n})"
print(json.dumps({"code": code}))
