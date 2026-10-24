# Character-selection exit: NUI draw-list fill conversion

The user-directed Arelith session in
`reports/public-browser-1792868454764.json` closed during `area-loading`,
following character selection. Its engine log records repeated
`Invalid call. Nonexistent 'bool' constructor` errors at
`systems/nui_canvas.gd:40`. The host intentionally stopped on the script error;
the native exit was 0, shutdown was graceful, and all reported retired owners
were released. This incident is distinct from the still-unresolved historical
native access violations. The log did not retain the offending fill value's
type, so null versus string/container is not established.

`NuiService.draws` now resolves each literal/indexed binding's fill using the
existing JS renderer's truthiness and sends an actual boolean to Godot.
`NuiCanvas.draw_fill` also accepts previously projected raw JSON values,
including null, nonempty strings and empty arrays/dictionaries. It does not use
GDScript's narrower `bool(...)` constructor. Other draw properties and the
host's script-error detection remain unchanged.

Validation, using authored layouts and no public connection:

- 25 Node tests passed across `nui-service.test.mjs`,
  `nui-session-input.test.mjs` and `test/network-nui.test.js`.
- `reports/nui-draw-fill-v1.json`: 49 native Vulkan checks passed. Actual
  production NUI controls render both normalized projections and raw legacy
  values; pixel reads verify filled interiors and unfilled outlines for all
  12 cases, followed by window/resource retirement.
- `reports/nui-draw-fill-v1.cdb.log`: debugger armed, no trapped native exception.
  Engine log has no script errors or ObjectDB/resource leak warnings.
- Main regression script passed the pinned runtime's compile check.

The reopened public browser is for a user-directed retry. Successful admission
and complete public-world loading after this fix remain to be observed; local
regression evidence does not establish that acceptance.

## Follow-up: nullable numeric fields

The next user retry, `public-browser-1792868798724.json`, passed character
selection and reached the protocol's playing state, but no native world load
completed. It then closed on the same canvas's `float(line_thickness)` call.
The first fix covered only fill and was insufficient. Its shutdown again was
graceful with native exit 0; the log does not identify the invalid value type.

All numeric draw fields now pass through finite projection in
`tools/nui-draw-values.mjs`, preserving nullish defaults for thickness/order,
coordinates, curves and enum fields. The canvas independently checks raw
legacy fields before float/int conversion, including chart points/colors.
Malformed containers use numeric defaults rather than constructor exceptions.
Non-finite values cannot reach a Godot numeric constructor. Native integer
fields are additionally bounded to signed 32-bit range.

Follow-up evidence:

- 26 Node tests pass, including indexed fills and nullable/structured numeric
  input projection.
- `reports/nui-draw-fill-v2.json` / `.debugger.json`: 51 Vulkan checks pass,
  no debugger exception or script/lifetime errors, tested sources unchanged.
  All eight primitive paths render; normalized projections and raw nullable
  input produce byte-identical pixel buffers. Main game compile check passes.
- The broader existing `nui_ui_test.gd` completed its 15 assertions, but
  **the run failed overall**: CDB trapped a native access violation after the
  report was written. See `reports/nui-draw-ui-v1.debugger.json` and `.cdb.log`.
  Do not promote this to a clean NUI/stability acceptance. The captured stack
  currently lacks useful function symbols; its relation to older native faults
  remains unproven. The script-conversion fixes do not resolve that fault.

No automated public-server connection was used for either regression suite.
