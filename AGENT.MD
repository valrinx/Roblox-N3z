# AGENT.MD

## Platform Separation Rules

These rules apply to every game module in this repository.

### 1. PC and Mobile must be separate implementation paths

For games that support both desktop and mobile, prefer:

modules/<game>.lua
modules/<game>/core.lua
modules/<game>/pc.lua
modules/<game>/mobile.lua

The top-level <game>.lua is only a thin loader/router.
core.lua contains shared game logic.
pc.lua contains desktop-only behavior.
mobile.lua contains Android/iOS-only behavior.

Do not copy the whole game implementation into both platform files.
Shared logic belongs in core.lua.

### 2. Platform detection

Use ctx.platform from the Hub whenever available.
Expected values are "pc" and "mobile".
The Hub owns platform routing. Game modules must not invent a conflicting routing rule.
When a low-level check is unavoidable, Android/iOS are mobile.
Never use only TouchEnabled to classify a client as mobile.

### 3. No cross-platform behavior changes

A Mobile task must not silently change PC UI, controls, input behavior, visuals, or defaults.
A PC task must not silently change Mobile behavior.
Shared changes are allowed only when genuinely platform-neutral.
If a shared contract changes, review both adapters before committing.

### 4. UI and input separation

Desktop presentation and keyboard/mouse controls belong in pc.lua.
Mobile presentation, touch controls, safe-area and orientation behavior belong in mobile.lua.
Do not redesign shared UI while implementing Mobile support.
Do not make Mobile fall back to mousemoverel or desktop Aim Key behavior.
Do not make PC depend on touch controls.

### 5. Visual backend separation

The platform adapter owns visual backend policy.
PC normally uses Drawing API and a PC-approved fallback when required.
Mobile normally uses NativeGui/ScreenGui.
Shared ESP calculations, colors, positions, relations, ranges and categories belong in core.lua.
Core consumes a small visual interface instead of branching on platform throughout ESP code.

### 6. Aim separation

Shared aim logic belongs in core.lua: target selection, FOV, bones, LOS, prediction and ballistics.
PC aim actuation belongs in pc.lua: mouse/key state and desktop aim movement.
Mobile aim actuation belongs in mobile.lua: touch/fire state and mobile camera movement.
Do not duplicate target selection or prediction in both adapters.

### 7. Module loader contract

Submodules must be loaded through ctx.loadModuleFile(path) when the Hub provides it.
Do not add direct raw-GitHub HttpGet calls inside game adapters.
The top-level game loader selects ctx.platform, loads core.lua, loads exactly one adapter,
passes that adapter into core, and fails visibly when a required submodule cannot load.

### 8. Lifecycle and cleanup

Each adapter owns deterministic cleanup for its connections, GUI, Drawing objects, input bindings,
camera/input state and any platform-specific hooks.
Core owns cleanup for shared state.
Unload/reload must not leave ghost UI, stale connections, or old hooks.

### 9. Versioning

When a game module changes, update its Hub registry version.
When the Hub loader/shared contract changes, update the Hub version too.
Do not leave display versions behind implementation versions.

### 10. Testing discipline

Test the target platform on the target platform.
Do not use PC runtime behavior as proof that Mobile works.
Do not use Mobile runtime behavior as proof that PC works.
Shared static validation may include syntax checks, git diff --check and contract checks.
Runtime status must be reported separately as PC tested/not tested and Mobile tested/not tested.
Never claim runtime validation for a platform that was not actually tested.

### 11. Change scope

Before committing a Mobile change, inspect the diff for accidental desktop changes.
Before committing a PC change, inspect the diff for accidental Mobile changes.
Prefer small platform-scoped commits over mixed platform commits.

## Recommended adapter contract

Adapters should expose a small explicit contract rather than reaching into core internals arbitrarily.
Typical responsibilities: id, visual backend creation, aim/input controller creation, status, destroy.
Core provides callbacks/data needed by adapters so other games can reuse the same architecture.
