# NWN-62: selective light-template recipe E matrix

E is a private source overlay and is **not accepted**. It selects recipe capture only for eligible small templates with an original light feature; other small templates keep the packed route. The accepted engine, client default and broad D artifact are unchanged. The staged pair used accepted Core E engine SHA-256 `753b3e188068efaf865bda3abd6322ebe44e3a98ef2f5d199c8af1a78624c98b`, identical generation-2 recording, camera, settings and flags, and exactly two source differences: `model_template.gd` and `native_model_recipe.gd`. The profiler-on graphical order was candidate/control/control/candidate. Preflight passed with `clientStarts:0`; focused E graph/lifecycle 55/55, original tail-model 15/15, and light guards 3/3 had already passed.

All four legs reached 1,918 entities and 1,784/1,784 known base objects, with no pending/failed objects or world/script errors. The one recorded ready view appears broadly similar in control and candidate screenshots; this does not prove full visual parity. The strict driver exited 1 in every leg solely for the same shader-cache/root-certificate environment diagnostics while native world completion succeeded.

| Metric | Candidate 1 / Control 1 | Candidate 2 / Control 2 |
| --- | ---: | ---: |
| Largest small packed template | 37.968 / 55.825 ms | 22.083 / 559.027 ms |
| Largest template step | 38.189 / 56.440 ms | 22.642 / 560.173 ms |
| Largest terrain callback | 5.363 / 57.251 ms | 5.316 / 560.394 ms |
| First playable, candidate minus control | +42.642 ms | +97.203 ms |
| Known base complete, candidate minus control | +657.781 ms | +304.680 ms |
| Steady mean frame, candidate minus control | +0.570 ms | −0.006 ms |
| Steady p95, candidate minus control | +0.602 ms | −0.038 ms |

Candidate construction used 110/111 recipe templates and 600 recipe clones, versus 15 recipe templates and 401 recipe clones in controls. The remaining 417/419 candidate templates were packed; no candidate capture fallback was recorded. The selected light graph removes the observed several-hundred-millisecond *terrain/template pack* tail, but still adds total loading time in both pairs and gives no repeatable steady FPS gain. A different early asset-callback peak reached 610.387 ms in candidate 2 without a matching template-step peak (22.642 ms); its cause is not attributed to the selector from these reports and it prevents claiming that all entry hitches are solved. Do not promote E or move NWN-62 to review.

The next implementation choice should reduce recipe clone cost or narrow selection further using measured structural features, then recheck full loading and the callback tail. The offline original-scene replay is not live Arelith acceptance. Source and matrix receipts: `.cache/nwn62/small-recipe-e/source-receipt.json`; `.cache/nwn62/small-recipe-e-pair-a/staged.json` SHA-256 `771b855e99304262830995c255e6ae0588e3af7b86eecfda93894ab3775aed39`; `.cache/nwn62/small-recipe-e-pair-a/matrix-review.json` SHA-256 `17e8ca861a12b90986677c7ae980646b35b46a5ff2cb5db147ba02eb1efc045e`.
