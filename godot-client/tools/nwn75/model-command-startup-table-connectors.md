# Model command CRT startup connectors

Pinned original `nwmain.exe` SHA256: `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. The [connector ledger](model-command-startup-table-connectors-ledger.json) joins three model command-registration table slots to the previously mapped CRT `_initterm` loop. This is initialization work, not a repeated model-load or render-frame cost.

The CRT startup path calls `_initterm` `0x140ca3400` at `0x140c11a77` with `[0x140d7d790, 0x140d7fea8)`. `_initterm` reads each qword at `0x140ca3435` and guard-dispatches a nonnull pointer at `0x140ca343d` (`ev_be6263d5a626b348111e5fe33735e08b8f215caba7b56f84dc5a088d9addfa92`; decoded read `ev_bd63eeb29844b19d2010e822c79bf4d020b191a3076f91b05c21cfcd530216e4`). All three exact slots lie in that range and are nonnull in the pinned image:

| Slot | Original bytes | Stub | Command |
| --- | --- | --- | --- |
| `0x140d7da90` | `d052014001000000` | `0x1400152d0` | `newmodel` |
| `0x140d7daa0` | `5051014001000000` | `0x140015150` | `beginmodelgeom` |
| `0x140d7dab8` | `3053014001000000` | `0x140015330` | `setsupermodel` |

Pinned slot evidence: `ev_2e4bf0cbf57601193c292ca4e9963276d115145bf950a1f42bb6827239210fd0`, `ev_37b107281eba6c2e67c24177b8eca64d8669a6c533b0aa2335a03e009c5ce0ba`, `ev_6f8ef3d73a1c805a4afc73036ed8f3d2bfb079520ee1a1d2740fd64623f512e9`. The [two core command holders](model-text-command-registration.md) and [other model command holders](model-text-other-command-holders.md) already record each stub's name, ConsoleFunc registration and conditional interpreter dispatch. `setsupermodel` can call `FindModel` for a named parent model, then conditionally store/AddRef that reference; it does not imply a recursive demand on every model. Startup/registration success, exact text token and model cache hit remain gates. No external callback or active-frame usage is inferred from table membership.
