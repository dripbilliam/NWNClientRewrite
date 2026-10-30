# Native journal frame — scoped milestone

The generic journal is replaced by the original 360×460 panel, three page
tabs, title/close control, Date/Name/Priority radios, expandable quest rows,
Galahad14 font, text-height artwork poses and original scrollbars. Both active
and completed records retain their received identity and metadata. The
[earlier reconstruction](NATIVE-JOURNAL-RESEARCH.md) records the original
resources and unchanged-code ordering observations.

`native_journal_frame.gd` owns presentation, `journal_state.gd` owns local
expansion/read/sort state, and `journal_notes.gd` persists editable Personal
Notes under the replacement profile. Sorting and expanding issue no gameplay
commands. Opening/closing still uses the actual original-compatible window
operation; the server owns quest addition, updates, completion and removal.
An ordinary received record is never relabeled as a personal note. The
transport's historical `isQuest` field corresponds to native unread/attention
state, not a separate Notes category.

Original timestamp formatter 140597a70 supplies the policy for day/month/year,
hour/minute and unsigned limits, using the received module minutes-per-hour.
Expanded entries retain its timestamp, two-newline separator and rich text.
The state test compares 160 unchanged original formatter observations. Existing
ordering checks compare 312 original selection-sort/index observations.

Personal notes support real native text input, long-content scrolling,
Ctrl-End/caret visibility, delayed persistence and a final capture on closing,
changing identity/page or retiring the owner. Character name plus DM state
selects an isolated profile file. Atomic replacement, write failures, retained
drafts and later recovery are tested. Original NWN notes are not overwritten;
importing its sanitized LOCALVAULT/DMVAULT filenames remains open.

Received world messages retain a separate, source-styled **Messages** utility.
It is a replacement-only entry, not an invented fourth original journal tab.
Its button alone occupies input space outside the original 360×460 window.
The larger visual extent is used only to keep that button on screen when
dragging. Original world/DM journal creation, editing and deletion are not yet
claimed as equivalent.

## Simultaneous-window composition

Review of the real local-server screenshot found lower character-sheet text
showing through the translucent journal. `native_window_layers.gd` now clips
covered lower native UI while leaving the world visible through source alpha.
Actual canvas order, dragging, visibility, desktop scaling and explicit
out-of-panel utility rectangles update coverage. New controls inherit their
window's material; removing/retiring owners restores original material state.
An unchanged desktop does not republish shader uniforms or scan descendants.

Original research in `../backups/animations/rea-native-window-order-v1.json`
shows `CGuiMan::UpdateAndRender` scene ordering, `CGuiPanel` first/last ordering,
and `Camera::RenderScene` sharing GUI depth after its first GUI clear. The
rectangular Godot coverage approach is an implementation inference, not a
proven reproduction of every original per-mesh alpha/depth case. Its scope is
ordinary windows in the native desktop canvas. Separate NUI/tooltip canvases,
custom shader subtrees, irregular source holes, rotated controls and over32
covering rectangles remain outside this acceptance. Overflow/custom roots are
reported, rather than silently counted as parity.

The isolated composition fixture first detects the old bleed, then compares
the front window against a world-only reference pixel for pixel. It also
checks hiding, reordering, movement,125% scale, late text, explicit utilities,
idle uniform publication and ownership retirement. The original-resource
journal test separately compares a full360×460 journal with and without an
actual native character sheet behind it. Both pass. Visual review includes the
actual-server journal screenshot, not only a synthetic panel.

## Evidence and rollback

`tools/audit-native-journal-frame.mjs` verifies current source hashes, debugger
receipts, original observations, fixture identities, failure history and the
read-back-verified `backups/native-journal-frame-v1.zip` checkpoint. Its report
is `reports/native-journal-frame-acceptance-v1.json`. The scoped checks total
2,489; they are not a percentage of journal or whole-UI completion.

The original owned server at127.0.0.1:5125 passes17 journal checks using the
authored `GodotJournal2` fixture, including actual replication, JRL text,
expansion, completion/removal and server chat feedback. A separate standard
run passes116 existing gameplay actions. Other native suites cover journal
resource/order/state/input, fonts, party/health, resizing, quickbars,
conversations, spell preparation, retirement and playability. Exception traps
are armed, normal heap is used, source remains unchanged during each test,
and no engine/lifetime errors or public connections occur. No physical mouse
movement, activation or original/manual-client shutdown is used.

Failed early inputs, the incorrect first JRL End field (BYTE rather than
WORD), and the first composition fixture's Container-managed footer are
retained. The pre-layering candidate checkpoint remains available. The
historical intermittent blood-pixel test failure remains a separate open
issue; this passing standard run does not resolve it.

## Remaining completion work

Direct original-client visual/input comparison, exact large-font/localization
and long-title/rich-description sizing, native notes filename compatibility,
world-message/DM actions, all role/disclosure/transition variants and broader
window coverage are still unaccepted. The active
[complete UI parity goal](NATIVE-UI-PARITY-GOAL.md) remains incomplete. General
porting stays deferred; this checkpoint accepts only the documented journal
implementation and local checks.
