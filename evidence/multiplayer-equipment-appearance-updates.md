# Equipped item appearance changes and missing Arelith player

Target: installed NWN:EE89.8193.37-17 x64, SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. Original binary and live original clients remain unchanged.

## Live observation, 2026-10-20 UTC

The user entered Arelith's Character Set-up Area with Yrs. The replacement
client displayed the portrait and other actors but no controlled model.
Read-only diagnostic-console inspection confirmed localObjectId4294967200,
area2147489769, no scene binding for that ID, no failed model IDs, and camera
waitingForTarget=true. Steady performance at3100x1121 was approximately72–82FPS
with no pending model/shader jobs. This does not prove loading latency is fixed.

The runtime reported a rejected612-byte message near entry and incomplete
appearance records with equipment action U. The incomplete reader preserves
only finished preceding records, so a U within a P record loses that entire
appearance record and its successors. This is a plausible explanation of the
missing player; the actual612-byte failure and causal link remain unverified.

## Native evidence

REA reader `14077fe10`, equipment loop `140780a90`: CHAR operation,
raw client OBJECT_ID (`1409737c0`), DWORD slot. U branch starts `140781078`.
At `1407810a2` the original reads a BYTE; at `1407810b1` it reads
ObjectVisualTransformData through `140973160`. It looks up an existing item,
clears its previous effect (`14083f660`, call7810bf), conditionally applies a
nonzero effect (`14083e040`, call7810d0), and applies the object transform
(`140766960`, call7810dd). It creates no item and changes no equipment slot or
owner. `14083e040` uses the active item visual-effect table's ModelSuffix.

Sources: `rea-live-arelith-player-item-appearance-v1.json` and extracted text;
`rea-live-arelith-item-visual-byte-v1.json`. These are static analysis, not a
claim of complete effect rendering.

`inspect-native-equipment-appearance-update.py` executes original code from
780a90 through78111b in isolation for32 combinations of message format,
effect0/1/7/255, slot16/32 and item present/absent. Original scalar readers and
branch routing execute; object lookup, transform parsing/application, effect
rendering and map cleanup are captured boundaries. The empty transform fixture
does not validate the complete transform reader. Output:
`native-equipment-appearance-update-observations.json`.

## Replacement change and validation

P/U now consumes the effect BYTE and existing transform format, preserving
following records. World import updates only an existing canonical item and
matching equipment references, preserving item ID, metadata, ownership and slot.
Missing-item U records do not manufacture objects. Invalid-message diagnostics
now retain the specific parser error, major/minor and failing record location;
no raw packets or authentication data are logged. The scene debug snapshot
includes a narrow controlled-actor readiness summary.

Focused replication/inventory/session regression suite:44 passed before adding
the native-oracle assertion. Production build passed. Mixed P/U followed by
player P, every packet truncation, item metadata/ownership preservation and
missing-item behavior are covered. Live reconnection was interrupted by the
physical Escape key before restart; no live success is claimed. A diagnostic
harness was then run with explicit user approval. The goal remains active.

## Follow-up: remote build owns incoming layouts

The first updated reconnect no longer encounters equipment-U rejection but still
has no controlled appearance. Diagnostic-only re-decode locates the failure in
I at byte388, mask0xd5ff, with skillCount29. The level-up fields remain aligned;
the reader diverges at effect icons, treating the following feat count18 as
an icon-addition count. Trying alternative skill counts in the diagnostic
harness finds no complete decode and never changes production state.

The authenticated Arelith advertisement reports8193.36.12; the installed client
is8193.37.17. Original receiver helper `1407c4ab0` calls
`CNetLayer::ServerSatisfiesBuild`, as directly shown in
`rea-arelith-incoming-build-gate-v1.json`. The original player reader7b4f70
uses that helper for effect-icon widths. Our envelope dispatcher incorrectly
passed the installed client build to most incoming readers. It now uses the
authenticated server build for object/player updates, area/module information,
quickbar embedded items, examination and visual messages. Existing offline
writer fixtures may still explicitly supply their wire build through the legacy
clientBuild argument. No server name, module name, spell or character condition
is involved.

Regression replays every format1 original PlayerUpdate fixture with a newer
client and the fixture's older server build.64 focused incoming-layout,
area/transition, quickbar, examine, visual and session checks pass; production
buildv2 passes. Subsequent live confirmation succeeds: run starting
2026-10-20T05:04:40.355Z enters playing at4256ms and attaches Yrs's canonical
4294967200 model at7370ms, with zero invalid packets or renderer errors.
The user confirms loading. Curated proof is
`creation-experience-player-entry-proof-v1.json`. The full live stream is
excluded from checkpoints. Model scale/pose, texture selection and lighting
differences reported next are separate open presentation work; see
[visual resource evidence](multiplayer-visual-resource-parity.md).

The next reconnect received BNCR connectionError9. Native connection UI715dd0
maps9 to TLK63258 (0xf71a), whose installed English text is "Your CD Key is
already in use on that server." No replacement process remained at the time
of the delayed retry. The rejection does not establish which stale/other
session held the key. No authentication bypass or identity change was attempted.
Evidence: `rea-arelith-connection-error-ui-v1.json`, extracted text and the
curated rejection report. Live logs/raw sample streams stay outside checkpoints.
