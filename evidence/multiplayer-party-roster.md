# Multiplayer party roster and portraits

Target: installed NWN:EE89.8193.37-17 x64 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executable/server/Ghidra project are read-only. REA native dossiers
`rea-network-party-*` and the explicit original-code oracle are retained under
`backups/animations`. Previous goal turn PROGRESS; this turn PROGRESS.

## Wire and native roster behavior

Sender1404dddb0 writes signed INT count then OBJECT_IDServer entries via major14,
minor1(full)/3(add)/4(remove), excluding every source ID equal to its exclude
argument. The count's vectorized >7 path and scalar tail both execute in the
oracle. Complete client handler1407a7440 reads these fields and calls the party
panel owners. Nonpositive counts do not read IDs. Unknown creature IDs still
create party-panel entries, not game objects or ownership relationships.

The native list is not a wholesale replacement in incoming wire order:

- Full852ac0 marks existing entries stale;851220 clears an existing entry's
  stale flag or appends a new entry;852f90 sweeps stale entries at the end.
  Previously present members retain their physical ordering.
- Add851220 retains that ordering and suppresses ordinary duplicate IDs.
- Remove853060 marks the first matching entry, then sweeps marked entries.
- Lookup851c60 uses INVALID as its empty cache key, allowing repeated INVALID
  rows. Native sweep retains ID0 even when marked. These edge cases are
  preserved in the roster model; neither creates a proxy in GameObjectArray.
- Array removal851700 compacts the native physical array. Party membership
  removal does not destroy a creature or change player control.

`network_party.js` ports this state separately from the canonical object table.
Malformed fields/batches are rejected atomically, consistent with the existing
network import policy; this is stricter than native partial mutation on damaged
messages. Missing proxies stay pending IDs and resolve only when actual server
object updates arrive. Reset clears the roster; area imports retain it.
Associate queries mirror count8520c0/first851dd0/next851ff0: current creature
lookup plus type274/master270, not membership-based ownership. Henchman shortcut
choices now use those ordered roster matches rather than scanning the registry.

## Presentation and input

New NetworkPartyView shows a controlled primary portrait and server roster
portraits, names and transmitted health. It shares existing native UI assets
and active portraits.2da; it does not run singleplayer UI/session simulation.
Primary853640 requests medium portrait3; member853430 requests small2. Neighbor
size fallback order follows84c2f0. Numeric portraits use active BaseResRef;
custom portrait refs remain server-provided. Names resolve through NetworkText.
Health uses current+third SHORT and the fourth/max SHORT, matching the original
creature update's853820 call, without recalculating local HP or class rules.

Primary ID write853674 belongs to853640. Callers77fe10 and781380 explicitly
refresh the controlled primary. This was checked before choosing a controlled
header, rather than assuming it stays on the original PC during possession.
The controlled primary and the raw server roster are projected independently;
native per-frame filtering/layout/status-icon details still need original-client
screen comparison. The current screenshot during possession has both the
controlled familiar primary and its still-transmitted roster entry. No guessed
membership removal or substitute PC ID was introduced to change that display.

Member context callback851020 builds creature radial98e340 for owned associates,
otherwise normal role98e550. The replacement uses the same shared native action
selection, canonical target and session/area/control guards from previous work.
Portrait clicks while targeting use NetworkSpellTargeting, so class/feat/innate
casts keep the same typed server request path. Ordinary portrait chat/action
composition remains explicitly diagnosed; it is not replaced by invented camera
movement or local control transfer. Targeting members in another area and the
full native portrait modifier-key behavior are not yet verified.

Static command-menu clarification: self creator9914b0 passes flag0 to9945d0;
ordinary non-DM self commands expose only the five global leaves already wired.
The extra henchman branch requires flag1 or DM. Quickbar creator9ac860 passes
flag1. Those native conditional assignment-menu layouts/pagination and full
associate inventory UI remain open; they must not be injected into the normal
self wheel. Existing replacement assignment categories retain native payloads.

## Verification

`inspect-native-network-party-list.py`:630 cases execute original4dddb0 -> full
7a7440 ->851220/852ac0/852f90/853060/851c60/851700 with real scalar/ID writers and
readers. Inputs cover both format modes, all three minors, existing/reversed/
stale/sentinel/ID0 entries, duplicate/new IDs, exclusions and vectorized source
lists. Object lookup is absent in this fixture; GUI constructors/labels/models/
layout/scroll/destruction and memory copy are explicit lower captures. Member
constructor layout is modeled fixture memory. This proves wire and list state,
not full original GUI rendering. v1 stopped because the fixture omitted the
client application's extra pointer indirection; v2 initializes it and passes.

All630 match replacement ordering/flags/IDs, with no mutation of the input
snapshot. Every truncated format1 native message is rejected. Separate checks
cover signed count bounds, malformed atomic rollback, membership versus object
destruction, missing proxies, dynamic ownership/type queries and HP projection.

Real v64: unchanged installed wizard.bic, owned unchanged vanilla Prelude
nwserver/ELC on/UDP5121, real hidden offscreen production Electron renderer.
Eighteen actual portrait/menu/key inputs summon a familiar, send targeted Stand
Ground/Follow through its portrait, activate existing Light shortcut Ctrl-F8,
then click its portrait as the spell target. Server6/18 targets canonical familiar
0x80000299; prepared Light uses2->1 from server records. Owned portrait Possess,
controlled primary Unpossess and owned Unsummon complete. PC0xffffffff and that
same familiar proxy remain canonical across control changes. Actual14/3 adds
the familiar;14/4 removes it, leaving only the PC primary. A real move request
also runs through the normal production input path.

Numeric familiar portrait703 and custom PC portraitpo_el_m_06_ both load; names
and77/77,52/52 health display from server values. Final PC portrait remains
loaded after unsummon.4366 GPU frames, zero runtime errors or portrait warnings,
clean disconnect; QA54844 exited. All three PNGs visually inspected. Full server
wire replay verifies stable object references, roster add/remove and restored
PC control. Source remains generic; no spell/module/creature-name substitution.

346 focused tests PASS(network-party-list-tests-v3.txt); production build
PASS(v3, existing chunk-size warning); codec/view/backend/harness syntax PASS.
The roster-specific native import and portrait-targeted cast are demonstrated;
this is not complete party/chat/inventory UI, exact native layout/status icons,
all multiplayer casting/effects/audio or original-client concurrent play.
The full multiplayer goal remains ACTIVE.

Credential audit11840 files/private hits0: recursive source/test/evidence/tooling,
built UI, retained research/text/current native fixtures/renderer captures and
REA stderr. Private server profile/settings/identity/logs excluded. Owned vanilla
server36824 still runs on UDP5121; completed QA54844 is absent/disconnected.

Verified checkpoint `multiplayer-party-roster-20261018-v1.zip`:13216 files,
265782929 bytes. Writer27212 finished terminal0; every entry length/SHA256
verified. Scope41 required present/forbidden0. Only audited REA stderr is
included from runtime-logs; private profile/settings/binaries/assets/BICs are
excluded. This postseal note and scope audit are outside the sealed archive.
