# Random projectile initialization and reset nodes — 2026-10-16

Progress toward the full spellcasting/combat/campaign goal. Generic randomized
projectile initialization now drives live path4/9, and high-ballistic path3 can
cross its reset node. The kind12 mathematical branch is implemented, but its
model-reference parenting service remains unavailable. No spell-specific branch
or alteration of installed spell data was added.

Read-only target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game/Ghidra project unchanged. Previous verified backup:
`client-projectile-render-1834-20261016-v1.zip`,9501 files,113300039 bytes.
See [live presentation scope](client-projectile-presentation.md).

## Native findings and implementation

Initializer987f10 random kinds4/9/12 normalize the supplied orientation argument,
derive an angle with CRT acosf, adjust it by a CRT draw and the shared global
DAT141428e7c, then construct a random direction. Kind9 consumes an extra parity
draw and allows a negative vertical component. The global toggle changes before
the speed draw. Zero/epsilon displacement bypasses this whole branch and consumes
no random values.

The helper atc946b0 is **logf**, not distance rounding. Speed uses the absolute
truncated integer of log(distance)*5 plus1 as its random modulus, then adds3.
Velocity is the normalized random direction times that speed; acceleration is
derived from remaining time and displacement with native scalar float32 rounding.
Replacing this with a guessed speed/ramp or adding arbitrary draws changes all
later random results on the client thread.

`client_projectile_random.js` supplies these shared mathematical owners.
`native_projectile_math.js` adds the finite acosf port and uses the **existing**
`native_log.js` implementation for both SSE/FMA branches. The observable speed
bound is accepted only if both branches agree; interior log bits may differ when
they produce the same integer. Exceptional math/CPU-dependent final outputs
remain explicit failures. The native trig guards are retained.

The angle-side cell is shared by the client module rather than reset per actor,
projectile or area. `main.js` now retains the same client animation RNG across
area rebuilds and shares it with projectile initialization. The local startup
seed remains1; actual startup seeding/full native client scheduling is not proved.
This does not change the authoritative server RNG or object registry.

High-ballistic reset nodes call CAurObject::AnimateExternal8c080. Its model header
counter increments before and after the virtual animation call, with the header
re-read afterward. `model_external_animation.js` ports that owner. The renderer
adapter supplies its counter and existing animator/run services, enabling reset
nodes to continue. Native outer Gob scene/culling/cache gates are still diagnosed
as `visual.projectile-external-animation-adapter-incomplete`.

## Independent evidence and tests

- `native-projectile-math-observations.json`, final capturev7:6042 cases,
  including2012 acosf and2015 positive logf cases for each CPU profile. Tests match
  exact bits, including positive subnormals, and verify the pre-existing log
  constants against captured binary values. Acos uses the native mixed float/
  double PI correction; subtracting an approximate asin from halfPI is inadequate.
- Unicorn cannot reliably execute this original AVX/FMA path. The final oracle
  decodes the **original VEX instruction stream**, supplies explicit packed/scalar
  instruction semantics and host CRT IEEE fmaf for fused instructions, while the
  original branch/control flow and SSE instructions execute in the emulator.
  FP notification is captured; original process CPU detection/errno/flags are not
  claimed. This is instruction-level emulation evidence, not hardware execution
  of the game's FMA path. Early attempts/v3-v5 produced invalid AVX observations;
  those are not acceptance. The first SSE port comparison found the native
  normalization base was0.5, not1. The final code reuses the existing correct log
  implementation; no parallel table/algorithm is retained.
- `native-client-projectile-random-observations.json`, finalv2:2601 full original
  initializer executions,867 per kind. Actual normalize, magnitude, acosf, logf
  and SSE sinf/cosf execute. Model/object/part lookups, CRT draws, sqrt/FP status
  and kind12 NewCAurObject(ref,empty)->null are captured lower services. Tests
  compare exact argument mutation/aliasing, velocity/acceleration, draw sequence,
  final CRT seed and shared toggle. NaN outputs compare classification; other
  vectors compare exact bits. Kind12 graph parenting is **not** proved.
- `native-model-external-animation-observations.json`:48 complete original
  wrapper cases. Animation is captured, optionally replacing the header. Counter
  wrap, no-header behavior, call order/delta and pointer replacement match.
- Presentation fixtures create five distinct client models from appearance7/
  path4, verify15 CRT draws and reclaim all five IDs/models/scenes. Path9 uses
  four draws. High-ballistic movement crosses its reset node and completes its
  lifecycle. These use owned model/service fixtures, not an installed spell or
  screenshot acceptance claim for those paths.
- Full1842 tests and build pass (`client-projectile-random-full-tests-v1.txt`,
  `client-projectile-random-build-v1.txt`). Installed projectile/Daze workflow and
  existing spellbook/radial/F2/cancel/counterspell rendered regressions pass
  (`client-projectile-random-projectile-ui-v1.txt`,
  `client-projectile-random-existing-ui-v1.txt`). These preserve prior fixture
  startup/entry overrides; not campaign acceptance.

The active installed inventory has nine ready wizard projectile slots and no
use-Projectile physical rows for paths3/9 in this session
(`installed-projectile-path-inventory-v1.json`). Native overrides are tested through
their actual appearance7 header inputs; installed data was not changed to invent
a ready spell for the new paths.

## Corrected filename collision

An early constant extractor accidentally reused the existing native_log_table.js
filename. The existing module was restored byte-for-byte from the latest verified
1834 checkpoint before any build. The temporary projectile copy was removed and
the extractor no longer writes source files. Both native_log.js and its table are
SHA256-identical to that checkpoint, recorded in
`projectile-log-table-preservation-v1.json`; old6018-case log tests and new
instruction comparisons pass. No original installation assets were affected.

## Remaining work

Linked kind7, kind12 reference parenting, scene-sampled paths8/11/12/13, child
projectile creation, c_dummy targets, cast controller98b130, impact part prefixes/
attachments and moving loop audio remain. Their missing services still throw or
produce specific durable diagnostics. Native client CC8 widgets and complete
renderer/client AI/cache/destructor parity remain open. Previous auditv47 is
unchanged evidence (65 unbound/22 missing), not a new audit. Full spells, combat
and campaign completion remain unproved; the goal stays active.
