# Dynamic replication and area readiness

Target: unchanged installed NWN:EE89.8193.37-17 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No native server/client patches, injected code, Ghidra edits or local gameplay
simulation. This is a protocol/store milestone; renderer input and concurrent
original-client gameplay have not been demonstrated.

## Native owners and evidence

- Area handler1404435a0 accepts lowercase p/4/3 with no body, advances player
  load state1->2 and calls MovePlayerToArea. Module-ready p/3/2 alone only
  initiates module/area transfer. The probe now sends area-ready after importing
  each ClientArea, permitting the server to publish the controlled character.
  `rea-network-area-ready-handler.json` records the complete handler.
- SendServerToPlayerGameObjUpdate1404d9140 emits P/5/1 containing a record stream,
  not one object. CreateNewLastUpdateObject1404cbb70 writes A records;
  UpdateAppearance1404ea6c0 writes P; UpdateObject1404eb590 writes U;
  visibility/departure owners write D; work progress uses W.
- ObjectVisualTransformData::Write140596760 calls596610/596980: two keyed map
  passes, identity optimization, ten interpolation channels and native build
  gates. Native CreateNewLastUpdateObject creature coordinates are full FLOATs;
  U position uses scale100/16bit XY and range[-20,320]/18bit Z. These cannot share
  an assumed generic position layout.
- AddItemAppearanceToMessage1404c8170, AddActiveItemPropertiesToMessage1404c7da0,
  AddPlaceableAppearanceToMessage1404c8490 and inventory-slot writers define the
  nested appearance/equipment records. ModelType comes from the resolved module's
  baseitems table; no item/spell/module-specific decoder selection.
- CNWRules::LoadClassInfo1402a4a90 reads PickDomains/PickSchool into4f4/4f8 on
  successful INT lookup. InitLegacyClassDefaults1402a4350 supplies Cleric2 and
  Wizard10 fallbacks when those cells are absent; explicit 2DA values override.
  CLoopingVisualEffect::GetIsBeam1404954f0 tests exact Type_FD strings B/P from
  the visualeffects table. The decoder loads these table-driven wire-shape inputs
  through the module resource resolver, without a ModuleSession.
- PlayerList_All1404de710/Add1404de300/Delete1404dec20 carry explicit PLAYER_ID
  and full client OBJECT_ID. P/18/11 is a CC feedback message, not a player-ID
  assignment: SendServerToPlayerCCMessage1404cf090 case11 starts with a WORD
  feedback type. Candidate call-site byte search alone was not semantic proof;
  the containing native procedure resolved the question.
- CHAR1402dacb0/1402d98d0 and SHORT1402db790/1402da110 have distinct native type
  tags and destination-width negative-zero normalization. New reader methods
  preserve those widths, including the AL/AX return ABI in isolated fixtures.

REA results are retained in `backups/animations/rea-network-*`; long object and
appearance pseudocode also has bounded-view/continued evidence. The capped
UpdateObject result is complete retained evidence, read in two pages, not an
incomplete-function claim. The class-loader first40k page contains the relevant
PickDomains/PickSchool stores; the remaining loader is not claimed implemented.

## Implemented behavior and validation

`network_object_updates.js` decodes creation, appearance, updates, deletion
notifications and work markers, including nested item/visual-transform state.
Unknown records stop at their boundary and return a diagnosed verified prefix;
there is no length field that would permit skipping unknown records safely.
Malformed known records fail before committing their message. Unclassified
fields retain native offset names. Looping effects remain change notifications,
not locally computed spells or invented uint64 effect IDs.

`NetworkWorld` keeps explicit server IDs, stable proxy identity, sparse body-part
and equipment merges, separate player/control maps and transactional object
batches. Effects/deletion events are exposed for presentation ownership. Full
native deletion cleanup semantics remain open: deleted visuals are flagged and
the native flag is retained; unknown cleanup behavior is not guessed.

Validation completed:

- 160 original CHAR/SHORT writer-reader cases in both formats, including reduced
  widths and negative-zero.
- 48 original UpdateObject writer executions, masks0..7/type9, with original
  scalar/ranged-float readers recovering exactly the replacement's values.
  GetGameObject/non-creature virtual cast and raw ID cursor are captured fixture
  boundaries. This is positional/orientation/animation evidence, not a native
  oracle for every U flag or gameplay system.
- Real v4 capture fully decodes the925-byte initial NPC/door/placeable update and
  subsequent159-byte effect update. Real v5 adds controlled-player creation,
  appearance, class/stat and effect records after area-ready.
- Fresh `local-network-character-v5.json`:60 received frames,33 registered proxies,
  explicit player0 -> object0xffffffff, native wizard class10 at server position
  [6,3], native NPC equipment IDs preserved, clean BNDM logout. Server independently
  logged join23:44:26/leave23:44:42. No decompression, malformed-message or import
  failures. Historical log display “Player1” is not the wire PLAYER_ID.
- Every truncation of a fully supported real P/5/1 packet rejected; conflicts in
  a later object record leave prior proxies untouched. Repeated/sparse updates
  retain proxy identity. Synthetic alternate 2DA entries verify table-controlled
  shape and native fallback precedence.
- 47 focused network/scalar tests PASS; client build PASS with the existing bundle
  size warning. Logs `network-object-tests-v1.txt` / `network-object-build-v1.txt`.
- Full-credential audit:1997 source/evidence/script/test and selected network
  capture text files, zero occurrences. Private identity input was never stored.

## Open requirements

The current stream still reaches unimplemented I player-state/GUI records;
their prefixes are retained and their boundaries diagnosed. Other GUI/inventory
record families, native request codecs, renderer/UI ownership, movement,
transitions and shared combat/casting remain open. The app has not been switched
to this network world yet. All authorized local protocol probes use original
server authority, but there has been no original-client concurrency validation.
The complete multiplayer goal remains ACTIVE.

Post-seal checkpoint: `backups/multiplayer-object-replication-20261017-v1.zip`,
11944 files/194123882 bytes, every archived length/SHA256 verified. Writer26954
exited0; all15 selected source/oracle/evidence/capture entries present, excluded
executable/object/BIC/module/credential-profile artifacts absent. Final five
object tests also passed after the unknown-deletion notification adjustment
(`network-object-final-tests-v1.txt`). Current unhandled game envelopes remain
18/11,2/12,18/20,52/3,28/12,9/5,54/2,30/1 in the fresh v5 run; I boundaries are
separately logged. This note and list formatting were added after sealing.
