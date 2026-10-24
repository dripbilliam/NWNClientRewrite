# Server sound objects — 2026-10-19

Placed sound objects now use their existing canonical type16 proxies, native
packed settings and a client presentation scheduler. No server sound list,
gameplay AI, script execution, spell resolution or object-ID allocator runs
in the presentation owner. Both initial area4/1 and dynamic23/6 use one decoder.

## Native protocol and lifecycle

Read-only NWN:EE89.8193.37-17, nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a;
nwserver98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.
Original install, processes and Ghidra remain unchanged; no assets copied.

Dispatcher7b0000 admits23/2 play,3 stop,4 volume,5 position,6 create,7 destroy.
Complete server writers4e04b0..4e0890 and packer4f5120 were retained. Commands
carry OBJECT_ID, then signed INT volume or three FLOAT positions where needed.
Create carries outer lookup ID, area ID, then the packed record's inner ID.
The legitimate server writes the same sound ID twice. Packed fields preserve
active/positional/looping flags, volume and variation, time/hour settings,
pitch, generated type, interval and variation, min/max distance, continuous/
random list flags, random position/ranges, origin and16-byte resource refs.

Complete client create7b0550 checks outer lookup absence and current area,
constructs9893c0, unpacks98a3b0 and attaches989fd0 through the shared
CGameObjectArray::AddExternalObject. Duplicate or wrong-area creates log and
do not replace objects. The replacement also diagnoses inconsistent outer/
inner IDs before registration; it does not reproduce malformed alias/crash
paths. Sound membership is added/removed from the area's sound list.
Destroy7b07b0 stops output and deletes the actual canonical registry entry.
Missing non-destroy commands are ignored; missing destroy is diagnosed.
An unrelated creature ID cannot become or destroy a sound object.

Position7b01c0 calls98a1b0, which adds the original height to the new Z and
then calls the virtual position setter98aaa0. Base position766760 retains
that adjusted vector. Live stored height stays separate from later commands.
Volume98a230 retains the full signed INT while passing its low byte to output.
Play98a8f0 resets first/wait state when hardware is idle and activates looping
admission when needed. Stop98ac70 stops output and clears both countdowns.

## Scheduling and source behavior

Complete frame989610, selection98a260, shuffle98ab00, interval98ad10 and time
gate98af90 establish the implemented policy. The list walks in order; at a
continuous wrap, Random selects a permutation by repeatedly extracting a
random element from the shrinking old list. The reserved resource "0" ends
playback. Failed resources can be removed from the presentation list without
changing the server's declaration. Empty lists are diagnosed and suppressed
rather than reproducing a native invalid dereference.

Time categories0/1/3 use day,2/4 night; unknown categories preserve the prior
gate. Times0 uses Hours with the native low-five-bit shift. Loop and non-loop
branches differ: non-loops apply random volume, position and pitch, and use
duration plus interval countdowns. A single continuous reference with no
random position or interval is promoted to looping after initial priority
selection, matching unpack. Priority groups are2/3 for transmitted loops,
19/20 for non-loops, split by2D/3D. Native variation moduli and float32 random
coordinates are retained. Random coordinates use inclusive first-match tile
lookup7db200 and the transmitted tile18 integer height, not a guessed visual
transition-height multiplier. GeneratedType is retained; native weather-owner
behavior remains separately diagnosed by the existing weather path.

Source Play1df2e0 returns duration, not BOOL. Real GetWaveInfo1a5940 reads the
RIFF fmt/data fields; duration uses compressed bit depth and data bytes, with
integer division by channels, rather than fact count or decoded AudioBuffer
duration. Native timing metadata is now cached beside decoded buffers. Pitch
variation uses original WAV sample rate even when Chromium resamples PCM.
SetPitchVariance1d9fe0 clamps0..1; its lower Play uses asymmetric downward/
upward frequency variation. SetResRef1da1c0 stops and resets duration/pitch
even for the same resource. Stereo3D returns duration without a voice and
without consuming the native pitch random draws. Native GetWithinRange1dc500
uses source/listener magnitude and inclusive max distance.

Initial3D voice1e0050 uses raw native XYZ. Moving SetPosition1e15a0 retains
raw XYZ internally but negates Z for the active hardware source. The adapter
preserves that observed distinction. Gain uses byte/255 for3D, byte/127 for2D;
linear panning uses the transmitted min/max range. Loops outside range park
and can acquire a voice on approach; stop/unload cancels that eligibility.

## Adapter and validation scope

BufferAudioSource shares GameAudio's WAV decode cache, listener and lifecycle.
Metadata loading yields asynchronously without blocking network delivery;
its pending continuation cannot revive after stop, destroy or area unload.
Native-source configuration is separate from canonical objects. Installed
archive WAV retains module/HAK/KEY precedence with inventoried ambient WAV
fallback. Ordinary sources remain strict WAV4 even if a neighboring BMU8
exists; the earlier streaming music adapter keeps its distinct8-before4 rule.
Area changes clear decoded lookup caches while existing playing one-shots
retain their own buffers. This bounds reuse and avoids stale module overrides.

384 original server writer/packer cases and3680 original client cases were
executed:1568 frame,900 time gate,60 interval,192 selection/full shuffle,
240 source pitch and720 original WAV parser+Play timing. Message codecs,
CResRef copies, state arithmetic and list shuffle execute original code.
Source hardware methods, resource Demand/data, clock/tile/object providers,
debug markers and allocator/list-growth are explicit lower boundaries. The
frame oracle stubs selection; separate full-selection/shuffle cases cover it.
These are not a claim that the full original mixer executes in our client.

Muted Chromium fixture uses captured original-server m0q1d's32 sound objects,
installed WAVs and the production decoder/frontend/world/scheduler/output.
It measures nonzero actual PCM, checks native gain/ranges, stop/play/volume/
move/destroy, range park/resume, interval sounds and complete unload. Fixture
commands use independently native-verified codecs; they are not fresh server
emissions. First fixture caught stale listener ordering on range reentry;
GameAudio now updates the listener before stateful-source range admission.
Native parsed duration also replaced the initial decoder-duration assumption.
Final focused/regression, build and live acceptance are recorded below.

Remaining: native priority-group voice limits, synchronized pause/world-clock
corrections, exact sample phase after range resume, native mixer/master/category
settings, hardware output/resampling equivalence, generated weather ownership,
duration/moving VFX audio and voice. Known mixer/phase/clock omissions are
recorded once per connection; actual load failures are individually recorded.
No new active original-origin shared combat/casting is claimed. Full
multiplayer goal remains active.

Final checks before live rollout:494focused/network/shared sound/codec/timer/projectile tests, buildv2/index-XKdCVkAG.js and muted Chromium UIv3 PASS. Actual32-source fixture peak0.0791138; target loop starts3 across play/range-resume, all five commands and interval playback pass, and no sources survive unload.

Final lifecycle review: area teardown7e7770 explicitly stops and deletes every area sound from CGameObjectArray, not just its hardware voice. Area import now replaces old sound instances while retaining server IDs and unrelated static/party proxies; rejected imports still validate before teardown. Integer timestamp snapshots also prevent fractional browser frames from cumulatively truncating elapsed sound time.496regression tests and buildv3 cover these corrections. Earlier138/index-XKdCVkAG ran32 objects and both interval sources with zero runtime or load failures, but does not claim these later fixes.

QA launch139 failed at session-setup before window/session creation because durationMs180000 exceeded the owned harness120000 validation bound. This was a test configuration failure, not a server/client gameplay failure; its empty states/report and corrected90000 retry are retained separately. Final live retry is140. Muted Chromium UIv4 additionally verifies that area unload removes canonical type16 IDs as well as physical sources.

Live final140/PID26560 runs final buildv3. Frozen network-placed-sound-current-v140.json and acceptance-v1 retain32sources, both2D interval sources played, original canonical playerFFFFFFFE,144tiles and zero runtime errors/failed scene objects. Native door2147484109 remained closed after its first valid request; a second request from beside it produced animation50/open. Subsequent ordinary native walk moved the actor beyondX45 and admitted positional torch2147484261 (priority3, raw44100Hz), while distant loops stayed parked. No local position/door mutation or physical-pointer acceptance is claimed. The cause of the first approach without opening remains unverified. One prior QA shorthand action "open" was rejected; the harness retained and recovered that sampleFailure before using the implemented "door.open" action.

SEALED137:720samples/461wire; SEALED138:617samples/134wire; both final closed with no capture/session failures.138 used the earlier build and is separate from final140. Final140 remains running; its full capture is active/unsealed and excluded from the checkpoint. Frozen bounded proof, ready/range screenshots and failed-before-session139 evidence are included. Original33744 and vanilla server20964 remain unchanged. Full active original-origin shared combat/casting and full multiplayer completion remain unproven.

Verified placed sound backup: multiplayer-placed-sound-20261019-v3.zip contains101files/27735668bytes. Independent audit103entries/8parents/46required, zero missing/forbidden/duplicates/new credential candidates; all9final live artifacts separately checked. Post-seal audit and this verification paragraph are outside the archive. Live140 remains running with no further gameplay inputs scheduled; full multiplayer goal ACTIVE.
