# NWN-61 menu-entry split: original-asset replay checkpoint

Pinned private pair `.cache/nwn61/entry-menu-split-pair-a/pair.json` (SHA-256 `915e8b275946132631e78f5d68f19afeeea0d0ed1a0aa4ada6b213e76a7abd3d`) uses the accepted Core E engine, original generation-2 recording, identical settings, flags, seeds and 2,392 source pins. Only `native_main_menu.gd`, `native_video_options.gd` and `native_key_settings.gd` differ. The menu candidate is present in the working source but is not promoted to the accepted client selection.

The exclusive graphical sequence was candidate/control/control/candidate. The first candidate process exited `0xC0000005` after a partial timeline. Its cause is unknown. Both controls and the second candidate completed the timeline; one further candidate rerun also completed. All four complete runs reported native gameplay success, 1,918 entities, 1,784/1,784 base scenery, zero pending batches and zero world errors. Their outer drivers exited 1 because of shared shader-cache/root-certificate diagnostics, despite native success. The crash leg is excluded from timing comparisons but remains an acceptance blocker.

| Complete run | Video setup max (us) | Key setup max (us) | Entry step max (us) | Playable (ms) | Known base complete (ms) | Steady mean / p95 (ms) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Control 1 | 811 | 658 | 6,103 | 4,356.665 | 17,577.308 | 7.353 / 7.793 |
| Control 2 | 739 | 634 | 5,672 | 3,747.312 | 17,243.666 | 7.407 / 7.904 |
| Candidate 2 | 285 | 166 | 6,761 | 3,909.968 | 17,439.187 | 7.583 / 8.210 |
| Candidate 3 | 234 | 190 | 5,601 | 3,698.313 | 17,041.484 | 7.326 / 7.787 |

The split consistently shortened its own menu setup calls in completed runs. It did not consistently shorten the largest whole entry step, and the steady frame results straddle the controls. This is bounded work per entry frame, not a demonstrated FPS or total-work saving. The earlier six-run budget matrix saw 12–19 ms unsplit menu calls; neither control leg in this pair repeated that tail, so this pair does not prove the larger hitch was eliminated. Keep NWN-61 In Progress and the candidate unpromoted while the `0xC0000005` startup is investigated. A live Arelith test is useful only after a stable, source-pinned candidate replay.

Reports: `reports/nwn61-menu-split-c-{candidate-1,control-1,control-2,candidate-2}.json` and `reports/nwn61-menu-split-d-candidate-3.json`; SHA-256 values and order are retained in `.cache/nwn61/entry-menu-split-pair-a/matrix-partial{,-d}.json` and the driver logs beside them.
