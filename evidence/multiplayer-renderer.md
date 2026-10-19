# Multiplayer Electron bridge and server-owned scene

2026-10-18. Goal ACTIVE. This milestone connects the native session to the app's
renderer. It does not establish playable or concurrent original-client gameplay.

## Implemented application path

`electron/network_ipc.cjs` owns one session per attached Electron main frame,
restricts requests to the built application URL, checks session ownership, and
releases sessions on window closure. It exposes connection, character admission,
area readiness and archive-resource lookup. It exposes no raw packet sender or
filesystem reader. The preload forwards parsed state/messages and diagnostics.
The installed-session factory constructs the existing native peer/session,
private identity and installed build/resource providers. Installed HAK lookup
now includes the native data/hk directory as well as data/hak/profile content.

The Multiplayer dialog accepts server/port/player name, CD key/server password
and a BIC file. Credentials are transient, cleared from controls/request objects
and never saved in configuration or logs. The existing full character-creation
wizard is not yet integrated with this multiplayer dialog; character BIC
admission is available. The installation picker is main-process owned.

`NetworkFrontend` imports parsed messages into a client `NetworkWorld`, loads
the scene, and explicitly acknowledges its area generation. The singleplayer
session, action queue, movement controller, audio and simulation presentation
bindings are removed before entering multiplayer; no competing scripts, AI,
combat or spell rules are started. Singleplayer/model load controls are disabled
while connected. Old session/area acknowledgements cannot operate a new owner.

`NetworkScene` uses the server's tile list and explicit unsigned object IDs.
It loads the active SET/2DAs and uses the existing model hierarchy, skinning,
texture/PLT palette, supermodel animation and creature-part attachment code.
Local GIT spawns are not imported. Static area placeables and dynamic proxies
have different source records; both are supported. Creature model/equipment
appearance derives from server P records, not the selected BIC after admission.
The installed native part-order mapping is shared semantically with SaveItem;
model anchors are matched case-insensitively, matching the existing renderer.

Native animation-name selection and weapon-class updater 0x140811190 are reused
with server equipment and active baseitems/appearance data. The caster's native
animation 1 selects nwreadyr rather than an invented idle clip. Attack/cast
coordinators, transitions/timing and other presentation work remain incomplete.
Position projection is native [x,y,z] -> Three [x,z,-y]. Native A orientation
vectors and subsequent U yaw agree in real snapshots: Fenthick's
[-.83147,-.55557,0] corresponds to 123.75 degrees, player's
[.92388,.38268,0] to 292.5 degrees. No movement prediction is run.

Native area MoonAmbient/Diffuse are +98/+9c and SunAmbient/Diffuse +b8/+bc,
as already established in area_message_metadata/properties. Existing lighting
remains approximate and dark. The temporary preview light used for geometry
inspection is explicitly a viewer aid, not evidence of native lighting parity.

## Real application verification

Original installed client: NWN:EE 89.8193.37-17, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original server SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
No original executable/live-process/Ghidra writes were made.

`scripts/probe-network-renderer.cjs` uses the real preload, IPC owner, installed
session and bundled renderer. Its credential input is encrypted over an
ephemeral loopback connection using X25519/HKDF/AES-GCM: no clear CD key in
argv/environment/files/captures. A one-time test token/public keys identify that
local channel. This is a test harness, not a new game/network protocol.

Early test-harness stdin/named-pipe access failed; outside-sandbox GUI execution
and the encrypted local input channel resolved those test-environment issues.
v4 exposed an initial static-object source assumption; v5/v6 also exposed
remaining static-appearance access and case-sensitive anchor lookup. These
failed/partial observations are retained, superseded by v7/v8.

`local-network-renderer-v8.json` uses normal GPU settings (gpuDisabled false):
real server admission, nine area tiles, 33 canonical proxies, 19 rendered object
bindings, 20 model components each for player/NPC, native NPC pause1 and caster
nwreadyr, no failed object bindings, clean disconnect and final closed state.
Native server log confirms join 00:55:49 / leave 00:56:34. The earlier v7 app
window was inspected with the computer-use skill: server area, beds/chests and
upright assembled caster visible, including inspection under the preview light.
No authentication dialogs were automated. v8 diagnostics are archived separately
as `local-network-renderer-v8-diagnostics.json`; no error-level, object-load or
missing animation-clip errors occurred in that final run.

36 focused tests PASS (`network-renderer-tests-v3.txt`), including direct reads
of installed native model skeletons, all captured static/dynamic scene bindings,
ownership/cancellation, actual app capture, and prior area/object/player/resource
decoders. App build/syntax checks PASS (`network-renderer-build-v6.txt`), with
the existing bundle-size warning. No full-suite rerun was needed.
Private audit: 2031 source/root-note/network-evidence files, zero full credential
matches (`network-renderer-credential-audit-v1.txt`). Obsolete private test
listeners were closed; no test peer remains connected. The original server is
left running for the user.

## Remaining work

Native movement and interaction requests are not connected. Multiplayer GameUi,
radials, combat/casting requests and their full presentation, transitions,
inventory UI, NWSync download and original-client concurrency remain open.
Robes, held equipment, per-part color overrides, door/placeable animation,
looping effects, weather and area audio are explicitly diagnosed when observed;
they are not silently treated as implemented. Native major/minor omissions and
missing emitter textures (including fxpa_cloud02) remain recorded. Default
lighting and camera/wall occlusion need further parity work. The session's
`playing` phase describes completed admission, not completion of this goal.

Post-seal checkpoint: `backups/multiplayer-renderer-20261018-v1.zip`, 12015
files / 195734582 bytes. Writer 46908 completed with exit 0; every archived
length and SHA256 verified. All 18 selected new/updated source, capture and
validation entries are present; compiled/native assets, BIC/module files,
CD-key configuration and the private server profile are excluded. This paragraph
was appended after sealing. Server PID12956 remains running for the user.
