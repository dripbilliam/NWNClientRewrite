# Automatic server list and header refresh

The first permitted Internet presentation now starts discovery automatically.
This applies both to selecting the Internet tab and opening directly into it
after character Cancel. The existing busy/status view appears during the fetch;
success publishes the canonical rows. Successful results remain cached across
tabs, browser reopening and connection retirement, so returning to the list
shows those rows immediately. The refresh icon explicitly updates that cache.
An empty successful list is also a valid cached result.

`tools/server-browser-service.mjs` owns discovery and a monotonic two-second
refresh deadline. The deadline survives presentation resets, tab changes and
connection changes. While discovery is pending the existing busy guard also
prevents overlapping work. Failures release busy state, preserve cached rows,
publish the error status and retain the deadline. Back aborts its controller;
a retired completion cannot replace a newer presentation. Automatic discovery
still requires the session's existing Internet permission. It never joins or
queries individual game servers.

`systems/native_server_browser.gd` places the refresh icon inside the top-right
header, hides it on saved-server pages and removes the old button below the
box. `native_refresh_button.gd` draws a circular arrow using Godot primitives
in the existing black/brass palette. It neither stretches original artwork nor
depends on a Unicode glyph missing from the original bitmap font.

The icon locks immediately on a click, before the provider reply. Authoritative
`refreshCooldownMs` extends that deadline if necessary. A one-shot Godot timer
re-enables it when elapsed, unless another operation is busy or Internet access
is disabled. Changing tabs or receiving a quick idle reply cannot clear the
lock. Closing the browser stops its timer; reopening retains the elapsed-time
deadline. There is no per-frame cooldown polling in production.

This follows [the browser responsiveness work](NATIVE-BROWSER-RESPONSIVENESS.md)
and [character Cancel routing](NATIVE-MULTIPLAYER-NAVIGATION.md). Their earlier
statements about manual discovery describe the versions before this change.

## Validation

145 local checks passed:

| Receipt | Checks |
| --- | ---: |
| `native-browser-auto-refresh-service-v1.tap` | 59 |
| `native-browser-auto-refresh-ui-v1` | 19 |
| `native-browser-auto-refresh-pages-v1` | 32 |
| `native-browser-auto-refresh-retained-v1` | 16 |
| `native-browser-auto-refresh-cancel-v1` | 19 |

The Node suite uses fake discovery and a controlled monotonic clock to check
automatic tab/direct-list loading, exact 1999/2000ms boundaries, reset/tab
bypass attempts, cached reopening, failures, provider cancellation, stale
completion and disabled Internet policy. The graphical test clicks the actual
icon, waits for its real two-second timer, tests quick provider replies and tab
changes, and checks busy/policy/lifetime behavior. Existing native list rows,
page actions and character-Cancel navigation remain covered. Native receipts
pin current source hashes and report no engine/lifetime errors or exceptions.

The screenshot was visually reviewed:
`reports/native-browser-auto-refresh-ui-v1.png`.
No public discovery, game-server join or manual client restart was performed.
This is local behavior verification, not a public-provider availability test
or full UI parity acceptance.

Backup: `backups/native-browser-auto-refresh-v1.zip`.
Audit: `reports/native-browser-auto-refresh-audit-v1.json`.
