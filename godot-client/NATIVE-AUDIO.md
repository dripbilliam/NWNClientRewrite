# Native creation voice samples

Status: **creation voice core verified; full audio migration remains incomplete**.
All live validation uses the owned local server. No Arelith connection was made.

The Voice page now has a fixed-footer **Play sample** button and persistent
selected-voice/playback feedback outside the scrolling soundset list. Repeated
clicks sample the next line. Selection and first-level BIC generation continue
through the existing creator and active server rules.

`tools/creation-voice.mjs` reuses the original `CreationVoicePreview` selection
state machine and SSF parser. It cycles native codes0–48, advances across empty
entries and resets to code0 for a different selected soundset. Its output adapter
prepares audio for Godot rather than starting an offscreen browser AudioContext.
Private native control handles choose the selected soundset; a client-provided
resource path or voice ID is never used to select another sound resource.

`tools/native-audio.mjs` preserves16-bit PCM sample bytes/rate/channel layout,
normalizes other supported PCM/IEEE formats into signed16, reuses the existing
IMA decoder, and strips the original BMU wrapper while retaining its MPEG bytes.
Original BMU/MPEG voices are decoded by Godot's MP3 stream. The encoded Ogg path
is present but a valid Ogg native playback fixture remains unverified; its magic
classification test is not decoder acceptance.

The asset owner permits four concurrent preparations and a32MiB LRU cache.
Resources follow the existing sixteen-byte CP1252 audio-reference rules,
including punctuation/accented names. It shares the existing active resource
resolver and resource-owner lifetime. Buffers pass through bounded128KiB chunks,
with explicit owner/sequence, declared byte count, ordered indices and SHA256.
The64MiB per-stream limit and PCM frame/channel/rate bounds are checked before
native allocation. Game audio bytes are never written to reports or the workspace.

`systems/creation_audio.gd` owns one non-positional `AudioStreamPlayer`, full
volume for the original preview profile. It replaces earlier playback, validates
the complete transfer before playing, and rejects stale owners/sequences, partial
transfers, invalid chunk order and bad digests. Selection changes, leaving Voice,
creator close, connection replacement and shutdown stop/release native playback.
Retiring the backend also drains SSF/audio work and releases its decoded cache.
The native player does not enter gameplay object registries, targeting or physics.

## Evidence

- `reports/native-voice-creation-local-v3.json`: **48 live checks**. Three original
  MP3 voice samples use the actual **WASAPI** driver; native decoded durations are
  positive and the playback clock advances. Backend/native bytes and hashes match
  for codes **0,1** of one soundset and **0** after selecting a second soundset.
  The fixed controls and selected voice were visually reviewed in
  `reports/native-voice-creation-local-v3-voice.png`. The selected soundset survives
  all three canonical character exports. Creation, save, disconnect and reconnect
  produce two original-model moving/animated admissions. Native exit0 and engine
  logs are clean; retired audio owners have zero jobs/cache bytes.
- `reports/creation-audio-native-v3.json`: **19 authored native checks**, clean
  engine log. Covers exact PCM/rate/channel transfer, native clock progression,
  stereo replacement, multi-chunk assembly, checksum/order/partial/size rejection,
  stale owners, creator close, and an actual synthetic pointer click on the fixed
  sample control with an eighty-entry list. This headless check uses Dummy audio;
  it is distinct from the actual Windows-driver evidence above.
- Existing native creator/browser/lobby GUI regressions pass **16 /22 /20**
  checks in `voice-creator-ui-regression-v1`, `voice-browser-ui-regression-v1` and
  `voice-lobby-ui-regression-v1`, with clean engine logs.
- `reports/native-voice-node-regression-v2.log`: **135 passing tests**, no failures
  or skips. Includes original BMU parser oracles, voice cycling and delayed-close
  behavior; native-format preparation/transport/cache/reference rules; private
  creator controls and retirement; browser/settings/lobby/level-up regressions.

The first full live run also passed48 checks, but visual review found its sample
button below the long voice list. It is superseded by the fixed-footer run. An
intermediate rerun failed during login before resources or any voice action;
that terminal failed report is retained. Native peer diagnostics are now captured
alongside session diagnostics for future connection failures. Existing particle
fidelity/missing-resource diagnostics in admitted scenes remain unresolved and are
not waived by audio acceptance. Physical audibility/device selection/accessibility
and complete UI/performance parity are not claimed.

## Remaining

Broader original-model appearance preview coverage, creator descriptions/help/native
font/skin and broader content/device coverage remain. World/server/script/UI
sounds, ambient/music streaming, positional listener/source behavior, priorities,
pause/resume, effect/projectile/animation sound events, synchronized playback,
volume/mute/device preferences, full compressed-format coverage and long/custom
resource failure cases still need native integration and evidence.

The core native appearance preview is now verified separately in [NATIVE-CREATION-PREVIEW.md](NATIVE-CREATION-PREVIEW.md); this does not complete world/audio migration.

Subsequent partial migration: [native world audio](NATIVE-WORLD-AUDIO.md) now
connects effect phase sources and actual server script-sound messages, with
native listener/range/stereo/delay rules, stream caching and playback ownership.
World/creation shutdown now waits for actual mixer playback references as well
as scene nodes. Wider audio systems and the intermittent native shutdown AV
remain open; this does not promote the whole audio subsystem to complete.
