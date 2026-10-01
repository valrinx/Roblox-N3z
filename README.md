# ⚡ Roblox-N3z (N3Z HUB)

A high-performance Roblox script hub featuring a modern **Native-GUI bottom dock UI**, responsive controls, and high-framerate visual and combat enhancements.

---

## 🚀 Quick Launch

Paste and run in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/n3z.lua"))()
```

or via the wrapper:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/valrinx/Roblox-N3z/main/init.lua"))()
```

---

## 🌟 Key Highlights

### 🎨 Sleek Native-GUI Dock
- Floating bottom dock inspired by modern desktop dock interfaces.
- Fully interactive cards, animated switches, and responsive full-width rows.
- Dynamic key rebind system with live `[...]` capture mode.
- Default toggle key: **`RightShift`** (configurable in SETTINGS).

### 🎯 Combat & Visual Enhancements
- **Live Skeleton ESP**: True joint bones (Head, Neck, Spine, Shoulders, Arms, Hips, Legs) with 60 FPS viewport projection.
- **Player & Box ESP**: Health bars, distance display, weapon tags, and customizable FOV circle.
- **Aimbot Engine**: Smooth angle tracking, deadzone dampening, distance filtering, and universal aim-key binding (Keyboard or MouseButton1 / MouseButton2 / MouseButton3).
- **Auto Heal**: Automated recovery using healing items whenever character health drops below configured threshold.
- **No Recoil**: Server-safe client recoil compensation.

---

## 🎮 Supported Game Modules

| Module | Game | Place ID | Features |
| :--- | :--- | :--- | :--- |
| **WarZPVP** | WarZPVP OPEN BETA | `135187059974536` | Skeleton ESP, Aimbot, Auto Heal, No Recoil, Loot Radar |
| **Steal An Egg** | Steal An Egg | `107778070777162` | Auto Farm, ESP, Teleport |
| **Illegal Soccer** | Illegal Soccer | `126987974021910` | Auto Goal, Speed, Stamina, Ball ESP |
| **Wanted** | Wanted | `14438406081` | ESP, Silent Aim, Triggerbot |
| **War Tycoon** | War Tycoon | `4639625707` | Base Auto Collect, Player ESP |
| **Frisbee Frenzy** | Frisbee Frenzy | `106986181033085` | Auto Catch, Curve Boost |

---

## 📁 Repository Structure

```
Roblox-N3z/
├── init.lua           # Entrypoint wrapper
├── n3z.lua            # Main loader & module manager
├── n3z-dock.lua       # Native GUI Dock library
├── n3z-compat.lua     # Window adapter for legacy & new modules
├── modules/           # Game-specific modules
│   ├── warz_pvp.lua
│   ├── steal_an_egg.lua
│   ├── illegal_soccer.lua
│   ├── wanted.lua
│   ├── war_tycoon.lua
│   └── frisbee_frenzy.lua
└── README.md
```

---

## ⌨️ Hotkeys

- **RightShift** : Toggle Dock Menu (Rebindable in SETTINGS tab)
- **Aim Key** : Default `MouseButton2` (Rebindable in COMBAT tab)


---

## 🛡️ N3Z Shield v3

Shield v3 provides three build modes:

- `auto` (default): hybrid selection per file using file role plus a 28 KiB plaintext threshold.
- `performance`: larger blocks, one decode round, lower runtime overhead.
- `max`: smaller blocks, three decode rounds, stronger per-build diversification.

Auto policy forces `init.lua`, `n3z.lua`, and `n3z-compat.lua` to `max`; forces `n3z-dock.lua` to `performance`; and selects module profiles by size. The threshold can be overridden with `--auto-threshold-kib`.

Build from plaintext working-tree sources:

```powershell
cd tools
python protect_all.py
```

This repository currently keeps Shield v2-protected Lua in the working tree. To migrate without double-wrapping v2, build from the last plaintext Git revision:

```powershell
python protect_all.py --profile auto --source-ref b4559de
```

Artifacts are written to `dist/<profile>/` by default. Every build writes `shield-manifest.json` with the selected profile and byte sizes for each file. Use `--output-dir` for a custom destination. Explicit `--profile performance` or `--profile max` overrides Auto. `--in-place` exists for compatibility but is not recommended.


### Benchmarking

Use `tools/benchmark_shield.py` to compare build cost and decoder throughput. It can emit a Luau-only decode/compile benchmark that validates checksums but does not execute the decoded payload.

Current live measurements show `max` at roughly 2x the startup cost of `performance` on representative 38 KiB and 66 KiB project files, while protected output size differs by less than 1%. See `tools/BENCHMARK.md` for the measured values and profile policy.
