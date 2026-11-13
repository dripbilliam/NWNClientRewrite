# NWN-82 local graphical pre-join replay

The graphical replay in `prejoin_visual_replay.gd` uses the actual `LocalConnection.browser_request` and `LocalConnection.receive` methods with actual `CharacterLobby`, `ServerBrowser`, and `NativeMainMenu` instances. It reuses connection 1's exact NWSync phase/progress values from `reports/native-sync-handoff-local-v3-roundtrip.json` (SHA-256 `135a55792ccb1c6cf94c5eaf66c6f7b2d142b154037352625082646a3f4dd12a`). Its browser join envelope is reconstructed: the older local recording began with `lobby-join`, before NWN-82's browser handoff existed. The fixture does not connect to a server or configure original browser art.

Run from `godot-client`:

```powershell
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --path . --windowed --position '-1800,100' --rendering-method gl_compatibility --log-file .cache/nwn82-visual-replay-c-godot.log --script res://tools/nwn82/prejoin_visual_replay.gd -- --report=.cache/nwn82-visual-replay-c.json --record=reports/native-sync-handoff-local-v3-roundtrip.json
```

Result: exit 0, seven frame PNGs, no fixture failures, secondary display and `FLAG_NO_FOCUS` confirmed. In the rendered `first-after-join` frame, the browser and main menu are hidden, `CharacterLobby.native_wait` is shown, the fallback character column is hidden, and the visible text is `Connecting to server…`. The same exclusion holds for connecting, manifest, download, complete, and the busy browser update. The first-after-join and download PNGs were inspected visually. Report: `.cache/nwn82-visual-replay-c.json`; first frame: `.cache/nwn82-visual-replay-c-first-after-join.png`.

Independent root rerun after adding explicit fixture teardown: `.cache/nwn82-visual-replay-root-clean.json`, exit 0, seven frames, zero failures and no ObjectDB/resource leak at exit. The first-after-join PNG was visually checked again. The environment still reports its existing `user://` shader-cache and root-certificate diagnostics, which did not fail the replay.

The report pins SHA-256 of `local_connection.gd` (`7f60ad25cd5b0c98870f62000777615e1ab97d57a2e3b723975f6be1c09ec6b0`), `character_lobby.gd` (`a57ca3c3a173d5e2406df569ca8e511048fa199c2c578dfba3fc0c9b7dc9dc4c`), `server_browser.gd` (`e302d8442d39c93ff2cbe63e710bbf04bdd4af9652a5f7f1802da24f3fad370d`), and `native_main_menu.gd` (`0a68d98b934db31a8f5abb24179a21fb238f16ef99409484b87f07b439342b03`).

This proves the local rendered handoff and recorded progress presentation for that source identity. It cannot prove that the live Arelith frontend receives messages in the same timing/order, nor that the fully configured original-art browser cannot flash on an unrecorded authority path. Those are the remaining normal-client acceptance boundaries. No FPS measurement was made.
