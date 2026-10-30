# Native local-vault discovery — scoped follow-up

The chooser now enumerates installed `data/lcv`, the selected profile's
`localvault`, and enabled Workshop `localvault` directories. Local byte paths
are private authenticated transport; Godot still owns BIC decoding, native
names/classes/portraits, Pregen classification, presentation and input.
Server-vault policy continues to determine whether local rows are admitted.

## Original lookup evidence

Root `backups/animations/rea-native-local-vault-discovery-v1.json` retains
read-only original-client evidence against SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Together with `rea-native-local-character-catalog-v1.json`, it traces:

- Chooser enumeration: installed alias, then profile and Workshop aliases.
- `GetDirectoryList`: appends matching files without deduplicating rows.
- Resource tables: LOCALVAULT priority81M precedes installed priority80M.
- `ServiceFromDirectory` → typed `CExoFile` → `CExoFileInternal`: demand
  constructs the alias/resref filename and calls `ResolveFileName`.
- Alias resolution: first matching Workshop file, then primary profile file.

The raw filesystem adapter retains each enumerated row's identity and filename
stem while resolving its bytes using that precedence. Enabled mod selection
remains the user's explicit replacement-client feature. Steam installed-item
metadata controls Workshop ordering; directory-name sorting is the fallback.
Scanning is nonrecursive and does not interpret BIC data in JavaScript.

Each lobby snapshot carries its source roots. The native metadata worker includes
those roots in its work identity, so changing them invalidates old decoded rows
even within the same connection. Integrity hashes and byte bounds still apply.

## Validation and limits

`native-vault-discovery-graphical-v1` passes63 native checks, including the39
installed BIC corpus, actual source-checkbox input, active server table/TLK
updates, root changes, stale work and worker retirement. The screenshot was
reviewed: names/class labels and portrait proportions render; stacked tab
outlines remain an explicit appearance defect.

The raw discovery, lobby, byte-ticket and Workshop suites pass29 Node checks.
They cover profile and Workshop membership, disabled mods, root-only mods,
nonrecursive scan, duplicate identities, Steam order and lookup precedence.
They use owned opaque files, not copied user characters.

`test-native-actions.ps1 -LocalVault -LobbyPages` supplies one owned copy of an
installed BIC in the isolated test profile. It preserves existing files, checks
the copied file's hash before cleanup and removes only that exact fixture.
The original installation and user profile are read-only. The live validation
receipt and rollback archive are indexed by
`tools/audit-native-local-vault-discovery.mjs`.

`native-vault-discovery-live-v2` passed207 checks:7 native login/admission,
18 real two-participant server/player-page,12 exact-preview record input and
170 authoritative action checks. It decoded40 records with no failures, kept
Show Pregenerated off, selected `local:nwn_local_ui.bic`, retired all workers,
removed its preview bytes and closed without a debugger exception. This proves
the profile path through the real server, not every Workshop/DM corner case.
Together with63 graphical and29 Node checks, this follow-up has299 scoped
passing checks; the earlier failed run is excluded.

The first live attempt, `native-vault-discovery-live-v1`, is retained as failed:
the test driver redundantly selected its already-selected local character and
cancelled the concurrent exact-preview input probe. The driver now preserves
the current ready selection. This is a diagnostic sequencing correction, not
a claim that an original-server protocol defect was fixed.

Not accepted: full Workshop-character upload coverage, DM vaults, exact OS and
non-ASCII enumeration/sorting, unusual CResRef/filename/overflow collisions,
cross-vault server/DM resource priority interactions, Delete/Customize, all
chooser visual states and full UI/role/scale/stability parity. The existing
startup heap exception and headless Player List artwork failure are unresolved.
The raw byte-ticket helper still reads a whole file before Godot's size bound;
bounding that IO remains follow-up work. General porting stays deferred.
