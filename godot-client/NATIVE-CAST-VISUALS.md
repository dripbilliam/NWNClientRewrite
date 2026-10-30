# Native conjure and cast-release visuals

The direct native entry now owns the original casting visual controller,
private original effect models, chant selection, fade callbacks and sequential
cleanup timers. This is scoped combat progress toward
[original-client parity](BASE-GAMEPLAY-GOAL.md), not complete casting, combat,
renderer or mixed-client acceptance. Particles remain off by default; visual
tests enable them only in their isolated session.

## Ownership and original reference

- `native_data/cast_visual_controller.gd` implements original constructor,
  start/release, clear, donefade, tick and creature-driver control flow.
- `native_render/cast_visual_world.gd` owns native worker-backed model handles,
  original physical attachments, private animation clocks and model callbacks.
  It retains only active casters/effects and pending casting disclosures; it
  adds no per-frame scan of scenery or the full object registry.
- `native_data/projectile_spell.gd` reads conjure references and chant names
  from the active physical spell row. Models, sounds and casting IDs are not
  selected by a production spell-name database.
- Decoded animation/spell/silent fields reach Godot immediately through the raw
  combat transport. An older throttled world snapshot cannot start a new cast
  with the previous spell's visual. The JS change clones decoded fields only;
  Godot selects resources, models, voices, animation, attachment and lifetime.
  Actors which have never disclosed casting fields add no casting messages.
- The projectile receiver releases casting visuals and CastSound before the
  `Proj` gate, exactly once per packet despite worker retries. A `Proj=0` parent
  can have cast visuals/sound without becoming an invented missile. A server
  impact script can independently emit genuine child projectile packets.
- `actor_instance.gd` registers a model-scoped Detonate callback for each
  original Explosion emitter. Fountain and other models do not receive that
  subscription. Retirement disconnects these listeners.

Read-only reference target: original nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Controller entries are `14098b0a0`, `14098b100`, `14098b130`, `14098b450`,
`14098b9f0`, `14098baa0`, `14098bb50`; creature driver `1408018d0`;
release call `1407ac670` -> `14098b130` and its release flag write. Original
`MdlNodeEmitter::InternalCreateInstance` registers the Explosion listener at
`1400622aa..1400622c7`; `Detonate140061a30..140061a38` writes BYTE +108=1.
Fresh REA metadata/pseudocode/assembly for release and emitter registration are
retained in `reports/native-cast-*-research-v1.json`. The original binary and
process are not modified. Stored isolated original controller observations
retain explicit lower model/audio/allocation boundaries.

Native voice projection uses disclosed stats racialType (the native WORD50)
and disclosed appearance gender when the source model is available, not the
differently named legacy race BYTE. The replicated silent flag is authoritative.
Missing race data does not invent a racial chant. Complete created-appearance
replacement semantics, reference source/shape membership, preparation delay and
world-clock behavior remain distinct acceptance areas.

## Evidence and observed failures

The original controller corpus contains 3,644 cases. The final native check
performs 4,069 checks including callback/context identity, all ordered lower
calls, allocation failures, aliasing, release/cancel animation ranges, sound
gates, UINT countdowns and separate conjure/cast intervals. Numeric state fields
are compared recursively with exact integer values; model handles retain
identity semantics. An initial Dictionary equality test incorrectly rejected
JSON-promoted numeric values and was replaced by the existing typed recursive
comparator; native expectations were not changed.

The native model-owner check passes 28 checks using original spell 107 and the
original drow caster. It requires non-null original physical anchors, real
conjure01/cast01/fade clips, donefade callbacks, Explosion Detonate delivery,
other-model event isolation, female chant/silent selection, immediate cast
state overriding an older snapshot, sequential retirement, canonical ID reuse,
queued cancellation, original Proj=0 behavior and complete model/provider cleanup.
These authored replicated fields do not by themselves prove a server outcome.

`native-cast-live-v4.json` passes 39 actual unchanged-server checks at localhost
5125. Original ActionCastSpellAtObject supplies Fireball and Magic Missile,
with real decoded parent headers, original models, native sounds/attachments,
moving Fireball and cast cleanup. The inspected Magic Missile capture shows its
release burst: hiding only that original model changes 139 sampled pixels in
the 220-pixel region around the caster. All three cast models retire, two
donefade callbacks fire, no source changes or trapped exceptions occur, all
workers exit, and public connection count is zero. This functional fixture's FPS
label is not a general performance benchmark.

Final reruns, gameplay/ranged/lifecycle regression evidence and source/checkpoint
integrity are indexed by `tools/audit-native-casting.mjs` and its output report.
That audit checks the actual per-report scope; it does not complete the goal.

Retained diagnostic runs exposed an invalid oracle filename, a typed variable
compile error, double-counted stale-source telemetry, a wrongly named fixture
spell constant, stale cast metadata from throttled snapshots, and no pixels from
missing Detonate delivery. The owned stalled fixture run was verified/stopped;
logs remain. The original spell 107 is Magic Missile despite its shared sonic
release model names. No live server outcome or expected pixel result was faked
to make a test pass. The first owner fixture used a private visual rig ID for
the caster, allowing two null anchors to compare equal; the final fixture uses
the actual actor rig ID and explicitly requires non-null physical anchors.

## Remaining work

Complete impact blood/weapon visuals, real shield blocks, specialized/child
projectile paths, reaction/death/recovery presentation, arbitrary server resource
and source shape coverage, paused clocks and paired original-client sessions
remain open. Existing reference-helper, point-to-point particle, wind and scene
intersection limitations remain diagnosed. Black terrain wedges visible in the
functional room are a separate unresolved rendering gap. This milestone does
not establish pixel parity for complete spells or entire areas.

Source checkpoint before this work is
`backups/native-special-projectiles-direct-after-v1.zip`. The verified after
checkpoint is `backups/native-casting-visuals-direct-after-v1.zip` once final
audit succeeds. No original model payload or executable is included in these
authored-source checkpoints.
