"""Load the real local Hub and saved profile on the connected client; leaves the Hub running.

Use --baseline <ref> to reproduce startup against an older core implementation.
Use --cold to unload the current Hub and remove its persistent namecall slot first.
This integration check includes the actual game catalog APIs and executor permissions.
"""
import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
paths = ['n3z-dock.lua', 'n3z-dock-mobile.lua', 'n3z-compat.lua',
         'modules/warz_pvp.lua', 'modules/warz_pvp/core.lua',
         'modules/warz_pvp/pc.lua', 'modules/warz_pvp/mobile.lua']

def quote(value):
    eq = '='
    while f']{eq}]' in value:
        eq += '='
    return f'[{eq}[{value}]{eq}]'

sources = {p: (root / p).read_text(encoding='utf-8') for p in paths}
if '--baseline' in sys.argv:
    ref = sys.argv[sys.argv.index('--baseline') + 1]
    sources['modules/warz_pvp/core.lua'] = subprocess.check_output(
        ['git', 'show', ref + ':modules/warz_pvp/core.lua'], cwd=root).decode('utf-8')

hub = (root / 'n3z.lua').read_text(encoding='utf-8')
hub = hub.replace('local function fetch(localPath, urlPath)',
                  'local function fetch(localPath, urlPath)\n    return assert(LOCAL_SOURCES[localPath], "test source missing: " .. localPath)\nend\nlocal function unusedRemoteFetch(localPath, urlPath)', 1)
hub = hub.replace('local ok, moduleResult = pcall(activeModuleFn, Window, ctx)',
                  'local ok, moduleResult = xpcall(activeModuleFn, debug.traceback, Window, ctx)', 1)
end = hub.rindex('return Window')
hub = hub[:end] + '''assert(type(env.__RAVEN_WARZPVP) == "table", "WarZ Hub startup failed; inspect console traceback")
assert(Window.itemsByFlag.WZP_InstantPickup, "startup stopped before Instant Pickup")
assert(Window.itemsByFlag.WZP_SilentAim, "startup stopped before Silent Aim")
assert(Window.itemsByFlag.WZP_InfiniteStamina, "startup stopped before Stamina")
return env.__RAVEN_WARZPVP.GetStatus()
'''
code = 'local LOCAL_SOURCES={' + ','.join('[' + json.dumps(p) + ']=' + quote(s) for p, s in sources.items()) + '}\n' + hub
prefix = ''
if '--cold' in sys.argv:
    prefix = '''local env=getgenv()
if env.__RAVEN_WARZPVP then env.__RAVEN_WARZPVP.Destroy() end
if env.__N3Z_WINDOW then env.__N3Z_WINDOW:Destroy() end
local slot=env.__RAVEN_WARZPVP_NAMECALL
if slot and type(slot.original)=="function" then
    hookmetamethod(game,"__namecall",slot.original)
    env.__RAVEN_WARZPVP_NAMECALL=nil
end
'''
code = prefix + 'local ok,result=xpcall(assert(loadstring(' + quote(code) + ', "@startup-integration")),debug.traceback)\nreturn {passed=ok,status=ok and result or nil,error=not ok and tostring(result) or nil}'
print(json.dumps({'code': code}))
