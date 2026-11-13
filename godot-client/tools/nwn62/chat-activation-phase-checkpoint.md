# NWN-62 chat activation phase probe

Current `systems/native_chat_hud.gd` adds opt-in `--nwn62-chat-activation-phases` counters only. The default path retains the same activation statements, callback order, `context_prepared` signal and visibility. The probe prints one `NWN62_CHAT_ACTIVATION_PHASES` row per successful `activate()`: parse, construction and direct art/font binding subtime, pane/prompt/mode construction, refresh, font application, placement, admission, successful history rebuild calls and notification. `direct_bind_us` is nested within `construct_bind_us`; `history_all_us` is nested partly in `place_us` and partly in `final_history_call_us`. These fields must not be summed. `context_new_us` and `context_add_us` distinguish allocation from the Node entering the scene tree. No optimization or FPS measurement was made.

Source SHA-256: `368f245c01bae2c289379bf09386a0d5c13bfba8687350ca35727426eaac038c`. Runner `tools/nwn62/chat-activation-original-check.cjs` SHA-256 `3a9551fb98f66ae2dbefe62b545e69914d5e2e5f04f800315c3197e191044d67`. Installed-original `native_chat_hud_test.gd` SHA-256 `3f4b1c19a3bc7994dd0194865efa4ab570599bd2ef9550e87b9486f48e7701cc`. Godot 4.7.2 custom console ran the fixture headlessly with the opt-in flag; report `.cache/nwn62/chat-activation-original-d/report.json` SHA-256 `de9d849dca452c6c2b642f758ff45cbabc50a554e589e2217fda9db87ba11a1a`. It passed 61/61 original-content and input checks, exit 0, and emitted two activation rows. This was a local original-resource fixture with two and then zero chat rows; it is not the original Arelith startup load or an FPS test.

| Phase | First activation, two rows | Second activation, zero rows |
| --- | ---: | ---: |
| Total | 9.886 ms | 12.228 ms |
| Parse layout/reply | 0.997 ms | 1.497 ms |
| Construct and bind | 5.649 ms | 7.207 ms |
| `server_radial.new()` | 0.010 ms | 0.019 ms |
| `panel.add_child(server_radial)` | **3.559 ms** | **3.580 ms** |
| Explicit direct binds within construction | 0.289 ms | 0.546 ms |
| Placement (includes any history rebuild) | 2.380 ms | 3.077 ms |
| All successful history rebuilds | 0.532 ms / 2 calls | 0.140 ms / 2 calls |

The largest isolated local leaf is `panel.add_child(context)`, which enters `server_radial.gd:_ready()` and constructs the radial UI's root, button/label/icon/arrow controls and a preview group. This is roughly 3.6 ms in the local fixture, not the saved 58.915 ms `but_chat_reply` consumer. Direct art binding and double history calls are too small here to explain that historical tail; the two history calls occur on opposite sides of `rebuild_admission`, so deleting one without changing admission order can alter first visible chat output. No safe short split of the 59 ms historical callback is established by this local fixture alone.

Independent root rerun on the same source and engine: `.cache/nwn62/chat-activation-original-root/report.json`, 61/61 checks, exit 0, two phase rows. Totals were 12.178 and 8.272 ms; `panel.add_child(context)` was 3.837 and 1.603 ms. The variation reinforces that these local activations cannot be substituted for the recorded 58.915 ms completion.

Next exact gate: one source-pinned recorded-entry diagnostic with both `--nwn62-chat-activation-phases` and `--publication-completion-diagnose`, comparing the `but_chat_reply` completion row to its activation row. The phase probe can then show whether the large callback is radial scene entry, a different construction phase, or external publication outside `activate()`. A candidate to prebuild the radial owner before final chat-model completion would move about 3.6 ms in this local fixture and needs full owner/admission/cancellation review; it is not yet a production fix.
