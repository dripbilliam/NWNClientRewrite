# Native record entries — scoped admission and ordering

`native_data/character_record_entries.gd` now implements the original character
sheet's Feats-page admission and Skills/Feats sorted insertion. This changes
record presentation only; `game_ui_rules.gd.feats()` and the authoritative
received ownership lists remain unchanged for combat and other actions.

Original `CCharPageFeats::SetData`1409c0920 follows an owned successor from a
primary feat while it is present in either primary or bonus lists, tests the low
16 bits, and admits the final valid feat once in that first pass. The secondary
pass excludes primary membership, but does not deduplicate against successor
results already admitted. For example, primary `[1]`, bonus `[2]` with1→2→3
admits `[2,2]` if3 is unowned. Both rows get separate private view entries. This
quirk is reproduced rather than silently replacing the original admission rule.

Current received `fields118` and `fields128` take precedence over earlier player
feat snapshots. Before these lists arrive, the existing player/bonus snapshots
provide the display fallback. Active physical `feat.2da` rows supply `FEAT` and
`SUCCESSOR`; missing/inactive rows are omitted. The original loader marks a feat
inactive when `GetINTEntry("Feat")` fails. Malformed owned successor cycles are
bounded and exposed in `rules.record_errors`, instead of hanging the UI. Input
IDs are normalized to16-bit integers without mutating captured/server arrays.

Original row constructors1409bfa50 and1409c0630 insert by `_stricmp`, with a
lower-bound search. The original default `_stricmp`140c9a9fc calls
`__ascii_stricmp`140c9a9bc when its locale-change flag1415d7c18 is zero. This is
byte comparison with ASCII case folding, not natural-number or Unicode locale
sorting. Thus “Skill10” sorts before “Skill2”; equal labels are inserted before
older equal labels. Native rows encode original CP1252 source bytes before the
comparison. Alternate runtime C locales are not accepted by this milestone.

Evidence and current source-pinned receipts:

- `scripts/inspect-native-record-feats.py`: complete original SetData
  instructions run unchanged in the offline mapped image for15 cases. Lookup,
  clearing and row-construction services are captured; successor/membership/
  duplicate admission execute in the original code. Cases include both native
  short-list and sentinel-based long-list searches and restored input arrays.
- `scripts/inspect-native-record-order.py`:225 original comparator cases in the
  executable's asserted default locale, including ASCII, CP1252, case ties,
  lexicographic numbers and embedded source NUL bytes. The accepted v2 fixture
  transports bytes explicitly; v1 string transport triggered Godot's NUL
  replacement diagnostic and remains retained as failed test evidence.
- Root `backups/animations/rea-native-record-entries-v1.json` retains original
  admission, GetFeat and complete feat-loader pseudocode. The separate
  `rea-native-record-order-v1.json` retains insertion/comparator code.
- `native-record-entries-v4`:250 headless oracle/projection checks.
- `native-record-order-frame-v1`:28 graphical original-frame/input checks.
- `native-record-order-rules-v1`:15 existing native rule checks.
- `native-record-order-desktop-v1`:41 existing native desktop checks.

All final receipts have unchanged source, clean native debugger teardown and
zero public connections. No current-source original-server or original-client
visual completion is claimed for this display milestone. Earlier accepted
frame/value checkpoints remain historical source snapshots.

The full record/UI goal remains open: original complete detail content and
disclosure, resize/text/page geometry, remaining row color/hover/pressed/audio
states, alternate locales, all role/server/language/scale variants and actual
original-client comparisons still need acceptance. General porting is deferred.
