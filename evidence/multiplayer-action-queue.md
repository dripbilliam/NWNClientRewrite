# Native multiplayer action queue — 2026-10-19

Target NWN:EE89.8193.37-17, nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original binaries and processes are read-only research inputs.

Native player-state receiver1407b4f70, queue branch7b728d..7b79c0,
reads A/S/D/U records. A appends; S creates a special widget after existing
special widgets, ahead of normal ones. S is not a target update (the earlier
artifact filename rea-queue-client-retarget.json is misleading). U consumes
type/group/target but makes no visible change. Target and position temporaries
carry within one batch; S supplies zero coordinates. D removes the first
matching type/group, promoting the next widget if needed. Original GUI list
owners140873df0/1408741f0/1408748b0 establish this order and duplicate behavior.

The client now merges those changes persistently as presentation metadata.
widgetSerial is a local widget identity only: canonical uint32 game IDs and
wire WORD action/group IDs remain unchanged. No action runner, pathfinder,
AI, combat, spell or script resolution is attached to this list.

Original click callback140874a00 sets widget model alpha to0.5 and calls
1407bf390 with WORD action and WORD group. That sender uses6/20. The whole
server input dispatcher1404531b0 branch454d3f..454d90 reads both WORDs,
checks overflow, resolves the controlled creature, checks commandability,
and calls CNWSCreature::CancelAction140386700. Only server updates remove
widgets; clicking does not locally stop movement or remove actions. There is
no new global Escape cancellation binding: the observed native caller is a
queue-icon click. Existing spell-target Escape behavior is unchanged.

144 original-code sender/receiver cases cover both native codec formats,
WORD boundaries, absent controlled creature and uncommandable creature.
The oracle executes the complete original sender and dispatcher, real scalar
codecs, synthetic controlled-object lookup and a captured CancelAction call.
It does not execute live action cancellation, GUI rendering or AI. Original
GUI list order is established by static disassembly/pseudocode, with focused
merge tests; it is not claimed as a whole original-GUI execution oracle.

The network view uses installed CTL_ACTIONQUEUE art and active actions/spells/
feat rows. Normal cast icons use associated FeatID when nonzero; item casts
use the spell icon. Unknown item-spell rows are hidden as in the receiver;
unknown spell metadata remains diagnosed. The replicated list retains the
server record even if unavailable metadata prevents its icon from rendering.
Normal missing action icons follow native ir_use fallback. Ten visible slots
retain the logical tail; local pending opacity survives unrelated updates.
Area/session/control/asset changes invalidate stale widgets and async loads.
Skin, label and icon failures are recorded independently.

80 focused regressions pass, covering native packet matching, persistent
queue updates, U decoding, scoped backend/IPC input, unchanged canonical
objects, player-state/casting/interaction/transition behavior and singleplayer
queue regression. Installed muted Chromium HUD checks real skins/icons,
click dimming, deferred server removal, stale detached input and late resource
completion after reset. Buildv2 passes. Initial test failures were fixture API/
prefix/tail-padding assumptions and are retained in focusedv1/v2 reports.
The first screenshot preceded Chromium paint; subsequent capture waits for it.

Live vanilla-server click-cancellation acceptance is pending. The existing
replacement145/original33744/server20964 remain running before rollout.
Initial attack approach failure remains unexplained; the original client
attack sender sends only6/2 and server AIActionAttackObject1403dcd50 owns
approach. No speculative client waypoint workaround has been introduced.
The full multiplayer goal remains active.

Live acceptance completed: sealed146/PID40632 disconnected normally and saved
its character,182samples/72wire messages, no capture or runtime failures. A
physical walk-icon click sends6/20 action0/group0; server D removes it and
server position stays43.83,88.35, before requested55,85. An ordinary native
return waypoint restores30,85. A physical cast-icon click sends4/group2 after
self-targeted prepared Light100 starts; server removes it without release,
keeping two prepared uses. Original player health86 and local77 stay unchanged.
The self-spell is a validation scenario, not a spell-specific implementation.
Both canonical PCs remain connected; original-origin active shared play has
not been demonstrated by these checks. verify-network-action-queue.mjs replays
the complete wire capture against installed active rules and checks requests,
A/D pairs, pending opacity, movement stop and retained preparation.

Sealed145 is also closed/no failures,720samples/333wire. LIVE passive147/PID18816
runs final index-2DnsjGHb.js at m0q1d/144tiles,[30,85], empty queue, no failed
scene objects or runtime errors. Frozen current147 JSON and ready screenshot
are explicit; its active full capture is excluded from backups. No gameplay
inputs are scheduled. Original33744/server20964 are unchanged. The final screenshot
was visually inspected. Exact queue layout/capacity/resize behavior, initial
attack approach, remaining combat/voice/projectile audio, authored missing
sco_mehanacid01 and active shared campaign acceptance remain open. Full goal ACTIVE.

Source checkpoint multiplayer-action-queue-20261019-v1.zip verified52files,
1578271bytes; independent54entry/11parent audit has zero missing/forbidden/
duplicate/new credential candidates. A final live-inclusive checkpoint follows.
