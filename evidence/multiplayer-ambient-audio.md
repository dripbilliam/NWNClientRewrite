# Native area music and ambience — 2026-10-19

Area audio now uses server-selected track IDs and active resource tables. An
area owns two presentation streams: non-looping music with a repeat delay and
looping ambience with day/night byte volumes. Server packet40 controls music,
battle music, ambience, track changes and volume. No gameplay state, spell
resolution, scripts, authoritative clock or canonical objects are created.

## Native evidence

Read-only NWN:EE89.8193.37-17, nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a;
nwserver98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.
Original processes, install and Ghidra remain unchanged. No assets copied.

Complete server writers4cd290..4cd6c0 and client router76c9d0 establish:

| Packet | Fields | Meaning |
| --- | --- | --- |
|40/1|BOOL|music play/stop|
|40/2|INT32|music repeat delay|
|40/3|BOOL day, INT32|day/night music track|
|40/4|BOOL|battle music play/stop|
|40/5|INT32|battle music track|
|40/6|BOOL|ambient play/stop|
|40/7|BOOL day, INT32|day/night ambient track|
|40/8|BOOL day, INT32|day/night ambient volume|

Complete client readers76cbb0..76d750 resolve the active area audio owner,
with overflow/underflow gates. There is no area/object ID in these packets.
Native BOOL writer retains the low bit of its INT input, not nonzero truth.
Native area unpack876070 loads the three play flags, repeat delay (zero->1),
five track IDs and two volume bytes. Constructor875ad0 sets music looping0,
ambient looping1, separate streams188/190 and a30000ms initial delay before
area unpack. Its actual vtable is confirmed by destructor875ce0, rather than
inferred solely from the candidate pointer scan.

Resolver8771a0 selects ambientmusic.2da or ambientsound.2da by physical row,
reads Resource (plus three music Stinger fields), uppercases names and clears
missing entries. No campaign, module, spell or track-specific production
switches are used. Play owners876990/876530/8761a0 implement ordinary music,
battle interruption/stingers and ambience; the single-stream fallback follows
the same battle>ambient>music precedence. Startup878070 reads native stream
capability flags and enables the owner. Browser supports two streams; the
single-stream path is independently checked but not selected by a native
OpenAL capability query in our browser adapter.

Day/night8783d0 classifies0/1/3 as day and2/4 as night; other values retain the
previous choice. It requests10000ms music or6000ms ambient fades when current
files match the previous tracks. Other music stops use800ms. Existing fades
are not restarted. Frame878240 schedules repeats in world milliseconds and
uses1000ms between battle repeats. Missing music retries after10000ms; failed
ambience stays latched until its track is resolved again. Volume setters
8777b0/877a80 compare the stored byte to the full supplied INT before truncating
the new value to a byte, and only update a matching active file.

Streaming Play1df780 checks BMU type8 before WAV type4 for a WAV request;
strict BMU never falls back to WAV. SetVolume1e1ac0 divides byte volume by127
and applies a native category gain. FadeAndStop1db7c0 preserves an existing
fade. Native source IsPlaying1dd8c0 checks OpenAL state, not file existence.

## Implementation and validation

Network packet decoding is independent of the canonical registry. Frontend
routes commands to the active area presentation owner. Asynchronous table IO
retains command order; generation checks and stream disposal cancel old area
loads, queued autoplay, media callbacks, URLs and graph nodes. Native source
ResRefs retain the16-byte copy behavior. Session-owned IPC admits resource
keys/types, checks stale sessions and does not expose arbitrary paths.

Installed lookup uses existing module/HAK/KEY priority for archive resources,
then inventoried music/ambient directories for that type. Native8-before4
selection applies across both. Loose/archive collision priority within a
single type is an adapter policy, not yet independently established from the
native resource manager. Loose filenames never derive filesystem paths from
server strings. BMU V1.0's eight-byte header is removed in memory. Encoded
music uses an HTMLMediaElement through the shared Web Audio context, avoiding
a full-track PCM allocation. IMA WAV is converted to PCM WAV in memory.

scripts/inspect-native-network-ambient.py executes5848 original-code cases:
256 server writer,3840 play owner,1400 track/delay/volume setters,192 day/night
and160 frame coordinator. Real message codecs and CResRef copy execute.
Transport, stream output, table resolution, string comparison, world-clock
reads and nested virtual owner callbacks are explicitly synthetic boundaries.
Tests compare stream calls, native flags, signed values, byte truncation and
timing decisions; they do not claim full native output execution.

Muted Chromium fixture replays captured vanilla-server m0q1d area settings,
loads installed active2DAs and actual BMU/WAV through production adapters,
observes nonzero PCM independently from each stream, exercises volume/delay
commands and verifies unload cleanup. Fixture area/track names are evidence
inputs only, never production policy. The isolated fixture is not a fresh
server emission or hardware audibility proof.

Remaining: native mixer category/master settings, synchronized pause/world
clock corrections, exact native fade quantization, native driver behavior and
collision priority. Production records the mixer/clock omission once per
connection. Placed sound objects, moving/duration effects and voice remain
separate, diagnosed work. Full multiplayer goal remains active.

## Live acceptance and final checks

Original-code5848cases,471 focused/network/shared audio+timer+codec regressions,
muted installed-resource Chromium UIv3 and buildv3 PASS. Buildv3 bundle is
index-abq43wVl.js (the existing bundle-size warning remains). Native UpperCase
16c8c0 calls byte-wise CRT toupper; the shared native string helper now guards
unmapped locale-specific bytes instead of applying Unicode expansions to
resource names. Unsupported table casing is diagnosed per track. Missing
ambient track resolution preserves the native failure latch.

Prior v135/PID47980 closed normally and SEALED:720samples/430wire messages,
final closed, no capture/disconnect failure. v136/PID48720 joined the unchanged
server20964 beside unchanged original33744, m0q1d/144tiles/zero failed objects
and zero runtime errors. Fresh area state selected installed music and
ambience; both streams report actual successful media playback, not merely
resource presence. A later passive observation records music loaded/started2,
ambience loaded/started1, same area generation and no automated gameplay,
movement or interaction requests. The fixture separately measures each
stream's PCM and validates unload. Fresh live packet40 emission and active
original-origin shared combat/casting remain unverified.

v136 ran index-dRzCbTFE.js. The final missing-track/casing safeguards are covered
by the later v3 tests, build and fixture. Final live refresh is recorded in the
checkpoint notes below; frozen v136 initial/repeat proofs retain their exact
scope rather than claiming the later bundle ran in that earlier test.

Final refresh v137/PID34336 runs buildv3/index-abq43wVl.js, m0q1d/144tiles, both streams playing, no runtime errors/failed objects, original33744 and server20964 unchanged. Prior136 is now SEALED364samples/88wire messages/final closed/no capture or disconnect failure. Frozen initial136, repeat136 and final137 proofs are independently checked by verify-network-ambient.mjs. Full137 report remains unsealed and no gameplay actions are scheduled.

Verified checkpoint multiplayer-ambient-20261019-v2.zip:113files/23006536bytes. Independent audit115entries/7parents/50required/zero missing, forbidden assets, duplicates or new credential candidates. Eight final scope artifacts separately verified. These post-seal verification notes and audit output are outside the archive.
