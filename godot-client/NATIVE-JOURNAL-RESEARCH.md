# Original journal reconstruction — historical data plan

The [native frame milestone](NATIVE-JOURNAL-FRAME.md) now replaces the generic
window and adds retained record state, timestamps and persistent editable
notes. This document retains the earlier data/research plan and its open work
as historical evidence. Its plan-only receipts are not full UI acceptance.
General porting remains deferred under [the active goal](NATIVE-UI-PARITY-GOAL.md).

## Verified original structure

`CJournalPanel` constructor883610 loads `JNL_PANEL`. Initialization8853e0 creates
exactly three linked page tabs using `CTL_JNL_BTN_TAB`, `CTL_JNL_BTN_TAB2` and
`CTL_JNL_BTN_TAB3`, with tooltip TLK refs0xf809/0xf80b/0xf80a. Page factory884b40
routes0 to `CActiveQuestPage`,1 to `CDoneQuestPage`,2 to `CNotesPage`. The notes
page focuses an editable text box. The current generic fourth Messages tab is
not part of this recovered original panel.

Quest pages load `JNL_PAGE_QUEST`/`PNL_JNL_PAGE1`. Native metadata gives:

| Element | Original logical geometry |
| --- | --- |
| Main header |360×58|
| Full header/page |360×460|
| Page origin |0,58|
| Tab origins |0/119/239 atY58, using each model's next hook|
| Quest viewport |1,89 with342×370 extent|
| Linked quest tree |6,89|
| Quest row |`CTL_JNL_QUESTBTN`, nextlink0,40, title hook41,21|
| Personal notes |`edit_jnl_348x408` bottom attached at0,460|
| Notes text |6,63 with333×396 extent|

DateRadio, NameRadio and PriorityRadio come from the original GUI. Their
embedded labels use Galahad14/TLK6325,154,6326 respectively. The original panel
title and close control also come from the GUI, not replacement spacing. The
source row is a checkbox-style expanding quest button, not a generic heading
followed by an always-visible description. Opening a row inserts its own
`CTL_JNL_ENTRYTXT` model into the linked list; closing removes that list entry.

Expanded text885b50 includes the original translated world timestamp, a
separator and received description. Its measured string height is assigned
separately. The `textheight` animation time is float32 `min(pixelHeight,1536)/30`;
the nextlink moves by that capped height plus20. Both original text hooks have
the sameY: measuring their difference cannot supply text height. The native
plan keeps measured text height separate from the capped artwork/linkage.
Timestamp translation, exact line measurement and original rendering/input
still need integration and comparison.

The original keeps expansion/read flags in local presentation records. It
clears the encouraged state when a received row is opened. Local expansion and
sort changes do not send invented journal updates to the server. Original
window open/close sends operations10/11; the existing compatible transport is
`native-panel`/`journalWindowRequest`.

## Data, ordering and notes ownership

Manager7d4ec0 divides journal records using `completed` at offset0x44. It does
not use the `isQuest` notification flag to make personal notes. The current
desktop's non-quest-to-Notes filter must be replaced when the native journal
is connected. Preserve stable record/tag identity, received title, description,
date, time, priority, picture and completion; its current projection drops most
of those fields. Original array movement/index tie behavior across updates
still requires a native state owner, beyond the pure ordering plan below.

The Date/Name/Priority callbacks select0/1/2. The recovered index sort7d6cd0
uses selection exchanges; equal-key ordering is not generally a stable sort.
Date compares unsigned day/time with the actual world-timer day length and
returns-2 for an out-of-range time; newer valid dates sort first. Name uses
case-sensitive unsigned legacy bytes, ascending, after localized-title
resolution. Preserve the resolved raw title for sorting rather than stripping
its inline color controls first. Priority sorts ascending unsigned priority,
then date. These unusual details are verified against original instructions.

Personal notes885500/8861b0 are an editable local text file, never a server
quest/category. The original derives the filename from the character's first
and last names, strips characters and truncates, and uses TXT type10 in
LOCALVAULT or DMVAULT. The native port needs persistent character/DM identity,
load/edit/save on page/session retirement, original-styled scrolling, focused
typing and failure feedback. Keep tests' files isolated and preserve the user's
original profiles/notes; no original note file has been changed by this work.
The precise filename sanitization/truncation edge cases remain to recover.

World-journal protocol1/2 feeds a separate manager6ac310 via7d5700/7d58a0;
quest protocol6 feeds manager6ac200 via7d4ec0. `JNL_PAGE_WORLD` and
`JNL_WLD_DM_NEW` resources exist, but their complete runtime reachability and
role-specific controls are unproven. A named-string search found no defined
`JNL_PAGE_WORLD` literal, which does not prove the surface is absent. Do not
silently discard received world messages or assume the generic fourth tab is
an original control. Recover their proper route, or keep a clearly unique
native-styled auxiliary interface if original compatibility needs it.

## Authored native plan and evidence

`systems/native_data/journal_layout.gd` parses active original GUI/model
resources into panel, title, close, tabs, sort controls, quest viewport/tree/bar
and personal-notes attachments. Its expanded description helper samples
original transform/vertex tracks, without stretching screenshots. No original
art/text is copied into source. Missing required controls return an error.

`systems/native_data/journal_order.gd` reproduces original comparator and index
exchange policy without mutating received records. It is not yet connected to
the visible generic journal. The future owner must avoid sorting/rebuilding
unchanged data each frame; wide-list timing and update identity remain open.

Read-only research is retained at workspace root:

- `backups/animations/rea-native-journal-research-v1.json`: constructor, page,
  protocol, manager, notes-file and comparator dossiers plus vtable/callback
  observations, all tied to original client SHA
  `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
- `scripts/inspect-native-journal-order.py`: unchanged original sort/comparator/
  timer instructions in the established isolated emulator. Localized title
  resolution and free calls are captured boundaries using authored CP1252
  strings; this is not a live localization/UI proof.
- `backups/animations/native-journal-order-observations-v1.json`:312 original
  index-order observations across Date/Name/Priority, input permutations,
  unsigned priority/date limits, CP1252 titles, ties and invalid times.

`reports/native-journal-model-geometry-v1.json` records10 original resource
hashes/hooks/animations. `native-journal-layout-v4` passes339 headless checks
under armed native exception monitoring, unchanged source and no engine errors.
Earlier v2/v3 failures remain retained: they incorrectly expected animated text
hook separation to provide height. The corrected plan follows885b50's explicit
string-height assignment instead. No live UI, authoritative journal action,
font/pixel/input, notes persistence, role or complete journal acceptance is
claimed. Public connections0.

The read-only `tools/audit-native-journal-layout.mjs` verifies the receipt,
oracle/research/resource hashes and rollback
`backups/native-journal-plan-v1.zip`. This checkpoint is a data/research step;
the previous conversation milestone remains historical scoped evidence.

## Next implementation and completion work

1. Add the native journal presentation owner with these actual three pages,
   title/close/tabs, sort radio controls, original linked checkbox rows,
   independently expanding entries and original scrollbars.
2. Replace the generic projection/filter with record identity and received
   metadata, original ordering and retained expansion/read/sort/scroll state.
   Preserve server outcomes and original open/close requests.
3. Implement editable persistent personal notes under isolated native storage,
   character/DM identity, focus/scroll/caret handling and flush/retirement.
4. Recover world timestamp formatting, world-message routing and role-specific
   add/delete actions; do not invent server completion or silently lose data.
5. Verify real original local-server add/update/complete/remove journal events,
   original native input/artwork at supported scales, simultaneous-window
   movement/focus/persistence, and direct original-client comparison.
6. Complete the full control/state/role audit; these plans/tests alone cannot
   mark the journal or overall UI goal finished.
