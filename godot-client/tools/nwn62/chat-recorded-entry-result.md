# NWN-62 chat activation in one recorded entry

## Pinned gate

- Stage: `.cache/nwn62/chat-recorded-a/staged.json` SHA-256 `9ce3eb4a19b7822ae921a6f22024753175c195975242d3dd6aa1679f6bec48eb`.
- Current source was copied into an immutable production selection. The private candidate changes only `systems/native_chat_hud.gd`: its existing phase probe listens to `--publication-completion-diagnose` instead of `--nwn62-chat-activation-phases`, allowing both existing diagnostics in the same replay. Production source was not edited for this gate.
- Candidate source signature `529c903c0dee948a5fb08efd2fafd84b91747678c65c6978fbcdb357e58c6a80`; accepted Core E engine SHA-256 `753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b`; generation-2 recording SHA-256 `1913892cd42db0f68dfa1b0edbdd37be4c380bdda50c95c178dc4ca2ba38a463`. Control and candidate have identical runtime, options, flags, and preference seeds.
- Run: `node tools/nwn62/chat-recorded-run.cjs` with `--headless`, `--profiling=false`, completion diagnostic, preview, and no steady/FPS window. Runner receipt: `.cache/nwn62/chat-recorded-a/run-receipt.json`; replay report: `reports/nwn62-chat-recorded-a.json` SHA-256 `380dcdd8e605f606d5418c012fb32c7041648f92e7b3f6f5a2357237768a82f8`; raw rows: `reports/nwn62-chat-recorded-a.engine.log` lines 20-21.

## Correlation and result

The final `but_chat_reply` callback and chat activation are one synchronous call chain: `prepared()` stores the last result and calls `activate()` before the completion service prints its callback tail. The recorded row has request ID 14, type 2002, decoder `actor-model`, epoch 1, and source SHA-256 `f45443550d53db695e0ad735908132b57b84e714602e1ee835b34e3b7ee8d503`. It matches the identity of the historical 58.915 ms row in `reports/nwn62-small-recipe-d-control-1.engine.log`.

| Current recorded-entry measurement | Time |
| --- | ---: |
| Completion callback / consumer | 16.865 / 16.814 ms |
| `activate()` total | 16.728 ms |
| Parse / construction and binds / placement | 1.126 / 9.420 / 4.620 ms |
| Radial `panel.add_child(context)` (inside construction) | 2.922 ms |
| Direct art/font binds (inside construction) | 2.649 ms |
| Refresh modes / font / final history / notification | 0.194 / 0.794 / 0.035 / 0.524 ms |
| Rows / panes / models / history calls | 0 / 2 / 14 / 2 |

`activate()` accounts for 99.5% of this run's measured completion consumer. Nested phase values are not additive with their parent phase. The historical control used the same request ID and asset hash but measured 58.915 ms consumer; its extra 42.101 ms did not recur, so this gate does **not** identify which activation leaf caused that outlier. The historical source selection is older and the historical run was graphical; the new diagnostic is headless. A further matched graphical diagnostic would be needed to attribute the 58.915 ms specifically.

The headless replay reached `ready=true` and `object_visuals_complete=true`; source and preference checks passed. The driver returned exit 1 because its strict native diagnostic gate saw the known root-certificate-store error. This does not invalidate the printed callback/activation correlation, but it is not an accepted replay performance result.
