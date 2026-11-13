# NWN-61 entry menu owner split, source candidate

The six-run current-source entry-budget matrix recorded `menu:keys` up to 19,476 µs and `menu:video` up to 12,519 µs inside a nominal 4,000 µs commit budget. The two 4 ms runs had ACK maximum steps of 19,509 and 12,553 µs. These are indivisible child-page `configure()` calls in the staged entry continuation. The earlier 54.116 ms functional frame report predates this exact attribution and cannot itself be assigned to these calls.

This candidate keeps the public synchronous `configure()` bodies and request order. Entry-only `begin_entry_configuration`/`entry_configuration_step` move the video owner's setup into eight units and key owner's into ten. Each asset request is one unit. The main menu stays in its video or keys phase until the child completes, then installs modal order, signals and any ready page publication. A child callback arriving between units may store data but cannot build the page until setup completes. Closing a partial owner invalidates its token; main-menu cancellation retires its asset scope.

The exact pre-edit sources are pinned at:

| File | Pre-edit SHA-256 | Frozen source |
| --- | --- | --- |
| `systems/native_main_menu.gd` | `2d111f9391bcef8e43fd736aa2963c9d6f19691757e7c4a1227d26c049a064d4` | `.cache/nwn61/core-entry-split-a/candidate-input/systems/native_main_menu.gd` |
| `systems/native_video_options.gd` | `964668aedbdc8b62b86ebeb8c8604db27ab2668b8466165a76c95adc4e021087` | `.cache/nwn61/tail-entry-d/candidate-input/systems/native_video_options.gd` |
| `systems/native_key_settings.gd` | `b573e74e09e38d0855b4faa700a34a7820305d3a17a83c7cc09837c607b89c14` | `.cache/nwn61/tail-entry-d/candidate-input/systems/native_key_settings.gd` |

The focused source-only diff is `entry-menu-owner-split.patch` beside this note. Current source hashes are captured in `.cache/nwn61/entry-menu-owner-split-c.json`.

The light headless fake-catalog check passed **22/22** assertions. It compared synchronous and staged request order/state, completed the real main-menu continuation, checked publication signal setup, rejected completed/cancelled tokens and observed asset-scope retirement. Its keys owner had six requests and ten setup units; video had four requests and eight units. The fake-catalog diagnostic maximum was 52 µs for keys and 162 µs for video in that run. These small times do not predict original-asset or live frame cost. The engine printed unrelated log-file and Windows root-certificate diagnostics, while the fixture wrote a successful report and exited normally.

The candidate still needs a matched original-asset entry replay and Arelith check before any live hitch or FPS conclusion. The split can reduce maximum single commit work but adds scheduler calls; it is not a total-work reduction.
