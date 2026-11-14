# NWN-84 server-browser first-row assets

The browser's static cohort previously omitted the selection highlight and six row-caption fonts on each of its three tabs. Those bindings were created only when received server rows first appeared. The browser now binds one hidden original highlight and six original caption fonts per tab before sealing the installed-content cohort. The hidden bindings remain in the page owner; received rows use the resident textures and fonts.

The official Godot 4.7.2 OpenGL installed-content check ran on the secondary display without focus. `.cache/nwn84-browser-row-original-root-b.json` exited 0: all seven existing browser/dialog cohorts were ready with zero pending/failures, and first selected rows on Internet, History and Favorites used resident highlight textures and six applied fonts. The browser cohort now includes 290 image placements and 66 font placements, versus the prior 287 and 48. The check also exercised browser admission, missing-image isolation and password-dialog guards. No FPS or original-client visual comparison was made.

This closes first received server-row highlight/font preparation only. Later scrollbar thumb changes, portraits, item/effect/spell/action icons, post-NWSync screens and complete startup residency remain open under NWN-84.
