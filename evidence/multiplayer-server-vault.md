# Multiplayer server-vault selection and pre-world UI

Implemented 2026-10-19 (local). Target: NWN:EE 89.8193.37-17 x64,
`../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
The original installation, binary and existing Ghidra database were read only.

## Native evidence

REA dossiers are `backups/animations/rea-server-vault-*.json`.

| Function | Address | Observed contract |
| --- | --- | --- |
| HandlePlayerToServerCharListMessage | `0x140444a00` | p17/1 requests the list; p17/3 reads preview type and CResRef16 |
| SendServerToPlayerCharList | `0x1404d1260` | P17/2 WORD count, localized first/last names, reference, source, portrait WORD, unconditional custom portrait reference, BYTE class count, INT32 class ID/BYTE level |
| SendServerToPlayerUpdateCharResponse | `0x1404e12d0` | P17/4 type, reference, DWORD length and opaque SaveStats BIC |
| HandlePlayerToServerLoginMessage | `0x140457850` | p2/2,14,17 load an advertised reference; p2/19 creates a server character from a BIC; p2/1 is local-character upload |
| HandlePlayerToServerPlayModuleCharacterListStart | `0x14045c5e0` | p49/1 subscribes to currently connected characters; p49/2 stops |
| SendServerToPlayerPlayModuleCharacterListResponse | `0x1404de030` | P49/3 present BOOL, raw DWORD object ID, localized names, portrait, conditional custom portrait and BYTE/BYTE class records |

List sources 17, 2 and 14 correspond to account server vault, pregenerated
server vault and saved-module characters. Their preview types are 5, 1 and 4.
The currently connected player list is a separate protocol and never supplies
selectable vault characters or creates canonical world objects.

`inspect-native-server-vault.py` executed original scalar/localized/reference
writers in the observed list order and the original preview/Play request
handlers. Three list fixtures and twelve request observations are recorded in
`native-server-vault-observations.json`. Filesystem, send and character-load
boundaries were captured, not executed by this oracle. The full directory/GFF
list sender was not emulated. Tests ignore only the five unwritten padding
bits in the final native byte, and check the remaining wire data and reads.

## Application behavior

Connect authenticates and resolves the server's advertised resources before
listing characters. Selection requests a main-process preview; only derived
presentation fields reach the renderer, and the BIC buffer is cleared.
Play sends the current list reference and source, with no BIC upload. List
generations and session ownership reject stale selections. Confirmation then
continues the existing module/area admission path; IDs come from the server.

The public BNXI vault policy gates local files and saved application-vault
entries. Unknown policy does not silently permit local uploads. Explicit New
Character opens the existing full wizard against the connected server's rules,
TLKs and model catalog; Play uses subtype19 for server-only admission. The
server performs final validation. Existing-character admission and new-character
creation are intentionally separate methods.

The model inventory includes mounted NWSync manifests, HAKs, module, loose
overrides and installed keys. IPC exposes model names, not filesystem paths or
an arbitrary directory reader. This fixes the wizard's former assumption that
its resource resolver always lived in the renderer with local archive internals.

The UI follows the supplied screenshots: black/gold main menu, live Internet
browser, history/favorites, direct connect, vault list, portrait/record, class
levels, abilities, AC/HP/XP, record tabs, server info, player list and explicit
Play/Cancel. Actual fonts, logo, portraits and button models come from installed
or active server resources. DDS GUI textures now have the same existing decode
path as other game textures. No game assets are bundled in the workspace.

## Validation

- `server-vault-arelith-list-v1.json`: authenticated arena.arelith.com:5123
  returned a valid empty account list for the test identity. No character was
  uploaded, created or entered there by this pass.
- `server-vault-local-session-v1.json`: real unmodified vanilla server listed
  the generated account fixture, served its preview and admitted it through
  explicit p2/17. No p2/1,4,19; clean disconnect.
- `server-vault-renderer-create-v3.json`: production Electron renderer, preload,
  trusted IPC and full wizard created Vault Created, a recommended level1
  dwarf barbarian. The isolated vanilla server accepted p2/19 and assigned
  controlled object `0xfffffffe`, area `0x80000001`. No p2/1 request. Clean close.
- `server-vault-renderer-v1.json`: production list/preview/explicit Play passed;
  this first capture ended before a controlled world object arrived. The later
  harness requires the object registry entry, rather than merely phase playing.
- `server-vault-renderer-v3.json`: final production build explicitly selected
  Vault Fixture from the now two-character account and entered through p2/17,
  without upload. Controlled object `0xfffffffd` was present in the canonical
  registry; area `0x80000001`. Native player-list subscribe/unsubscribe passed.
  The v2 harness timed out because it assumed the first account character was
  still the wizard after creation added a second one; v3 selects it by name.
- `server-vault-ui-v1.json` plus `server-vault-ui-v3.txt`: hidden Electron visual
  checks with real assets and the live public list; six Arelith rows, no console
  errors, explicit Play required, fixture display HP6/6, AC12 and next XP1000.
- `server-vault-focused-v9.txt`: 84 focused tests passed. `server-vault-build-v5.txt`:
  production build passed, with the existing bundle-size advisory.

Test characters and their separate server profile are external under AppData;
`server-vault-fixture-v1.json` records its location. Test server port5124 is
separate from the user's server5121. Original client/server sessions were not
restarted. Credentials were delivered through the encrypted one-use loopback
bridge; reports contain neither private keys nor BICs. Failed UI test attempts
are retained: v1/v2 creation exposed the missing model catalog, corrected in v3.

## Limits

This is not a claim of complete Arelith gameplay or universal custom-class
creation support. Its test account had no existing server characters. The local
preview reuses existing native-derived stat arithmetic; broader saved active
effects and effective skill modifiers are not a fully verified preview system.
Skill values are base ranks. Some SaveStats previews omit known spells.

The supplied install has TXI metadata but no TGA/DDS for `gui_chrsht_tabs`;
text tab labels remain usable and the missing atlas is recorded. The animated
main-menu scene is pending. Movies/Options/News and Buddy List remain diagnosed
placeholders. Browser Sync status is unknown rather than invented, and advanced
filters are not a complete native browser implementation. Server Delete and
Customize are disabled, as in the supplied reference. Existing area/audio/particle
diagnostics remain visible; zero session/console errors does not imply zero
runtime omissions. The overall multiplayer goal remains incomplete.
