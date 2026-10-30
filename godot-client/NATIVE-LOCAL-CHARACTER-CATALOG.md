# Native local character catalog — partial parity

Installed and replacement-vault BIC row metadata now decodes in native Godot.
Rows use native character names, typed class IDs/levels and portrait identities,
with active native TLK/classes/portraits resources. The pregenerated filter uses
the active `Pregen.2da` rather than assuming all installed files are pregenerated.
This makes the original filter usable for the currently enumerated local files;
The [local-vault discovery follow-up](NATIVE-LOCAL-VAULT-DISCOVERY.md) extends
enumeration to profile and enabled Workshop vaults. Local mutation and full
catalog parity remain unfinished.

## Original evidence

Root `backups/animations/rea-native-local-character-catalog-v1.json` retains
original list construction `140705f10`, local record construction `1407068d0`,
row creation/sorting `14070cd20` and BIC stat import `1407f7e20`, against binary
SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

The original enumerates installed/local/workshop BIC sources when local vaults
are permitted. It loads `Pregen.2da`, reads physical column1, compares filenames
exactly, and sets a separate character-record flag at `0x48` for matches. Failed
table loading leaves the membership list empty; it does not disable local play.
The local record constructor also derives an ordinary numeric filename suffix.
The row loads BIC metadata, resolves the full name, adds a positive suffix,
chooses long or short active class names, resolves the portrait and inserts by
case-insensitive name. Invalid BICs do not become usable rows.

## Native flow

`tools/native-local-character-files.mjs` supplies raw byte path/size/SHA256
identity only. Its filesystem reads do not interpret BIC fields or Pregen rules.
The authenticated native startup ticket supplies allowed local directories;
received server rows cannot carry local-file tickets. The existing protocol
service still owns catalog keys, source/generation validation and upload.

`systems/native_local_character_catalog.gd` runs one private batch in a worker,
with only the latest replacement batch pending. It verifies directory, format,
size and digest, parses BIC and projects metadata through
`native_data/local_character_metadata.gd`. Class import reuses the earlier
original-validated typed pregame source policy. No world, scripts, effects or
render objects are imported. Superseded connections cannot publish old rows;
close cancels queued work and joins the active worker. Timing, decoded/failure
counts and retirement state remain in diagnostics.

The chooser waits for native metadata and completion of the Pregen-table read
before enabling local selection. It resolves names on the main native text path
and refreshes class/portrait/name presentation from active native resources.
Metadata is retained for the current catalog so TLK/table repaints do not reread
BIC files. A late localized name repaint preserves acknowledged selection;
real catalog/filter membership changes keep original first-row selection rules.
Failed/missing-column Pregen tables yield no matches and retain local selection.
Bad byte sources are omitted with a visible diagnostic instead of invented data.

The normal default-off preference is preserved. Since all39 installed files in
this installation are listed in the original Pregen table, the owned local test
now clicks the actual checkbox to expose its installed fixture before choosing
it. It does not bypass filtering or hardwire visible rows. The real native
checkbox action and unadmitted state are retained in the native receipt.

Server rows also resolve supplied localized names through native TLK rather
than displaying the service's fallback label. The legacy coordinator still
maintains fallback labels; removing that redundant coordination is open and is
not claimed as a complete removal of JS services.

## Verification and rollback

`tools/native-local-character-fixture.mjs` builds independent read-only
expectations with the existing JS GFF reader for diagnostics only. It is not
imported by rendering. Native tests compare all39 installed BICs to those raw
name/class/portrait expectations, exercise actual source checkbox input and
active Pregen/TLK overrides, and reject foreign roots/digests/sizes and stale
worker results. JSON fixture class integers are normalized explicitly before
native container comparison; their integer values remain checked.

| Final-source receipt | Checks | Scope |
| --- | ---: | --- |
| `native-local-catalog-final-graphical-v1` |61|39 actual BIC comparisons; native filtering, names, class/portrait artwork; custom text/table refresh; unavailable-table fallback; selection and worker ownership |
| `native-local-catalog-final-live-v1` |207| Seven original local admission, eighteen live two-participant roster, twelve exact native record-input and170 authoritative gameplay/UI actions |
| `native-lobby.test.mjs` + `native-local-character-files.test.mjs` |22| Protocol/lifecycle regression and local/server byte-ticket isolation |

Total:290 scoped checks with zero automated public connections. Final native
runs have unchanged source pins, armed exception traps and no reported native
exception or engine/lifetime errors. The final local worker decoded39 characters
in246.911ms, once, with zero metadata failures; this is a worker duration, not
total connection time or an FPS claim. The source checkbox exposed39 rows before
admission. The owned server/participant, worker and both preview files closed.
Graphical windows used a secondary screen without OS focus or mouse capture.
Original clients were not interrupted.

The final graphical capture was reviewed. Native names, class labels, small
portrait proportions and populated rows are visible. Stacked tab outlines and
other original-client appearance/state/scale comparisons remain unaccepted.
Earlier chooser/cursor/preference/page regressions also passed during integration;
their counts are not added to the final-source matrix above.

Development receipts are retained: initial comparisons caught a localized-name
adapter failure, then JSON fixture container-type normalization; a separate
before/after test caught selection resetting during TLK name repaint. Their
failed runs are not counted as acceptance. The original separate startup heap
exception and headless Player List artwork failure remain unresolved.

`tools/audit-native-local-character-catalog.mjs` validates current source pins,
independent raw source digests, original evidence, fresh local outcomes and the
read-back-verified archive `backups/native-local-character-catalog-v1.zip`.

## Remaining work

The original checkpoint below covered installed `data/lcv` and this client's own
saved vault. [Profile/Workshop discovery](NATIVE-LOCAL-VAULT-DISCOVERY.md) now
extends that scope with explicit remaining limits. DM sources,
duplicate/non-ASCII sorting, full malformed/locale/portrait cases and numeric
suffix edge cases remain open. Owned saved-vault UUID/blob identities do not yet
preserve original filename suffix semantics. These limits prevent full catalog
parity despite the installed-corpus and live test results.

Delete/Customize remain disabled until their permitted roles and complete
confirmation/mutation/creator flows are implemented. Initial original evidence
for those paths is saved in root
`backups/animations/rea-native-local-character-mutation-v1.json`: Delete opens
the original yes/no confirmation; accepted deletion updates the row selection;
Customize loads the existing BIC into the character-creation owner. Trace their
availability and storage effects before enabling them.

Continue [the complete UI goal](NATIVE-UI-PARITY-GOAL.md), including remaining
original visual/widget/role/scale/interaction surfaces, before general porting.
Complete UI, chooser/catalog and startup stability parity remain unaccepted.
