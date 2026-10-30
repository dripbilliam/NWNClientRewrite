# Native character chooser — source layout, partial

The [pregame Spells follow-up](NATIVE-PREGAME-SPELLS.md) connects the fourth
record tab. All three list tabs now have native owners; the Character page and
the overall chooser still have explicit data/input/visual/role gaps.

The [pregame Skills follow-up](NATIVE-PREGAME-SKILLS.md) adds the typed native
Skills page. Spells and complete Character statistics remain open.

The [pregame Feats follow-up](NATIVE-LOBBY-RECORD-FEATS.md) supersedes the
disabled-Feats state below. Skills and Spells remain unported; derived record
statistics and complete original-client comparison remain open.

The [Server Info / Player List follow-up](NATIVE-LOBBY-PAGES.md) supersedes the
disabled-page state and prepared evidence below for those two pages. Its current
checkpoint also adds received server status and tighter held-input ownership.

PRE_PLAYMOD now replaces the generic chooser during admitted character selection
and rejection. Connecting/downloading and in-game session operations retain the
existing fallback owner. It borrows the active session's native painter, catalog
and TLK/2DA reader, and closes its workers before these owners retire. No JS
rendering was added; the existing protocol/preview service remains in use.

Original CPlayModulePanel7143f0 imports PRE_PLAYMOD and attaches record/server/
player pages programmatically. Row70cd20 uses CTL_PRE_BTN_CHAR, two text lines,
case-insensitive name insertion and a portrait replacement mesh. Portrait bounds
are derived from that mesh hierarchy (16x25). Source row advance44, scrollbar and
footer/control geometry are preserved. Mode0 CPanelCharSheet88a0a0 uses
PNL_CHRSHT2 and tabs5–8. Callback710720 explicitly requests417 pixels
(float43d08000); this viewport and layer ordering keep Play/Cancel visible.

Read-only original evidence:

- `../backups/animations/rea-native-character-chooser-v1.json`
- `../backups/animations/rea-native-character-record-owner-v1.json`
- `../backups/animations/rea-native-character-lobby-pages-v1.json`
- `reports/native-character-lobby-catalog-v2.json` and
  `reports/native-character-row-parts-v1.json` retain source hashes/hooks/meshes.

Native rows resolve class names through active classes/TLK, accept public portrait
metadata and resolve portraits natively. The service whitelists public fields;
paths, credentials and vault bookkeeping are not forwarded. Local choices still
require server permission. Existing source/generation validation, preview/upload
and Play requests are preserved. Row mouse-down selects; fast double-click waits
for its connection/key/nonce acknowledgment and consumes activation once. A
connection replacement or dismissal retires it. New invokes the existing creator;
Cancel sends authoritative no-save disconnect. Basic received record values,
ability glyphs and server-ruleset modifiers occupy source hooks. Unknown values
remain blank. Supplied pregenerated flags can filter rows, initially off; the
checkbox is disabled if local choices lack classification metadata.

Final evidence:25 graphical native input/layout/lifetime checks,12 full startup
routes,7 native admission plus170 gameplay/UI regressions against the owned
original server127.0.0.1:5125, and23 service/connection tests. These237 checks
have different scopes. The local regression preserves the existing automatic
character-selection driver; it does not prove every new chooser button against
an original peer. The populated native image was reviewed. Startup and graphical
windows stayed unfocused on secondary screen0; client public connections were
zero. The local test client/server exited normally and released their workers.

The first headless run caught an incorrect rich-text API call even though its
individual assertions passed. Its failed debugger receipt is retained. The fix
passed headless; final graphical v3 and startup/local receipts supersede earlier
development runs. Visual review also caught record artwork covering the footer;
the source viewport/layer correction is now tested.

Remaining requirements:

- Full Server Info / Player List acceptance: native owners and protocol wiring
  are in the follow-up above; the owned live roster follow-up verifies a second
  participant. Complete original-client role/gesture/scale/large-font comparison
  remains open.
- Embedded Skills, Feats and fourth record page: source artwork is present but
  unported actions stay disabled. Complete statistics/race/alignment, source title
  prefix/flag policy, the Spells page, source description/list scrolling and gray
  background/pose/tint differences need migration and original comparison.
- Native BIC metadata for local/pregenerated rows, persistent pregen preference,
  permission-dependent Delete/Customize and their real confirmations/flows.
  Disabled controls never fabricate success.
- Original automatic first selection, keyboard/page movement and reveal, complete
  rejection/role/DM/version cases, byte-order/name sorting, sounds, gestures,
  multiple scales/resolutions and original-client visual/state comparison.
- The broader UI inventory and every other remaining UI requirement.

This is partial native presentation/interaction work. Keep the overall goal
active. `tools/audit-native-character-chooser.mjs` verifies the scoped final
receipts and rollback checkpoint; it deliberately cannot accept full UI parity.
