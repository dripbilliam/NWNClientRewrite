# Procedural duration lights and model controllers

Target: read-only NWN:EE89.8193.37-17 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
No installed asset/binary changes or Ghidra annotations. Evidence captures are
under `backups/animations`; proprietary model/texture/shader files stay in the
installed archives.

## Original owners and observations

- Client visual loader14096cf10..14096ed64 reads active VISUALEFFECTS
  `ProgFX_Impact/Duration/Cessation` into WORD+d0/d2/d4. Attachment owner
  14096ed70..14096f6dc selects these according to phase+fa. Full assembly:
  `native-client-visual-loader-asm.txt`, `native-client-visual-postloader-asm.txt`.
- Type lookup14096c340 reads active PROGFX.Type. Dispatcher14096a110 uses
  its jump table14096a53c; Type4 calls14096a570. Model loader14096c8e0..
  14096ccb0 Type4 branch14096cb93 queries Param7 and loads that resource
  with Aur loader1400931f0, debug label fx_light. Captures:
  `native-client-visual-program-methods.txt`,
  `native-progfx-type4-and-type-query-asm.txt`.
- Complete Type4 owner14096a570..14096a996 queries animation Param1,
  FLOAT speed Param2, INT shadow toggle Param3, BYTE Param4 into+10c,
  INT Param5 into+110 and INT Param6 for controlled-creature vision GUI
  attachment. It calls14096bbb0, plays animation with mode3/start0,
  toggles shadowing and sets model virtual+1a0 to2 for controlled creature,
  4 otherwise. Param4/5 and this final presentation mask remain unresolved
  policies; preserving metadata is not full policy implementation.
- Shadow toggle wrappers1400c57d0/1400c57b0 call SetShadows1400d3630.
  Ghidra confirms exported name AurEnableShadowing. Recursion changes PartLight
  +78 only when its node has affectdynamic or isdynamic. Constructor copies
  node shadow into PartLight+78. `native-model-light-enable.txt`,
  `native-binary-light-conversion-and-toggle.txt`,
  `ghidra-progfx-light-toggle.txt`. Despite that first capture's historical
  filename, its1400a0d90 function is the ASCII node constructor dispatcher,
  not the serialized light reader.
- Creature attachment14096bbb0..14096c174 obtains headconjure transform,
  adds nativeY+.75/Z+.5, writes procedural root transform and attaches to
  main model root. Constants140d84a74=.75,140d81930=.5 read directly.
  `native-client-visual-program-owner-candidates.txt`,
  `native-light-attachment-constants.txt`, `native-light-attachment-height.txt`.
- PlayAnimation140052580 retains mode flags; Animate14004dbd0 at14004e543
  tests bit1 and clamps time at either endpoint. Thus mode3 is a held one-shot,
  not a repeating fade-in. `native-light-animation-mode.txt` and
  `native-light-animation-clock.txt`. Full native animation stack is not ported.

## Serialized models and rendering

Binary dispatcher14007abe0 calls14007a790 at14007b384 for light nodes.
Complete14007a790..14007abd4 verifies92-byte extension: flare radius at
serialized node+70, seven DWORD flags at+b0..c8. Array/flare resource owners
also exist in this function; lens flare presentation is not implemented.
`native-binary-node-dispatch.txt`, `native-binary-light-payload-reader.txt`.

Base reader14007b6c0 remaps serialized controller offsets to the64-bit
layout. Its light branch14007b909 adds28 to IDs>=76. Consequently binary
76/88/96/100/140 correspond to runtime104/116/124/128/168 for
color/radius/shadowradius/verticaldisplacement/multiplier. The ASCII parser
14009db90 establishes these runtime IDs. Mesh opacity remains serialized128;
emitter/controller IDs must not be interpreted as light or alpha globally.
`native-binary-controller-remapping.txt`, `native-light-parse-control-asm.txt`.

`inspect-native-binary-light.py` executes the complete original light reader,
including its complete base reader, for12 scalar/flag profiles with synthetic
controller pools. Allocation/memcpy and As-node queries are explicit lower
boundaries. All scalar flag and controller remapping results match the parser
tests. Flare arrays are empty in this oracle, matching fx_light_clr; it proves
neither lens flares nor GPU equations. Output:
`native-binary-light-observations.json`, `native-binary-light-v1.txt`.

The active tables select fx_light_clr and White_15m for the installed prepared
Light cast in the rendered fixture. No production spell ID, color or radius
special case exists. `probe-looping-visual-resources.mjs` inspects metadata
without retaining asset geometry. `looping-visual-resources.json` includes
light fields, authored color/radius keys and active PROGFX selection.

The former renderer used9/(2*r*r) as an intensity divisor, producing severe
overexposure. Full SetLightGL140080c10 confirms that value is an attenuation
coefficient. The installed active inc_lighting resource2069, loaded through
the normal module resolver, has a legacy ComputePointLightSource branch using
`1/(1+coefficient*distanceSquared)`; its GAMMA_CORRECTION branch differs.
Only metadata/equation observations retained, no shader asset copied.
`native-set-light-gl-v2.txt` captures full native upload, including the
separate adjusted color/radius branch. The Three adapter now implements the
legacy curve and compensates its diffuse BRDF'sPI factor. Ambient-only model
lights remain spatially attenuated; they no longer become global ambient.
This is not full renderer parity: gamma configuration/adjusted lighting,
per-object light selection, vertical displacement, shadow radius, material
ambient/diffuse separation, shadow volumes and flare passes remain open and
explicitly diagnosed. Parser/playback retain all light channel values.

## Lifetime and acceptance

`LoopingVisualPresentation` reads the canonical nativeLoopingVisuals160 list.
Each record, including duplicates, owns a local instance. Removal, destruction,
render rebinding and area disposal invalidate pending loads and dispose both
attached and late-completing resources. It never allocates gameplay IDs or
rewrites canonical effects. Unsupported procedural types, geometry-node
duration visuals, vision GUI attachment, non-creature anchors, body-part scope,
reverse playback and nonidentity transform controllers remain logged.

- 1,446 tests pass, production build passes. Focused tests cover binary/native
  reader agreement, scoped animation IDs, ASCII light keys, independent
  instances, rest/endpoint behavior, spatial falloff and async removal/rebind/
  destruction/area disposal. Captures `light-full-tests-v1.txt`,
  `light-focused-v2.txt`, `light-build-v2.txt`.
- Rendered `light-item-targeting-ui-v2.txt` passes actual memorized wizard
  Light -> equipped robe566, player565, real slot consumption. Telemetry
  asserts duration visual175 -> program302 -> fx_light_clr/White_15m,
  completed.3-second fade, live13.3 radius and nonzero model light.
  Spellbook/F2/item wheel and cancel tests still pass; engine failures[].
  `live-item-targeting-ui.json` retains all diagnostics, including DM preset
  rejection, missing plc_w02 walkmesh and visual206 geometry-node omission.
- `live-item-light-before.png` and `live-item-light-after.png` visually checked:
  dark room becomes illuminated without the first attempt's overexposed floor.
  Black roof/beam occlusion and other renderer limitations remain visible.
  Entry/startup fixture is explicit; this is not campaign acceptance.
- Self casting, defensive/counterspell/radial/F2 regression passes in
  `light-self-ui-regression-v1.txt`. Summoning, canonical associate transfer
  out/back and radial dismiss pass in `light-area-transfer-ui-v1.txt`;
  DoSinglePlayerAutoSave remains a recorded unsupported engine call.

Formal goal stays active: full spell ecosystem, then combat, then continuous
campaign play/fix/resume. This checkpoint implements a duration-light path,
not the remaining procedural/effect/combat systems.
