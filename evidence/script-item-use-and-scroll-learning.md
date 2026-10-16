# Scripted item use and scroll learning

Target: NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original game files and Ghidra database were read-only throughout.

## Script item commands

`script_use_item.js` ports complete ExecuteCommandActionUseItem14050f190..14050f471,
shared by installed API910 ActionUseItemOnObject and911 ActionUseItemAtLocation.
The complete unwind-bounded capture is casting-location-effect-command-asm-v1.txt
(requested14050f310 lies inside this owner). Both are real typed VM bindings in
ModuleSession and share NativeItemRuntime.use / UseItem1403a9f70 and action46.

The owner pops item OBJECT_ID, itemproperty structure, target object/location,
subproperty INT and consumption INT. Pop failure returns-639; the local VM
adapter preserves its actual typed error and engine context. The active-property
pool is scanned by uint64 property ID against the structure's propertyId+f0,
without an effect-type/property-type gate. The returned effect handle ID is a
different identity. Index and variant narrow to BYTE; consumption remains INT.
The first physical match wins. No matching property is a normal no-op.

Object commands pass target ID with a zero point. Location commands pass INVALID
target and copy XYZ, while area comes from the ACTOR's current area, ignoring the
location area field. Missing actor area passes INVALID. UseItem's return value is
ignored; this wrapper returns0. Structure scope cleanup is location then property
on all exits after successful property pop. Decoded local structures are JS-owned
copies; release does not mutate canonical item/effect/property storage. Native
scope destructor/deleter ordering is compared with captured allocator boundaries,
not claimed to reproduce native heap ownership.

- inspect-native-script-use-item.py / native-script-use-item-observations.json:
  591 original executions. Includes pop failures, missing objects, empty/negative
  counts, high uint64 property IDs, duplicate IDs, physical indices254..259,
  variant narrowing, raw consumption, missing area and rejected lower UseItem.
- installed-script-item-use-v2.json: unchanged installed wizard/potion, actual
  typed GetFirstItemProperty612 then ActionUseItem910/911. Player565/item570,
  effect ID76 versus property ID52 (hex); wrong upper property-ID bits queue
  nothing. Object consume0 heals67→77 while stack stays3; consume1 heals and
  decrements3→2. Location command consumes2→1 with INVALID target and no healing,
  then object use heals57→77 and immediate scheduled consumption destruction
  removes the final item. All four casts execute real action46/animation70 and
  authored impacts; class/innate pools and canonical actor ID remain unchanged.
  Script result is void; lower queue rejection never becomes a script result.
  Startup/general AI are disabled for this isolated probe, not campaign proof.

## Scroll learning

`scroll_learning.js` ports complete CNWSCreature::LearnScroll140396b80..140397040.
Ghidra incorrectly truncates it at free(NULL); full assembly is authoritative in
native-scroll-learning-authority-v1.txt. Item-menu callback1409a81e0 and writer
1407c0ee0 establish major12/subtype13 inventory traffic. Full server inventory
handler140455f50 subtype13 reads an object ID and calls LearnScroll before sending
reply14 REGARDLESS of learning success. Client inventory handler14079f150 reply14
refreshes the item widget and clears its pending240 flag if the item still exists.
The shared refresh owner is14076b760, a GUI/equipment/repository traversal, not an
item-field packet reader. These selected message branches are ported; the other
inventory message subtypes are not completion claims.

Research corrections remain visible in the captures: initial input/GUI-event
candidates4531b0/451b30 were wrong families; the writer and actual LearnScroll
caller at456c41 establish inventory455f50. Field240 candidates770640 and7b0de0
belong to other pending operations. Actual reply14 is79f150; no semantics were
assigned from an offset match alone. Correct type constants5/6 are read from
140dc2a44/45. Earlier miscomputed data addresses are retained as failed evidence.

Learning requires base75 and first physical active property, whose subtype maps
through active iprp_spells SpellIndex. It does not filter that property's type,
check identified, or invoke generic CanUseItem. Repository admission uses the
direct owner creature or one actor-owned bag and the shared membership owner.
Missing/null repository storage remains explicit rather than fabricating it.
Each physical class with LearnScroll is checked independently through active
spell level, native spell gain and minimum ability, school/opposition and known
spells. Error precedence, WORD known count versus BYTE known index, and duplicate
handling are preserved. All eligible classes learn before one scroll is consumed.
Successful stack>1 decrements directly; the last scroll invokes RemoveItem with
1,1,0,1 then the actual immediate item destructor. Success feedback222 carries the
spell ID; rejection codes retain their native values. Plot/identified/charge
flags are not new learning gates.

The runtime shares existing active-data spellbook rules and canonical known
pools, acquisition/removal/destruction and feedback. No class ID, spell ID, item
template or campaign name is hardcoded in gameplay behavior. Client pending state
is a separately named local item-menu projection. Item removal preserves native
IDs and clears canonical quickbar references through the existing removal owner.
The local decoded reply does not invent a transport PLAYER_ID or substitute the
creature OBJECT_ID for one; original packet codecs/sending remain separate.

Inventory right-click Learn now queues the real learning request and updates the
existing spellbook. Busy items reject opening/reusing their menu until reply.
Local queue cancellation/control/area changes release pending state without
executing learning; this is a local input cancellation policy, not a reconstructed
network disconnect protocol. The first rendered run found target.areaId was
INVALID for carried items; the learning entry now captures actor.areaId. No
campaign/tag/coordinate exception was added.

- native-scroll-learning-observations.json:893 LearnScroll,4 menu,24 input13 and
  96 reply14 executions =1017. Registry/repository, table/class/spellbook queries,
  AddKnown, item removal/destructor, allocation, feedback and GUI widget refresh
  are captured boundaries. Tests compare actual selected original instructions,
  call/error order, multiclass/duplicate behavior, stack, result and pending state.
  Combined with the item commands:1608 new original executions.
- installed-scroll-learning-v3.json: untouched installed wizard, stock scroll
  templates selected using live class/spell/school/known data and created through
  shared native acquisition in the owned fixture. Endure Elements50 (subtype98)
  learns, stack2→1; duplicate rejects221, stack1 stays1 and pending clears; newly
  learned Protection from Alignment321 (subtype284), stack1, is immediately
  removed from registry/inventory/repository. Feedback222 carries each spell ID.
  All ACKs are1, independent of learning result1/0/1. No transport ID was invented.
  A retained JS reference to the destroyed item still has pending1, as native
  reply lookup cannot find that deleted object. It is not a live pending item.
  Startup/AI and module acquire/lost events are isolated in this CLI probe.
- live-scroll-learning-ui.json / scroll-learning-ui-v5.txt: same two stock UTIs
  added only to an owned in-memory BIC, actual inventory wheel click, canonical
  queue, duplicate rejection, consumption/destruction and known-spell entries
  each appearing once in the visible Spellbook. Native AI stays enabled. Known
  combat/trap/dirty-stat/corpse/overflow/feedback-presentation warnings remain
  recorded; no console errors or new error-severity failures. Missing PWK stays
  recorded wherever encountered; this run is not a clean campaign/area pass.
  live-scroll-learning-wheel.png shows Learn and the active use entry; book.png
  shows both newly learned spell names after scrolling them into view.
- scroll-learning-ui-v1.txt / scroll-learning-ui-v1-failed.png retain the area-ID
  regression. v2 behavior passed, but offscreen capture returned an earlier frame;
  v2 JSON/stale screenshots remain labeled separately. Final captures wait two
  animation frames and are visually inspected. DOM assertions alone were not
  presented as proof that those earlier captures showed the correct state.
- All1625 tests pass (script-scroll-full-tests-v3.txt), production build passes
  (script-scroll-build-v3.txt, existing chunk warning). Auditv34 remains88 unbound
  names/22 missing NCS: the scanned authored impact corpus does not use910/911.
  Binding presence alone is not implementation or completion evidence.
- script-scroll-potion-regression-v1.txt also passes the existing whole-item
  drag/wheel/F2/drink/stack-exhaustion/shortcut-removal rendered workflow after
  adding the scroll pending guard and learning dispatch.

## Remaining work

Spell preparation/memorization UI must support newly learned spells through
native admission and rest, beyond displaying/casting existing stored slots.
Item artwork, native feedback presentation, previews/release/projectile visuals,
rendered scroll/wand/variant/daily casting and other effect/API gaps remain open.
Native GUI heap/composite layout, full packet transport, save/reload, combat and
continuous campaign completion are not claimed. The persistent goal stays active.
