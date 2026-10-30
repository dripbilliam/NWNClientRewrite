# Native Internet, History and Favorites — partial browser migration

The main Multiplayer flow now presents the original server-list page frames,
tabs, six-column rows, source row highlights and attached native scrollbars.
Godot owns this presentation and input; the existing browser protocol service
owns current handles, queries, settings and connection outcomes. The browser is
still incomplete: game-type filtering, the complete Details/password/connection
panels and remaining text/gesture/role/scale parity must be finished.

## Source layout and ownership

`server_browser_layout.gd` resolves `SERVERLIST_PANEL` and the three page GUIs
from the independent pregame catalog. Its `pages` model hook attaches each page;
recursive source-parent offsets retain all six nested text columns. Internet's
625×366 viewport differs from the785×415 saved-page viewport. The latter has
wider name/module columns and uses CTL_SRV_HILIT3 instead of CTL_SRV_HILIT.
Highlight textures keep their model-derived size rather than stretching to a
container. All six row columns share one scrolling body and the original20px
row spacing, independent of the source font's bitmap height.

Read-only evidence: `../backups/animations/rea-native-server-pages-v1.json`, with
earlier common-init/page/Cancel dossiers in the Multiplayer/filter follow-ups.
Original client SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

- 8c3990 sets row spacing20 and the base highlight;8d2570 imports the columns,
  sorting headers and scrollbar and clips the model through Viewport0/1.
- 8c2460 loads Internet,8c2290 loads History and disables its sorting headers,
  and8c20e0 loads Favorites with its Remove button and wider highlight.
- 8d4870 owns five tab definitions. Tab1's model is removed and tab4 requires
  Steam/GOG authentication, which this client does not currently own. Only the
  three available tabs are painted; the other definitions remain in the plan.
- Common initialization selects the Players radio visually without firing a
  sorting callback: CGuiTabSet::SelectTab1eff30 only changes check state. Sorting
  priority and that initial visual check are therefore recorded separately.
- CConnectionLib113ad0 reads GameSpyRooms.2da by physical columns1/2 for caption
  references/group IDs. The native sidebar resolves those captions through the
  same catalog/TLK, and shows its original scrollable list. It is currently
  read-only with an explicit unported-filter tooltip; it must gain actual group
  selection before browser parity can be accepted.

## Connected actions and state

Source tabs request an authoritative page view. Row clicks send current private
entry handles; only the acknowledged selection enables Details/Connect. Native
checkboxes preserve password/vault filtering and the original mutually exclusive
Hide Local / Hide Server interaction. The source Additional Filters modal opens
over the list under a full input shield. Direct Connect retains the list behind
its modal; Back/Cancel retires it and aborts pending providers through the prior
Multiplayer-return operation.

Internet/History Add Favorite now sends explicit addition, so clicking Add on an
existing favorite cannot remove it. Favorites sends explicit removal. The legacy
generic route retains its old toggle contract. Source header actions retain
per-page direction and priority state; History refuses sorting actions. A held
row, header, footer or Connect press cannot submit into a superseding view or a
retired owner. All source/scroll workers join before the shared painter retires.

Source header handler8d1eb0 toggles the current column or promotes a different
column through8d7a60. `scripts/inspect-native-browser-sort.py` executes those
unchanged instructions for4,608 supplied priority/direction/pending fixtures.
The native service's direction/promotion helper matches every observation. The
final original GUI reorder is an observed boundary in that harness; it does not
execute the entire comparator, constructor or window. Numeric player/level
ranking uses the inspected packed counts and keeps selected endpoint identity
through reorder. Full comparator edge cases and translated PvP/NWSync words
remain unverified.

Replacement-only paging and explicit Refresh use original button artwork and
fonts below the frame. Refresh respects current discovery permission and never
runs automatically from the menu. These are intentional transport extensions,
not controls found in the original GUI. Backend status/error feedback stays
visible. Details currently queries and displays received information through an
interim source OK notice; this is limited and must be replaced with the complete
SRV_SRVDETAILS owner, including its description scrolling and navigation.

## Checks and rollback

Current settled-source receipts:

- `native-server-pages-input-v4`:32 graphical/native-input/lifetime checks;
  Internet and History viewport PNGs were visually reviewed at one size.
- `native-server-pages-entry-v3`:35 native Multiplayer/Direct regression checks.
- `native-server-pages-filter-v1`:23 native Additional Filters checks.
- `native-server-pages-generic-v1`:22 legacy browser regression checks.
- `native-server-pages-catalog-v2`:five-resource read-only geometry/table scan.
- `native-server-pages-service-audit-v1`:46 service/protocol tests, including the
  preceding4,480 original filter cases and4,608 direction/priority cases.
- `native-server-pages-startup-v2`:full graphical startup with the same20-second
  watchdog/art gate and12 routes, now requiring the source browser owner itself.
- `native-server-pages-local-v2`:native admission and170 authoritative actions
  against the owned original loopback server at127.0.0.1:5125.

Early startup/local receipts did not pin all newly imported browser helpers.
Their observed passes are retained, but final runtime receipts now explicitly
hash the browser store, endpoint policy, filters, sorting and protocol modules.
`tools/audit-native-server-pages.mjs` enforces those pins, current source hashes,
both original-instruction evidence files and the verified rollback checkpoint
`backups/native-server-pages-v1.zip`. Nested instruction cases are separate from
UI/action counts and cannot establish full browser or full UI acceptance.

## Remaining browser acceptance work

The subsequent [native Details/password migration](NATIVE-SERVER-DETAILS.md)
replaces this milestone's interim Details notice. Its separate receipts cover
extended server data, source windows, navigation and query cancellation; the
remaining full browser acceptance work below still applies where unverified.

Finish game-type group/filter semantics, native full Details and password/CD-key
and connection-status owners, row double-click/keyboard behavior, role/platform
variants and complete original comparator behavior. Native rows currently show
raw PvP values and unknown local NWSync availability rather than fabricate cache
success. Authorization/password colors do not certify original version-mismatch
coloring. The readonly category list, some bounded-label wrapping/line spacing,
all disabled/hover/pressed states, complete summary wording, other scales and
resolutions, backdrop, GUI audio and original-client side-by-side comparison
remain open. The legacy generic form still exists for non-main/test routes.

The entire UI inventory remains the active goal; general porting is deferred.
No public/Arelith connection is authorized for automated checks. Windows remain
unfocused on a secondary monitor and do not control the physical pointer.
