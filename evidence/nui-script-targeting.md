# NUI toolbar spell selection

The user reports that NUI toolbar spells do nothing and a subsequent target
click moves the character. The current live log contains eight unsupported18/23
commands paired with57/2 targeting data. There are no recorded NUI input errors.
This is consistent with toolbar clicks reaching the script but its target-mode
request being discarded. No new automated Arelith input was sent to establish
exact click-to-packet timing; the user supplied the live reproduction.

## Native observations

Follow-up: installed nwscript identifies the third18/23 DWORD as the bad-target
cursor. It was named flags in this first investigation; the cursor/preview work
corrects that to badCursor and now presents57/1 and57/2 targeting shape data.
See target-preview-cursor.md for the implementation and graphics validation.

Read-only NWN:EE89.8193.37-17 x64, SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a.

- GUI receiver140770c80, subtype23 jump entry14077a378, reads three DWORDs.
  A zero object mask calls cancellation via1406ab440/1406d66f0. Otherwise call
  site14077a3c6 invokes14098bd90, forwarding to14098d5f0.
- The start owner registers object mask bits0..9 as client kinds
  5,6,7,10,11,12,9,14,13,2, using the supplied cursor, and stores the third
  DWORD at118. Ground is kind2. It installs selection callbacks14098c230 and
  14098c2b0. Those report selected OBJECT_ID plus XYZ via1407c0110.
- Reply writer1407c0110 writes a raw client OBJECT_ID and three native FLOATs,
  then sends major6/minor37. It does not send an ordinary spell-cast request
  and does not add the innate-cast Z offset. Object/position callbacks reset
  targeting preview afterward. Cancellation14098bdb0 clears preview without
  sending a target reply.
- Target-data receiver1407b1340, subtype2, reads shape, sizeX, sizeY, flags,
  range, spellId and featId. It updates shared target-preview configuration.

REA failed to decompile the large140770c80 owner. The targeted read-only
disassembly and its jump table establish subtype23 instead; that failed REA
result is not counted as successful analysis. The initial string search used
an invalid query key; the corrected pattern search succeeded. Original binary,
Ghidra project and live original process were not modified.

## Correction

Decode18/23 and57/2. Keep target mode/data within each connection's NetworkWorld.
Arm the existing NetworkSpellTargeting through a ready-area fast path, independent
of pending model/chat work. A script target uses the original object mask; the
next valid canvas or inventory selection reports through the new typed target
IPC and native6/37 writer. The server script retains authority to cast or take
another action. No toolbar resource name or server-specific spell is hardcoded.

Target versions, actor and area ownership reject stale/replaced requests. A
selection consumes its version before asynchronous transport, preserving newer
server commands received during the send. Invalid targets retain targeting;
Escape/right-click reset locally, and a server zero mask cancels. Connection
reset, committed area transition and controlled-creature replacement clear
ownership. Existing target picking includes the controlled player, and normal
click-to-move remains available after targeting ends.

The target preview fields are retained as data. Native shape/range preview
geometry, cursor artwork and every specialized flag behavior are not claimed
as fully rendered here. This fixes the missing generic script-target handoff,
not all remaining NUI/native presentation parity gates.

## Validation

`inspect-native-script-targeting.py` executes unchanged original writer code
for12 target/point cases and the original mask branches for13 masks. Scalar
framing and object namespace are native; allocator/transport and controller
services are captured. Tests compare all defined packet bits, excluding native
A5 fixture padding. This is an isolated oracle, not a live-server cast test.

`smoke-nui-targeting.cjs` uses real Chromium mouse events on a headerless image
toolbar, production NUI/frontend/targeting/session code, native-format synthetic
server replies, typed IPC and the actual extracted main.js canvas pointer-up
handler. Three physical toolbar clicks produce creature, ground and self replies
with exact coordinates, zero move requests during selection and zero errors.
Server cancellation restores click-to-move. Zero joins/uploads. A synthetic
server callback does not establish authoritative Arelith spell outcomes.

All56 focused targeting/NUI/spell/feat/IPC tests pass. Build
index-D94Tiz7j.js/index-8ID_vg9F.css passes. Evidence under backups/animations:
native-script-targeting-v1.json, creation-experience-nui-targeting-v1.json,
nui-script-targeting-focused-v2.txt, nui-targeting-ui-run-v1.txt,
nui-script-targeting-build-v1.txt, nui-target-entry-assembly-v1.txt and the
rea-nui-target-* captures. Scripts/fixture assets are authored/synthetic.

No running client restart or public-server action was performed. The user must
restart to load the build and confirm Arelith's resulting spells. Broader goal
remains paused; changes are unsealed after checkpoint49.
