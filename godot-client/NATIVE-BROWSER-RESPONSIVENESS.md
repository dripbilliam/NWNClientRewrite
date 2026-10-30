# Server browser input and integer text

The native list previously destroyed and recreated every row and all six labels
on each `set_view`. `refresh_entry` could call it multiple times for the same
presentation, including the local busy/acknowledgment transition of a simple
selection. The controller also rebuilt its hidden prototype Tree. That added
local allocation, font/style binding and layout work while input was pending.
The reported live session has no detailed browser timing capture; this identifies
concrete avoidable work rather than claiming every delay has been measured.

The list now retains its row controls and labels. A page updates one shared
input context when its view changes, preserving current canonical entry IDs and
revision/scope guards without reconnecting signals. Changed row records update
their text/color/selection; unchanged records are skipped. Removed rows retire,
new rows allocate only on growth, and highlights are retained after first use.
Repeated identical views are skipped, but dismiss/reopen revisions force context
refresh so old captures cannot become current input. The hidden prototype list
is not rebuilt alongside a ready native page.

The source rows still wait for the local authoritative browser-service reply.
Double-click activation still requires its exact selection acknowledgment,
password handling stays scoped, and stale/modal/retired input remains rejected.
This does not change network discovery/query behavior or fabricate server data.

Godot's JSON decoder supplies numeric protocol fields as floats. Direct `str`
and `%s` formatting had exposed `.0` in ports, player counts, levels, PvP values,
page totals and fallback ping text. `native_data/browser_numbers.gd` now supplies
integer/unknown and endpoint formatting. Browser rows, tooltips, fallback text
and endpoint identity use it. The older lobby endpoint status also casts its
port. Real version strings and textual descriptions are not modified.

## Diagnostics and local validation

The native browser snapshot records view-update count, duplicate views skipped,
row nodes created, dirty row updates and cumulative presentation CPU microseconds.
These measure event-driven presentation work; they are not frame-rate, GPU or
server-response measurements.

Current `native-browser-responsive-` receipts:

- `retention-v1`:16 checks with128 rows and actual native pointer input. Thirty
  changing selection/status views retain all row/label instances; only changed
  rows update. The test covers real JSON float formatting, hidden-list avoidance,
  canonical input after sorting, stale captures, shrink/reopen and fallback text.
- `pages-v1`:32 original page, header, wheel, modal, favorite and action checks.
- `activation-v1`:24 selection acknowledgment, double-click/password/join guards.
- `keyboard-v1`:15 original list focus, cursor and scroll/retirement checks.
- `details-v1`:31 original details/query/modal/cancellation checks.
- `filters-v1`:23 original filter input and scope checks.

These total141 native UI checks with authored replies and no public connection.
`startup-v1` separately runs the complete Main Menu startup check. The auditor
`tools/audit-native-browser-responsiveness.mjs` checks current source hashes and
the rollback manifest. Live responsiveness of the updated build still requires
the user's next manual test; complete browser/UI parity remains unfinished.

An older pages fixture clicked Multiplayer after layout parsing but before the
entry artwork became visible, then accessed rows from a page it never opened.
Its failed run was stopped without touching the manual client. The fixture now
waits for the actual visible entry readiness and keeps all original32 checks;
the final run passes. Intermediate retention receipts precede the final dirty-row
update path and are historical.
