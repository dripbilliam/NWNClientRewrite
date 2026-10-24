# Multiplayer containers — 2026-10-19

Core-feature continuation; broader multiplayer objective remains active.
Bag double-click/default radial Use and default container shortcuts now send
native object use. Server container status opens a paired container/backpack
view; repository drag/drop sends native requests, never local item transfer.
Placeable use shares the status/contents path. Alternate GUI presentation,
merchant inventories, full container art/icons and complete campaign validation
remain unfinished. No particular bag, module or spell is special-cased in
production; the live QA harness selects installed preset inventory fixtures.

## Native evidence

Read-only NWN:EE89.8193.37-17 binaries at the existing install. nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a;
nwserver SHA256
98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.
REA dossiers rea-container-*.json; no native binary/project/process changes.

Client14085bec0 checks baseitems.Container before equipment or item powers.
Container ->14083f5d0 ->1407c07c0:major6/minor11, OBJECT_ID, BOOL0,BOOL0.
Existing general use writer matches. Native close1407bdeb0:25/1 plus OBJECT_ID.
GUI1408575f0/140857cd0 hides its pane/clears its grid and sends close with0;
this is local GUI state, not an authoritative item mutation. Next1407bde70
and previous1407bde90 send empty25/2 and25/3. Bounded discovery finds calls
7bde84,7bdea4,7bdf1b; each containing function was then analyzed directly.

Server140451810 closes the previous item/placeable, then resolves the incoming
ID. SetOpen1404be930 clears the container's last-update list and resets its
page. Item repository/possessor checks remain on the server. Existing isolated
native-container-input-observations covers the complete handler and next/
previous page owners4be8a0/4bec00. Only placeables qualify for server paging;
bags use one page. Server14046ad80 opens item inventories; CloseInventory
140465f80 and GUI close ownership distinguish explicit notifications from
local closure. No positive close acknowledgement is assumed by our GUI.

Status writer1404d9c30 emits major25/minor1, OBJECT_ID and BOOL.
Client1407a41a0 major25 ->14079ceb0 reads both fields and chooses GUI via
6abbe0(nonzero) or6abfd0(zero). G dispatcher1407b3c90 likewise passes1 for
uppercase C/I/R and0 for lowercase c/i/r. Thus BOOL nonzero means primary;
it is not success, open, or alternate. v96 initially reversed this and
diagnosed an alternate UI instead of displaying the bag; mapping corrected.

G/C reader1407b3790 dispatches A/D/U/M membership and P BYTE.
P ->140857ad0 sets page COUNT2f60 and clamps current2680, not current page.
The old decoder's page field was mislabeled; it is now pageCount. Presentation
page is local navigation; page limits/list contents come from replicated GUI.
Items retain exact canonical uint32 IDs and move between GUI memberships.
Container context is separate from controlled actor and tracks primary and
alternate owners separately; unknown owners remain diagnosed.

Repository transfer remains existing1407c1030 major12/minor9, item ID,
destination ID and BYTE coordinates. Server455f50 owns access, recursive
container rules, slot fit, weight, stacking and eventual item changes. Main
process accepts a source in controlled R/I or current open C; destination must
be controlled actor or the current open container. Close/paging is scoped to
current actor/area/generation/container. No local repository fit or split rules
compete with the vanilla server. Closing clears GUI owner/membership after
sending, but preserves canonical items and their last metadata.

## Verification and observed corrections

inspect-native-network-container.py executes complete original use/close/page
writers and the server status writer with actual scalar/OBJECT_ID codecs.
50cases span both scalar formats, namespace/sentinel IDs, both selectors and
directions. Format1 defined bits match JS; native uninitialized padding masked.
First run used a wrong transport stub address; observed1404dc490 corrected
and retained oracle v3 passes. Tests also preserve status ownership, pageCount,
stale scope, server-only movement, nested item Examine and bag shortcut use.
Focused v5:58 tests pass; installed DOM UIv3 passes drag in/out, equipment-pane
replacement, page command, server close plus existing HUD/spellbook/Examine.
Buildv3 passes with the existing size warning. No full-suite run this section.

Live v96 failed primary selector mapping; retained report/PNG explicitly
failed. v97 successfully used real production DOM double-click and drag/drop:
same potion2147484309 moved from actor to bag2147484308 and back, two server
12/9 success replies. Its local-close pane remained visible because code was
waiting for a status reply; native GUI owner analysis corrected that lifecycle.
v97 closed PNG is therefore failed evidence, not final acceptance.

Final v98:two12/9 success replies moved potion2147484309 (stack3) into
bag2147484308 at[0,0] and back to actor at[9,3]. Close sent one25/1
with0, restored equipment locally, and whole inventory then closed. No
sampling failure or runtime errors. Full normally closed capture and compact
network-container-acceptance-v1.json agree; all four final PNGs inspected.
v99 PID36584 left open without automated actions; readiness frozen separately.
Its full report only exists after normal close.
The unchanged local nwserver and user's original client are left untouched;
this section does not constitute a new original-client concurrent gameplay run.
Original-client shared combat/casting and multi-page placeable looting still
need live acceptance. Further movement polish remains deferred.
