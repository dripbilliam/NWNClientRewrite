# Native multiplayer audio — 2026-10-19

Work toward the active full multiplayer goal. Original client/server and binary
inputs remain unchanged. Live v134 confirmed native Light and Haste audio and
closed normally; v135 passed the updated QA flow and remains open. Area ambient/music,
sound-object scheduling, duration/moving sounds,
dialogue/SSF voice, combat sound queues and native mixer limits remain open.

Target NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a;
unchanged nwserver SHA256
98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.

## Routing and native owners

Server SendServerToPlayerAIActionPlaySound1404ccfe0 writes major9/minor7,
source OBJECT_ID and CExoString. It is not a chat subtitle. The old replacement
decoder misclassified this channel as speech; the corrected frontend dispatches
it to audio and the chat view also rejects accidental channel7 presentation.
No source object, local script, combat result or server reply is synthesized.

Complete client77c140 pseudocode retains common stream, source cast and GUI
readiness gates. A missing source is rejected before its playback branch.
Its later branch77e330..77e3bb converts the string to a16-byte CResRef, chooses
3D when the base-object cast exists and otherwise2D, priority8/delay0/volume0.
The replacement currently admits existing current-area proxies with a position;
it does not invent a2D fallback for a missing or incomplete proxy. Exact cast
coverage for every uncommon client object subclass is not yet established.

Original listener coordinator1406e67e0 uses controlled eye position(z+1.8)
plus one-sixth of the vector toward the camera, then computes forward/up from
the actual native camera quaternion. It requires scene, camera and controlled
object, preserving the prior listener if absent. The replacement uses the
rendered controlled pose and the existing native camera controller's position/
quaternion, without changing canonical state. Coordinates stay native Z-up.

Original CExoSound::Play3DOneShotSound1401d9c40 adds its height argument toZ;
it is not a gain multiplier. Spell/projectile callbacks previously labeled
that argument gain and discarded it. They now preserve native position,
height, priority and selected resource through the shared audio adapter.
Existing cast/projectile and object/area visual phase owners choose cues from
active installed tables and server-replicated events. No per-spell switch was
added. Their nonnetwork fallback diagnostics remain in place. Duration/moving
sound callbacks still record their unimplemented owners.

Source ctor1401da910 defaults volume127/maxDistance20. Native1df2e0 rejects
stereo positional resources and checks listener range before starting. Source
volume1401e1990 uses127 for2D normalization and255 for3D; user/category gains
and spatial blend remain separate mixer state. Source3D setup1401e0050 sets
AL_MAX_DISTANCE20 and retains OpenAL referenceDistance1. Initialize1401dc590
selects AL_LINEAR_DISTANCE_CLAMPED(0xd004). Web Audio uses explicit positional
self-cues, source gain, fixed one-shot origins and linear distance attenuation;
it does not silently center positional stereo files. Browser permission delays
are an adapter boundary. Decode/queued cues cannot reappear in an old area or
disconnected session; started one-shots retain their fixed origin.

Native priority values are retained, but group voice limits/stealing and user
mixer settings are not implemented; a diagnostic records this omission. The
OpenAL mixer/panner, priority arbitration, Doppler/reverb and hardware samples
are not claimed identical. Nonzero one-shot delays remain explicitly rejected.
API interpretation is checked against the [OpenAL1.1 specification, sections
3.4.4 and4.3.2](https://www.openal.org/documentation/openal-1.1-specification.pdf)
and [Web Audio PannerNode](https://www.w3.org/TR/webaudio/#PannerNode).

## Validation

inspect-native-network-audio.py executes218 original-code cases:30 complete
server writers,20 bounded client playback branches with actual ResRef copying,
72 complete height/priority/volume wrappers and96 complete listener coordinators.
GUI/source admission and mixer/output are explicit boundaries in the oracle.
This is not a complete77c140 execution or original audio subsystem emulation.

32 initial focused checks,20 updated audio/projectile/visual checks and392
network/projectile/cast/visual/SP-audio regressions PASS; builds v2/v3 PASS with the
existing bundle-size warning. Installed Chromium audio fixturev3 PASS: original-
code9/7 packet -> production decoder/frontend/audio -> installed mono WAV ->
nonzero measured PCM, played1/pending0, own-source panner and camera-responsive
listener, zero chat rows/errors and unchanged canonical objects. It is muted;
fresh server emission and hardware audibility are not demonstrated. The initial
fixture failed because a DOM id named result shadowed its completion global;
the fixture now uses a distinct name and waits for actual playback. The final
PNG was visually inspected; it is a fixture, not a live multiplayer screenshot.

## Native live casting

v133 closed normally after save; its full capture is sealed. v134/PID48988
joined through the existing saved vault entry and sent two ordinary6/18 casts:
Light100 and Haste78. Both have server start/release feedback. Light used canvas
targeting; Haste completed through the player portrait. Its earlier center-of-
world-object clicks did not submit; pending target selection was still present.
Prepared Haste existed in the server export and portrait submission succeeded;
no cast-availability change is justified by those observations. World-picking
and input gates need further investigation. Read-only click telemetry now
distinguishes a suppressed input from a missing scene hit.

The six source events were vs_chant_evoc_lm/sco_mehanholy01,
vs_chant_ench_lm/sco_mehanelec02, spr_los and sim_movhaste. Four conjure events
retain priority11/height1.5, projectile impact retains priority12 and its native
position, and the object visual retains priority11/height1.5. Actual output
decoded6/played6/pending0/context running. No sound load error occurred. The
live screenshot was visually inspected. Starting sources is not a recorded
hardware listening comparison or full native mixer acceptance.

Sealed local-network-audio-v134.json:720samples/147wire messages, final closed,
no final failure/sampleFailure/disconnectFailure. It retains one recovered QA
failure: the generic panel-close selector ran before async spellbook rendering
completed. That evaluation also generated one runtime.uncaught diagnostic
"Panel close unavailable". It is not omitted or counted as zero total errors.
The harness now waits up to5s for the real close control before clicking.
The original client33744/server20964 stayed running. Its player remains in the
party, but no original actor was visible in this area, so active shared casting
acceptance remains unproved.

Fresh v135/PID47980 on build index-MTTbstKV.js completed Light by portrait and
Haste by actual canvas input: both native6/18 requests and all four native
start/release feedback rows, six sounds played, no pending cues, zero runtime
errors/failed objects. Spellbook open/async close succeeded. Click telemetry
shows targeting=true, no input gate, and the actual hit objectFFFFFFFF/type5.
This retry succeeds without changing cast availability or picking behavior;
the earlier misses therefore remain unexplained, rather than claimed fixed.
network-audio-current-v135.json is a frozen passive summary; the active full
report is unsealed. No further actions are scheduled. Native export/reconnect
continues to use the saved entry, retaining equipment.

Follow-up native evidence identifies major40 as ambient/music control:
SendServerToPlayerAmbientSoundLoopPlay1404cd630 emits40/6 with BOOL;
client router14076c9d0 handles minors1..8. Sound object creation1404e0630 is
23/6 and packs canonical sound/area IDs plus the existing sound-state packer.
These control families remain unimplemented; packet40 is no longer unclassified.
