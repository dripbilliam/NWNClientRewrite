# Native context mouse cursors — partial parity

The live native world now connects `world_input.cursor_action` to
`native_mouse_cursor.gd`. The owner loads original TGA resources through the
active native catalog/worker decoder. It does not use the legacy JS image
request path in `server_cursor.gd`. This is a cursor and target-input milestone;
the entire UI goal is still active and incomplete.

## Original evidence

The original client SHA256 is
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Reduced REA dossiers are under `../backups/animations/`:

- `rea-native-cursor-init-v1.json`: initializer14083a2c0 supplies fixed17-byte
  resource-name slots. IDs1..58 are29 up/down pairs;59..90 directional run/walk;
  91/92 pickup;93..292 custom00..99 up/down. Slot0 is empty. The apply guard
  accepts293, but the named resource array ends292: no invented filename.
- `rea-native-cursor-policy-v1.json`: apply14083b3e0 selects an odd ID's next
  image only when both press flags are set. Directional callers must disable
  pressed pairing; the apply function has no special directional-ID exception.
  Hardware publication uses32*scale square, corner hotspot or16*scale center,
  original32bpp TGA rows reversed before SDL upload. Inventory hover881f20/
  882000 uses centered91; inventory drag881b00/881bf0 uses centered92.
- `rea-native-cursor-followup-v1.json`: creature/self/player helpers and the
  `cursors.2da` table member store at1402b6446 (`[RBX+0x1e0]`). The loader's
  bounded bytes around1402b6401 reference the `cursors` string, then store that
  member. Consumer86f6a0 reads physical BYTE row `displayType`, columnCursorID,
  into trigger+19c. ResRef is not a global enum-to-filename replacement map.
- `rea-native-cursor-targets-v1.json`: CActionTarget and spell704720/predicate
  704640, feat703310, item703ea0/7039f0, skill702c30, script98d5f0. Spell masks
  distinguish self1, other creature2, ground4, item8, door16, placeable32,
  trigger64. Valid spell cursor29/failure31; spell-backed feat failure39.
  Skills use37/39. Lock/trap/healing tools use41/43,33/35,55/57. Script target
  mode supplies its own valid and invalid cursor IDs and a different object mask.

`scripts/inspect-native-mouse-cursor.py` executes unchanged initializer,
software selection and forced press/release instructions with explicit captured
external boundaries. Observations contain293 names,2336 selection cases and32
press/cache cases. `scripts/inspect-native-target-cursor.py` executes unchanged
spell setup/predicate for128 masks and script setup for1024 masks. These
oracles do not open a game, connect to a network, or use process memory.

## Native behavior

`systems/native_data/mouse_cursor.gd` owns names, pressed selection, geometry,
physical trigger table lookup, common received-object cursor projection and
the target-mask policies. Native rules come from each active server's tables;
no stock spell or feat list determines the target masks. The existing parser's
`replicated.light.field260` is the custom cursor alias used by the earlier
reference client; its exact original reader-field mapping still needs an
independent receiver execution check.

The cursor owner prepares the92 small stock TGAs independently of the full
rule-table gate. Custom images are demand loaded from the current catalog,
including overridden stock artwork. Separate owners cannot share missing-image
decisions across catalogs. Images must be original32bpp TGA; generated cursor
textures are bounded to128 cache entries. Missing images temporarily use the
native arrow. Unchanged fallback selection does not re-publish each frame;
completion never directly publishes a stale hover image.

The owner applies an OS cursor only while the game window has focus, allows
focus, and contains its pointer. It never activates a window, captures, moves
or warps the physical pointer. Camera cursor visibility remains under camera
ownership. Focus loss, session retirement and shutdown release custom cursors
and join all workers. Tests inject publication instead of altering the OS cursor.

Inventory/store/trade slots share centered pickup hover and drag selection.
When targeting, slots use their received item ID and current repository view;
a valid click goes through the canonical `native-cast`, item/feat/skill or
`native-script-target` owner rather than selecting/moving the item. Invalid
targets remain in selection mode. World targeting now also suppresses invalid
target submission. Right-click cancels targeting over a menu. Script valid/
invalid cursor IDs are preserved in the native desktop's target state.

`callback_mouse_cursor` measures per-frame cursor work, and
`gameplay_ui.mouse_cursor` records prepared/pending/missing images, failures,
publications and selection. This is diagnostic coverage, not an FPS claim.

## Verification and remaining gaps

The scoped native tests are `native_mouse_cursor_test.gd` (original pixel rows,
names/press oracle, scaling/hotspots, stock/custom catalog isolation,
stale completion, slot lifetime and cleanup) and `native_target_cursor_test.gd`
(original mask/predicate oracle, active table changes, native viewport input,
request payloads, world invalid targets and cancellation). Cursor atlas and
scale PNGs were visually reviewed. HUD startup with a held feat worker and
owned loopback authoritative gameplay are separate integration checks. See
`reports/native-mouse-cursor-acceptance-v1.json` for final source-pinned receipts
and the verified rollback checkpoint. No automated public connection is used.

The following remain unverified or incomplete; this is not full cursor/UI parity:

- Exact original associate/master/dead/DM and inventory-holder cursor rules,
  directional click-steering arrows, map pushpin publication and other modal
  action cursors. Current common creature policy distinguishes controlled self,
  listed players, hostile actors and ordinary NPCs; it is not all native cases.
- Exact shipped SDL scaling filter and mouse-scale override option. Native
  publication currently uses nearest resampling and GUI scale. At exceptional
  scales above8, hardware images/hotspots are bounded to Godot's256px limit;
  original-sized software cursor publication is still required there.
- Original source cursor0/293 behavior and malformed/missing-image retention,
  complete GUI target classification, spell range/LOS/additional callbacks,
  targeting every auxiliary GUI widget, and full original-client live comparison.
- Automated tests use injected cursor publication and synthetic viewport input;
  they do not prove hardware pointer appearance in the user's live session.
- The original initializer/press oracle skips SDL and the full targeting input
  owner; the target oracle captures lookup/preview/registration boundaries.
- Main menu/lobby cursor ownership and all inventory/store/trade item radial
  layers/actions still require completion. Their existing generic/limited item
  menus are not certified by these cursor tests.

The original game/manual replacement sessions remain preserved. A replacement
client restart is needed to use this build; no restart is performed automatically.
