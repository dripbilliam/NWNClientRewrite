# Native key editor and editable hotbar bindings

In-game Options now opens the original Change Key Settings frame, source tabs,
rows, bitmap fonts and native scrollbar. Its Game tab appends a separate
Hotbar key bindings section with all36 slots. Click a row to assign; right-click
a hotbar row to clear it. Existing F1–F12/Shift/Ctrl defaults remain available.

The shared native binding owner routes implemented movement, camera axes,
highlighting, menu actions and hotbar keys. Preferences live in the replacement
layout configuration's `Keymapping` and `HotbarKeymapping` sections; original
profiles and server shortcut contents are never rewritten. Close/OK and X
commit; Cancel and Escape discard; Defaults remains pending until committed.
Saved positions and other configuration sections survive a binding update.

All36 hotbar slots accept physical keys and Shift/Ctrl/Alt/Meta combinations.
Assignment clears matching bindings across hotbar slots and normal actions.
Unchanged F-key defaults preserve active-page aliases and Ctrl precedence.
Custom key text appears on the actual native quickbar. Text-entry focus
suppresses shortcuts. Capturing an assignment suppresses movement, camera,
highlight, quickbar and radial keyboard paths, and clears previously held keys.
Browsing the editor still permits movement and outside-menu mouse input.

The [original research](NATIVE-KEY-SETTINGS-RESEARCH.md) remains the source for
the four-page native behavior. Editable hotbars and cross-action conflict
handling are the user's requested extension. The original table/oracle is not
changed to pretend that these extra bindings were editable in the binary.

## Verification and limits

Native logical-viewport input checks cover all36 original hotbar keys and all36
rebound slots through the real quickbar request signal, transaction/capture
behavior, conflicting actions, private persisted preferences, mapped drive flags,
camera/highlight ownership and suppression of an already-open radial wheel.
Actual pointer/key checks cover the Options child, original source artwork,
fonts, tabs, rows, pending feedback, Defaults/Close/X/Cancel/Escape, window
dragging, retained placement, source-caption line endings and scope retirement.
These tests do not move the OS cursor or steal focus.

The owned original server check at127.0.0.1:5125 verifies reassigned movement
against received server positions and casts an assigned spell using a custom
hotbar key, consuming an authoritative prepared use. Rebinding and restoring
the key preserve the exact received shortcut contents. All146 local action
checks pass; broader UI regression receipts and their source hashes are indexed
by `tools/audit-native-key-settings.mjs`. Failed test callback/diagnostic exports
remain retained and excluded. A verified rollback archive accompanies the audit.

**Complete key/UI parity remains unfinished.**28 source actions have no installed
input/action route yet (including advanced camera endpoints, directional radial
keys, GUI/quickchat/save/DM actions and inventory tab keys). Their rows remain
visible but disabled with explanatory tooltips. Other role/state/custom-resource
variants, native-client visual/gesture comparison, pregame integration, every
possible chord/OS-reserved-key interaction and supported scale comparison remain
open. No claim of full UI completion or menu-prebake performance is made.

## Next user-required UI work

1. Add a **separate Prebake UI option**, independent of model/world preparation.
   Prepare and persist original GUI artwork/states/fonts before play, expose
   progress and cancellation, and reuse it on later launches. Source/resource
   identity must invalidate changed HAK/override/NWSync UI assets. Opening a
   prepared menu should show its frame immediately and refresh current data.
2. Restore original context mouse icons for movement, targeting and invalid
   targets, doors/transitions/interactables, item operations and drag states.
   The current live Godot pointer still uses generic fallback shapes. The old
   JS resource/policy code is reference only; cursor decoding/selection must
   be native and use the active catalog.
3. Replace the inventory item popup with the original wheel, enable the store
   item right-click wheel, and finish trade-item wheels. Preserve actual
   server requests and state/role/context availability, stale-item/merchant/
   trade validation and window-front input. The existing trade wheel is minimal;
   the inventory uses a generic popup and store right-click is suppressed.

The current scene's `native_item_icons.gd` caches rendered GUI textures in memory;
explicit model prework can save only already-opened UI packets. A complete
standalone UI bake still needs discovery of unopened GUI resources, original
programmatic controls and variable/generated frame variants, persistent native
pixels/bounds/font resources, consumer cache checks and cold-launch validation.
The existing data-only headless model worker cannot render GUI textures merely
by renaming a model-preparation button. Implement the separate path before
exposing it as a working option.
