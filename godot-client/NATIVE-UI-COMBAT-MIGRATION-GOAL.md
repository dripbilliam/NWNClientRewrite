# Native UI and combat migration goal

Priority changed 2026-10-28: [complete UI parity](NATIVE-UI-PARITY-GOAL.md) is
the active goal. General/combat porting is deferred until that UI goal is fully
complete. This document retains unfinished backlog and historical evidence;
the priority change does not mark its requirements complete.

Requested 2026-10-27. Parity and completion are unproven. Continue the
Godot migration with the original binary as the behavioral and visual reference.
The user explicitly reiterated that parity includes the UI's actual appearance,
not only the availability of its controls and actions.
The earlier JS client is reference only, never a rendering/UI implementation
dependency. The performance investigation remains documented and incomplete;
this priority change does not turn its unrun experiments into accepted fixes.

## First priority: sliding and attack facing

Reproduce the user's reported sliding and incorrect attack facing. Trace the
full authoritative motion/orientation -> visual pivot -> locomotion/attack/cast
queue -> private model playback path, including when ordinary pose updates can
overwrite a combat orientation or clip. Compare the original binary's target,
turning, clip-selection and timing rules read-only. Preserve authoritative state
instead of guessing gameplay outcomes or overwriting network positions locally.

Verify repeating idle/walk/run cycles, strafing and turning, starting/stopping,
attacks on moving/static targets, casting, reactions/death, equipment/body/shape
changes and per-actor independence. Use real owned local-server scenarios and
scoped animation/pixel/state evidence; a passing queue fixture alone cannot prove
that the actual streamed character faces its target and animates correctly.

Current entry points: `systems/native_render/live_world.gd`, `network_motion.gd`,
`native_render/combat_presentation.gd`, `native_render/combat_rigs.gd`,
`combat_animation.gd`, `model_rigs.gd` and `native_data/animation_lookup.gd`.
`NATIVE-COMBAT.md` already labels the migration partial and lists open clock,
shape, reaction/death/audio and mixed-client gaps. Keep those gaps visible.

## Native-style UI that actually works

Audit and port the original game's HUD, party indicators, base gameplay menus
and movable persistent windows. Give the right-click radial menu explicit
coverage: appearance/layout, original icons, target/context-dependent choices,
submenus (including spell families), availability, pointer/keyboard interactions,
screen-edge placement, layering above other menus and dismissal behavior.

Every actionable control must issue the correct server request and display the
authoritative result, including failure/targeting feedback. Verify inventory,
character sheet/level-up, spellbook, map/journal, dialogue/examine and party/action
interfaces against actual migration gaps. Preserve simultaneous windows, saved
positions and ordering, outside-menu click movement, WASD and middle-mouse camera
behavior. Keep text readable and server-provided tokens/icons data-driven.
NUI completeness must not displace the user's priority on base-game playability.

Visual follow-up reported 2026-10-28: some assets in the recent images appear
stretched. Treat aspect ratio and cropping as open acceptance items, including
portraits, equipment silhouettes, item icons and button artwork. Compare the
rendered rectangles with original GUI/MDL geometry and UVs at native scale and
when scaled; preserve a common scale on both axes for artwork. Account for
portrait padding before measuring proportions. Do not mark this resolved from
functional input checks, or replace original mesh/UV layout with a blanket
texture-fitting rule. The specific distorted assets still need confirmation.

## Compatibility, validation and delivery

- Rules and resources come from the selected server's actual tables, overrides,
  HAKs and NWSync scope. Do not hardcode Arelith/NPC IDs, feats or spell lists.
- Preserve original models/textures, private mutable state, protocol and original
  client/server compatibility. Native Godot owns rendering and gameplay UI.
- Use the owned local Prelude/gameplay server and sealed captures; no automated
  public/Arelith connection. Manual user sessions are observational evidence,
  never permission to drive public gameplay automatically.
- Do not interrupt the user's live session or competing game. Launch on the
  secondary monitor without focus or mouse capture. Keep performance diagnostics
  and existing optimizations; Compact scenery remains opt-in/default off.
- Investigate broader rendering/loading candidates separately. Obtain user
  approval before promoting a drastic method as the main/default approach.
- Preserve verified backups at notable milestones, original-binary build/address
  evidence, scoped test receipts, remaining gaps and a usable reference index.

Completion requires representative server-authoritative UI actions and actual
movement/combat presentation with original-binary parity at the tested scope.
Screenshots, synthetic tests, fewer nodes or a menu that only looks clickable
do not prove completion. Report remaining evidence gaps honestly.

Starting verified checkpoint: `native-entity-inspector-body-flags-v1.zip`, SHA256
f5f8d98bd4e6950a26c5709267cd3c8c9265826719a14d7cd200b41b26994164.
The layer-retirement prototype is isolated under `experiments/`, unrun and not
imported by production. Do not silently mix it into the gameplay/UI migration.

## First scoped result

`NATIVE-TARGET-FACING.md` records the missing native lock-target resolution,
correction and original-binary call sites. Authored/oracle/integration checks
and the owned local graphical combat scenario pass, including actual rendered
pivot alignment to the server-selected attack target.

`NATIVE-MOVEMENT-CUE-PLAYBACK.md` records the missing correction-cue delivery
and actual-visual feedback, now implemented through native private playback.
54034 scoped checks and8 owned-server graphical correction checks pass.
Movement destinations are cross-checked against incoming wire positions.
The combined combat scenario exposed an undisclosed maximum-HP blood-effect
dependency. The [private constructor follow-up](NATIVE-BLOOD-VISUALS.md#private-constructor-hp-follow-up)
now matches original client storage defaults without inventing authoritative
NPC HP. Original constructor/model checks and67 full owned-server action checks
pass, including facing, visible impacts and cancellation. Broader effects and
other private-stat consumers remain separate acceptance work.
UI appearance and complete combat/mixed-client acceptance are still pending.

## Radial artwork result and continuing UI audit

[NATIVE-RADIAL-UI.md](NATIVE-RADIAL-UI.md) records the original constructor,
attachment/selection/placement evidence and implemented native model-art port.
Separate original56px circular discs and server-scoped32px icons replace the
380px filled panel and88×72 caption rectangles. Native hooks,155px placement,
hover ring/text, portrait/category centers and Back are verified along with
actual server examination and spell casting. Late artwork cannot overwrite a
newer menu binding. Verified source checkpoints and failed receipts are retained.

The [native feat port](NATIVE-FEAT-RADIAL.md) implements the original leaf,
variant and callback rules, fixes menu state/shortcut packing and adds the core
Special Attacks tree. Original-server Druid testing verifies an authoritative
family shortcut/shape change and the new body's cycling native walk. Remaining
class grouping, mode-state presentation and broader combat acceptance stay open.

This does not complete radial parity: native preferences, submenu previews,
rubber-band art and full context/role availability remain. Other gameplay
windows still need original framing/layout and broader action acceptance.

The [inventory equipment follow-up](NATIVE-INVENTORY-EQUIPMENT.md) replaces
approximate slots/full-box icon stretching with original GUI positions, model
frames, icon centers and empty-slot art. Original-resource, pointer/lifetime and
full owned-server action checks pass. The [outer-frame follow-up](NATIVE-INVENTORY-FRAME.md)
adds original inventory/container layouts,33px repositories and per-state artwork
sizes, including the user's reported stretched assets. The [gold follow-up](NATIVE-INVENTORY-GOLD.md)
connects original amount/drag controls, real ground/container transfers and barter
refusals, and fixes container request identity. The [player barter follow-up](NATIVE-BARTER.md)
adds original trade controls/artwork and real local two-player item/gold exchange,
including recipient-role cancellation refunds. Mixed original/replacement trade,
edge cases and the remaining gameplay windows still need parity.
The [merchant follow-up](NATIVE-STORE-FRAME.md) now supplies original panel/tab
attachments, grid/icon geometry, local hover/confirmation text and purchase/sale
controls with real local-server acceptance. Identification's original examine
placement, scrollbars/fonts and wider merchant callbacks remain open.
