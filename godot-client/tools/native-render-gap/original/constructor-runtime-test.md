# Original model constructor runtime test

Tested 2026-11-12 against the installed `nwmain.exe` at `C:/Program Files (x86)/Steam/steamapps/common/Neverwinter Nights/bin/win32/nwmain.exe`, SHA-256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. This is byte-identical to the original binary used for the NWN-75 call tree. The executable ran with `bin/win32` as its working directory and a private `-userdirectory` under `.cache/native-original-constructor`. No installed executable or asset bytes were modified.

The CDB probe stops at original `NewCAurObject` (`nwmain+0x931f0`). The ordinary startup run observed eight successful GUI-model calls, including `GUI_mouse`, `empty`, `GUI_radialband`, and `GUI_ICON_0X0L`. For the tile test, the probe changed the input resref of its fifth and sixth calls **in the private process** to `tcn01_a01_01`, the exact installed tile used by `tests/nwn75_direct_model_prep_benchmark.gd`. It then stepped to each return and read the returned Gob's Model pointer at `+0x68`. The same Model pointer appeared in both Gob objects in the final run, confirming Model object reuse across these constructions. A separate probe stopped at `CreateInstanceTreeR` (`nwmain+0x8dab0`), let the recursive call return, and observed a nonnull Part root.

| Run | First `NewCAurObject` (ms) | Second, same model (ms) |
| --- | ---: | ---: |
| a | 2.5412 | 0.5082 |
| b | 3.0668 | 2.6205 |
| c | 4.1113 | 0.5129 |
| d | 5.1769 | 1.5276 |
| e | 5.1051 | 1.0201 |
| f | 4.6132 | 1.0137 |
| Median | 4.3623 | 1.0169 |

These are **debugger-observed wall times**, not native microbenchmark times. Each measurement includes breakpoint handling, debugger scheduling, and the return stop. The separate recursive tree observation was 0.5058 ms; even an `empty` GUI-model call measured 0.5067 ms, showing a roughly 0.5 ms observation floor in some runs. The variable second-call timings also show that these figures must not be used as a native/Godot speed ratio. The first call includes resource demand/parse, Model creation, Gob/Part creation, postprocess, and material setup. The second reuses the Model object, but the static `LoadModel` path may still parse and discard duplicate model data. `CreateInstanceTreeR` covers recursive Part construction and initial control only; it excludes the other work in `NewCAurObject`.

The existing Godot headless test on the decoded tile reported 17.190–19.420 ms for 32 PackedScene placements **including one template build**, 57.648–61.255 ms for 32 fresh direct GDScript constructions, and 40.124–40.940 ms for the recipe path. Those tests start from decoded data, run different publication work, and create 32 placements rather than two debugger-stepped Gob objects. They establish that the fresh direct GDScript builder is slower than the current PackedScene path in that client fixture, but do not establish a numeric gap to the original constructor.

Evidence: `.cache/native-original-constructor/constructor-probe.log`, `constructor-tree.log`, and `constructor-cached-a.log` through `constructor-cached-f.log`. `constructor-cached-f.log` records equal Model pointers and distinct returned Gob pointers. Reproduction scripts: `constructor-probe.ps1`, `constructor-probe.cdb`, `constructor-tree.cdb`, and `constructor-cached.cdb` in this directory.
