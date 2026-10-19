# Multiplayer global commands and associate shortcuts

Target: installed NWN:EE89.8193.37-17 x64 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original binaries/Ghidra project remain read-only. Static REA records under
`backups/animations/rea-network-command-*` and `rea-network-*-shortcut-*` retain
addresses, complete bodies and call relationships. No injection or extensions.
The previous goal turn made verified progress; this turn extends those paths.

## Native distinction

Global wheel builder1409945d0 registers slots2/3/4/5/6 as Attack Nearest,
Follow, Stand Ground, Guard, Heal Me, with quickchat WORDs0/22/10/9/4.
Callback140998100 calls140805440, then sender1407c3770: one WORD via22/0.
It does not enumerate visible associates or send targeted6/27 requests.

Server handler14045cf80 reads that WORD, resolves the controlled object and
calls RelayQuickChatCommandToAssociates1403d6c30 when its physical associate
list exists. The relay maps0->-3,4->-4,9->-7,10->-2,22->-5 and dispatches native
ReceiveAssociateCommand on the server. It re-reads the live physical list
between calls, including duplicates/stale lookups/list mutation. Other WORDs
do not dispatch associate AI. The handler also calls response sender1404df1c0.
That sender broadcasts OBJECT_IDServer+WORD via22/0 to players in the same area
within squared distance400. These decisions all stay on the server.

The five global command leaves now send typed22/0 requests. Owned-associate
wheel leaves continue using6/27, as established in
[targeted command/control evidence](multiplayer-associate-control.md).
Narrow IPC checks trusted main frame/session/current area/current actor. A
stale control target cannot submit a global command against a new creature.
Quickchat replies decode canonical IDs and WORDs; audio/text presentation is
explicitly diagnosed as unfinished rather than simulated locally.

## Shortcut fields and input

Native general activation14085c8f0:

- Type38 calls7bff40: empty6/19, server chooses/validates familiar possession.
- Type39 reads a widget's low SHORT role and signed high SHORT command. Role1
  uses the saved ID, role2 the current controlled companion+278, role3 the
  current familiar+27c. Other roles send nothing. Missing dynamic IDs remain
  OBJECT_INVALID; native sends them without name scanning or substitution.
- Type42 calls805440 and sends the command's low WORD through22/0.

Crucially, the native persistent/server button39 stores its command INT and
associate-type WORD separately. Replication adapter1408693b0 packs them as
command<<16|type for GUI setter860760; the latter writes widget+118. The
replacement retains the separate wire fields and truncates/sign-extends only
when activating, matching the original. It does not mistake persistent INT
for an already-packed widget value.

Original setter140860760 supplies native icons/TLKs for targeted unsummon,
unlock, inventory and disarm shortcuts;14086b460 supplies possession;
140868230 supplies global commands. The existing replacement assignment
category UI now offers those types from actual replicated ownership/links,
with native binding payloads. Targeted choices use role1/saved canonical ID,
as callback995f10 does; received role2/3 buttons resolve current links at use.
Assignment UI/category layout remains the replacement's existing workflow,
not a claim of pixel-identical original quickbar menus.

Native30/2 assignment uses7becd0(type38),7be1d0(type39),7bec10(type42), complete
452030/4521d0 server reading and AssociateCommand setter3a3a50. Client-owned
shortcut layout changes are distinct from gameplay results. No AI, control,
cast resolution, resource spend, object creation or removal runs locally.

## Original-code and live validation

`inspect-native-network-party-command.py`:640 cases execute original request
serialization, full quickchat server handler/relay and full general shortcut
activation with the original senders. GUI860760 is a declared modeled boundary
from its observed widget writes;8693b0 itself executes. Object/player lookups,
final ReceiveAssociateCommand, response sender and transport are captured
lowers. A missing possession GUI lookup was discovered in v1; v2 explicitly
captures it and completes. This does not claim full original GUI/AI execution.

`inspect-native-network-quickbar-requests.py --associate-extension`:108 cases
run original typed emitters/full native server30/2 reader/setters for38/39/42,
including separate role/ID fields and signed INT boundaries. It uses a separate
fixture, preserving the original216-case default fixture. v1 stopped at an
uncaptured3a3a50 dependency; its original body was inspected, then v2 executes
it. All108 agree with the replacement encoder and stored native fields.

`inspect-native-network-quickchat-response.py`:720 cases execute complete
4df1c0 and original writers, including same/different areas, missing sources,
radius20 boundary, both scalar formats, reserved/high IDs and WORD bounds.
Lookup/player-list/transport lowers are explicit. Reply decoding agrees with
every emitted native packet; every truncated format1 reply is rejected.

Real v63 uses unchanged installed wizard.bic and the owned unchanged vanilla
Prelude nwserver/ELC on/UDP5121. Twenty actual DOM/pointer/F-key inputs:
summon -> self Stand Ground -> assign Follow/type42 -> F11 -> assign
Possess/type38 -> F12 -> self Unpossess Familiar -> assign Unsummon/type39 ->
F10. One ordinary production move request moves the PC away while standing.
The familiar remains stationary until the server receives Follow, then moves
over0.5 units toward the PC and closes the distance by over0.5. The records are
actual server positions, not renderer interpolation or a local AI simulation.

Native outbound packets:6/6,22/0(10),30/2(type42),22/0(22),30/2(type38),6/19,
6/27(-13),30/2(type39/-8/role1/saved ID),6/27(-8). Server22/0 replies echo
PC0xffffffff+10/22. Possession/control cycle and final unsummon pass. Replaying
all server game messages preserves the same PC/familiar proxies, restores PC
control/book and server-replicated type42/38 shortcuts after possession, then
clears the familiar link and marks the canonical familiar removed. Final live
layout also contains the assigned type39 shortcut.4261 GPU frames,94 diagnostic
records, zero errors, clean disconnect; QA49116 exited. Both PNGs inspected.

342 focused tests PASS(network-party-tests-v3.txt); production build PASS(v2,
existing chunk-size warning); backend/IPC/preload/harness syntax PASS. These
checks cover this change and affected networking/casting/associate paths, not
the entire campaign or original-client concurrent play.

## Open requirements

Party-list14/1/3/4 parsing/UI and conditional multiple-henchman global menu
branches are still absent; only the five verified global command leaves are
projected. Targeted henchman inventory opening still needs its actual inventory
control/ownership/UI path. Full quickchat voice/text presentation remains
diagnosed. Native other modes, spells/item powers/preparation, persistent
effects/audio, broad combat and original-client concurrent gameplay remain
unverified or incomplete as documented in earlier checkpoints. Goal ACTIVE.

Credential audit:11792 files/private hits0 across recursive source/tooling/
evidence, built client, retained research/text captures, current native fixtures,
renderer captures and REA stderr. Private server profile/settings/identity/logs
are excluded. Server PID36824 remains live; completed QA49116 is absent.

Verified checkpoint `multiplayer-party-commands-20261018-v1.zip`:13162 files,
260994509 bytes. Writer92282 finished terminal0; every entry length/SHA256
verified. Scope43 required present/forbidden0. Only audited REA stderr is
included from runtime-logs; private profile/settings/binaries/assets/BICs are
excluded. This postseal note and scope audit are outside the archive.
