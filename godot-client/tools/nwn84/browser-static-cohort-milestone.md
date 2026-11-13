# NWN-84 static multiplayer cohorts

The multiplayer entry, three constructed server-list pages, Direct Connect, Player Profile with its hidden OK notice, Filters, Details and password prompt now each have an independent installed-content admission gate. `constructed_ui_cohort.gd` freezes the control tree after its GFF/2DA/model jobs finish and records exact painter model keys for static images and button clips, bound bitmap-font names, and the initial scrollbar rail/thumb requests. A screen opens only after its own captured textures and fonts are published or reports its own missing key. Godot's untagged internal `ScrollContainer` adornments are excluded; client-created images carry source keys. The selected browser page and each dialog remain hidden while their cohort is pending. A 50 ms timer stops after all static cohorts are ready or failed.

At first admission, a non-null texture counts only when it is the texture published for the captured key. An initial scrollbar thumb retarget must publish its current key before admission. After admission, scrollbar thumb/rail changes and received server rows are separate state/arrival cohorts and cannot make the static receipt permanently cold. These dynamic cohorts remain NWN-84 work; this milestone does not claim all UI or icons are preloaded.

Installed-content graphical run on official Godot 4.7.2 OpenGL Compatibility, secondary/no-focus, through actual `ServerBrowser.configure_native`: `.cache/nwn84-browser-delayed-a.json` passed in about 9 seconds. Every named cohort had zero pending and zero failures:

| Cohort | Models | Constructed image placements | Fonts |
| --- | ---: | ---: | ---: |
| Multiplayer entry + hidden confirmation | 3 | 34 | 9 |
| Server browser panel + three pages + game types | 26 | 287 | 48 |
| Direct Connect | 4 | 15 | 7 |
| Player Profile + hidden OK notice | 7 | 26 | 10 |
| Filters | 5 | 28 | 7 |
| Details + game types | 10 | 81 | 35 |
| Password prompt | 3 | 10 | 4 |

The same run opened each owner, proved the controller displays the browser only when its cohort is ready, injects a failed browser image to show the exact key while hiding only that page, and restores admission. With the selected row requiring a password, a cold password image disabled Connect; a direct join attempt sent no join, and back/view change before readiness did not queue one. `browser_cohort_gate_test.gd` passed 9/9: per-screen missing-image and font isolation, exclusion of a later dynamic image, exact initial texture identity, and static admission stability after a later thumb change. The installed-content graphical run is a readiness check, not FPS or original-client visual parity.

Existing graphical interaction tests were updated only to wait up to 15 seconds for the exact screen cohorts they use before clicking. Their original activation/action assertions passed: `native_multiplayer_entry_test` 35/35, `native_server_pages_test` 32/32, `native_direct_connect_test` 35/35, `native_server_details_test` 31/31, `native_server_filters_test` 23/23, and `native_player_profile_test` 809/809. Unchanged fallback `server_browser_test` passed 22/22 headless. Reports are in `.cache/nwn84-*-updated.json` and `.cache/nwn84-server-browser-fallback.json`; the installed source receipt is `.cache/nwn84-browser-delayed-a.json`.
