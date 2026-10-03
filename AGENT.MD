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



