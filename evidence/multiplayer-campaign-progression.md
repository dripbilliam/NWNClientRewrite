# Campaign and placeable continuation — 2026-10-19

Previous goal turn made progress: real bag transfer/closure was implemented
and verified. Container checkpoint14531files/389404769bytes verified each
SHA256/length; independent scope46required,0missing/forbidden/duplicates/
credential candidates. Current changes continue the full multiplayer objective;
they do not complete it. Movement polish remains deferred.

Native target hashes are in multiplayer-server-speech.md. Existing Prelude
module and server remain unchanged. Read-only installed GIT inspection located
usable Desk, Armoire and Chest near the starting player. Product code does not
hardcode their IDs, positions, spells or campaign state; QA uses actual scene
IDs and installed NPC name references to select normal interactions.

v100 opened the actual chest and received Watchman's Club2147484313. The chest
reported one page, so disabled page buttons were correct; the initial QA plan
incorrectly required an enabled Next button. That failed run is retained.
v101 production chest-item double-click sent native12/9; server success removed
that same ID from C and added it to R. The installed item became identified
and its visible name changed to Tethir Wood Cudgel by server results. The
inspected looted PNG confirms its presence in the backpack. No local identify,
transfer, loot spawning or rules evaluation occurred.

Original client page Next140855d00 and Previous140855be0 both clear grid882700
before transport lookup/send7bde70/7bde90. Current page2680 reads its low BYTE;
count2f60 controls wrapping. Complete original handlers run on synthetic GUI
memory:140cases span current-1/0/1/2/255/256/257,count0/1/2/3/255,direction and
missing/present transport. Grid/string/label/transport are explicit lower
boundaries. selectContainerPage matches every transport-present case; missing
transport leaves the original stored page unchanged after clearing.

The replacement now clears C GUI membership before a page request and retains
the canonical item objects/last metadata. Primary and alternate channels stay
separate. Server owns container access, contents and page limits; local page
selection is presentation state. Native two-digit page label is reproduced.
Installed DOM fixture asserts the grid is empty at the send delegate.43focused
tests and build passed before the speech integration; the later52focused and
246network tests include this work. This one-page live chest cannot prove
multi-page placeable rendering; that live acceptance remains open.

v101 spoke to Pavel and stopped at the harness's12-reply limit. v102 completed
the explicit normal exit in10replies. Server still reported locked1 on the
quest door; an attempted transition correctly rejected rather than bypassing
the authoritative lock. Door GIT is Plot1,KeyRequired1,Lockable0; OnFailToOpen
nw_od_feedback8 invokes authored one-liner feedback. Native4531b0 subtype3
WORD21/22 queues AddOpenDoorAction/AddCloseDoorAction, matching the existing
typed request. No invented local unlock fix was applied.

Decoding real9/12 packets exposed Pavel's instruction to speak to Bim. Bim's
native name reference57902 and authored position identify the next QA target.
v103 walked through the normal server path to Bim, received his first tutorial
stage and instructions to return. These packets now display in the message log.
This also explains why a first-dialogue-only test did not demonstrate exiting
the room. Subsequent tutorial/transition results are recorded in the acceptance
capture, with failures distinguished from successful progress.

The original-client launch via Computer Use reported user Escape cancellation.
No further Windows UI input was issued. Later read-only process inventory
showed nwmain32948 running, but that is not proof of a connected original
client. The observed player list still contained only ReplacementTest. Shared
original-client interactions/combat/casting remain required for completion.

The later user-reported door freeze was traced and corrected; see
multiplayer-area-transition-recovery.md. Native packets did reach m0q1b.
Sealed v107 verifies the new attached100tile scene without the former facing
exception. User confirmed closing the test window. Longer campaign testing
and original-client coexistence remain open.
