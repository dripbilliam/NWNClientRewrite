# Area readiness and associate restoration

Target NWN:EE89.8193.37-17, original read-only
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Ghidra/full instruction inspection and isolated Unicorn comparison. No original
binary/assets or Ghidra edits.

## Observed owners

`src/player_area.js` implements four separate native owners:

- AreaWait1403ac840..1403acf89 is internal action60. RunActions uses actionID-1
  to index table1404ad2cc; its entry59 branches1404acf5a and calls this owner at
  1404acf9d. PC DWORD89c nonzero, or familiar type3 controlled by a player, may
  wait. Area missing returns1, present returns2. Other creatures return3. There
  is no dead/dying gate. Live action dispatch is connected; cancellation uses
  the already verified shared tail.
- Area-message handler1404435a0..140443803 accepts subtype3 after the overflow
  check. Initial client stateBYTE50==1 becomes2. In server mode2 with a player
  object it sends player-list Add audiences-9/-10 then All, combining returns
  bitwise with1. A second independent mode/object gate controls placement and
  party update; pause categories1 and2 are sampled afterward. Only pause==1
  sends pause state, whose return is ignored. This decoded owner is compared
  but is **not yet connected to the application's client-load transport**.
- MovePlayerToArea140568520..140568720 resolves the canonical controlled
  creature and module/pending area. Pending native XYZ is copied before lower
  callbacks; path+24 becomes actorID. ComputeSafeLocation(range20,straight1)
  falls back to the copied point only on exact0; other results use its output.
  Destination subareas precede AddToArea(0,1). RealizeAssociateList and
  UpdateVisibleList still execute if area lookup fails; PC/possessed-familiar
  map update follows. This placement coordinator is compared, pending its
  lower PC ClientArea/automap integration.
- RealizeAssociateList14039d820..14039db3b reads the live physical associate
  list. An associate's pending area/point has priority; otherwise use the
  master's current area/position, then the master's pending area/position.
  Missing associate and area warn. One zero-initialized safe-location output
  survives the entire loop, and native search return is ignored. AddToArea,
  recursive realization, visibility and optional automap precede field58c=0,
  ClearAllActions, field54c=0 and field550=1. Do not replace this with generic
  teleport-to-master logic or allocate replacement IDs.

`ObjectLifecycleRuntime.realizeAssociates` connects the last owner to canonical
NPC area removal/addition, native placement, visibility and action clearing.
Cycles diagnose unsupported ownership rather than hang. The current local PC
scene-transition adapter invokes it on an area change. PC area-entry callbacks
are queued before NPC AddToArea callbacks. This improves actual companion
continuity while preserving the explicitly separate legacy PC adapter; it is
not a claim that the native PC send/ack protocol is already live.

## Validation

`inspect-native-player-area.py` executes unchanged native owners with captured
lower registry/cast, placement, area, visibility/automap, action-clear and packet
boundaries. **5,688** cases comprise72 wait,3,888 ack,192 player-placement and
1,536 realization observations. Tests compare ordered calls, result where
semantic, initial-entry state, path owner and associate scalar cleanup. Cases
include raw nonboolean values, subtype narrowing, repeated ack, independent
mode gates, result ANDs, exact-zero safe fallback, null/missing/live-mutated
associate lists and retained safe output. These finite observations do not
prove the captured lower owners or serialized multiplayer acceptance.

`probe-live-associate-transfer.mjs` casts an actually ready installed summon
spell, queues the real authored Follow command, then enters training/library
areas through the local PC adapter. The summon keeps canonical ID574, master565,
type4 and inventory identities. Old spatial membership is removed, destination
membership/visibility is restored, native action/scalar cleanup passes, and
PC entry precedes NPC entry. The queued wait60 gate is exercised separately.
Report:`live-associate-transfer-v3.txt/json`. Known absent `plc_w02.pwk` and
`script2.ncs` remain recorded; spell presentation/broadcast placeholders also
remain in the headless fixture. This is not an all-diagnostics-clean run.

`smoke-live-summoning-ui.cjs --check-transfer` uses actual installed spell and
right-click Follow/Stand commands, the normal area selector out/back, rendered
companion models with unchanged ID575/master565, then radial Unsummon and model
removal. `player-area-transfer-ui-v2.txt`, `live-associate-transfer-ui.json/png`
pass the transfer/render/input assertions with no browser errors. Visual
inspection confirms the returned library scene/player/associate. The image
also shows the unimplemented autosave call; lighting remains dark.

The UI fixture now records **engine failures separately from browser errors**.
It observed `DoSinglePlayerAutoSave` once on training-room entry. The omission
is persisted in the runtime log and report, not excluded or treated as success.
It needs a real save-system implementation; a no-op would not meet the goal.
This rendered check is not native PC protocol or issue-free campaign acceptance.

**1,387 tests and production build pass**: `player-area-all-tests-v2.txt`,
`player-area-build-v2.txt`. Original binary hash reverified unchanged.
Verified backup:`backups/player-area-restoration-1387-20261015.zip`, report
`backups/animations/player-area-checkpoint.txt`. The full goal remains active.

## Next dependencies and retained evidence

Native PC ClientArea sender1404cd9d0..1404ce035 is fully captured in assembly;
the decompiler truncates its loading-screen handling. Its body reads active
loading-screen table/tileset rows, writes XYZ/facing and transition flag, calls
area export140363200, then sends family4/subtype1. Do not replace it with an
invented acknowledgement or claim the current scene adapter is this protocol.

Automap research captures: UpdateAutoMap1403a7390, ReconcileAutoMapData14039dbc0,
LoadAutoMapData140397400, GetTileExplored140393270, SetTileExplored1403a4330,
SetAllTilesExplored1403a2ac0, ExploreArea14036bb40 and its DFS14036ce60. The native
area map uses an ordered area-ID list plus separate128-byte buffers; reconcile
preserves/reorders existing ownership. Indoor flags0 reveal3x3; flags1/2 use
visibility/path-node DFS. SetAll uses area BYTE348 as its byte count, not an
assumed128. LoadAutoMap reads Mod_MapNumAreas/Mod_MapDataList/Mod_MapData/
Mod_MapAreasData/Mod_MapAutoExplores; absent/empty cases need full assembly.
Constructor flag6e0 is1 for both verified LoadLocalCharacter and LoadCreatures
callers (native-player-map-constructor-callers.txt). These map owners remain
unimplemented; no fake enabled/disabled flag or map success was substituted.

First-client area activation also needs the door trap/static predicate and
other virtual type branches mapped before using native AddToArea for PCs.
Module limbo, native PC handshake, automap, save/autosave and remaining spell/
combat/campaign gates are still open.
