# Server path playback and player camera — 2026-10-18

Previous goal turn: PROGRESS. This continuation: PROGRESS; full goal ACTIVE.
User reported walking clips with stationary models followed by teleports, plus
an unanchored camera. Inspection confirmed that path/rates were decoded but
NetworkScene copied only packet positions. The multiplayer camera was framed
once on area entry and did not follow the render binding.

Target is read-only installed89.8193.37-17 x64 nwmain, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Retained REA dossiers network-client-path-*,motion-*,set-position and facing-step
map the update owner781e80, path installation8001f0, path storage80b0d0,
cursor804bf0, movement8114d0, stepping811fc0 and correction804840.

Client8114d0 advances server waypoints using transmitted millimetres/second
walk/run rates and world elapsed milliseconds. Ordinary paths accelerate and
decelerate; script movement uses its transmitted multiplier. Creeping78/79 uses
the original fixed rate. Native correction804840 has a512ms window and snaps
at four horizontal metres. Waypoint arrival, cursor advancement and sub-frame
milliseconds are preserved. New NetworkMotion keeps presentation state separate
from canonical NetworkWorld proxies; no route/AI/action or gameplay resolver is
run locally. Ordered movement events include repeated wire updates separately
from combat/cast events. Area/deletion cleanup and model replacement retain
the appropriate presentation ownership.

inspect-native-network-motion.py executes original8114d0,811fc0,804bf0 and
804840 with original vector/math instructions.3933 cases agree on position,
render correction, cursor and acceleration. Rules WALKDIST/RUNDIST, visual
scale, model clip/draw, flat height query, sound, facing notification and final
animation notification are explicit captured lower boundaries. Native collision
checks/path joining in8001f0, terrain/vertical projection and detailed facing
easing are not proven by this oracle. Runtime height projects onto installed
area WOK triangles; complex overlap/steps remain an adapter boundary. The native
path endpoint/received path remains authoritative; local scene motion changes
neither canonical positions nor gameplay requests.

Installed-model replay of actual concurrent original-client capturev65 proves
render positions advance across multiple frames between wire deliveries while
canonical proxies remain unchanged. Camera tests cover movement, zoom/orbit
offset preservation and server-controlled possession changes. Held equipment
continues following the displayed skeleton; combat event ordering is retained.
353 affected checks PASS(network-motion-tests-v7.txt); final camera-specific
checks PASSv8. Buildv2 PASS, with the existing bundle-size warning only.

Livev69 uses the real vanilla server and visible replacement client. The user
confirms "movement works". Passive snapshots show camera/render anchor and
server positions after actual movement; no runtime errors or movement failures.
These retained snapshots are not a complete high-rate movement recording.
The client remains open; no original-client session is claimed for this run.

The user further requested camera anchoring exactly like singleplayer. The
passive sample shows an off-player controls target after panning. The follow
target now locks to rendered player+0.8 height each frame, preserving orbit and
zoom while cancelling incidental pan. Area entry and F recenter use the same
focusPlayer helper as singleplayer (7,5,7 offset,2..80 distance limits and
0.05..500 clipping). This is shared singleplayer behavior, not a claim of a fully
reconstructed native camera. This final framing change needs the next renderer
load; v69 still runs the earlier framing build until explicitly reconnected.

Server was restarted at the user's request after coexistence tests: current
PID22040/UDP5121, Prelude, validation ON. Current replacement PID50752/v69.
Do not restart either while the user tests. v67/v68 interactive close reports
carry a historical failure label because the harness checked for playing after
the requested disconnect; the harness now treats interactive closure separately.

Blank party entries remain under investigation. v66 wire roster includes five
unresolved IDs while the player list has two active entries, matching original
GUI blanks. Native quit owners6d76b0,712180,70f8d0 all call DisconnectFromSession
2372e0->239f60->SendBNDM2505b0, the same packet ours sends. This rules out a
guessed missing application logout packet, not every possible cleanup defect.
TURD reconnect lookup47dc60 compares player name and both localized character
names. Platform-specific identifiers are randomized authenticated blobs; their
per-connection variation alone is not evidence of changing player identity.
No speculative identity or server-state change was introduced.

Checkpoint multiplayer-movement-playback-20261018-v1.zip:13289 files,
274280330 bytes. Writer9975 terminal0; all archive entry lengths/SHA256 checked.
Scope21 required present/forbidden0; credential audit11805 files/private hits0.
Final framing buildv3 PASS. This postseal note and scope audit are outside the
sealed archive. Source/docs identify the still-running earlier v69 build.
