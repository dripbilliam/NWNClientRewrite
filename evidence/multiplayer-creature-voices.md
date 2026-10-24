# Multiplayer creature voices

Target: installed NWN:EE89.8193.37-17 nwmain.exe, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
All original binaries and running original clients remain read-only. Installed
SSF/WAV/TLK content is loaded in memory, never added to this repository.

## Native behavior and implementation

Client807240 demands the current soundset, reads the WORD SSF entry, releases
the resource, and checks nonempty WAV4 existence BEFORE replacing source+e8.
Silent or missing new cues preserve the previous source. Controlled characters
use priority6; other player objects7; NPC size category<4 uses15, otherwise14.
It resets delay+f0, deletes the old source, allocates the new source, sets3D,
priority and (if3D) nativeXYZ plus height1.5, then plays. Allocation failure
leaves no source. Appearance setter80aea0 changes soundset+3b8 and handle+400
without stopping a previously playing voice. Appearance decoder77fe10 reads
server8a0/8a4 under mask2000; field8A0 is the replicated soundset WORD.

Server4e25d0 writes26/1 OBJECT_ID+BYTE. Client7b9160 resolves an existing
creature then calls807240 with3D=1. Server4df120 writes22/0 OBJECT_ID+WORD;
the area/radius broadcaster4df1c0 has separate recipient selection. Client
7aaa00 resolves the SSF quick-chat entry, formats its caption, and replaces
the same source+e8 with initial height0 and priority6/7. Creature update8114d0
subsequently moves that source with height1.5. Completed voices remain owned
until replacement/object/area cleanup. Existing native attack playback bark
callbacks11..13 and hit reactions14..16 now enter this same owner. Native
cosmetic random selection order is unchanged; no server combat is resolved.

NetworkCreatureVoices retains per-canonical-object presentation state outside
the registry. It loads active soundset/soundsettype2DA and SSFs, validates WAV
existence asynchronously, suppresses stale object/area/disposed completions,
and prevents an older valid request from replacing a newer valid source.
Silent or missing newer entries do not cancel an older valid pending request.
No local AI, spells, health, canonical IDs or object allocations are added.
Network messages schedule this work without holding up packet application.

Quick-chat captions currently enter the existing received speech pane. Exact
native overhead and remote-profile formatting remain diagnosed by
network.quickchat-overhead-unhandled. This is not full caption UI parity.

## Compressed installed voices

The first installed-resource check failed: PC voices commonly contain
BMU V1.0+MPEG data even when requested as WAV4. Native CResWave::OnResourceServiced
1a5ab0 decodes that container to16-bit PCM before GetWaveInfo1a5940 and source
Play1df2e0. Treating these as ordinary RIFF bytes prevented playback.

GameAudio now strips the eight-byte BMU wrapper for browser buffered decoding.
nativeBmuWave ports iterator6a4430's MPEG1/2 layerIII metadata gates, CRC/padding
length, first Info-frame suppression, and native sample-rate/channel/16-bit
duration calculation. Timing does not use the AudioContext resampled duration.
Decoder ProcessFrame6a3b00 returns1152 samples for MPEG1 or576 forMPEG2 after
successful side/main-info decode. Native header iteration stops at invalid
sync fields; unsupported/empty BMU data is explicitly rejected locally.

The browser MPEG decoder remains a platform adapter. Its synthesis, encoder
delay/gapless trimming, PCM quantization, and damaged-frame recovery are not
proven equivalent to OpenMP3. Header-derived durations assume valid frame
decoding. No sample-perfect original hardware claim follows from this work.
Native mixer priority limits, pause/sample-phase behavior and weapon combat
sound coordination remain incomplete and separately diagnosed.

## Validation before live rollout

486 whole original807240 executions compare gates, priorities, replacement
and call ordering, with SSF/resource/player/rules/audio services captured.
120 original26/1 and22/0 writer cases execute native scalar/OBJECT_ID codecs;
the complete26/1 receiver runs with explicit creature lookup/voice boundaries.
294 original MPEG iterator/sample-owner cases cover MPEG1/2, bitrates, sample
rates, mono/stereo, CRC, padding, Info, truncation and failed decode services.
These MPEG cases use synthetic bodies and captured side/main/PCM services;
they do not execute actual MPEG synthesis. The oracle initially read a bool
as DWORD; v2 masks its native AL return. Earlier failed test reports are kept.

107 focused regression tests pass (network-creature-voice-regression-v2.txt).
Buildv2 passes with the existing bundle-size warning. Actual installed muted
Chromium PCM fixture selects a soundset from active tables, delivers26/1 bark
and22/0 Follow through production decoding/voice/audio owners, replaces the
source, verifies independent real PCM after100ms analyser settling, moves it
without restarting, and disposes all sources. Canonical state/cursors remain
unchanged. The isolated fixture is not a live server or original sound-device
comparison. Final fixture/live acceptance details are appended after checks.

## Vanilla-server acceptance

Normal-close149 saved and disconnected cleanly. New buildBCnGQusb connected
as150 to the unchanged vanilla server20964; original33744 stayed running.
Physical portrait right-click -> Issue command -> Follow was exercised twice.
Two native22/0 requests produced two server22/0 echoes for canonicalFFFFFFFF,
quick-chat22. Replicated soundset217 selects active VS_FCallahM/Follow;
both voices loaded and started exactly once with priority6/3D/volume127,
raw sample rate44100 and native duration2742ms. Ten samples caught physical
playback. The second replaced the retained source. Both localized captions
appeared in Messages with the real player name and tiny portrait.

A normal backend walk request moved the server proxy30->31 on X. Its retained
voice moved to native[31,85,1.4997720718], without restarting. This particular
live move happened after the spoken cue finished; the installed fixture
separately verifies moving a still-playing voice. Area tiles144, failedObjects0,
health77/86 unchanged, runtimeErrors0. Normal-close150 requested and received
one native character export and disconnected cleanly. Its capture is sealed.
verify-network-creature-voice.mjs replays captured original packets and active
installed SSF/TLK data; v2 PASS. First verifier picked a partial final sample
whose HUD had not been sampled when close started; v2 requires a complete HUD
sample. No production behavior was relaxed.

Muted installed PCM UIv4 PASS: selected soundset210 from active data, attack
peak0.0213595 and Follow0.0702262 after100ms analyser settling. Installed HUD
fixture also PASS, including actual DOM suppression of a delayed quick-chat
caption after its canonical actor's current predicate becomes false.

Passive replacement151/PID49124 is left playing on the same server at31,85;
no automated gameplay inputs are scheduled. Its live/control/full capture are
active and excluded from checkpoints; only the explicit frozen bounded current
snapshot and inspected ready PNG are included. The original client remains
passive in another area. This does NOT prove new original-origin active combat,
server26/1 gameplay emission, or live combat bark triggers. Those remain part
of the active full multiplayer goal, alongside native weapon SFX and wider
shared gameplay/campaign acceptance.
