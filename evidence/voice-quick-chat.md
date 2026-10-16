# Voice chat and installed soundsets — October 15, 2026

Target NWN:EE89.8193.37-17; nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executable, installed assets and Ghidra project remain unchanged.
Source-path strings/xrefs, read-only Ghidra and complete assembly are recorded
under backups/animations. No proprietary voice files were copied into the repo.

## Script and server ownership

PlayVoiceChat421 is ExecuteCommandVoiceChat14054b060: read integer/object,
substitute self only for OBJECT_INVALID, resolve creature and message transport,
then SendServerToPlayerQuickChatMessage1404df1c0 with the code's low WORD.
Invalid/noncreature IDs do not become self. The VM command ignores the send
result. This path is distinct from BroadcastVoiceChat140384e60/voice-play26.

The quick-chat sender resolves the canonical object, casts creature three times,
samples area/position, then samples the player-list endpoints once. Each client
game object must have the identical area pointer and squared native float32
3D distance<=400 (DAT140dda4cc=20). Two null areas may compare equal. Packet
family22/subtype0 writes actor OBJECTID and WORD code. Native result starts1,
bitwise-ANDs write/send results, and stops at the first zero accumulated result.
This includes nonboolean send results. No extra visibility/hostility/PC gate is
invented. Local authority supplies a decoded delivery channel; actual packet
encoding, object-ID transport mapping and multiplayer acceptance remain open.

inspect-native-quick-chat.py records572 bounded original command/sender cases.
test/quick-chat-native.test.js compares branch/query/delivery ordering, raw
WORD conversion, range boundaries, null areas, missing viewers and failures.
VM stack, registry/cast, packet allocation/write and transport are captured lower
boundaries, not reimplementations proved by this coordinator comparison.

## Client resource and text selection

Dispatcher1407a41a0 sends family22 to1407aaa00 and family26 to1407b9160. The
former reads OBJECTID/WORD and fetches the actor's exact SSF sound index through
140801730; it is not a guessed per-voice lookup table. The latter reads a BYTE
and plays through140807240. Soundset manager1407d7280 loads active SoundSet and
SoundSetType tables; failure of the second admits no voice rows. GetSoundSet
1407d7b00 uses the index's active RESREF. Client soundset selection14080aea0
disables indexFFFF. Runtime adapter uses the imported SoundSetFile WORD.

CSoundSet GetStrres1407d7ba0 reads V1.0 header count/offset table, ignores zero
entry offsets, and reads16-byte ResRef plus DWORD StrRef. An out-of-range sound
ID warns and returns0. A valid StrRef fetches TLK with its gender selector0;
the SSF's explicit ResRef always overwrites TLK's sound, including empty. A
subtitle-only entry therefore plays no invented WAV. Wrapper140801730 demands
and releases the resource and returns1 after a successful demand even when the
entry itself is absent. CResRef copy14018dea0/140190d30 runs unchanged in the
fixture. Local parser adds bounds/header validation for malformed files; those
guards are not claimed native recovery behavior.

inspect-native-sound-set.py records72 original observations (48 entry and24
resource-wrapper). Source entry/text selection compares all48 entry observations.
Data/heap/TLK/warnings are captured lower boundaries. Source class tests also
exercise active tables, zero offsets, full16-byte names, empty WAV override,
BYTE-vs-WORD channels, canonical actor removal and session replacement.

VoicePresentation serializes local caption/audio delivery, resolves the active
module tables and installed SSF/TLK, then sends real audio cues to GameAudio.
Battle cries now use that same installed-resource playback through their separate
voice channel. Each actor owns a replacement voice cue; unrelated sound effects
remain separate. Slow decoding cannot resurrect an earlier cue/deleted actor or
cross into a replacement session. Input unlock now creates/resumes the audio
context before the first cue, avoiding a lost first gesture.

## Verification and remaining presentation limits

probe-live-voice.mjs executes the actual command for the installed wizard and a
nearby installed NPC: three real SSF/TLK/WAV cues load, invalid target sends
nothing, and diagnostics report0 errors. It records metadata rather than audio
or a subtitle corpus. The authored associate probe no longer permits a
PlayVoiceChat exception; all exercised calls must pass.

smoke-live-voice-ui.cjs creates an isolated Chromium client/audio fixture with
real file selection and installed module/BIC/resources. Voice217/index22 decodes
and starts vs_fcallahm_foll, outputs one matching caption, has pending0/running
context/played1 and0 errors. Output is muted: this proves actual Chromium
decode/source start, not hardware audibility. live-voice-ui-v5.txt/json/png are
saved. The fixture caption is not a native overhead-layout acceptance test.
Production summon/Follow/Stand/Unsummon/model-removal input regression also
passes (voice-summon-ui-v1.txt). All1,379 tests and production build pass.

The production HUD displays received quick-chat captions. Exact native overhead
layout, party/player profile formatting, token substitution, sound mixer
categories/priorities/interruption and listener attenuation remain presentation
work. Browser spatialization retains the documented local approximation. This
is real installed cue delivery, not a claim that the whole native voice client,
all spell audio/VFX, spell ecosystem, combat or campaign is finished.

## Floating-text binding repair

The browser fixture build exposed a duplicate FloatingTextStringOnCreature
property in the session command object. A late legacy HUD-only implementation
was overriding the earlier mapped native recipient owner. That duplicate is
removed; a session-level regression verifies type11/feedback94, canonical target,
string and raw sound argument reach the native delivery owner. HUD handling for
feedback93/94 preserves visible text after correct recipient routing. Requested
floating-text sound still reports its separate unimplemented owner. Static
impact-script audit-v17 has160 unbound commands/22 absent scripts; binding
presence alone does not prove branch completeness.
