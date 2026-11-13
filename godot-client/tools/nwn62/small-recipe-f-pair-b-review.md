# NWN-62 targeted small-recipe F: paired original-scene review

Status: private candidate; do not promote to the accepted client. The source-pinned pair B ran candidate/control/control/candidate with profiling and 5-second steady windows. The user had another game open during measurement, so frame and loading comparisons are preliminary. The control was the immutable accepted-source E control without the unpromoted NWN-61 menu split. Both paths used Core E, the same generation-2 recording, settings, camera and flags. Stage receipt: `.cache/nwn62/small-recipe-f-pair-b/staged.json` SHA-256 `1e5ab8a43eb9ce7465b1207581e02455a215309a1a2dfad4e502ed02ad4755fb`.

| Leg | First playable ms | Known base complete ms | Mean frame ms | p95 ms | p99 ms | Recipe templates | Recipe clones | Max small pack ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| F 1 | 5308.334 | 22114.131 | 9.3226 | 9.924 | 20.808 | 20 | 427 | 18.065 |
| Control 1 | 5133.605 | 21066.922 | 9.2730 | 9.795 | 20.782 | 15 | 401 | 94.150 |
| Control 2 | 4683.702 | 20362.796 | 9.2258 | 9.703 | 20.528 | 15 | 401 | 646.519 |
| F 2 | 4405.028 | 20440.535 | 9.3903 | 9.993 | 20.752 | 20 | 427 | 37.841 |

Paired F minus control: known base completion +1047.209 and +77.739 ms; mean frame +0.0497 and +0.1644 ms; p95 +0.129 and +0.290 ms. First playable changed +174.729 and -278.674 ms. F avoided the observed long `PackedScene.pack` tail in these runs but added 5 recipe templates and 26 recipe clones. This proves a narrower pack operation was removed, not a reduction in total CPU work or an FPS gain.

All four native runs succeeded with 1,918 entities, 1,784/1,784 known base scenery resolved, zero failed scenery or object errors, complete object visuals, matching source/runtime pins and 5-second steady windows. Each strict replay wrapper exited 1 solely with the same shader-cache and root-certificate sandbox diagnostics; engine logs contain no other ERROR, SCRIPT ERROR, FATAL or lifetime message. Reports: `reports/nwn62-small-recipe-f-b-{candidate-1,control-1,control-2,candidate-2}.json`; performance streams carry the pack maxima.

Next: inspect the 26 recipe-clone overhead and loading critical path before considering another candidate. Repeat the tight paired run without a competing game and add visual/Arelith acceptance before any default change. NWN-62 remains In Progress.
