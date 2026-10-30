# Native creature voices and compressed BMU playback

2026-10-27. **Native integration; headless component acceptance only.** Combat
barks and decoded server26/1 voice requests now enter the direct native client's
actor-owned voice source. Original resources and active soundset/appearance2DAs
are read by Godot workers. No JS audio/resource preparation is involved. The
protocol host forwards decoded identity/code only.

The user's pause on particle optimization, live gameplay and GPU tests remains
in force. All checks here were headless/offline. No graphical client or server
was started. The full base-gameplay/migration goal is still active/incomplete.

## Original rules and evidence

NWN:EE89.8193.37-17 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

- Complete owner `0x140807240..0x1408074a7` checks soundset WORD+3b8 and handle
  +400, demands the SSF, reads a WORD entry, releases it, and checks nonempty
  WAV4 Exists **before** replacing source+e8. Empty, out-of-range and missing
  new cues leave the old source intact. Admitted cues reset delay+f0, destroy
  the previous source, allocate/set3D/setPriority/position/play the new source.
  Allocation failure leaves the source null.
- Priority: controlled6; another player7; NPC appearance SIZECATEGORY<4 is15,
  otherwise14. Initial positional height is1.5. Raw positional input is nonzero
  rather than assumed to be a Boolean BYTE.
- SetSoundset80aea0 changes SSF selection without itself stopping an old voice.
  Appearance77fe10 mask2000 maps replicated field8A0 to the soundset WORD.
  Server4e25d0 writes26/1 OBJECT_ID+BYTE; receiver7b9160 looks up an existing
  creature and calls807240 with3D1. Source update8114d0 moves the still-owned
  +e8 source at height1.5, including finished sources. The cached body includes
  the explicit SetPosition block following LAB_140811e81.
- CSoundSet GetStrres7d7ba0 reads the V1.0 offset table and20-byte entry. SSF's
  explicit sixteen-byte sound name overrides TLK's sound, including an empty
  name. The new playback path never substitutes a TLK audio default.
- Retained dossiers: backups/animations/rea-combat-voice-owner-current.json,
  rea-combat-voice-selection-current.json and
  rea-combat-voice-creature-position-current.json. Wire/SSF details and previous
  original observations are indexed in
  [multiplayer-creature-voices.md](../evidence/multiplayer-creature-voices.md).

The retained unchanged-original corpus native-creature-voice-observations.json
has486 complete807240 executions with controlled SSF/resource/lookup/allocation/
audio boundaries. Native GDScript is compared directly with it; prior JS ports
are reference only. This corpus does not execute actual codecs, devices or the
whole original actor AI.

## Native ownership and delivery

`native_data/creature_voice.gd` implements the original provider flow;
`sound_set.gd` decodes bounded SSF V1.0 records natively. The asset service adds
ssf-native-v1. `native_render/creature_voice_world.gd` owns asynchronous SSF work,
per-canonical-actor voice state, original code/priority selection and source
replacement through the existing native effect_audio/world_audio owner.

Combat presentation's existing bark11..13/14..16 events now have a consumer;
no cosmetic RNG draw, damage, feat result, HP or authoritative action is added.
Undisclosed NPC HP still prevents the existing damage-bark branch; it is not
guessed. Raw voice26/1 transport uses RawCombatEvents' canonical lifetime IDs.
Native area/generation and wire-serial gates precede admission. Voice delivery
can await the matching snapshot but cannot attach to a later reused actor or a
changed soundset. Newer invalid cues do not supersede an older valid source.
Newer admitted requests prevent older deferred work replacing their source.

Player membership comes from decoded world.players data, not a PC-looking model.
Appearance size comes from the active table. A loaded actor supplies its current
pose for source refresh; raw replicated position remains the fallback before
physical model admission. Completed sources remain owned until replacement or
actor/area cleanup, matching the original source slot.

The SSF queue/cache have explicit bounds. No decoding holds up packet handling
or world admission. The independent voice asset service participates in actual
live_world.asset_owners/worker_tasks. begin_retirement stops sources and refuses
new/late work before the existing scheduler drains actual worker handles. Final
close disconnects callbacks, joins/releases assets and clears private state.
Existing native mixer stream/playback weak-reference retirement remains in use.

## BMU resource support

Original voices frequently contain BMU V1.0 + MPEG LayerIII when requested as
WAV4. `bmu_wave.gd` implements the original iterator6a4430/ProcessFrame6a3b00
metadata profile: MPEG1/2, bitrate/rate/mode gates, CRC/padding, first Info-frame
suppression and original16-bit sample-count/channel/rate duration arithmetic.
WaveData recognizes BMU and effect_audio strips its eight-byte header for
Godot AudioStreamMP3. Existing RIFF PCM/IMA and native timing metadata remain.

292 of the294 retained synthetic original MPEG iterator/sample-count profiles
are compared directly. The two injected codec-internal side/main-info failure
cases are explicitly excluded; Godot's MP3 provider does not expose those
original decoder internals. Actual MPEG synthesis, gapless trimming, quantization
and damaged-frame recovery are not asserted sample-identical. Unknown non-RIFF/
non-BMU encodings remain explicit errors, not guessed formats.

## Verification

All final Godot runs use source-pinned test-native-kernel-debugger.ps1 headlessly
with captured stderr, four native exception traps and terminal clean exits.
No final engine/lifetime error or native exception; all sourceUnchanged=true.

| Report prefix in reports/ | Checks | Coverage |
| --- | ---: | --- |
| native-voice-final-data-v2 |783|486 original voice-owner cases; bounded SSF;292 original MPEG profiles, invalid headers and timing |
| native-voice-final-world-v2 |27|Actual installed SSF/BMU, Dummy MP3 and authored PCM playback, advancing clock, current-pose refresh, active custom rules, valid/invalid replacement, packet deduplication/lifetimes, actual retirement inventory and mixer release |
| native-voice-final-special-world-v2 |27|Special initialization/original models and queued live probe compilation |
| native-voice-final-equipped-world-v2 |22|Equipped original effects/colour/ownership regression |
| native-voice-final-cast-world-v2 |28|Casting/world regression |
| native-voice-final-retirement-v2 |72|Actual blocked native workers, repeated world replacement and retention-bound cleanup |
| native-voice-final-effects-data-v2 |66|Original controller data and exact authored IMA decode regression |

Total1025 headless assertions. native-voice-transport-final-v1.tap separately
retains5 Node protocol-identity/clone/removed/stale-area cases. The original
resource selected by the headless test is c_aasimar_atk1, read from original
c_aasimar SSF entry11. Its SHA256 is
0f0f87a6b10b721c38e1bdf8de35b2963ada053f9acf422e98eb018b1ee6bf86.
Only names/hashes/metadata are reported; proprietary sound bytes remain external.

The world test uses an authored active soundset table and SSFs around that
original voice. A deliberately malformed SSF produces exactly one expected
resource diagnostic and preserves the previous source; valid requests have no
audio import failure. This is not a claim that every possible asset succeeds.
All audio output here uses Dummy, not WASAPI or physical speakers.

Historical world-v1 failed on test-only SceneTree/void-return syntax. world-v2,
v3/v4 and final-v1/v2 pass; the final-v2 source includes current-pose refresh and
the actual live-world retirement inventory. Earlier reports remain retained.
The casting fixture keeps its preexisting missing fx_ref scope and pending
point-to-point warnings. Its passing regression does not resolve those gaps.

## Queued and open acceptance

The existing local Parry probe now waits for an actual controlled combat bark,
matching native combat event and advancing native audio clock, and records
resource/profile/driver details. If the sample has no authoritative soundset,
it explicitly reports missing coverage. Do not run while live testing is paused:

```powershell
./godot-client/tools/test-native-actions.ps1 -Parry -Run native-creature-voice-live-v1
```

Actual original-server26/1, WASAPI/device/physical audibility, moving voices in a
live fight, mixed original/replacement clients and wider custom content are
unaccepted. Quick-chat22/0/captions, weapon attack/hit/miss sounds, footstep/death/
ambient/music/placed sources and full original mixer priority budgets remain
open. Current source priority values are not proof of original voice-stealing
policy. Direct-native script-sound packet forwarding is also separate pending
work; older JS-staged world-audio evidence is not current-entry acceptance.
Previous shutdown AVs remain unexplained, not waived by these clean checks.
