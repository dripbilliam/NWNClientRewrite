# Whole-item shortcut configuration

Target: NWN:EE89.8193.37-17 x64, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra database remain read-only.

`item_quickbar.js` ports full ConfigureItem140867760..140867d02,
count14086bef0..14086c100, client wield1407fdb10..1407fdc98 and client relative
size1408012d0..1408013d0. Complete unwind-bounded captures are
native-quickbar-item-config-v1.txt and native-quickbar-item-dependencies-v1.txt;
Ghidra truncates several of these at free(NULL). Native caller captures in
native-quickbar-item-config-initialization-v1.txt confirm whole-item drop uses
packed0xff00ff/force0; restored item wrapper14086b3d0 configures primary then
secondary with force1. Item-menu selection1409a8530 uses force0.

Configuration checks controlled creature, canonical item, identified flag,
base row, cached CanUseItem unless forced, then container/equipment/properties.
Feedback97/23 leaves the prior shortcut intact. QBBehaviour1/2 scans physical
active properties for the first valid spell, defaulting to child0 only when that
parent has children; other non-equippable property-bearing items use property0
and variant255. Stored indices and icon-selection BYTE narrowing remain
distinct. Four common base types use item icons. Other spell properties use
the selected parent/child icon with item art as the secondary native icon.

Equipment pairing preserves classification, shield exceptions, cross-hand slot
tests and ordering. Client relative size deliberately does not use the server's
-10 clamp. Equipped highlight reads client25c, distinct from possessor264.
The local adapter derives equipped ownership from actual canonical equipment
membership. Count refresh uses property low WORD, actual stack INT versus its
display WORD, eight cached-use cells, unlimited '*', and intentionally omitted
callbacks. Cost1 on nonstacking equippable items explicitly enables the button
after clearing its count; the full assembly supersedes an earlier research
summary that missed that callback.

Client flag1c0 is independently traced through Name14083d8a0 and installed
TLK5548 '(Unidentified)'. Client288 is traced through readers14076bd30/14079a1e0
and senders1404c7da0/1404d8220: the server sends CanUseItem(creature,item,1) for
inventory and CanUseItem(...,0) for identified examine data. Full sender/GUI lower
captures are native-quickbar-item-config-lower-v2.txt. Its last requested
property580 leaf lacks unwind metadata, so that capture command exited1 after
the preceding owners; no complete580 claim. Equipped-owner25c leaf has an
external tail jump. Its verified blocks and clear85c240 are captured separately
in native-quickbar-item-clear-v2.txt. Failed leaf-CFG attempts remain retained;
their bounded-region rejection was not bypassed with invented function bounds.

## Integration and validation

NativeItemRuntime supplies active base/spell/property/appearance metadata and
the shared CanUseItem owner. GameUi serializes asynchronous eligibility queries,
revalidates character/session/area/item identity, commits canonical QB fields
only after acceptance, preserves a source shortcut when a drop fails, and
restores paired shortcuts. GUI state is held separately from canonical records.
Use counts refresh from shared native item state; exhausted buttons do not send
an activation request. The local authority computes usable state instead of
fabricating replication packets.

- Original execution oracle:927 configuration,1920 count,721 wield and48 size
  cases (3616 total), compared against actual original instructions. Captured
  lower boundaries: registry/metadata/2DA/property lookup, cached eligibility,
  GUI clear, icon construction/destruction, text/enabling, notification and
  equipped-owner lookup. Allocation failure and full native GUI heap/layout,
  sounds, composite-icon geometry and network serialization are not proven.
- Seven focused tests include original comparisons plus asynchronous rejection,
  stale identity/context, restore/default selection and paired canonical IDs.
  The first async fixture omitted item.objectType6, preventing the intended
  eligibility boundary from running; corrected fixture passes without changing
  production semantics. Failed output retained as item-quickbar-tests-v3.txt.
- default-item-ui-v3.txt / live-default-item-ui.json: unchanged installed wizard
  potion, whole-item DOM drag payload0xff00ff normalizes to0xff0000, count3 is
  visible, actual wheel click plus two F2 activations run input9/action46, three
  animation70/drink clips, stack3→2→1→destroyed, shortcut cleared. Console errors0,
  new runtime errors0. Prelude entry-position/startup-off fixture, native AI on;
  the known absent plc_w02.pwk remains separately recorded. Full HP means heal0;
  injured-HP healing was verified in the earlier installed item executor probe.
- item-quickbar-explicit-ui-v1.txt passes the existing explicit property wheel
  drag/F2/consumption regression. item-quickbar-reload-ui-v2.txt passes whole-item
  assignment, shortcut move, spell/feat assignment, radial, modifier rows, key
  input and full renderer reload with saved shortcut restore.
- All1617 tests pass (item-quickbar-full-tests-v4.txt), production build passes
  (item-quickbar-build-v5.txt; existing chunk-size warning).

Native GUI lower clear/icon/count/animation/notification ownership is represented
through explicit local presentation adapters, not byte-layout equivalence. The
renderer still needs complete native composite-icon geometry and animation
presentation; current equipped marker is a local CSS indication. Visual review
of live-default-item-assigned.png confirms count3 and also the existing text-only
item art: baseitems has no usable ItemIcon provider. The new adapter therefore
records ui.item-icon-unimplemented at each requested item-icon construction,
instead of silently treating an empty 2DA lookup as native item icon238.
Selected spell icons still use their actual IconResRef. Non-property
equipment/container shortcut activation remains explicitly diagnosed as
ui.item-equipment-activation-unimplemented. Scroll learning, script ActionUseItem,
rendered scroll/wand/variant/daily-item acceptance, previews and other spell
effects remain open. Spell, combat and continuous campaign completion gates
remain unfulfilled. The persistent goal stays active.
