# Multiplayer system feedback — 2026-10-19

Previous goal turn was progress: native-compatible chat input/receive, live
bidirectional Talk and original-client receipt of four channels; split UI,
portraits and verified chat-v2 backup. This turn adds authoritative system
feedback and GUI notification sound output. Full multiplayer goal stays active.

## Original-code evidence

Read-only NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
No live process writes, game patches, copied assets or Ghidra changes.

Player-list handler1407a8c60 located from static LEA1407a9cb3 to profiling
string140e3fc88. Full33393-character pseudocode retained. Minor1 clears/loads
roster with local470=0, suppressing join announcements. Minor2 selects local470=1;
GUI-client branch uses TLK6610/player or6611/DM, with DM gated by server140.
Minor3 searches the old player record, uses TLK6612/player or6613/DM before
removal and checks GUI+28 readiness (getter1406f9a90). PlayerName parsing uses
PLAYER_ID in TLK+C0; account name is separate from character name/OBJECT_ID.
Explicit Add events are retained; no inferred roster-difference messages.
Native appends literal period + color close after the TLK text; installed
English TLK already ends with a period, so the resulting two periods are
preserved. Missing Delete records do not invent speakers. Client readiness is
currently approximated by frontend playing phase; precise loading-screen gate
lifetime still needs mapping. Native host/DM executable paths are out of scope.

Journal28/12 dispatch1407a0c10 ->1407a2890 reads localized title/quest/changed.
App wrapper1406ac450 ->1406dab60 tail-calls1407d6150 if journal GUI exists.
Immediate branch builds CNWCCMessageData string0, dispatches feedback184,
plays gui_journaladd or (changed!=0) gui_quest_done and encourages toolbar
button+428 if present. If client internal+450 and quest are both nonzero,
native queues title/changed instead. That alternate UI mode is not yet wired;
current client uses immediate normal-mode presentation.

64 complete isolated original owner/helper cases verify GUI absence, toolbar
presence, quest/changed/defer flags and empty/nonempty titles. Real string and
ResRef copies execute; app getters, message-data SetString, final feedback,
sound, highlight and deallocation are explicit captured lower boundaries.
Fixture capacity avoids queue resize; queue append itself executes intact.
First oracle failed at unmapped tail target7d6150; v2 includes the verified
helper and completes all64 cases. This does not prove the whole feedback UI.

Feedback wrapper1406aaf90 defaults empty color to bytes <c ff ff 01 >
(#ffff01), then calls1406cb2e0. Its complete171979-code-unit pseudocode is
retained in three pages (65000/65000/41979); original response exceeded MCP
transport budget, not an analysis failure. Entry jump table1406d5028+184*4
points to1406cc4f8. Bounded branch assembly1406cc4f8..6cc595 reads string0,
loads STRREF from140e45138 (=6395), formats %s %s and rejoins feedback output.
Installed TLK6395 is the journal-update prefix; titles remain module data.
No Academy Training special case exists in implementation.

## Implementation and checks

networkSystemNotices projects typed server messages only. Frontend captures
Delete context before canonical removal, applies the server message, then
dispatches presentation notices. NetworkText supports request-local PlayerName
context including a departed account; it changes no global token or game state.
System rows stay safe text, use the independent right pane and retain per-pane
bounded history. Late asynchronous output is ignored after world/reset changes.
Journal encouragement clears on button activation and journal panel opening.

GUI cues use the existing GameAudio decoder/output adapter, centered on the
controlled player, with an audio instance scoped to the network connection.
Area changes retain it; disconnect disposes pending/active cues. User input
unlocks suspended output. No local script/combat resolution is attached.
Current output is a browser adapter; native GUI volume/mixer parity is unproven.
Spatial network speech/combat/area audio remains separate unfinished work.

Real server captures v101/v105/v106 each contain28/12 title STRREF57878;
network-journal-notice-captured-v1.json preserves these packets and provenance.
Installed-resource muted DOM fixture displays the yellow journal line and
account join notice, verifies safe text, button encouragement/nonmutation and
decodes both original GUI WAV resources. Last cue stereo96kHz/6.13877s; this
proves decoding/graph construction, not that a human heard live output.
Screenshot network-system-notices-entry-v1.png was visually inspected.
23focused tests,261network regressions and buildv3 PASS. Existing bundle-size warning remains. Live v109 still runs
prior chat UI on server20964 with original33744; no new automated inputs yet.
A fresh live rollout follows the verified source checkpoint.

## Post-checkpoint live rollout

SEALED system-notices-v1 checkpoint:14755files/412612940bytes; writer99799
terminal0 consumed, every length/SHA256 verified. Audit14756entries/89required/
0missing/forbidden/duplicates/new credential candidates (69changed/new scanned).
Post-seal audit and these notes are outside archive. Backup precedes live rollout.
LIVE replacement v110/PID20748 now plays m0q1a/9tiles, split System log with
native Add/PVP notices, both canonical players/party portraits, zero runtime
errors/failed objects. Original33744 and server20964 unchanged. v109/PID31752
closed normally, sealed local-network-chat-v109.json:412wire messages/720samples/
6chat actions; final phase closed. No further automated inputs in v110.
Acceptance network-system-notices-acceptance-v1.json + ready screenshot outside
archive. Current v110 full wire report unsealed. Live journal cue not yet tested;
muted fixture decoded both installed cues. Native journal deferral450/readiness/
volume and full shared gameplay remain open. Goal active.
Next core targets: unsupported packets18/11,2/12,52/3,54/2 from live startup;
network scene/voice/combat audio; combat/casting and transition coexistence.

