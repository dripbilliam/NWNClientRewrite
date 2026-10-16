# Use Object action and request ownership

Target: NWN:EE89.8193.37-17 x64 nwmain.exe, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.
Original executable/assets and Ghidra database remain unchanged.

## Original owners and implementation

`src/use_object.js` maps full AddUseObjectAction1404ab5b0 and
AIActionUseObject1404a9790..1404aa8c3, excluding instrumentation. Action40 uses
three slots of types3,1,1; the latter two become deadline and phase. Request
commandability, canonical lookup/casts, corpse redirection, range/approach
queue order, orientation lock, trap reputation/faction gate, inventory observer
ownership, lock/corpse equipment provider calls, OnUsed25 and unsigned500ms
completion preserve original branch and call order. Cancellation40 takes the
ClearAction1403870b0 shared tail; it has no private GUI rollback.

The decoded input subtype11 at1404531b0/453acb..453ba9 reads OID and two BOOLs.
Only notification exactly1 queues OnClick42, before ActionManager2. Nonzero
popup writes retained GUI field4. There is no area-ID gate; the local UI checks
same-area targets. NWScript ActionInteractObject14050dec0 looks up a placeable
before the source creature and ignores the lower AddUse return. Both paths
now reach the real object action queue; the old OnUsed-only UI path is removed.
Placeable event25/42 delivery checks Useable264 and writes caller528/52c before
RunEventScript12/15(flag0). Event24 is disarm, not OnUsed.

Placeable loading now imports Locked, TrapActive and TrapFaction into their
native views; constructor3d4 defaults1 and3d8 defaults0. Synthetic body-bag
loader378/3b4 now updates the same locked/trapped views. GetReputation4abcd0
is a reputation owner, not trap detection. DestroyEquippedItems14038a7a0
visits all18 slots and directly destroys nonzero-droppable items, retaining raw
slot IDs until their owning cleanup runs.

## Verification

`inspect-native-use-object.py` executes original instructions:1,233 executor,
48 AddUse,36 cancellation,12 equipment and48 script-event cases. The separate
`inspect-native-use-object-request.py` executes201 decoded-input and96 script
command cases. Seven comparison tests cover these1,674 observations. Captures:
native-use-object-observations.json and native-use-object-request-observations.json;
use-object-native-v3.txt/use-object-request-native-v1.txt/use-object-tests-v3.txt.

Installed Prelude probe uses player565/placeable16, actual PWK use point and
ordinary queue/GUI/scheduler/VM owners. In-memory marker scripts verify
OnClick/OnUsed/OnOpen/OnClosed and last-caller queries. Real monotonic500ms
completion, cancellation without GUI rollback and NCS GetObjectByTag →
ActionInteractObject pass. Failed v1 selected another object sharing the tag;
v2 supplies the actual tag ordinal and asserts the queued canonical ID.
Startup/AI disabled. All diagnostics retained, no new errors.
`installed-use-object-v1.json`/`use-object-installed-v2.txt`.

All1,687 tests pass and production build passes with its existing chunk-size
warning: use-object-full-tests-v1.txt/use-object-build-v1.txt. The real rendered
wheel → native action → authored DestroyObject → delayed bag/pick/revisit
regression passes: use-object-body-bag-ui-v1.txt/live-body-bag-ui.json/.png.
Preview sun is enabled for visual inspection; this is not a lighting parity claim.

## Remaining boundaries

The live ordinary unlocked placeable path is connected. EvaluateLock14038d230,
FailedOpenInformAssociates1403d4b90, trap event26 lower owner, corpse broadcast
StripEquippedItems1404ccec0, item Open46ad80/Close465f80, and noncreature action40
adapters remain explicitly unavailable. Loot-window presentation and pickup
requests remain unfinished. Do not replace them with direct inventory mutation.
Exact original client wheel sender flags and packet codec remain unmapped; local
UI sends popup1, radial notify0, left-click notify1 to the verified receiver.

Native time14016dd40 flag0 uses cached DWORD+28 when global14128f0c8 is nonzero,
otherwise GetTickCount via IAT140d7c950 (import string14128c12c). The browser's
monotonic uint32 milliseconds preserve action comparisons, not the original
epoch/cache/granularity. Full spell/combat/campaign goal remains ACTIVE.
