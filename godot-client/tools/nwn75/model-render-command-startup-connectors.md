# Model render command CRT startup connectors

Pinned original `nwmain.exe` SHA256: `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. The [connector ledger](model-render-command-startup-connectors-ledger.json) joins three more model command table entries to the established CRT `_initterm` range `[0x140d7d790, 0x140d7fea8)`. `_initterm` reads each qword at `0x140ca3435` and guard-dispatches nonnull entries; evidence `ev_be6263d5a626b348111e5fe33735e08b8f215caba7b56f84dc5a088d9addfa92`, decoded read `ev_bd63eeb29844b19d2010e822c79bf4d020b191a3076f91b05c21cfcd530216e4`.

| Slot | Pinned qword bytes | Registration stub | Authored command effect after exact-name interpreter dispatch |
| --- | --- | --- | --- |
| `0x140d7daa8` | `8051014001000000` | `0x140015180` | `classification` can write `currentmodel+0x92`; a `door` classification later feeds conditional [Scene door fade](scene-door-classification-fade-material.md). |
| `0x140d7dab0` | `7052014001000000` | `0x140015270` | `ignorefog` parses an integer and writes zero to `currentmodel+0x93` only for value 1. The exact later consumer of this flag is not established here. |
| `0x140d7dac0` | `0053014001000000` | `0x140015300` | `setanimationscale` parses a float (initial value 1) and writes `currentmodel+0xcc`; later live animation admission is separate. |

Pinned byte evidence respectively `ev_fee4aa696c0e17cfbe16c79a031ad1eb1a7d061255f38b897da884764b67d33c`, `ev_b0434f7d8cd07e9dc1ba78922fa1b8518db1fbbaee5f2809d6c61a6ae4cc12df`, `ev_84b6effec38e3bd9b5f0dca2b26e515de4a617e59609c5011c08486dae7bec36`. The [command-holder continuation](model-text-other-command-holders.md) already proves each stub's literal name, holder registration, dispatch type and field effect. These new edges establish startup admission, not that a particular MDL includes the command or that it runs in a frame. The `ignorefog` consumer and animation-scale effect on later model/Part clocks remain precise open boundaries.
