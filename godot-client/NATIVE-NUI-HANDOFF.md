# Native NUI across owned server transfers

The native client now verifies real NUI menus across A→B→A on two owned
loopback NWN servers. Root and child menus remain open when each transfer starts;
the next connection clears their native windows, fonts, textures and partial
resource transfers before creating new menus. Production native adoption is
still disabled pending server-vault reference and NWSync handoff checks. No
online game server was queried or connected.

## Implementation and fixture

The existing `NuiService`, native connection reset and portal retirement perform
the actual work. `tools/local-host.cjs` now records NUI retirement results and
shares the character-export/advance helper between ordinary and NUI handoff
regressions. Only `--portal-handoff-smoke --portal-nui-smoke` runs the new probe.
The ordinary client does not automatically enable server transfers.

`tools/create-nui-handoff-servers.mjs --revision=3` derives authored modules from
the previously hash-verified GodotHandA1/B1 fixtures. All original artwork is
referenced by resref; no original binary or art is copied. Each server declares
an authored HAK with a distinct child layout under the same `port_nui_jui`
resource name. This tests resolver replacement as well as numeric token and
native window-handle reuse. The actual server scripts handle menu opening,
watched text edits, child creation from JUI and acknowledgement clicks.

`reports/nui-handoff-server-fixtures-v3.json` records the exact profiles and
loopback ports5121/5122, plus these SHA256 values:

| Authored content | SHA256 |
|---|---|
| GodotHandA4 | c51caeae76b12fe06914420d9ce6e09b61d9ec81a648198ba53acdb0d0d94e6e |
| GodotHandB4 | 7dc3d2a02a0ed43d67ad976f4d31a10210815fc553dd44624323b8be454e65cf |
| handnui_a3.hak | 4e9231360428c40b2d12c152bc05de36ee40d6826a6836cd739de2270e80f285 |
| handnui_b3.hak | 459e7359ba8dc516961a221bd06ba2e535854b384b79f9d12ecb2578e0763516 |

The test launcher checks exact owned server processes before connection.
`test-handoff.ps1 -Scenario nui -Report <unused-name.json>` uses only those
loopback endpoints. The secondary ownership helper selects this fixture only
with `-Nui`; ordinary handoff/recovery checks retain their original fixtures.

## Accepted evidence and limits

`reports/native-nui-handoff-local-v3.json` passes the strict
`tools/nui-handoff-evidence.cjs` gate after shutdown:

- Three native animated admissions and48 real dialogue/examine checks.
- **14/17/17 native NUI checks**, all passing: original skin/fonts/icon load,
  watched editing, GUI-routed child and acknowledgement clicks, correct A/B/A
  resource content, and two simultaneously open menus per server.
- Server root and child tokens1/2 and native root handle1 are reused. Two
  deliberately stale old-connection close requests are rejected; an old native
  remove frame also cannot remove the new root. These are the only two rejected
  inputs. The acceptance gate requires their exact connection sequence/reason
  and refuses additional errors.
- Canonical server echo and child acknowledgement agree with each native phase.
  Source and destination callbacks remain correctly scoped.
- Two real character downloads/source releases, three arrival/gameplay/save
  admissions and all portal ownership checks remain required by the ordinary
  handoff gate. No installed-character re-selection occurs at destinations.
- Both retired NUI services close with pendingResources0, all retired native
  weak window/resource owners are freed, and final NUI cleanup has no pending
  resources. All particle epochs release pending jobs and worker threads.
  Native exit0, disconnectedtrue, no renderer/script/leak errors.

Screenshots for A, B and return A were inspected. The editor was preserved;
incidental FPS counters in these sparse authored scenes are not complete-scene
performance evidence. Terrain, atmosphere, particle fidelity and broader UI
appearance remain separate migration work.

`reports/native-nui-handoff-backend-v2.log`: **106 passing checks** cover IPC,
wire portal behavior, native lobby/adoption, cancellation/failure barriers,
particle retirement, NUI service/input validation and strict acceptance gates.
The shared authored handoff test fixture contains no installed data. The
ordinary A-B-A regression is retained separately as `native-handoff-local-v7`.

The first live run is retained as failed: its child JUI existed only inside the
server module, which multiplayer clients do not receive as a resource pack.
The corrected fixture declares the authored HAKs. The v2 run completed all48
native NUI checks and canonical callbacks but failed acceptance because the gate
expected the wrong error string for deliberate stale input. V3 uses the actual
top-level old-connection rejection and passes. Failed reports were not promoted.
Preliminary v1/v2 fixture-generation reports remain retained and unaccepted.

Both server-vault reference variants are subsequently verified in
[NATIVE-VAULT-HANDOFF.md](NATIVE-VAULT-HANDOFF.md). NWSync content replacement
across servers remains required before enabling normal-client adoption.

This verifies this authored menu/resource path, not all NUI layouts or physical
input devices. Full NUI parity, live server-vault43/3 reference transfers,
NWSync changes between servers and public-server acceptance remain incomplete.
No original clients/editors are closed or modified. Full migration and sustained
moving-scene60FPS remain active goals; no online connections until user approval.
