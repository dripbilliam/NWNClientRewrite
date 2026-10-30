# Character Cancel and server-browser return

Cancel in the original character chooser sends the existing scoped disconnect
without exporting the character. The session owner immediately hides the
retired chooser, waits for the authoritative idle lobby state, then opens the
native server list. It restores the most recent Internet/History/Favorites tab,
defaulting to Internet for a Direct Connect session with no previous list.

The obsolete floating bottom-right Main Menu shortcut has been removed from
the character-lobby layer, including its input rectangle and session callbacks.
Use the existing Cancel/Back navigation or Escape to reach Main Menu.

The bug was two independent fallbacks: the session owner called `Browser.open()`
without the original-frontend context, then the browser's `closed` callback
showed character selection even when no connection remained. That exposed the
prototype browser and subsequently the empty prototype character lobby.

Owners and boundaries:

- `native_session_world.gd`: existing disconnect/cancel and connection fences;
  authoritative completion calls `server_browser.open_list()`. Browser dismissal
  cannot reveal a disconnected lobby. Completion clears the temporary status.
- `systems/server_browser.gd`: `open_list` retains original context and the last
  canonical list tab. Original frontend preparation never shows the prototype.
  Server-list Back still returns to original Multiplayer; its Cancel exits to
  Main Menu. Legacy surfaces remain available only for explicit old harnesses.
- `systems/character_lobby.gd`: native frontend idle/disconnecting/closed states
  keep the character panel hidden, including later idle updates.
- `tools/local-protocol.cjs` and `tools/server-browser-service.mjs`: bounded
  `listTab` input is accepted only for `open`. The first canonical data view
  already contains that list page, avoiding a Direct-view flash or extra tab
  round trip. This is raw browser data selection, not JS UI rendering.

No automatic discovery, query, join or credential reuse is added. Existing
profile ownership, secret clearing, stale view/connection guards, row IDs,
original Back behavior and authoritative disconnect completion remain in use.

## Local validation

117 native checks, source-pinned with no debugger exception or engine/lifetime
error, and 55 Node browser-service tests passed (172 total):

| Receipt | Checks |
| --- | ---: |
| `native-character-cancel-navigation-v2` | 19 |
| `native-character-cancel-disconnect-v2` | 14 |
| `native-character-cancel-pages-v2` | 32 |
| `native-character-cancel-entry-v2` | 35 |
| `native-character-cancel-frontend-v1` | 17 |
| `native-character-cancel-browser-service-v1.tap` | 55 |

The new graphical test clicks the installed original chooser's Cancel, feeds
the disconnecting and idle provider replies to the real native session owner,
verifies the first returned native History page, then clicks both original Back
controls. A later idle reply and the legacy close callback cannot revive the
retired picker. The Node test verifies first-view list selection, a retired
connection/view, bounded protocol fields and zero discovery/query/join calls.
Fixture replies are not live-server or physical-input acceptance.

The returned browser screenshot was visually reviewed:
`reports/native-character-cancel-navigation-v2-returned.png`.
An earlier screenshot exposed stale disconnect text; v2 clears it. The older
Multiplayer entry test was also made to wait for its cold source artwork, as
the production visibility rule already requires; its earlier failed receipt
is retained. No manual client was restarted or public server contacted.

Backup: `backups/native-character-cancel-navigation-v1.zip`.
Audit: `reports/native-character-cancel-navigation-audit-v1.json`.
The full UI parity goal remains incomplete.
