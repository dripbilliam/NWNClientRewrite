# Spell preparation and slot editing

Target: NWN:EE89.8193.37-17, nwmain.exe SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only original image and Ghidra research; no installation or database edits.

## Original evidence

- Prepare writer1407c3870..395b sends major6/subtype16: BYTE class index,
  DWORD spell ID, BYTE physical slot, BYTE domain base level, BYTE metamagic.
  Clear1407c3960..3a24 sends6/17: BYTE class/level/slot. Full captures in
  `native-spell-preparation-writers-v1.txt`. The earlier bounded writer search
  ended at7c3000 and missed these owners; broader `.text` candidates found
  them. Earlier provisional captures include unrelated request families and
  remain research candidates, not preparation authority.
- Input owner1404531b0 prelude obtains controlled object/AsCreature, preserves
  stats and nullifies the creature for nonzero8ac before initial overflow.
  Subtype16 at1404543de..4b6 reads all five scalars, checks overflow/underflow,
  creature, GetSpell, then calls SetMemorizedSpellSlot140415c00 with ability
  check1. Subtype17 at1404544b6..535 reads three BYTEs and calls clear.
  Both return0 after processing, irrespective of setter result. No extra
  commandable/dead/known/possession gate is added. Full input ASM and jump-table
  captures identify branch owners; duplicated group-input support44f720 is
  separately captured and not claimed as a complete port.
- Stats clear1403f1fc0..2069 warns/rechecks invalid class; ClassInfo
  clear1403f2070..210a warns on level>=10, compares BYTE slot against INT
  physical count, nulls the selected pointer before sized delete16. Count,
  allocation and other records survive. Full cleanup/tail delete captured.
- Widget setter1409c2630..286d calls clear(send0), writes spell/metadata,
  reconstructs GUI resources, and when requested calls prepare at1409c27d2.
  Domain request is widget level minus active metamagic cost with BYTE wrap.
  Widget clear1409c1fc0..20c3 destroys both owned GUI resources, sends clear
  at1409c204d only when requested, and plays erase sound. Native GUI heap,
  icons/tints/sound calls are presentation boundaries in this continuation.
- Full drop owner1409c21d0..2336 (four contiguous unwind fragments) checks
  event bits, source FourCC SpBx, destination kind0, distinct widgets and
  identical level. Prepared-to-prepared exchanges the displaced spell first;
  known source copies. The source domain flag is retained for both setter
  calls, including the displaced record. Both edited ready fields become0.
  Full captures `native-spell-preparation-ui-callers-v1.txt`,
  `native-spell-preparation-drop-callback-v1.txt`; other caller captures map
  list construction/update and first-empty selection.
- GetNextTreebuttonSpellID14088ddb0..e157: restricted classes enumerate known
  count as WORD and index getter as BYTE, filter active metamagic mask;
  unrestricted classes check raw client class level against MinCastingLevel,
  scan physical spells for matching class level, then distinct domain spells.
  Duplicates are suppressed between domains only. Missing controlled actor
  leaves output-domain unchanged. Client level1407f1080 is a verified closed
  leaf CFG, returns0 for index>=8 and otherwise reads raw BYTE class level.
  Missing optional MinCastingLevel and invalid domain storage remain explicit
  failures rather than invented defaults.

## Implementation and validation

`spell_preparation.js` ports decoded input branches, drop policy, domain
request conversion and list iterator. `spell_book.js` adds native clear beside
the previously validated setter; the setter still creates no extra slots and
leaves new spells unready. SpellBookRuntime shares live rules/pools, and
ModuleSession queues canonical actor/area-bound requests. Actor replacement,
area change and session closure discard stale local requests; this is local
input lifetime policy, not an invented network field or success reply.

The Prepare tab presents one active class, owned metamagic choices, available
class/domain spells and physical empty/occupied slots. DOM drag/drop uses the
native exchange/copy policy and queues both exchange writes before awaiting
authority. It rechecks current source and destination, actor, area, session
epoch and cutscene state. Double-click clears through the same queued input.
Canonical pools are not changed optimistically; edited spells require rest.
This is a web UI projection, not a full native CPanelSpellbook heap/layout port.

`inspect-native-spell-preparation.py` executes unchanged original routines in
isolation, capturing external dependencies. `native-spell-preparation-
observations.json`:384 clear,194 input,1536 drop,3459 iterator executions =
5573 comparisons. `spell-preparation-native.test.js` matches ordered calls,
return values, widths, deletion, slot retention, exchange metadata, cursors
and domain outputs. Additional tests cover request conversion and stale queues.
Full1631 tests pass (`spell-preparation-full-tests-v2.txt`); buildv2 passes with
the existing bundle-size warning.

Installed probev2 learns an active-data-selected stock scroll through the
shared acquisition/learning owners, observes it as a new preparation source,
clears/reprepares it unready, preserves slot length/capacity, and proves an
out-of-range request does not grow slots. Installed cleric/druid/paladin/ranger
sources use unrestricted class data; cleric domain preparation reaches the
shared setter and remains unready/domain1. Startup/general AI isolated here.

Rendered testv3 uses unchanged installed wizard, startup/entry fixture and
native AI enabled: real Prepare tab, DOM copy, exchange, clear, owned Empower
selection and metamagic preparation through canonical queues. Browser errors
and new error-severity diagnostics0. Complete diagnostics retain existing
trap/frame-stat/corpse/presentation warnings. `live-spell-preparation-ui.json`
and screenshot visually inspected. UIv1 failed because the diagnostic snapshot
was read before its first refresh; corrected fixture waits for it. The v1
failure log remains retained. No gameplay success was inferred from a timeout.

## Remaining gates

Rest request6/13 and full AIActionRest42 lifecycle, cancellation, enemy/area
admission, event timing, healing, effect/feat/item/spell restoration, script
ActionRest/ForceRest and UI wiring remain next. Do not substitute instant ready
flags. Rest14039f360 and AIActionRest1403ca890 full original ASM is already
captured; decompiler output truncates at free(NULL). Learn -> prepare -> rest
-> cast, rendered divine/domain preparation, save/reload, protocol, native
feedback/artwork and broader spell/combat/campaign gates are not completed by
these tests. Goal remains ACTIVE.
