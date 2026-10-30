# Original Examine frame and authoritative Identify — partial parity

Follow-up: [original scrollbars and GUI vertex animation](NATIVE-SCROLLBAR.md)
now replace the generic scrollbar in these two frames. This document retains
the earlier Identify checkpoint; its remaining-work list describes that point.

The native client now loads the active `EXAMINE_BASIC` and `EXAMINE_ITEM` GUI
resources and their original models. Panel bounds, title, X/Close/Identify
buttons, description rectangle and Icon hook come from those resources.
Original item rasters keep their proportions; creature portraits use the
original 64×100 image region. Existing server text, colors, asynchronous
property and portrait revision guards remain in use. This is a scoped UI
milestone, not full Examine or UI parity.

## Evidence and behavior

Read-only original NWN EE executable SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original constructors/importers, description formatting, Identify callback and
item reply handler are retained in workspace-level
`backups/animations/rea-native-examine-layout-v1.json`. Additional original
examine request, server item reply and Lore routines are retained in
`rea-native-examine-authority-v1.json`. These are static original-binary
observations, not live original-client execution oracles.

- Identify callback `140898d30` sends merchant Identify **7/7**, followed by
  a fresh examination **6/5** through original sender `1407bfa80`.
  The protocol service now preserves that sequence without predicting an item
  identification flag, property list or gold charge.
- Original server `UseLoreOnItem` (`1403aa210`) checks active skill availability,
  effective Lore and `skillvsitemcost.2da` `DeviceCostMax`. Cheap items may be
  identified free merely by examining them. An unidentified test item is not
  sufficient evidence that the paid button should stay enabled afterward.
- Identify requires the current merchant generation, current actor/area/session,
  a real carried/equipped item, a received unidentified state, an available fee
  and enough received gold. Original fee text uses TLK `10c3d`, local custom
  token 0; insufficient-gold text uses `14b3b` in red. Scoped substitution does
  not mutate server tokens.
- Pending requests cannot duplicate. Fresh authoritative item examination,
  refusal, timeout, merchant closure and changed scope retire the waiting state.
  A stale open header cannot reactivate the explicitly retired merchant
  generation. Closing the merchant leaves Examine open without Identify.
- The store's fallback Identify action remains available if the original
  Examine resources cannot be prepared; it is hidden when the original
  Examine owner is ready. Native worker/icon callbacks retire on close.

`systems/native_examine_frame.gd` owns the original frame and context guards;
`native_data/examine_layout.gd` validates its active resource geometry.
`server_examine.gd` retains the content and asynchronous state owner.
`electron/network_game_session.mjs` contains only the existing protocol path;
all of this UI and artwork rendering is native Godot.

## Verification at this checkpoint

- `native-examine-ui-v4`: **30** graphical checks with injected native pointer
  input, original resources, icon and creature portrait, server color spans,
  fee/refusal/timeout/duplicate/stale-generation/session reset cases, dragging,
  Close and worker retirement. Item and creature PNGs were visually inspected.
- `native-examine-identify-final-v2`: **99** checks against an isolated owned
  original server at `127.0.0.1:5125`. Cheap item identification is free by Lore;
  installed original `x2_c3_wswmbs006` remains unknown, then the actual Identify
  control causes the original server to reveal that exact item, return a fresh
  examination, and deduct the exact fee. No private key is in test artifacts.
- `native-examine-text-final-v1`: **1,025** native text checks.
- `native-examine-playability-final-v1`: **1,314** headless regressions.
- `native-examine-store-regression-v1`: **28** graphical merchant checks.
- `native-examine-inventory-regression-v1`: **157** graphical inventory checks.
- `native-examine-barter-regression-v1`: **28** graphical barter checks.
- `node --test test/network-identify-refresh-native.test.js
  test/network-store-native.test.js`: **5** protocol groups, including exact
  request order, stale context rejection and no predicted state mutation.

Native runs were source-pinned, debugger armed, exit 0, no native exception or
script/lifetime error; local gameplay retired with zero workers. No public
server connections. Final-v1 preserved a failed transient blood-particle pixel
comparison after its Identify checks passed; it is not accepted evidence.
The repeat final-v2 passed that unchanged regression and all remaining checks.
Earlier failed UI/session-fixture experiments are retained, not relabeled as
acceptance. The first additional scope test incorrectly used a delta update to
change epochs; the final test uses the real full-session reset path.

The isolated `GodotIdentify2` module is opt-in for the standard action test;
other fixture variants retain their older immutable `GodotActions` module.
Original item cost is 557850 GP, UTI SHA256
`0b250c8f8d56e1e2763ea9b75a69afdf5df4d918eef1562fdb0719668b7b90ab`.
No original item definitions or character skills were altered to force success.

## Remaining parity work

The description still uses generic fact rows rather than every original
item/armor/stat/property/level/cost/charge formatting rule and localized label.
At this checkpoint the visible scrollbar was still a Godot scrollbar (replaced
in the follow-up above). Original font selection,
supported UI scales, all target/role/context and asynchronous failure variants,
Escape/topmost ordering, range dismissal and original-client comparison are
not fully accepted. Keep `full_examine_parity` false.

Shared scrollbar research is retained in `rea-native-scrollbar-v1.json` and
`reports/native-scrollbar-resources-v3.json`. The original attaches
`scrollbar_simple` to `scrollmin`, stretches toward `scrollmax`, samples
`size` at `(rounded_pixels - 3) / 30`, samples `thumbsize` with a minimum 3.01
pixels, and sets this edit's thumb to 20 pixels. Arrow models attach to `up`
and `down`; the thumb travels between `min` and `max` minus its own size with
pixel rounding. The centers use animated mesh vertices and UVs (initially mistaken for skins),
so stretching a single screenshot discards original cap/UV/deformation rules.
Original rail/thumb/arrow textures and all active resources must be respected.
The later original-node audit corrects the earlier "skinned" description:
the centers use animated vertex/UV samples, covered by the follow-up.

Rollback: `backups/native-examine-identify-v1.zip`, verified by
`tools/audit-native-examine.mjs`. General porting remains deferred under
`NATIVE-UI-PARITY-GOAL.md`.
