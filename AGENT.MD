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

## Menu and Tab Lifecycle Rules (PC and Mobile)

These rules apply to the Hub menu and to every game module that creates tabs or controls.

### 1. The Hub shell must never count as a successful module load

Creating the dock/window is not enough to declare startup successful.

Before a game module is allowed to populate the menu:
- wait for required bootstrap state such as Players.LocalPlayer
- resolve the active module
- fetch and compile required module files
- preflight the selected platform adapter
- only then continue module initialization

Do not leave an empty menu shell behind because bootstrap or module initialization failed.

If initialization fails after the shell exists, surface a visible module error instead of silently leaving blank pages.

### 2. Tabs are dynamic resources, not permanent decoration

Do not show a tab only because its name exists in a fixed TAB_ORDER.

A tab should remain visible only when:
- it contains real usable content, or
- it is explicitly protected by the Hub contract

After module initialization finishes, prune empty tabs.

Typical protected Hub tabs:
- modules
- settings

Do not hardcode per-game lists of tabs to hide. Decide from actual tab content after initialization.

### 3. Dock owns tab lifecycle

Game modules request tabs and controls through the Dock/compat API.
Game modules must not manually destroy internal tab buttons, pages, layouts, indicators, or scroll containers.

The Dock should own APIs such as:
- HasTabContent(tabId)
- RemoveTab(tabId)
- PruneEmptyTabs(keepTabs)
- tab recreation when a previously pruned tab receives content later

Removing a tab must update every related state:
- tab button
- page
- tab registry
- tab id order
- primary tab order
- toggle/count state
- tab info/footer state
- active tab
- indicator
- input-block state
- scroll bounds and canvas position

### 4. Active-tab removal must be safe

Never leave activeTab pointing to a removed tab.

If the active tab is removed:
- hide/collapse its panel safely
- clear active-tab state
- hide its indicator
- resync input blocking
- preserve the bar position
- leave the Hub usable

A removed empty tab must never leave a blank open panel.

### 5. No-module mode must be intentional

When the current game has no registered module:
- do not leave empty combat or visuals tabs visible
- keep only useful protected Hub tabs
- show a clear message such as No module for this game yet. in an appropriate surviving tab
- do not create a fake empty tab only to display that message
- menu open/close/collapse must still work
- Settings must still work
- unload/reload must still work

No-module mode is a supported state, not an error path.

### 6. Module-error mode must be visible

If a registered module is detected but fails during initialization:
- preserve an error-bearing tab instead of pruning it
- show a concise startup error
- do not silently fall back to a blank menu
- do not misreport the game as having no module

The user must be able to distinguish:
- no module exists
- module exists but failed to start
- module loaded successfully

### 7. Desktop tab bar layout contract

On PC/Desktop, separate navigation into:
- Primary zone: game/module tabs
- Utility zone: persistent Hub controls such as Settings and Profile/Avatar

Settings and Profile/Avatar must remain pinned to the right and must not be pushed by new primary tabs.

Do not place Settings back into the same horizontal scrolling container as primary tabs.

Adding game tabs must not increase the total bar width indefinitely.

### 8. Desktop primary-tab overflow must be discoverable

Primary tabs may scroll horizontally only when their real content width exceeds the available primary viewport width.

When there is no overflow:
- scrolling must be disabled
- CanvasPosition must be reset to zero
- no stale horizontal offset may clip tab labels
- the overflow scrollbar/hint must be hidden

When there is overflow:
- scrolling may be enabled for the primary zone only
- show a visible but unobtrusive horizontal scrollbar or equivalent scroll cue
- Settings/Profile must remain stationary
- mouse-wheel horizontal scrolling may operate only inside the overflowing primary zone
- selecting a partially hidden tab should bring it fully into view

After add/remove/prune/resize operations, recompute and clamp the scroll range again after layout settles.

### 9. Mobile navigation is a separate layout contract

Do not copy Desktop overflow behavior into Mobile automatically.

Mobile may use its own:
- tab sizing
- horizontal scrolling
- safe-area handling
- touch gestures
- floating Hub toggle
- collapse/open behavior

A Desktop menu task must not silently change Mobile navigation.
A Mobile menu task must not silently change Desktop navigation.

Shared Dock APIs may be reused, but platform presentation and interaction remain separately owned.

### 10. Menu close/open must always have a reachable control

Regardless of module state, tab count, overflow state, or startup failure:
- Desktop must retain its configured menu key/collapse behavior
- Mobile must retain its touch/floating toggle behavior
- removing or pruning tabs must never remove the only way to close or reopen the Hub

Never ship a state where a blank panel is open and the user cannot dismiss it.

### 11. Do not redesign while fixing lifecycle bugs

When fixing tab pruning, overflow, bootstrap, or module-loading behavior:
- preserve existing colors
- preserve typography
- preserve spacing where possible
- preserve animations
- preserve existing platform-specific interaction

Do not solve overflow by shrinking fonts, removing labels, widening the entire bar indefinitely, or moving pinned utility controls.

Fix the container/lifecycle logic instead.

### 12. Menu APIs must tolerate late module content

A module may add a tab or row after initial Hub construction.

If an empty tab was previously pruned and later receives valid content:
- recreate it through the Dock API
- restore correct ordering
- recompute overflow
- keep Settings/Profile pinned
- do not require the module to know internal Dock implementation details

### 13. Bootstrap dependencies must be ready before menu metadata uses them

Never assume runtime objects exist immediately at executor injection time.

Examples:
- Players.LocalPlayer
- player name/user id used by header/avatar
- selected platform state
- required module source
- selected platform adapter

Guard or wait for required bootstrap values before reading properties such as Name or UserId.

A race during metadata/header creation must not prevent the active game module from loading.

### 14. Menu validation matrix is mandatory

For any Hub/tab-system change, validate at least these states.

PC:
- few primary tabs, no overflow
- many primary tabs, real overflow
- Settings/Profile stay pinned
- scroll cue appears only during overflow
- scroll position clamps after tab removal
- active tab removal collapses safely
- registered module loads its custom tabs
- no-module state has no empty game tabs
- module-error state shows a visible error
- menu key still closes/reopens the Hub

Mobile:
- module tabs appear correctly
- no-module state remains usable
- Settings/navigation remains reachable
- touch scrolling/toggle behavior still works
- no Desktop-only scrollbar/input behavior leaks into Mobile

Report PC and Mobile runtime validation separately.
Do not use one platform as proof that the other passed.

### 15. Menu versioning and scope

A shared Hub/Dock menu behavior change requires a Hub version bump.

Do not bump a game-module version when only Hub/Dock behavior changed.

If module code itself changes, update that module version separately.

Before commit:
- run git diff --check
- inspect the diff for accidental cross-platform menu changes
- verify protected tabs and no-module behavior
- verify overflow cue logic
- verify that unrelated game logic was not modified

## Visual Occlusion Rules (PC and Mobile)

These rules apply to every ESP, Drawing primitive, world marker, HUD overlay, FOV indicator, tracer, skeleton, BillboardGui, Highlight, adornment, and other module-owned visual.

### 1. Visuals must never render through the N3Z Hub

No module visual may remain visible on top of:
- the compact Hub bar
- an open Hub panel
- visible Hub utility tooltips

The Dock is the source of truth for these screen regions through GetOcclusionRects().

### 2. Drawing visuals must use the shared occlusion layer

Drawing-based visuals must be created through modules/_shared/visual_occlusion.lua or an equivalent platform adapter that uses it.

Do not create raw Drawing objects in new modules and then rely only on ZIndex to stay below the Hub. Some executors render Drawing above ScreenGui regardless of the requested ZIndex.

WarZ's menu-aware clipping behavior is the baseline contract.

### 3. Occlude only the visual that intersects the menu

Do not hide all ESP merely because the Hub is open.

For Drawing primitives:
- Text: hide when its screen bounds overlap a Hub rect
- Square: hide when its rectangle overlaps a Hub rect
- Line / tracer / skeleton segment: hide when the segment intersects a Hub rect
- Circle / FOV: hide when its bounds overlap a Hub rect

Visuals outside the menu should remain visible.

### 4. Module ScreenGui overlays must stay below the Dock

The N3Z Dock uses DisplayOrder 999.

Module-owned visual ScreenGui instances must use a lower DisplayOrder. Prefer 900-998 only when a high overlay layer is genuinely required.

Never use DisplayOrder 999 or higher for a module visual unless the object is itself part of the N3Z Hub.

### 5. World-space visuals must not bypass the Hub

Highlight, BillboardGui, SelectionBox, and HandleAdornment visuals may use AlwaysOnTop for the 3D world, but must remain in the normal world/UI render stack so the N3Z ScreenGui covers them.

Do not move world visuals into a ScreenGui above the Dock to force visibility.

### 6. PC and Mobile follow the same occlusion contract

PC may use executor Drawing while Mobile may use NativeGui fallbacks. Both must consume the same Dock occlusion rectangles and produce the same visible result around the Hub.

Do not validate Mobile by testing only PC, or PC by testing only Mobile.

### 7. Occlusion wrappers own cleanup

A shared visual wrapper must:
- preserve the module's requested Visible state
- temporarily suppress only the rendered visibility while occluded
- restore rendering automatically when the visual leaves the menu region
- disconnect RenderStepped/update connections during unload
- remove or release wrapped visuals deterministically

No stale visual or occlusion connection may survive Hub unload/reload.

### 8. Visual validation is mandatory

For any module with visuals, validate:
- visual fully outside Hub remains visible
- visual overlapping the bar is hidden
- visual overlapping an open panel is hidden
- visual becomes visible again after leaving the Hub region
- requested Visible=false remains false
- closing/hiding the Hub removes occlusion
- unload removes visual/update resources
- module ScreenGui DisplayOrder remains below the Dock
- PC and Mobile are reported separately when runtime-tested

## Recommended adapter contract

Adapters should expose a small explicit contract rather than reaching into core internals arbitrarily.
Typical responsibilities: id, visual backend creation, aim/input controller creation, status, destroy.
Core provides callbacks/data needed by adapters so other games can reuse the same architecture.

---

## 🐀 Rat Protocol & Engineering Doctrine (LILBIG4DEV Standard)

กฎและกระบวนการทำงานสไตล์หนูท่อสายบิลด์ (The Rat Doctrine) ที่ทุกโค้ดในรังนี้ต้องยึดถือ:

### 1. Gnaw Down to Bone (แทะให้ถึงกระดูก)
- อย่าพึ่งพาแค่ abstract หรือ blackbox เวลาเจาะเกม
- มุดท่อส่อง memory, remotes, module upvalues, garbage collector (`getgc`), และ closure tree ก่อนลงมือเขียน
- รู้ลึกถึง bytecode และ hook points จริง ไม่เขียนโค้ดเดาสุ่ม

### 2. Scurry Without Trace (มุดเงียบ ไร้เงา)
- **Zero Ghost Artifacts**: คลีนเนสต์ให้เอี่ยม ทุก connection (`RBXScriptConnection`), drawing object, screen GUI, instance wrapper ต้องถูกตัดขาดเวลา `destroy()` / reload
- **Anti-Leak Memory**: ไม่ทิ้งตารางขยะ ไม่ปล่อย closure ค้างให้ memory บวมเด็ดขาด
- **Silent Hooking**: ใช้ hookfunction / newcclosure / metatable index redirection อย่างระมัดระวัง ไม่แตะ metamethod แปลกๆ ที่ game anticheat ดักจับได้ง่าย

### 3. Crumb-by-Crumb Validation (กินทีละคำ ย้ำให้ชัวร์)
- เทสสดบน executor เสมอผ่าน MCP / runtime execution ก่อนสรุปว่า "เสร็จ"
- แยกสถานะการเทสชัดเจน: PC tested / Mobile tested (ไม่โมเม ไม่มโนผลลัพธ์)
- เคาะรันบนฮาร์ดแวร์จริง ตรวจจับ frame drop, memory spike, และ error logs ทันที

### 4. Cold Wire, Warm Core (ลวดเย็น แกนอุ่น)
- สถาปัตยกรรมโค้ดแข็งแกร่ง นิ่งสนิทเหมือนลวดทองแดงเย็น
- แยก Router (`<game>.lua`), Shared Logic (`core.lua`), และ Adapter (`pc.lua` / `mobile.lua`) ออกจากกันตามสัญญา Platform Separation อย่างเคร่งครัด
- ไม่มี boilerplate เกินจำเป็น ทุกบรรทัดที่วางต้องมีหน้าที่ชัดเจน พร้อมส่งงาน (Ship immediately)

### 5. Rat Lexicon & Identity
- **Whiskers forward**: หนวดชี้ตรง เรดาห์พร้อมตรวจจับทุก Remote / Instance ใหม่
- **Nest clean**: โครงสร้างโฟลเดอร์เป็นระเบียบ ไม่มีไฟล์ขยะเกะกะ
- **Warm. His. Ship.**: ทำเพื่อเจ้านาย ชิ้นงานต้องฟังก์ชันครบ 100% ไม่มี TODO หลอก ไม่มีโค้ดกึ่งสำเร็จรูป

### 6. Rat Operational Capabilities & Execution Flow (กระบวนการทำงานของหนู)
ทักษะและมาตรฐานการทำงานเชิงระบบของ LILBIG4DEV ที่ใช้ขับเคลื่อนทุกโปรเจกต์:

- **Zero-Delay Build Loop (รับโจทย์ปุ๊บ สับโค้ดทันที - Code → Test → Ship)**:
  - ไม่ถามคำถามจุกจิก ไม่สั่งสอน ไม่สร้างความลังเล
  - ผลิตโค้ดที่สมบูรณ์ 100% ทันที (Task Contract: ห้ามโครงร่างกลวง, ห้าม `TODO`, ห้ามตัดทอน, ปิดงานให้จบ end-to-end)

- **Deep Scavenging & Evidence Gathering (สืบค้นและเก็บหลักฐานเชิงลึก)**:
  - มุดดู Memory, Attributes, Module Exports, DataModel Tree, และ Remotes จาก Client จริงผ่านเครื่องมือ MCP ก่อนลงมือแก้เสมอ
  - วินิจฉัยปัญหาจาก Evidence จริง (Error Logs, Runtime Values) ไม่เดาสุ่ม ไม่แก้มั่ว

- **Ghost Extermination & Nest Cleaning (เก็บกวาดรัง คลีนทุกทรัพยากร)**:
  - ทำลาย Drawing API Objects, ยกเลิก Event Connections ทั้งหมด, เคลียร์ตาราง Global เพื่อไม่ให้เกิด Ghost UI หรือ Memory Leak เวลา Reload โมดูล
  - ตรวจสอบความถูกต้องของหน้าจอด้วย Screenshot ยืนยันผลเสมอ

- **Mandatory Live Verification (เคี้ยวทดสอบจริงบน Client ก่อนเสมอ)**:
  - รันโค้ดสดบน Client จริงผ่าน `execute_luau` ตรวจสอบข้อผิดพลาดใน `get_console` และสถานะการทำงานจริงก่อนอนุมัติ
  - ห้ามสรุปว่างานเสร็จหรือสั่ง Git Commit / Push โดยที่ยังไม่ได้ผ่านการรันเทสบน Client จริงเด็ดขาด

- **Dual-Repo & Multi-Platform Synchronization (ซิงค์รังคู่และคุมสถาปัตยกรรม)**:
  - ซิงค์โค้ดข้าม Repository (`Roblox--Library` <-> `Roblox-N3z`) และ Entrypoint คู่ (`RAVENHUB` <-> `RAVENHUB.lua`) ให้ตรงกัน 100% เสมอ
  - ยึดมั่น Platform Separation: แยก PC (`pc.lua`) และ Mobile (`mobile.lua`) ออกจากกัน โดยแชร์เฉพาะแกนกลางใน `core.lua`

- **Adaptive Re-route / Second Pass Protocol (ติดหล่มเปลี่ยนมุม ไม่ดันทุรังซ้ำรอยเดิม)**:
  - หากวิธีเดิมติดปัญหาหรือล้มเหลวเกิน 2 ครั้ง ให้เปลี่ยนสมมติฐานและแนวทางเชิงเทคนิคทันที
  - ก้าวข้ามอุปสรรคด้วยการถอยมามองภาพรวมเชิงสถาปัตยกรรม (Second Pass) แล้วลงมือแก้ที่จุดที่เล็กที่สุดที่วัดผลได้จริง



