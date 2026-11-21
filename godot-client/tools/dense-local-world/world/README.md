# DenseSync fixture world

The generator uses the authored [DensePerf.mod](fixtures/DensePerf.mod) for
its two 10 × 10 areas and travel triggers. This is a byte-for-byte copy of the
workspace's original DensePerf test module from
`runtime-logs/dense-performance-server/modules`. Its seven resources are the
module record, two fixture scripts, and two area layout and placement pairs.
The generator pins its SHA-256 and builds a fresh private `DenseSync.mod` and a
`ds_fixture.hak` containing generated TGA artwork. The pinned game install
supplies the terrain geometry and expanded source door records. The delivered
textures replace the installed surfaces referenced by `ttr01_g01_01`.

Run the parent fixture orchestrator for server, HTTP and client lifecycle.
The world component builds the private server profile.

```powershell
& .\godot-client\tools\dense-local-world\world\build-world.ps1 `
  -FixtureRoot .cache/dense-sync-example -Scale dense -Port 5127 `
  -SeedVault .cache/nwn79-package-j-local-20261117-b/fixture/profile/servervault

```

Build outputs are `world.json`, `resources` with exact loose NWSync inputs, and
`server` with the original server profile, MOD and HAK. Pack the HAK and loose
resources through the NWSync repository tool. Client profiles receive that
content through the manifest. For seeded builds, each server start restores the
original BIC into that fixture's private vault before accepting clients.

After the repository has been packed and is listening, the world server takes
its URL and exact manifest hash from the repository descriptor.

```powershell
$manifest = Get-Content .cache/dense-sync-example/repository/descriptor.json -Raw | ConvertFrom-Json
& .\godot-client\tools\dense-local-world\world\world-server.ps1 `
  -Action Start -FixtureRoot .cache/dense-sync-example `
  -NWSyncUrl $manifest.url -ManifestHash $manifest.manifestHash
```

`-Scale smoke` keeps six creatures and twelve placeables per area and serves two
small generated textures. `-Scale dense` has 96 creatures, 320 placeables and 48
doors per area. The 96 creatures in the timed entry area stay at their placed
positions with idle animations. Its travel area retains 48 authored roaming
creatures and 48 fixed additions. The 24 added actors nearest each entry
include alternating Curst Swordsmen and Elite Ogres. Both models use weighted
skin meshes. The area also includes non-interactable rigid props, base
static and replicated placements, and animated brazier, fountain, torch and mechanical
props. Door records are authored in both open and closed states. The dense scale
uses ten 512 × 512 generated terrain textures. `-DensityMultiplier 2` increases
the added object counts. These are authored area counts. Collect rendered and
replicated counts from the client for the measured window.

Multipliers 3 and 4 expand the scenery variety and add generated prop textures
and particle atlases to the same NWSync repository. At 4×, each area contains
240 creatures, 1,040 placeables, and 192 doors (96 open and 96 closed at build
time). The 960 added non-interactable placeables include 768 rigid objects,
128 ambient effects, and 64 levers. The rigid objects split evenly between
static and replicated placements. The 192 added creatures include 96 weighted
skin models and attendants positioned beside selected doors.

The expanded builds attach `stress_entry` and `stress_heartbeat` to the two
area records. The entry script starts the area-local driver for the entering
player. It restores the initial door states, alternates 24 levers on area
heartbeats, and waits for movement from spawn before pulsing 12 doors in small
banks. Attendants handle the original queued close action. The driver stops
issuing pulses when that player leaves or the bounded sequence ends.

Entry is in `dense_a` at [50, 40, 0]. The benchmark path goes to [58, 40, 0].
Dense builds keep object centers at least 3 m from that segment. The generator
relocates six authored creatures and six authored braziers to nearby free
slots at 1× and 2×. The expanded 3× and 4× layouts keep a four-metre corridor
around the timed route and its branch to the travel trigger in both areas.
Added objects also avoid the original travel trigger. A build requires
the retained DensePerf layout and the pinned original game installation. A
fresh fixture avoids side effects on accepted artifacts and installed profiles.
