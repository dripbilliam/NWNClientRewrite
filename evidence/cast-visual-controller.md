# Client conjure and release visuals — 2026-10-16

Progress toward the spellcasting/combat/campaign goal; the full ecosystem remains
unfinished. All selection uses the active physical spells.2da row and generic
native controller owners. Spell names/IDs occur only in acceptance observations.

Read-only target: NWN:EE89.8193.37-17 x64 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game and Ghidra project unchanged. Previous verified checkpoint:
`backups/client-projectile-random-1842-20261016-v1.zip`, 9542 files,
113714686 bytes. All source and evidence from this increment are intended for
`backups/cast-visual-controller-1852-20261016-v1.zip`.

## Native owners

REA dossiers and original instruction emulation are retained separately.

- Constructor14098b0a0 clears six model pointers, two timers, a release flag and
  three completion flags. Destructor14098b0d0 clears conjure before cast models.
- Start14098b450 loads three authored conjure resources under `conjurevisual`
  (head/hand) and `conjuregroundvisual` (ground). For each successful model it
  clears that completion flag, registers donefade callback14098b100, resolves
  source virtual+140 with255/1, attaches to headconjure/handconjure/root with
  flags0 and plays conjure01 with speed1, flags0, time0. It resolves handconjure
  for two optional one-shot sounds; failed lookup falls back to source position.
- Release14098b130 is called at receiver1407ae2dd. It loads cast resources under
  `castvisual`/`castgroundvisual`, attaches to the same three parts and plays
  cast01 with flags1. Existing conjure models receive fade in **hand, head,
  ground** order, flags1. The receiver subsequently sets controller38 to1.
- Callback14098b100 marks each matching conjure slot. It can mark multiple slots
  when they share the same model; it does not destroy during event dispatch.
- Cleanup14098baa0/14098b9f0 detaches then re-reads each slot, destroys the
  remaining non-null model and clears the pointer. Re-reading matters if virtual
  detach changes a slot.
- Update14098bb50 first consumes donefade flags. While38 is nonzero, timer30
  counts down and clears conjure models. It returns on that branch: timer34 does
  **not** consume the same frame or any leftover elapsed time. Later updates
  count timer34 down, clear cast models, and clear34/38 together. Native UINT
  comparisons and subtraction are preserved.
- Creature driver1408018d0 owns entering/exiting casting and the5000ms defaults.
  Native casting animation SHORTs are15..20,61,250..253,261; only15/16 start a
  fresh conjure group. It uses separate previous-casting368, spell-ID36c and
  sound-suppression374 cells. Voice selection also reads native classification
  SHORT at creature3b0+50 and BYTE at creature300+d0; those lower client fields
  have **not** yet been reconstructed for the renderer bridge.

`src/cast_visual_controller.js` ports these owners. The physical loader evidence
in `live-spell-metadata-loader-asm.txt` confirms76/87/98 conjure model fields and
a9/ba/cb male/female/VFX sound fields. `clientProjectileSpell` reads their active
columns through the existing native string-entry/CResRef helpers, with no new
spell-specific effect code.

## Renderer integration and limits

`ClientCastVisualPresentation` owns separate client controller views and model
handles, connected through `ClientProjectilePresentation`. The existing native
playback/event dispatcher and scene attachment adapter supply lower services.
Conjure handles register donefade before playback; actual authored events mark
the owning handle, and the next controller update removes it. Async proxy handles
retain the original ordered attach/listen/play calls. Destruction before asset
completion cancels playback and destroys late assets. Source replacement is
checked by mirror identity, including a sync after loading. Scene attachments are
updated as the caster moves; area teardown destroys owned handles and listeners.

The local bridge observes canonical animationState and nativeSpellId218 into
independent client fields. This is **not** native network field replication.
The unresolved voice classification/gender fields deliberately do not produce
an invented chant choice: the current adapter omits that branch and records
`visual.cast-client-fields-adapter-incomplete`. The authored ConjSoundVFX still
uses the checked sound position selection. Browser attenuation/priority are
diagnosed with `visual.cast-audio-adapter-incomplete`.

Native synchronous cache/loading and outer scene gates use an async renderer
adapter (`visual.cast-async-scene-adapter-incomplete`). It can start a model later
than the original synchronous call. No full cache/culling/scheduler parity is
claimed. Missing models, anchors, clips, controller and animation errors remain
durable failures. The old broad projectile-cast-visuals-unimplemented diagnostic
is replaced by these narrower remaining boundaries, not silently suppressed.

## Validation

- Final native capturev5: **3644 cases**, original instructions for constructor,
  start, release, callback, cleanup, update and complete creature driver.
  Cases vary resources, allocation failures, existing slots, done flags, detach
  mutation, zero/UINT timers, elapsed times, animation narrowing, invalid spell
  lookup, previous flags, suppression and both voice-selection branches. Model
  allocation/virtual scene/playback, sound, strings/CRT allocation and spell
  lookup are captured lower boundaries. This is not rendered original-game
  acceptance and does not prove those lower owners.
- Seven independent native-trace tests compare full controller state and exact
  ordered lower calls. Three presentation regressions cover full conjure/release
  and two-timer cleanup, actual event dispatcher ownership, late load disposal
  and replacement-source identity; deferred model instances are distinct.
- **1852 tests pass**, build passes. Full suite passed before adding the final
  alias observation; all10 new tests passed again after that capture addition.
- Hidden installed UI test selects untouched prepared wizard Daze37 from active
  metadata. Its actual vco_smhanmind01 model loads, plays conjure01(flags0), then
  fade(flags1), emits authored donefade and is destroyed. Actual vpr_los still
  travels, impacts and is deleted. No new cast model is authored for this spell;
  head/ground cast creation is covered by native lower-service observations and
  component tests, not claimed as an installed GPU test.
- `live-cast-visual-ui.json` retains snapshots/events/diagnostics; screenshot
  `live-projectile-ui.png` was inspected: the authored purple hand effect and
  white projectile are visible. The scene remains dark and partly occluded by
  existing geometry; this increment does not claim a lighting/occlusion repair.
- Existing spellbook/radial/quickbar/cancel/counterspell UI regression also runs
  on the final build. This is a startup/entry fixture, not campaign acceptance.

Next: reconstruct the native client spell/voice field and CC8 message consumers;
then the remaining projectile owners (dummy target, target-part prefix/impact
attachment, linked paths and ref parenting, scene-hit builders, child spawns and
moving loop audio). Effect/engine-call gaps, combat and campaign work still remain.
