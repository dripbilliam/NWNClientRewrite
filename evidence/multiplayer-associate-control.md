# Multiplayer associate control

Target: installed NWN:EE89.8193.37-17 x64 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executable/server/project read-only. Static REA evidence is retained
under `backups/animations/rea-network-*`; no injection or server extension.

## Original behavior and implementation

Native sender1407bf0e0 writes raw client OBJECT_ID followed by signed INT32,
then sends major6/minor27. Complete server dispatcher1404531b0, subtype27 block
140454288, reads through the original scalar/OBJECT_ID readers. It redirects
self/-19 to the first henchman, resolves the target and requires its master to
be the controlled creature, except self/-13. The latter is the native return
from a possessed familiar. Outer controlled-creature veto still applies.

ReceiveAssociateCommand1403d69f0 resolves the master before handling -13 through
master.UnpossessFamiliar1403daa40. Other negative commands dispatch original
associate script events or unsummon/domination owners; see the preexisting
[associate receiver evidence](associate-command.md). Those owners execute on
the actual server. The replacement sends the command and waits for its results.

Role selector14098e550 uses self first, then replicated master ownership.
Self builder14098ec00 registers type3 slot4, icon IFE_UNPOSSESS, TLK0x61e,
callback140995f10/-13. Callback140995f10 selects the menu target when the packed
high SHORT is -1, then invokes sender7bf0e0. Installed English TLK0x61e is
"Unpossess Familiar"; the first live v62 capture used the shorter "Unpossess"
label, subsequently corrected without changing the callback/slot/packet.
Owned child14098f8e0 and its existing original-code oracle define the other
command slots/icons/type-dependent Unsummon and possession entries.

`network_associate_input.js` implements that generic native request. Narrow
preload/IPC/frontend methods require the owning trusted main frame, current
session/area generation, current controlled actor and a live canonical creature
target. Ownership, cross-area semantics, AI, removal and control transfer remain
server decisions. No client gameplay state is changed by sending a command.
Network menu projection now exposes replicated master/type; it neither scans
names nor invents relationships. Owned Possess delegates to the existing empty
6/19 sender. Self Unpossess and owned command leaves dispatch native6/27.

## Validation

`inspect-native-network-associate-request.py` executes the original sender,
serialization/readers and full server dispatcher in451 cases: both format
modes, signed INT32 boundaries/commands, low/high-bit raw IDs, ownership,
self/-19 redirection, self/-13, absent actors/targets and veto. Transport,
GetCreatureByGameObjectID, GetAssociateId and final ReceiveAssociateCommand are
explicit captured boundaries. This is not an original AI/unpossession-body
execution claim. Existing596 receiver/broadcast/input oracle cases complement
it. The first oracle run failed because the test app's wire-format field was
uninitialized; v2 explicitly initializes it and completes all451 cases.

Real v62 uses the hidden offscreen production Electron renderer, unchanged
installed wizard.bic and owned vanilla Prelude server on UDP5121 with ELC on.
Fifteen actual pointer/radial inputs complete summon -> owned-menu Possess ->
self-menu Unpossess -> Follow -> Stand Ground -> Unsummon. Native requests are
one6/6, empty6/19, then four6/27 commands -13/-5/-2/-8. Canonical control follows
PC0xffffffff -> familiar0x80000298 -> PC0xffffffff. Server I/14/14 records restore
the PC spellbook and quickbar; unsummon clears its familiar link and marks the
same canonical familiar proxy removed. Full wire replay verifies stable proxy
identity throughout.3346 GPU frames,86 diagnostic records, zero error records,
clean disconnect and exited QA process48696. Both PNGs visually inspected.
Follow/Stand Ground here prove UI requests, not distant movement/AI coverage.

Unsupported packet/audio/effect/animation-node warnings remain. Party-list UI,
global/broadcast command selection, type38/39 shortcut UI/activation, exact
active/cancel modes, item powers/preparation/effects/audio and concurrent play
with original-client users are still open. The incorrectly named research file
`rea-network-associate-broadcast-client.json` actually decompiles emote helper
140804f50; it is not broadcast-command evidence. No guessed broadcast packet was
added. The multiplayer goal remains ACTIVE.

335 focused tests PASS (`network-associate-tests-v3.txt`), production build
PASS(v2; existing chunk-size warning), backend/IPC/preload/harness syntax PASS.
Credential audit11754 files/private hits0 across recursive source/tooling/
evidence/built client, retained research/current renderer captures and REA
stderr. The private server profile/settings/identity/logs are excluded.

Verified checkpoint `multiplayer-associate-control-20261018-v1.zip`:13122 files,
257984812 bytes. Writer52209 finished terminal0; every entry length/SHA256
verified. Scope32 required present/forbidden0. Private server profile, settings,
binaries/assets/BICs excluded; runtime inclusion only audited REA stderr.
This seal note and scope audit are outside the archive. Goal remains ACTIVE.
