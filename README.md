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
