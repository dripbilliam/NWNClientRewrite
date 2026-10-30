# Native world audio — partial migration, shutdown acceptance open

Current direct-native follow-up (2026-10-27): combat barks and server26/1 voices
now have native SSF/BMU, source/profile/position and retirement integration with
headless evidence. See [NATIVE-CREATURE-VOICES.md](NATIVE-CREATURE-VOICES.md).
Actual server/device acceptance is queued while the user's live-test pause is
active. [Direct native script sounds](NATIVE-SCRIPT-SOUNDS.md) now have native
source/profile/byte-string routing and disconnect cleanup with93 headless checks
and15 protocol/audio checks. Its real-server/device acceptance remains open.
The staged script-sound evidence below remains historical; quick-chat and weapon
audio are still open.

Godot now owns effect impact/duration/cessation sources and decoded server
script-sound output. The isolated JS staging build cannot create browser audio
players or duplicate that playback. The production JS client is unchanged.
Ambient/music, placed sounds, animation/voice events, user mixer/device settings
and native priority-group voice limits remain tracked work, rather than being
silently classified as migrated.

## Ownership and original rules

The existing bounded `NativeAudioAssets` preparation/32MiB LRU is reused per
admitted world. The local transport retains complete owner/area/generation/
ticket, immutable resource ID/name, codec/channel/frame/byte metadata, ordered
128KiB chunks and SHA256. Work yields between chunk groups; superseded area or
connection IO cannot publish. Closing drains work and releases cached bytes.
Original audio bytes remain in memory, never written into this workspace.

Godot validates assembly before decoding. World-scoped cached streams produce
independent players and loop copies; one source cannot change another's loop
mode. Original effect phase callbacks own duration-source settings, start,
position, stop and destruction. One-shots retain fixed source position and
optional delay; they can finish after their effect retires, but world retirement
stops all sources and releases transfer/cache/player/listener owners.

`world_sound_state.gd` ports listener1406e67e0, wrapper height arithmetic and
delay1e0c50 unsigned timing. It preserves five-sixths controlled eye plus
one-sixth actual camera position, the native camera quaternion basis, float32
height addition, reference distance1/max20, byte volume127 and positional
denominator255. Positional stereo sources are rejected; non-positional stereo
is supported. Requested loops park outside range and restart from their cached
stream on reentry. Exact resumed sample phase remains unverified.

`world_audio.gd` uses Godot spatial panning with the original linear clamped
distance gain calculated explicitly. Additional engine distance attenuation,
low-pass filtering and Doppler are disabled. This preserves the verified source
profile, not a claim of sample-identical OpenAL mixing or priority allocation.
API references: [AudioStreamPlayer3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html),
[MP3](https://docs.godotengine.org/en/stable/classes/class_audiostreammp3.html),
[Vorbis](https://docs.godotengine.org/en/stable/classes/class_audiostreamoggvorbis.html).

## Evidence and failed attempts

- `world-sound-state-v1.json`: **524 original-instruction comparisons**, zero
  mismatches:12 listener cases,72 height-wrapper cases,200 delay cases. Eight
  separate authored attenuation/name examples are labeled as authored, not
  binary mixer comparisons. Target nwmain SHA256
  `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
- `world-audio-stereo-v2.json`: **40 native authored checks**, Dummy stereo
  software mixer. Actual captured left/right energy reverses with source
  movement. `world-audio-wasapi-v7.json`:40 checks on WASAPI and this machine's
  7.1 output, with nonzero mixed signal, directional readback and advancing
  playback clocks. Both cover exact PCM/rate, independent simultaneous sources,
  range parking, cached restart, stereo rejection/2D playback, delay/cancel,
  malformed/partial/checksum/size rejection and explicit ownership cleanup.
- The stronger mixer readback initially failed a stereo-only assumption on
  7.1 output. `audio-panning-engine-v1.json` reproduces the same result with raw
  Godot nodes and no client adapter. Godot's
  [capture implementation](https://github.com/godotengine/godot/blob/master/servers/audio/effects/audio_effect_capture.cpp)
  shares one ring buffer across effect instances, including surround channel
  pairs; its
  [spatial mixer](https://github.com/godotengine/godot/blob/master/scene/3d/audio_stream_player_3d.cpp)
  includes LFE in the right lane of a pair. The final test keeps strict L/R
  dominance in stereo and checks directional change against centered output
  for aggregated surround readback. It does not claim isolated front-channel
  capture or human audibility. Earlier failed reports remain retained. The
  capture effect now waits for native mixing retirement before process exit.
- That investigation also found and fixed a real adapter issue: a newly
  recreated parked player must reapply gain even if the requested value equals
  its old value. The39-check tests explicitly cover this regression. Unchanged
  listener/source transforms and gain avoid redundant native property writes.
- `world-audio-focused-v4.txt`: **59 Node checks pass**, covering existing voice
  preparation, original effect/script behavior, new world cache/transport/
  scoping, typed observations, native-only staging and negative acceptance.
- `world-audio-local-v1` is a retained failed fixture: Darkness defines impact
  audio but no duration loop. `world-audio-local-v2/v3` pass39 checks using real
  stock Elemental Shield147 and its duration resource. Real original PCM impact,
  area and loop resources reach WASAPI, their native metadata/digests match the
  backend, and an authored player `AssignCommand(PlaySound)` produces a real
  received script-sound packet with priority8. Effect sources use priority11.
  Native loop clocks advance and actual server removal stops/destroys them.

The current authored module is `GodotSounds2`, SHA256
`f364afad8d76e612e2307b37395481884b4da84e82c8570c11ab8e2169d774a3`.
The source builder verifies installed NWScript signatures/constants; original
models/textures/audio remain references. Isolated bridgev40 suppresses only
the hidden browser presentation and preserves production source identity.

## Critical remaining failure

`world-audio-series-v1` **failed overall**: the first source-guarded local run
passes39 checks and cleanly exits; the second passes all39 checks and reports
zero tracked world/UI survivors, then exits with **0xc0000005**. The failed
report and engine log are retained. Passing functional checks or a later clean
exit do not waive that native shutdown failure. The earlier historical native
heap/access faults also remain unexplained; audio is not asserted to be their
cause or their fix.

`test-world-audio-debugger.ps1` attaches installed CDB only to the newly launched
pinned replacement process, traps AV/heap/fail-fast/illegal-instruction events,
and retains exception records/current context/thread stacks. It uses local
symbols only and preserves original NWN/editor processes. An exception capture
cannot qualify as a passed rendering/audio workload, even if debugger quit
changes the child exit code. Diagnosis and stable shutdown acceptance remain
open. Full migration, public-server and sustained complete-scene60FPS
acceptance remain false. No public game-server connection was made.

### Actual mixer retirement

Three CDB-guarded pre-fence reruns completed39 checks each without reproducing
the AV. They do not prove its cause or repair. A separate existing creation
voice regression then demonstrated a narrower cleanup defect: freeing the
players left actual `AudioStreamPlaybackWAV` and `AudioStreamWAV` references
alive in the mixer at process exit (8–10 leaked ObjectDB instances).

World and creation voice owners now collect weak references to their stopped
streams/playbacks. Native quit polls these alongside queued world owners and
yields real time to the mixer; merely completing two uncapped render frames is
insufficient. A bounded unresolved wait exits as failure. The shutdown report
adds explicit `audioSurvivors`, and new audio acceptance requires zero. Legacy
reports without the new field remain separately identifiable. This is actual
weak ownership polling rather than assuming a fixed delay completed retirement.

`world-audio-voice-regression-v3` passes20 checks, including release of stopped
native voice playback references, with no leaked-instance output. The40-check
world fixtures likewise require both player and playback-resource release.
This fixes the demonstrated mixer-retirement gap; the previous shutdown AV
still has no captured fault instruction and is not declared fixed.

`world-audio-debugger-v2.json` retains three source-guarded post-fence runs:
**117 local visual/audio checks**,18 tracked outer world owners retired, zero
scene/UI/audio playback survivors, zero remaining particle threads and clean
native exit0. All three logs confirm the exception handlers were armed and
none fired. The ordinary owned local server is restored. These are successful
functional/lifetime checks, not proof that the earlier AV is repaired. The new
WIP archive retains all failures; the last accepted rollback stays unchanged.
