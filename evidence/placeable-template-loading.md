# Placeable data loading and tag sanitation

Target: NWN:EE89.8193.37-17, read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No game assets, running original processes or Ghidra database entries changed.

## Data owner

`src/placeable_template.js` ports complete LoadPlaceable1404b4900..1404b6702.
This is the data-loader coordinator, with lower owners supplied explicitly.
It is not yet connected to WorldTemplateRuntime or CreateObject243. In
particular, this checkpoint adds no new playable spell or campaign-completion
claim. The active runtime still only admits waypoint templates.

Full assembly: `backups/animations/native-world-blueprint-load-owners-v1.txt`.
The six AnimationState jump destinations are independently captured in
`placeable-template-tail-heads-v1.txt`; states0..5 map to0,75,76,72,73,74.

The loader preserves these observed details:

- A nonempty new-tag descriptor overrides Tag. Otherwise Tag is read and
  sanitized before SetTag sanitizes again. The requested template was assigned
  by the outer placeable wrapper before this loader; TemplateResRef568 then
  overwrites the base template string30. No positions or orientations are read.
- Invulnerable falls back to Plot only when its read fails. Missing Static is
  derived from Useable being unequal to1. Constructor override5a4 equal to1
  forces Static0; Static equal to1 forces invulnerability. Those equality tests
  are preserved separately from normalization inside the BYTE-as-BOOL reader.
- HP and CurrentHP are signed SHORTs, extended into maximumE4 and currentE0.
  Appearance is read as DWORD but stored as WORD. The four trap defaults and
  BodyBag default retain their existing low bytes; regular faction350 and trap
  faction3d8 remain distinct. PortraitId below65534 selects the numeric setter;
 65534 and65535 select the portrait resref path.
- GroundPile is read with its existing low-byte default, then discarded;
  field368 is always set to1. LightState defaults through GetLightIsOn. A
  change commits light594 and dirty598 only after successful active LightColor
  lookup; the returned color value does not decide whether to commit.
- All16 authored scripts use resrefs and their distinct string members. Empty,
  null or exactly `default` trap scripts select traps.2da/TrapScript, using
  BYTE TrapType. A different case does not match the default literal. Animation
  has priority over AnimationState; failed reads preserve the existing state.
- ItemList must return status exactly1. It is not gated by HasInventory. The
  item constructor precedes loading; requested ObjectId is read only for a
  nonzero loading flag. Failed loads destroy the item, null allocations are
  skipped, and successful loads use LoadFromGff last flag0. Repository WORD
  coordinates truncate to BYTE for acquisition, whose result is ignored.
- AnimationDay/Time precede all five visual owners, followed by UUID import and
  unconditional module tag insertion. Lower UUID results do not change the
  loader's return1. The outer template wrapper separately loads variables.

`inspect-native-placeable-template.py` executes the complete original owner
against431 synthetic fixtures. Captured lower boundaries are typed GFF,
SetTag/AsTAG, string/localized and resref assignments, virtual portrait/script/
animation methods, table queries, allocation, item constructor/load/destruction/
acquisition, five visual owners, UUID and tag insertion. Every read/default,
boundary-call order and all39 primitive field results are compared. This does
not establish parity inside those boundaries, native allocator failure
unwinding, malformed resources or a concrete UTP runtime adapter.

Captures: `native-placeable-template-observations.json`,
`placeable-template-native-v3.txt`, `placeable-template-tests-v4.txt`.
The first fixture run had the wrong rules-global address; disassembly establishes
1412df8f8, corrected before the successful comparison. An initial tag test
missed the owner's temporary string assignment at insertion; leading-NUL
normalization is now reflected at that boundary. Final fixture includes null
item allocation, failed item loading, noncanonical statuses and nonempty fields.

## Lower-owner identification

Complete captured bodies in `placeable-template-tail-owners-v1.txt` identify:

| Address | Serialized data |
| --- | --- |
| 140497bb0 | VisTransformList, or legacy VisualTransform |
| 140496ea0 | Material/ShaderParams |
| 140497990 | TextureReplace/TextureReplaceList |
| 1404969c0 | AnimationReplace/AnimationReplaceList |
| 1404972b0 | MiscVisuals |

These are visual-data loaders, not saved effect or action loaders. They remain
explicit boundaries here; their complete runtime ports and reload behavior are
next work before admitting placeables into WorldTemplateRuntime. The existing
creature animation override importer is not a substitute for all these owners.

## Tag lower owners

`src/object_tag.js` ports AsTAG14016ac40 and SetTag14045df80's resulting tag.
Original iteration uses stored byte length, sign-extends each byte for CRT
classification, separately accepts underscore, preserves case and stops after
63 accepted bytes. It can skip embedded NUL and accept bytes after it. SetTag
moves the sanitized result into baseTag20; module insertion is a separate call.

`inspect-native-object-tag.py` executes complete AsTAG, SetTag and classifier
140c89e6c with the image's original static C-locale table at140ed68b0, reached
through1412a2090. The zero locale-change flag at1415d7c18 is asserted, not
patched. Only allocation/free/memcpy/cookie are boundaries.888 observations
include all256 byte values, empty/null-data descriptors, embedded NUL, long
rejected prefixes, the63-byte boundary and deterministic random byte strings.
The native owner accepts ASCII letters/digits/underscore in this state. Changes
to the original process CRT locale are outside this comparison and port.

Captures: `native-object-tag-observations.json`, `object-tag-native-v1.txt`,
`object-tag-tests-v1.txt`, `placeable-tag-classifier-full-v1.txt`.
The partial static-state capture errors when attempting to read a zero-filled
uninitialized PE section; the emulator's mapped-image assertion covers that
cell. No successful claim is based on the failed static-state capture.

## Runtime correction and checks

`ObjectLifecycleRuntime.bodyBagField` had aliased E0 to maximum HP and E4 to
current HP. Synthetic body bags initialize both equally, hiding the error.
The bridge now maps E0 to currentHP/authored.CurrentHP and E4 to authored.HP.
An actual ModuleSession regression writes max31/current7, then current-3 and
checks both script-facing hit-point queries and distinct native message cells.
The existing body-bag loader/spawn and renderer paths use this same bridge.

All1,715 tests and production build pass. The existing build chunk-size warning
remains. Rendered casting (spellbook/radial/hotbar, slots, animations, cancellation
and counterspell) and body-bag (radial use, authored destruction, item transfer
and dynamic model) regressions pass; both owned processes reached exit0.
Logs: `placeable-template-full-tests-v1.txt`, `placeable-template-build-v1.txt`,
`placeable-template-casting-regression-v1.txt`,
`placeable-template-body-bag-regression-v1.txt`. The verified source/capture
checkpoint is `backups/placeable-template-1715-20261016-v1.zip`; its terminal
verification log is `backups/animations/placeable-template-checkpoint-v1.txt`.
