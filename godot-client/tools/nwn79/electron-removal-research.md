# NWN-79 Electron removal: initial scope and estimate

Research snapshot: 2026-11-14. This is a source audit and format check, not an implementation or an acceptance result.

## Current normal launch

`join-native.ps1` starts a windowless Electron executable. `native-session-bootstrap.cjs` uses Electron `app.getPath()` and `safeStorage`, then starts `native-session-host.cjs` as ordinary Node. The bootstrap passes settings metadata and a temporary login key to the host, and `settings-broker.cjs` handles later protected-settings requests over child-process IPC. The host owns the server protocol and starts Godot. Godot owns the visible client.

```
PowerShell launcher
  -> windowless Electron bootstrap: user paths, protected settings, credentials
      -> Node session host: server browser, authentication, NWSync, gameplay protocol
          -> Godot: menus, world, UI and rendering
```

The active `electron/network_peer.mjs`, `network_game_session.mjs`, `installed_network_session.mjs` and `server_browser.mjs` import successfully in plain Node. Their directory name does not make them dependent on Electron APIs. The session host itself is already launched with `node` and has no direct Electron API import. Thus removing the Electron *process* does not require rewriting the original-server protocol or Godot renderer. It does require replacing the protected-settings owner and its launch contract.

## Existing-user credential compatibility is the critical gate

The current Windows profile has `client-settings.json` and Chromium `Local State`; two saved profiles exist. The saved-key ciphertext begins with `v10`, and `Local State` has `os_crypt.encrypted_key`. Only metadata and a three-byte prefix were inspected; no saved key was decrypted or printed.

Electron 33 `safeStorage` calls Chromium OSCrypt. For this `v10` format, Chromium stores a random AES-256-GCM key in `Local State`, wrapped with Windows DPAPI. The saved credential is encrypted with that random key. A replacement must unwrap the profile key under the same Windows user, authenticate/decrypt the `v10` payload, and preserve the old file until a verified migration succeeds. Calling DPAPI directly on the saved credential is insufficient. Failure and recovery must distinguish missing profile, unavailable user key and corrupt ciphertext without logging plaintext.

The new store does **not** need to use Chromium's format. The preferred target to investigate is a small native adapter to Windows Credential Manager: one generic credential per profile ID, with non-secret profile labels and mod settings in the existing JSON. Windows provides `CredWriteW` and `CredReadW` for the current user's credential set. A one-time importer can read old `v10` credentials, write and verify the new entry, then leave the old file intact until the upgrade is confirmed. If import is unavailable, the client can offer explicit key re-entry without deleting profile names or other settings. NWN-79 currently requires preservation of saved user data, so skipping automatic key migration needs an explicit acceptance decision; changing the store implementation alone does not waive that requirement.

Primary sources: [Electron 33 safeStorage implementation](https://github.com/electron/electron/blob/v33.2.1/shell/browser/api/electron_api_safe_storage.cc), [Chromium OSCrypt Windows format](https://chromium.googlesource.com/chromium/src/+/e649194568cba439daa209c762442a6ad4534460/components/os_crypt/sync/os_crypt_win.cc), [Windows Credential Manager write](https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credwritew) and [read](https://learn.microsoft.com/windows/win32/api/wincred/nf-wincred-credreadw), [Windows ProtectedData](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.protecteddata).

## Work remaining under the ticket

| Stage | Concrete work | Initial estimate |
| --- | --- | --- |
| New credential store and compatibility spike | Prototype a native Windows Credential Manager adapter, verify save/read/delete with throwaway profiles, then prove one-time `v10` import without exposing key material | 1–3 working days |
| Normal runtime replacement | Replace Electron bootstrap and protected-settings IPC with a Node-owned settings service; preserve profile paths, mods, browser state, launch arguments and shutdown | 3–6 days |
| Workflow and dependency retirement | Replace Electron-only test helpers and launchers; retire the old Electron frontend; remove package/lockfile dependency and add a no-Electron guard | 5–10 days |
| Acceptance | Clean install, existing-user upgrade, failed unlock/recovery, public-server login, character selection, NWSync, area/travel/reconnect, clean shutdown, packaging | 3–6 days |

**Initial total: roughly 12–25 working days (about 3–5 weeks for one focused developer).** A first normal launch without an Electron process could plausibly be demonstrated in 4–8 days, but that would not complete NWN-79. The range depends most on the credential compatibility spike and on how much historical Electron-only regression coverage must be moved before deletion. This is an estimate, not measured implementation time.

A source search found 16 JavaScript files importing the Electron API directly and 26 source launch/test files referring to `electron.exe`. The older migration inventory lists 866 `src/` and `electron/` modules, 753 still marked pending feature audit, and 747 reference tests. Those are audit/retirement scope indicators, not 866 modules to rewrite: runtime protocol modules can remain as Node modules, but the legacy frontend and useful regression coverage need classification before deletion.

## Boundary and likely benefit

NWN-79 permits retaining Node services when they run independently of Electron. Replacing Node protocol/authentication with Godot or another native implementation is the larger NWN-57 scope. The current Electron process has no game window or renderer; removal should simplify startup, packaging and process/memory use. It is not by itself a credible route to a large in-world FPS gain.
