# Transition regions: portal picking and Enter

The user's current-room portals had visible effects but no usable selection.
Source inspection found that type7 triggers were decoded, including transition
flags and polygons, but NetworkScene.sync excluded them, picking only used
rendered bindings, highlightEligible rejected them, and default interaction
provided no trigger action. The latest runtime log had no specific trigger
decode failure. Its metadata does not establish the identities of every portal
in the screenshot; visual effects alone do not prove an interactable object.

## Read-only native evidence

Pinned NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original executable, live sessions and Ghidra project were not modified.

* Exported AddTriggerGeometryToMessage1404c8630 serializes the trigger's
  world-space vertex list3b0/count3a8. Client creation1407b1670 reads the list,
  raises Z by0.05, sets non-trap transition18c and creates a trigger owner.
* Its geometry-center calculation14086f940 uses the extrema of those vertices,
  rather than requiring a separate position update. Constructor14086eab0 and
  model load14086f2c0 lead to an EMPTY model and trigger animation controller;
  a conventional visible placeable model is not required.
* Native PartTrigger::HitCheckGeom1400f06d0 uses a bounds check followed by
  polygon triangles and hit mask40000000. Part creation1400ef450 decomposes the
  polygon and can project vertices against terrain. Replacement geometry uses
  the supplied vertices with the creation-time Z lift; it does not port that
  terrain resampling or the exact native hit-priority system.
* The already verified native waypoint sender1407c0970 is called from ground
  input1406f3650 at1406f3b98. This patch uses that existing6/1 movement request
  to approach an interior point; remote trigger entry/transition behavior stays
  server owned. It does not invent a Use request or activate a local portal.
  Exact native selected-trigger argument forwarding is not claimed as parity.

Captures: `backups/animations/rea-trigger-*.json`,
`native-trigger-descriptor-sites-v1.txt`, `native-walk-click-call-sites-v1.txt`.

## Patch and validation

Server-supplied non-trap transition polygons now have an invisible geometry
binding. Concave triangulation, ray picking, wall occlusion and lifecycle cleanup
use the real polygon. No proxy is attached to arbitrary portal art. The geometry
also supplies bounds to the existing approximate hover/Tab highlight renderer.
The cursor uses native transition21/22; left click and radial Enter route through
the owning frontend/IPC/session to ordinary server movement. Its destination is
a triangle centroid so even a concave polygon receives an interior approach.
State changes invalidate bindings; deletion/area exit releases their geometry.
Scene diagnostics include trigger bounds for a subsequent live comparison.

13 trigger/highlight/cursor checks pass (`network-trigger-tests-v1.txt`), covering
concave holes, absent position updates, malformed geometry, disabled/nontransition
and trap exclusion, occlusion, updates/deletion, highlight selection/disposal,
cursor states, Enter routing, stale area rejection and no local teleport.

The broader offline set is58/59 (`network-trigger-focused-v1.txt`). Its old
installed scene test expects20 player model parts but gets12. The retained
baseline comparison (`network-trigger-existing-scene-baseline-v1.json`, runner
`scripts/check-network-trigger-scene-baseline.mjs`) gets the same19 objects and12
parts both with and without this trigger change. That pre-existing assertion is
not changed or counted as passing. An initial data-URL baseline attempt omitted
the bare `three` import resolution and failed before running; the saved runner
corrects it. Production build passes (`network-trigger-build-v1.txt`).

No public-server joins, movement, clicks or restarts were automated. The running
client must restart; actual selection/entry in the user's Arelith room remains
to be checked. Highlight appearance follows the existing approximate part glow,
not a full port of native trigger surface rendering. Decorative effects without
a replicated transition region remain decorative.

## 2026-10-24 correction: selected target forwarding

The earlier interior-point request omitted the selected trigger ID, explicitly
listed above as unverified. Actual localhost Godot testing now shows the player
reaching that point without transitioning. Complete original click assembly
retains the non-trap trigger ID at1406f0660, forwards it at1406f0cf3 through
ground-input1406f3650 to waypoint sender1407c0970 at1406f3b98. Retaining that ID
in the existing packet fixes actual click-driven A-B-A transitions. The focused
packet assertion now checks it. This supersedes the earlier approach-only
behavior; no client teleport is added. See
`godot-client/NATIVE-LIGHTING-PORTALS.md` and the hashed static evidence
`godot-client/reports/native-trigger-selected-id-evidence-v1.json`.
