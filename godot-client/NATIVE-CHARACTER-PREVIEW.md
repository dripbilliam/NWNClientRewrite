# Native character preview — partial migration

The [pregame Feats follow-up](NATIVE-LOBBY-RECORD-FEATS.md) now uses this raw
native projection in an original list/help page. Its later checkpoint and scoped
checks supersede this document's disabled-Feats state; other record gaps remain.

The native chooser now reads raw local/server BIC records with a Godot worker.
The protocol service transports bytes; it no longer calculates this client's
preview display fields through the JavaScript character-rules path. The legacy
JavaScript client retains its own preview implementation.

`tools/native-character-preview-store.mjs` writes byte-identical, SHA-256-named
sources into a fresh owned run directory. Small tickets avoid the bridge's JSON
frame limit. At most eight sources are retained; cleanup removes only tracked
files and then the empty directory. No key is stored in this directory.
`systems/native_character_preview.gd` checks path ownership, size and digest,
then decodes BIC/GFF through native code. One active task and one latest pending
selection bound work. Connection, selection, language and source identity guard
publication. Cancellation invalidates the result; shutdown joins the worker.

`native_data/character_preview.gd` extracts raw abilities, class levels, skill
ranks, feats, known spells, names, description, portraits and serialized HP.
It does not install scripts, effects or world identities. Active native tables
and TLK data resolve names and ability modifiers. Text publication revisions
refresh chooser text even when an override replaces an existing string key;
unchanged BIC bytes are not decoded again for unrelated lobby updates.

## Evidence and limits

Final receipts use `native-character-preview-` prefixes under `reports/`:

- `worker-v3`: 24 checks, including a record larger than the JSON frame limit,
  integrity/field failures, language changes, stale selections and worker exit.
- `frame-v3`: 15 graphical checks through the real worker and original-resource
  chooser, active rules/TLK replacement, native input and pregame visibility.
- `chooser-v2`, `pages-v1`, `phase-v1`: 25, 32 and 22 native regression checks.
- `startup-v1`: 12 original-resource entry routes, without network connections.
- `service-v2`: 55 protocol/lobby/storage regression tests.
- `local-v2`: 7 admission, 18 two-participant roster and 170 authoritative
  gameplay/UI checks on the isolated original server at 127.0.0.1:5125.
  Before automatic Play, independently parsed fixture fields and the BIC hash
  match the actual native preview and visible title. Native decoding took about
  12 ms in this one warm local observation; this is not a loading benchmark.
  The native worker exited and its source file/directory were removed.

Graphical windows remained unfocused on secondary screen 0, primary screen 2.
The populated `frame-v3.png` was visually reviewed. All accepted receipts require
unchanged source, debugger/lifetime checks and zero public connections. The
scoped audit and verified rollback are `tools/audit-native-character-preview.mjs`
and `backups/native-character-preview-v2.zip`. These are 380 checks across
different scopes, not a percentage of UI completion.

Retained development failures: worker-v1 used a name conflicting with Godot's
built-in Projection type; frame-v1 exposed JSON float versus native integer
selection identity churn; local-v1 passed its gameplay checks but accessed a
freed chooser during shutdown profiling. Final receipts supersede these cases.
Earlier sampler/capture and intermittent blood-pixel failures remain open in
their own ledgers; this change does not accept them.
The first acceptance-audit attempt incorrectly required a gameplay shutdown
snapshot from the no-connection startup route. The corrected audit checks zero
startup byte writes and closed empty storage, and requires the actual worker
shutdown snapshot for the local gameplay run. The prior v1 checkpoint is retained.

## Remaining work

This is a data ownership prerequisite, not complete character-record parity.
Derived combat statistics are deliberately marked unavailable: AC stays blank,
and HP is serialized HP, without a promised full equipment/effect calculation.
Native derived AC, saves, attack, damage and other original calculations still
need migration and original-method validation. Skills retain raw ranks, not
fully modified totals. Skills/Feats/Spells tabs remain disabled pending native
page/action implementation. Local row metadata, editing/deletion permissions,
keyboard/automatic selection, source title/flag policy, complete scale/pose/font
and original-client comparisons remain open. Text revision invalidation here
does not prove every other menu handles late overrides. Full UI and the overall
goal remain active and incomplete.
