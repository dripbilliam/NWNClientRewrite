# Native multiplayer chat — 2026-10-19

Concurrent chat works against the unchanged vanilla server. Current v109 is
still running the prior chat UI; the split-pane update is built and verified
in isolation. Full shared gameplay remains the active goal.

## Evidence

Read-only NWN:EE89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a;
nwserver98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.
No original process injection, patches, Ghidra edits or copied game assets.

Client major9 handler77c140 complete49631character view is retained in
rea-feedback-client-router-view.json. Channel5 is CExoString only; other
recognized channels first read client OBJECT_ID.8/9/10/15 then read DWORD
strref;11/12 use the separately verified localized one-liner/sound layout.
Other channels read CExoString. Mask0x401e4054 at receiver's post-text block
adds three FLOAT1/32 coordinates and BOOL:0 -> raw speaker-name CExoString;
1 -> first/last native localized strings. This permits remote/out-of-area
speakers without inventing canonical creatures. Only recognized handler
channels are admitted; other packet families remain diagnosed.

Complete server writer bodies: Talk4d4700, Whisper4d4a50, Shout4d4000,
Tell4d47f0, Party4d3cc0, StrRef4d4660, DM_Talk4d3800, DM_Whisper4d3a60,
DM_Silent_Shout4d35a0.96original-code cases cover format0/1, absent speakers,
raw custom names, localized names and reference-only names.86packets result;
missing speakers deliberately produce no Tell/Party/DM delivery. Actual
scalar/string/ID/locstring codecs execute; creature lookup, virtual name
getters, locstring construction/destruction and transport are explicit
synthetic boundaries. They do not prove live chat delivery by themselves.

Complete client senders Talk7ba7e0, Shout7ba700, Whisper7baab0, Party7ba620,
DM7ba540, Tell by PLAYER_ID7ba8c0 and Tell by first name7ba9b0 are retained.
80original-code cases cover format0/1, empty/ASCII/CP1252/markup text and four
uint32 player IDs.40format1 cases agree on every defined wire bit. Original
allocator padding retains0xa5 in unowned tail bits; the replacement useszero.
Tests mask only that undefined tail. Native reader can accept a spare physical
fragment byte in some zero-residual cases; tests retain that behavior rather
than tightening it to an invented protocol rule. All truncated fields and
two-byte trailing mutations reject.

Server445030 reads a Tell BOOL selecting first-name string or DWORD PLAYER_ID,
then the message. For allowed channels it owns module OnPlayerChat scripts,
channel/text changes, markup handling, DM policy and delivery. The replacement
submits native9/1,2,3,4,6,14 through its current controlled/session/area scope.
It never treats a PLAYER_ID as creature OBJECT_ID, echoes a draft as received
chat, runs local OnPlayerChat, or simulates native routing.

## Product behavior and validation

The message log receives all20recognized chat channels. Positional/raw or
localized speaker names remain presentation fields, separate from the world
registry. Source-only speech with an absent object is suppressed; system and
remote-name/one-liner branches retain their missing-speaker policy. Installed
TLK prefixes10300Shout,10301Whisper,10302Tell,10303Party,10299Server and
66756DM are used. Unknown Speaker5189 is the installed fallback. System pane
includes both5 and15. Text remains textContent and cannot become HTML.

The HUD has Talk/Shout/Whisper/Party/DM/Tell entry. Tell uses the native
first-name path; numeric PLAYER_ID is also supported by the typed encoder.
Enter focuses chat outside other modal/input controls. Typing stays within
the entry and does not activate movement or shortcuts. Pending requests
suppress duplicates; readiness disables sends while loading, and stale scope
is also rejected in the backend. Received history survives area transitions,
resets per connection and is bounded200rows per pane. No optimistic echo.

49focused session/IPC/chat tests and254network regression tests pass. Buildv2
passes with the existing bundle-size warning. Installed-resource DOM UIv2
passes request/recipient/text preservation, no-local-echo, duplicate guards,
remote-name rendering with no object creation, system strrefs, loading guards,
keyboard isolation and existing spellbook/inventory/HUD checks. The standalone
network-chat-entry-v1.png was inspected with the spellbook closed.


## Native screenshot reference and concurrent acceptance (2026-10-19)

User-supplied original-client screenshot proves replacement-origin Talk,
Shout, Whisper and Party arrived in the original client. Frozen passive
network-chat-concurrent-v109.json preserves five native server echoes
(including self-Tell), both public character identities, and original-origin
Talk "hell yera" received by ours. DM request had no DM recipient and no echo;
do not claim DM delivery or original-origin Party acceptance. v109 remains
open; full wire report is unsealed. Server20964 and original33744 untouched.

Chat now displays Messages and System simultaneously, each with independent
scroll and height controls. Names precede channel prefixes as in the reference.
Client77c140 constructs the speaker token from DWORD0x7f8f633c + WORD0x3eff,
i.e. bytes <c 8f 7f ff >, yielding #8f7fff. White Talk/Party, yellow Shout,
gray Whisper and gray server text are matched to the supplied screenshot;
exact native configurable body-color defaults remain unverified. Static
legacy TalkColor/Chat Colors/ShoutColor/WhisperColor string search and bounded
RIP-relative/pointer scan found no direct references; that absence is not
proof the options are unused.

Native but_chat_bar360 is rasterized from installed MDL/UV/texture data;
no proprietary resources copied. Chat tiny portraits use replicated portrait
IDs/resrefs and the same neighboring-size fallback scheme as party portraits.
A shared helper caches by asset owner, and asynchronous portrait IO never
blocks received-message dispatch or creates canonical objects. Late completions
are ignored after reset/world/asset replacement. Portrait failure is diagnosed.

Installed-resource DOM fixture UIv4 PASS; screenshot network-chat-entry-v1.png
visually inspected. Tests cover simultaneous safe text panes, native speaker
constant, reference channel colors, installed tiny portraits/bar, manual scroll
retention, height keyboard control, keyboard isolation and pending-send guards.
49focused tests/buildv3 pass; 254network regression tests pass (network-chat-network-regression-v2.txt).
First UIv3 launch inherited ELECTRON_RUN_AS_NODE and failed before rendering;
UIv4 explicitly restores GUI launch mode and exits0. The screenshot is an
isolated fixture, not live v109. v109 still runs the earlier tabbed chat build.

Remaining: exact native scrollbar art/resize/collapse semantics, configurable
palette, join/leave and journal notifications, combat log routing, overhead
speech/audio, commands/history/mute, broader character codecs. Server authority
and native request encoding are unchanged. Full multiplayer goal remains active.

The later user-supplied screenshot reiterates the two simultaneous panes:
speaker portraits and Talk/Shout/Whisper/Party on the left, player/PVP/journal
notices on the right, with independent upper resize handles and scrollbars.
Current code retains this layout. Subsequent system-notice and combat-feedback
work connects join/leave, journal and typed combat rows; see their separate
evidence files for native validation and remaining limits. Exact scrollbar
art/collapse behavior and configurable palette are still not established.
