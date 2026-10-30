# Native server-browser filters — partial browser migration

Later [native server-page work](NATIVE-SERVER-PAGES.md) replaces the main-flow
generic page frames and connects these filters over the original list owner.
That follow-up still leaves complete browser and UI parity unfinished.

`serverlist_filt` now opens through the native browser's Filters action. The
original frame, four nested labels, two checks, module edit and OK/Cancel/X use
source GUI/model attachments and installed bitmap fonts. The surrounding server
list remains generic. This is not acceptance of the entire browser or full UI.

## Original behavior

Read-only dossiers: `../backups/animations/rea-native-server-browser-filters-v1.json`.
Original client SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

- Internet page8c2460 binds Filters to8ce640, which activates `CFilterPanel`
  with `SERVERLIST_FILT`. Its initializer8d28e0 imports OK8d0b10,
  Cancel/X8cdda0, HavePeopleBox, NotFullBox and ModuleEdit. Nested labels must
  retain their parent offsets; copying only top-level controls omits them.
- Initialization8d5210 reads saved hide-empty, hide-full and module-name values.
  OK calls8db330 to persist all three and updates game filters while preserving
  the low three password/vault bits. Cancel/X only dismiss the owner.
- Modern Internet row callback8c6c20 rejects zero players for bit8 and equal
  players/capacity for bit16. It searches module text with CExoString::Find for
  bit1024, which is literal and case-sensitive. A count above capacity is not
  excluded merely by the equal-count full predicate; zero/zero is excluded.
- An older enumeration predicate8cbea0 differs in module comparison. Its behavior
  is retained as separate evidence, not silently substituted for the inspected
  modern Internet callback. Ping-filter bits are outside this implementation.

`scripts/inspect-native-server-filters.py` executes unchanged original modern
row-filter branches, GetGameFilters, Find and its substring routine in an isolated
emulator. App lookup, allocation/free, string ownership and byte copies are
captured helper boundaries; it stops before GUI row construction. The resulting
`native-server-filter-observations-v1.json` has4,480 independent instruction
observations across all low password/vault combinations, occupancy combinations,
literal/case/partial/CP1252 module strings and boundary counts. The service's row
predicate matches every case. This proves neither the original window's pixels
nor the legacy callback, ping filters or incomplete advertisement behavior.

## Native ownership and backend

Godot owns the filter window, native controls, draft, scoped OK and modal input.
Cancel, X, Escape, session replacement and superseding views retire the draft
without sending a save. A held old OK cannot submit into a later view. Backend
busy state prevents a second draft; storage refusal is shown through the source
OK notice rather than reporting a successful save. The current connection and
view handle gate every submitted preference.

The existing browser service validates the three fields, commits settings through
the existing atomic browser store, then publishes the authoritative view. The
accepted preferences survive reopening and a fresh store instance. Failed writes
retain old choices. A preference already accepted for atomic saving may finish
after the presentation closes, but its completion cannot revive that owner.
No password/key is stored in the filter preferences. Existing password/vault and
replacement search/sort settings remain independent.

Fields absent from an incomplete advertisement remain unknown; occupancy tests
only reject known counts. The module string is limited to1,024 characters by the
replacement transport/edit policy. Exact original input limits, clipboard/IME,
focus and all original key gestures still require verification. Do not call this
complete filter-window parity from the passing scoped checks.

## Verification and rollback

Final receipts for this checkpoint:

- `native-server-filter-input-v4`:23 native graphical/input/lifetime checks,
  source bitmap artwork reviewed at one viewport size. Additional scales and an
  original-client side-by-side comparison remain open.
- `native-server-filter-service-audit-v1`:43 service/protocol tests, including the
  4,480 original-instruction comparisons, deferred commits, failed writes,
  malformed/stale drafts and preserved settings. Providers are injected;
  no public discovery or connection occurs.
- `native-server-filter-browser-regression-v2`:22 existing browser checks.
- `native-server-filter-entry-regression-v1`:35 native Multiplayer/Direct checks.
- `native-server-filter-startup-v2`:full graphical startup, unchanged20-second
  watchdog/art gate,12 entry routes including native Filters open/Cancel and
  both prework cancellation checks.
- `native-server-filter-local-v1`:native Profile → Multiplayer → Direct admission
  and170 authoritative actions against the owned original server127.0.0.1:5125.
- `native-server-browser-source-v2`:read-only metadata for five original browser
  resources, including all nested list columns and filter labels. It is geometry
  evidence for further migration, not a visible or functional browser pass.

`tools/audit-native-server-filters.mjs` checks these receipts, current source
hashes and `backups/native-server-filters-v1.zip` with its verified manifest.
The full UI goal remains active. Automated tests use only owned loopback servers
and open unfocused on a secondary display, without physical pointer control.

## Next browser work

Original browser initialization8d4870 owns five tabs; tab1 is removed/disabled,
and tab4 depends on Steam/GOG authentication. Page factory8ce800 chooses
Internet8c2460, History8c2290, Favorites8c20e0 and a distinct buddy page. Common
initializer8d2570 attaches six synchronized columns, source scrollbar and a
viewport clipped by Viewport0/1. History disables its sorting headers; saved-server
pages replace the highlight model with CTL_SRV_HILIT3 and have wider columns.

Those original list pages, sorting/double-click/scroll synchronization,
game-type/filter summary lists, details, password/CD-key/connection status,
character selection, role/scale/backdrop/audio and the remaining entire UI
inventory still require migration and original comparison. The generic browser
must not be mistaken for completed original pixels or behavior.
