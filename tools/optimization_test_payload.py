"""Extract real WarZ code; --baseline [ref] --benchmark compares an older Git revision."""
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
core = (root / 'modules/warz_pvp/core.lua').read_text(encoding='utf-8')
if '--baseline' in sys.argv:
    index = sys.argv.index('--baseline') + 1
    ref = sys.argv[index] if index < len(sys.argv) and not sys.argv[index].startswith('--') else 'HEAD'
    core = subprocess.check_output(['git', 'show', ref + ':modules/warz_pvp/core.lua'], cwd=root).decode('utf-8')

def section(start, end):
    a = core.index(start)
    return core[a:core.index(end, a)]

def quote(value):
    eq = '='
    while f']{eq}]' in value: eq += '='
    return f'[{eq}[{value}]{eq}]'

def fixture(body, deps, result):
    return 'return function(deps)\n' + '\n'.join(f'local {d} = deps.{d}' for d in deps.split()) + '\n' + body + '\nreturn ' + result + '\nend'

visual_start = '    local function cacheVisualProperties' if '    local function cacheVisualProperties' in core else '    local function safeDrawing'
visual = section(visual_start, '    local function getHealthColor')
esp = section('    local function characterScreenBounds', '    -- [[ Loot ESP:')
cache = section('    local connections = {}', '    local espCache = {}')
if '    local function getPlayers()' not in cache:
    cache += '\nlocal function getPlayers() return Players:GetPlayers() end\n'
if '    -- Low-frequency support work' in core:
    support = section('    -- Low-frequency support work', '    -- [[ UI ]]')
else:
    heal = section('        -- Auto Heal (Tier 1)', '        -- Infinite Stamina &')
    stamina = section('        -- Infinite Stamina &', '        -- Loot Aura (Auto Pickup')
    listeners = section('    table.insert(connections, localPlayer:GetAttributeChangedSignal("CSGO_Stamina")', '    local remotesFolder =')
    support = 'local function updateAutoHeal(dt)\n' + heal + '\nend\nlocal function updateStamina(dt)\n' + stamina + '\nend\n' + listeners

sources = {
    'native': fixture(section('    local function createNativeDrawingBackend', '    assert(type(platform.createVisualBackend)'), 'Instance', 'createNativeDrawingBackend'),
    'visual': fixture(visual, 'visualBackend', '{draw = safeDrawing, image = safeImage}'),
    'esp': fixture(visual + esp, 'visualBackend espCache camera settings Players localPlayer bodyPart ESP_COLOR LIVEAIM_BONES LIVEAIM_BONE_COUNT getLiveAim findLiveBone boneWorldPosition getPlayerRelationColor getRenderedWeaponId getWeaponIconSource Workspace getHealthColor getPlayers', '{update = updatePlayerEsp, hide = hideEntry, destroy = destroyEntry}'),
    'cache': fixture(cache, 'Players', '{get = getPlayers, destroy = function() for _,c in ipairs(connections) do c:Disconnect() end end}'),
    'support': fixture(support, 'localPlayer settings running connections getCombatInput', '{heal = updateAutoHeal, stamina = updateStamina}'),
}
tests = (root / 'tools/test_optimization.lua').read_text(encoding='utf-8')
code = 'return assert(loadstring(' + quote(tests) + ", '@optimization-tests'))()({" + ','.join(k+'='+quote(v) for k,v in sources.items()) + ',realBenchmark=' + ('true' if '--benchmark' in sys.argv else 'false') + '})'
print(json.dumps({'code': code}))
