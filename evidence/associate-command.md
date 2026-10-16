# Associate commands and summon dismissal — October 15, 2026

Target NWN:EE89.8193.37-17, original nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Executable/install/Ghidra remain unchanged. All native observations use read-only
instruction mappings and explicitly captured lower boundaries.

Continuation: [authored listen/follow owners](associate-listen-follow.md) now
connects conversation event7, matched capture storage/queries and force follow.

## Original ownership and dispatch

ReceiveAssociateCommand1403d69f0 resolves master before storing +90c. Unknown
commands still store that value when a master exists. -9 clears master's +910,
-8 clears master's +914, and -9/-8/-10 invoke the same UnsummonMyself owner.
-13 calls the master's UnpossessFamiliar; -12 removes domination. Ordinary
-23..-2 commands (excluding those special branches) create script event7 with
integer0=expression capture count, integer1=command and strings1..count-1.
-2 first writes +708=1, the same cell used by passive-attack state. This is not
an immediate follow/move/attack shortcut. BroadcastAssociateCommand140382bb0
walks the physical live list, preserving duplicates/stale IDs/count mutation.

Decoded input subtype27,140454288..140454331, reads OBJECTID then signed INT32.
After overflow/underflow checks it redirects self inventory command-19 through
GetAssociateId(1,1), resolves the target and checks its master against the
controlled creature. Self-target command-13 is exceptional. Native return stays0
even when delivered. It imposes no additional commandability or same-area gate.
The shared entry's +8ac actor veto remains represented. Original wire encoding
and client/server transport remain separate from this local decoded adapter.

Creature constructor14037ab82/89 clears +90c/+910/+914. VM command321,
GetLastAssociateCommand140529ae0, returns +90c for a creature and0 for absent or
noncreature IDs (stack decode/encode failures are handled by the shared VM).

## Client menu

Role14098e550 compares owned master ID with the controlled ID. The local view
now uses canonical masterId, rather than inventory ownerId; direct canonical
fields stand in for client-replicated +804/+808, not network replication proof.
Owned submenu14098f8e0 retains native slots/icons and signed callback words:
summon4 Unsummon slot3/-10; companion2 slot3/-9 plus Talk7; familiar3
slot3/-8 plus Possess2; dominated5 slot3/-12. Henchman1 retains Examine0,
Dismiss3, Unlock1/-18, Inventory2/-19, Disarm4/-20, Search7/-23,
Cast5/-21, Stealth6/-22. Callback140995f10 uses selected canonical target when
the argument high WORD is-1 and forwards the command through1407bf0e0.
Unimplemented henchman removal/possession/domination owners remain diagnosed.
Ordinary commands now reach the original authored conversation script through
event7. Root Follow/Stand/Guard/Attack Nearest/Heal Me submit original signed
words; actual movement follows the installed script's force-follow request.
Voice-chat and stalled-movement forced jump remain separate unfinished owners.

## Verification and limits

inspect-native-associate-command.py records596 original receiver/broadcast/input
cases; inspect-native-owned-associate-radial.py records11 menu cases. Source
tests compare state/order, live list mutation, ownership, overflow, self target,
inventory redirection, icons/slots and command words. Lower VM, GUI allocations,
expression getters, event transport, unsummon and possession/domination calls
are captured boundaries. This is607 bounded observations, not full associate AI.

probe-live-summoning.mjs / live-summoning-v3.txt now tests native input dismissal:
ownership loss rejects without storing the command, restored ownership delivers
-10, the creature remains until deferred event11, then owned inventory, area,
associate and canonical objects are removed. Its master's effect is not silently
deleted. Existing replacement/expiry/adoption/spawn-race checks still pass.

smoke-live-summoning-ui.cjs / live-summoning-ui-v5.txt uses actual ground
right-click spell casting, camera orbit/zoom, world right-click on the summoned
model, Associate actions → Unsummon, and verifies animation/view removal with0
renderer errors. JSON plus before/after PNG are captured. The authored area is
dark in these captures; lighting parity is a separate remaining presentation
issue. No debug engine hooks, manufactured slots or installed-file writes.
All1,366 tests pass and production build passes. Spell/combat/campaign completion
remain open; this is a verified summon-command milestone.

Next bounded owner: script event7 at14038f623..14038f888. Assembly shows familiar
unpossession, speaker/listen/capture state, default NW_G0_Conversat and the
LL_ASSOCIATES_RUN_SCRIPTS gate. Pseudocode falsely stops at the first free; do
not bind generic commands directly to movement or omit this receiver.
