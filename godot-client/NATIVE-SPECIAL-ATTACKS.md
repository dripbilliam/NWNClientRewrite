# Special-attack visuals — native integration, incomplete acceptance

Follow-up to [shield impacts](NATIVE-SHIELD-IMPACTS.md). Native code owns the
original unarmed gate/load/play, body blur/completion events, equipped slotFB/
colours and special initialization/eye-effect owners. Full gameplay, visual and
mixed-client parity remain incomplete. Particle optimization and live/GPU tests
are paused while the user plays another game; feature integration continues.

All original instructions are from read-only NWN:EE 89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

## Established original boundaries

- `0x1407fd6b0`: retained complete owner dossier in
  `reports/native-weapon-effect-boundary-research-v1.json`. State at actor+378
  suppresses identical requests. With no right-hand item, special-attack39
  selects loader2 and296 selects3; the ordinary path checks `0x1407fdca0`,
  loads0 and plays0. Disable plays cessation in slot order2,3,0,1. An equipped
  ModelType2 weapon selects ItemClass+`_mb`, model slotFB and optional color
  scope4. Early-return/state-write distinctions must be preserved.
- `0x1407fdca0..0x1407fdd57`: raw class-type5 and feat213 lookup in either
  original feat list. Mode1 returns whether the **last matching class's BYTE
  level** is at least20; other modes return the feat/class predicate. Do not
  replace this with a sum or maximum of class levels. Receipt:
  `reports/native-special-attack-gate-research-v1.json`.
- `0x140803c50..0x140803f1d`, original log name LoadSpecialAttacks: types0/1
  lazily allocate slots0/1 with `vcm_monkki`/`kistrike`; type2 uses slot2 and
  `vcm_monkstun`/`stunfist`; type3 uses slot3 and `vcm_monkquiv`/`quivpalm`.
  Allocation and attachment are separate: only the selected type's slot is
  attached in a call. Animation203/200/202 or an active FE model slot chooses
  rhand;201 chooses lhand;204/263 rfoot_g;264/265/205 lfoot_g. Other animations
  leave attachment unchanged. Receipt:
  `reports/native-special-attack-loader-research-v1.json`.
- `0x1408074b0..0x1408075c8`, original log name PlaySpecialAttacks: type0/1
  plays both extant slots0/1; type2 plays slot2; type3 plays slot3. The virtual
  animation request is impact, speed1, flags1, time0. Unsupported types warn.
  Receipt: `reports/native-special-attack-play-research-v1.json`.

The recovered pseudocode sometimes displays a null model receiver for the
type2/3 play call. Actual assembly at807522/807529 and controlled execution
preserve the real non-null slot pointer in RCX; do not implement that decompiler
artifact. Constructor, attachment and clip boundaries still need their actual
native model providers and complete owner/lifetime acceptance.

## Independent unchanged-instruction cases

`scripts/inspect-native-special-attack-visuals.py` executes all three complete
original functions in the offline emulator, captures controlled class/feat,
constructor and Gob-vtable boundaries, and never modifies the executable or a
running original process. The retained output
`reports/native-special-attack-original-v1.json` contains112 gate,728 loader
and96 playback cases, with original function-byte and script hashes. It covers
preexisting slot masks, all four valid loader types, animation/FE choices,
feat-list alternatives, level19/20 and repeated class ordering; playback also
covers unsupported types. These936 cases establish original outputs, not a
passing Godot implementation by themselves. `native-special-attack-data-v3`
separately passes938 native checks against this corpus. Actual model/GPU, full
callers and teardown are outside the emulator's scope.

Existing historical receipts remain in
`backups/animations/rea-combat-weapon-visual-load-current.json`,
`rea-combat-weapon-prepare-owner-current.json` and
`rea-combat-weapon-effect-owner-current.json`. The prepare owner7fecc0 changes
model slots/flags; its name alone is not evidence that it creates these models.
Use these receipts before requesting another whole-function analysis.

## Native delivery and remaining acceptance

Original body slotFF registers blur_start at7fd6a0 and blur_end/doneattack01/02
at80f4a0. Read-only wrapper instructions feed enable1/0 into7fd6b0. The original
attack selector stores the selected record's special-attack field. Native
`combat_animation.gd`, `special_attack_world.gd` and
`native_data/special_attack_visual.gd` now connect that metadata to the actual
original models and physical body/robe Part ownership. Models use native
workers/catalogs; immutable owned resources warm without creating instances or
blocking control. Ready models attach/play synchronously in the blur callback,
and canonical actor/model/lifetime/area retirement releases their owners.

`native-special-attack-world-final-v1` passes21 actual original model/Part and
lifetime checks. `native-special-quivering-first-v1` passes14 checks, including
real server use consumption, visible Quivering Palm pixels, cessation and
cancellation. `native-impact-stun-visibility-v1` passes14 with visible original
Stunning Fist particles. **Earlier missing Stun output remains intermittent;
one passing repeat is not resolution.** The chained Stun→cancel→Quivering Palm
case still fails even with a mortal target; changing the fixture's immortal flag
did not establish or fix that cause. First-action Quivering Palm passing does
not establish chained action parity.

Equipped slotFB and colour-scope integration now has original-instruction and
headless native model/lifecycle evidence; actual server/visual acceptance is
queued while live tests are paused. See
[NATIVE-EQUIPPED-ATTACK-VISUALS.md](NATIVE-EQUIPPED-ATTACK-VISUALS.md).
Original810680 initialization and8033c0 level20 eye effects now have independent
original-instruction and headless actual-model integration evidence:
[NATIVE-SPECIAL-INITIALIZATION.md](NATIVE-SPECIAL-INITIALIZATION.md). Actual
server/visual acceptance remains queued. Broader clocks/reactions/death/audio,
terrain gaps and paired-client gameplay remain open. The captured shutdown stall at a future
frame_post_draw fence now uses force_draw(false); subsequent local pass/failure
paths retire cleanly, but historical stalled evidence remains and is not erased.
Goal status remains active/incomplete.
