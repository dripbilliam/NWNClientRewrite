# Native multiplayer feedback presentation

This pass decodes server CC18/11 feedback and formats 169 direct template and
token-copy branches in the client system pane. Server results remain authoritative;
this code does not resolve attacks, damage, spells, AI or object identities.
It also accepts server custom tokens50/1, retaining the native sorted token table
and its distinction between reserved script-command IDs and client token storage.

## Original evidence

Read-only installed win64 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Client CC dispatcher140770c80 enters CC11 at140777f2f; type lookup tables
14077a6e8/14077a65c select field readers. The bounded receiver ends at14077a4cd.
Build checks call1407c4ab0; server build metadata, rather than the client build,
controls the8193.35.0/36.1/36.4 extensions. Canonical IDs are unchanged uint32s.

`inspect-native-feedback-layouts.py` executes the original receiver with captured
scalar/string/setter providers:262 type codes x4 boolean masks x2 build results
=2096 complete traces. These are layout traces, not native codec execution.
Tests additionally serialize and decode every trace using our previously
native-verified wire codec and exercise both localized-name encodings. One actual
captured startup packet independently verifies type71: two INTs, no OBJECT_ID.

Feedback wrapper1406aaf90 calls formatter1406cb2e0. Native lower providers include
TLK parsing140198c60/1406d7700, number formatting14016c810 and object-name lookup
1406d83f0. The retained three-part formatter pseudocode is complete; the procedure
body attribution alone excludes some switch blocks. No original process is patched.
The isolated formatter retains original control flow, jump table and arithmetic;
lower text, names, allocation and GUI outputs are captured. Of5240 attempted
cases,4430 complete;810 stop on explicitly unmapped dependencies or fixture memory
accesses. Those fixture limits are not evidence of original-game crashes.

`build-feedback-descriptors.mjs` admits only169 branches whose five varied integer
profiles, both name-presence states and both world states produce a common direct
template/string recipe. Tests compare all3380 supported original observations,
including signed INT bounds, token write order, retained earlier tokens, output
flags128 and native TLK parse flags. This is sampled original-code evidence, not
a proof of the whole formatter. Complex arithmetic/rule/audio/floating-text/GUI
branches remain diagnosed as `network.feedback-format-unhandled`.

Type71 copies integer1 to CUSTOM0 and integer0 to CUSTOM1 before parsing TLK53122.
Its armor/spell-failure wording comes from the installed talk table; no English
spell/module table is embedded. Server TLK overrides and custom tokens participate
in the same text provider. Default feedback byte RGB isffff01; specific native
receiver groups useff6601 orcc77ff. Safe text spans interpret native color controls
without evaluating HTML. Nested closes restore the surrounding message color.

## Validation and limits

280 relevant network/token regression tests pass; the build passes with the
existing bundle-size warning. The isolated installed-resource Electron HUD fixture
passes with actual TLK53122 text, native yellow spans, simultaneous player/system
panes, no canonical mutation and existing spellbook/inventory/chat/journal checks.
Its screenshot was visually inspected. Synthetic fixtures do not send to the server.

Object-name presentation uses replicated names and public player names. The native
helper's full item/store/placeable fallback behavior is not yet reproduced.
93 complex formatter branches, floating feedback, combat voice/spatial audio and
complete attack/casting log behavior are still outstanding. Full concurrent combat
and campaign play remain required by the active multiplayer goal.

Source checkpoint and live acceptance are recorded separately; the running v111
client predates this source pass until a verified rollout is recorded below.


## Post-checkpoint live acceptance

Verified checkpoint multiplayer-combat-feedback-20261019-v2.zip contains14856files/421550460bytes; every length/SHA256 verified by writer and independent audit. Audit14857entries/24required/0missing/forbidden/duplicates/new credential candidates;59changed/new text scanned. The failed v1 archive is retained as an incomplete attempt (its active writer output was locked); it is not a valid checkpoint. Native codec/token follow-up26tests pass, recorded after sealing.

LIVE v112/PID9036 is playing m0q1a alongside original33744 on server20964. Native type71 yellow armor/ASF0/0 text appears in the right system pane. Echo replies8; zero errors, invalid-packet diagnostics, feedback diagnostics or unsupported game-packet diagnostics in this startup window. Existing renderer/audio limitations remain recorded. Screenshot visually inspected. Both canonical players and original-party portrait persist. No further automated actions scheduled. v111/PID46784 closed normally,390wiremessages, sealed report48860063bytes. v112 full report remains unsealed while open. See network-feedback-acceptance-v1.json.

User supplied an original-client reference: left player chat with tiny portraits and native channel colors/labels, right gray system notices and yellow journal updates. Current display has the two-pane semantic layout. Font, spacing, exact border/scrollbar geometry and duplicate join-notice behavior need comparison; no pixel-parity claim. Next work: remaining native CC11 formatter owners and spell/attack feedback, then shared server-authoritative combat/casting acceptance. Goal remains ACTIVE.
