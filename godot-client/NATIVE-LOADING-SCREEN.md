# Native loading screen and completed-batch stalls

2026-10-25. This is a scoped loading/presentation improvement, not completion of
the multiplayer migration or the 60 FPS goal. No public server was contacted.

## Behavior and ownership

`systems/native_loading_screen.gd` is a native CanvasLayer. It covers unfinished
worlds while the normal Godot frame loop and protocol processing keep running.
It automatically reveals only the current generation after all three milestones:

1. All base tiles and the terrain surface needed for admission are ready.
2. The complete controlled character and its own referenced models are ready.
3. The follow camera is anchored to that character.

Unrelated NPCs, scenery and their references continue streaming after reveal.
**Ctrl+Shift+L** hides the presentation early for the current transition. It does
not forge readiness, send an area-ready acknowledgement, or bypass authoritative
movement admission. The next transition restores the screen. Required loading
errors remain visible with a return-to-server-selection action. Failures are not
silently converted into ready tiles.

The active native catalog supplies `loadscreens.2da`, `BMPResRef`, original
`pnl_loadscreen` GUI geometry and its `gui_replace01` artwork layer. Resource
selection therefore follows the current install/HAK/Workshop/NWSync/override
precedence. Row 0 chooses a presentation-only random physical row 2+; row 1's
original custom-text path currently uses the normal fallback image. Original
tips/custom-text rendering and pixel-identical native loadscreen layout remain
unported. Artwork is rendered in a bounded private Godot viewport with original
UVs. The second GUI decoration plane is excluded from the backdrop; otherwise
its opaque central panel hides the selected image. General small GUI icons keep
their existing scale. No JS image/model preparation is involved. The protocol
hosts only forward the raw `entry.loadingScreen` value.

Area-ready remains separately gated on terrain/surface readiness. It must not
wait for the controlled player: original servers can withhold that replication
until they receive the acknowledgement.

## Read-only original binary evidence

Target NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
REA used an ephemeral immutable Ghidra12.1.4 import. Original executable, assets,
processes and existing Ghidra database were not modified.

| Function / exact site | Observed behavior | Evidence |
|---|---|---|
| ClientArea receiver14076d910;14076dd7e→1402d9ec0;14076df57→1401a68f0;14076df9f→1406e37f0 | Reads loading-screen INT; 0 selects random active rows2+,1 custom text; resolves `loadscreens.BMPResRef`; starts screen before14076e315→LoadArea1407dba70. | Existing `backups/animations/native-client-area-receiver-asm.txt`; fresh assembly view `ev_1fad8e718b6caf25b8d6518d74709d4d0351f6292f2826f0d27642df1163e0d6`. |
|1406e37f0 | Disables CExoInput/releases mouse, defaults to ls_load/ls_save, constructs/reuses screen, calls CGuiMan::SetModal and140837420. | REA `ev_7cb4961b85235572831ee86085ede6a2036d332616dc633a405f6c2e62e30416`. |
|140836f60 | Constructs CGuiAreaLoadscreen; loads LOAD_SCREEN.GUI; imports LoadBar,TitleLabel,DescLabel,TipLabel. | REA `ev_fc3808d85a53084b79c21b42916204f738e0dc1daed56336c2aa2384d5ce9a05`. |
|140837420 | Virtual+0x60 replaces gui_replace01 with selected resource; virtual+0x80 receives gui_replace01/loadscreens. | REA `ev_3e7e78dcf6240ed408f11e70c5aa241d162abdf25ba3f0e5ac4668799f585b41`. Exact second virtual's shader/UV semantics remain untraced. |
|LoadArea1407dba70;1407dcfb7/1407dcfc7;1407dcfeb→1400451c0;1407dd03b→1402376a0 | Timer comparisons50000/15000µs, screen updates during loading and final tile, connection check inside tile loop. | Existing `NATIVE-WORLD-JOIN-METHODS.md` and unchanged assembly/oracle receipts. |

The Godot modal presentation and incremental frame loop are adaptations of
these observations. The three reveal milestones and early-dismiss shortcut are
the user's requested policy, not a claim about the original client's exact
completion condition or shortcut. The oversized receiver decompile returned a
resource-constraint result; whole-receiver pseudocode parity is not claimed.

## Actual stall and fix

The recorded user session `native-user-1792978895445` attributed a 959.6ms frame
to 952.6ms of world adoption; its other render/selection spans were small. New
child timers on an offline captured-room replay isolated completed-owner close,
not actor installation, as the large cost.

`systems/native_data/data_retirement.gd` now releases detached decoded Variant
graphs on bounded low-priority worker tasks. Scene nodes, live actor state,
immutable pooled GPU resources and shared cache contents are not cleared by the
worker. Creature/object streams move their temporary data containers into that
queue after adoption. A persistent session owner survives transitions, bounds
pending tasks, and joins everything on shutdown. The queue reports pending,
completed, forced-drain and worker-duration diagnostics. Its durations are wall
times, including scheduling/contention, not CPU-time measurements.

Publication is also capped at eight entities / approximately3ms per frame
(checked between entities). A completed batch stays alive until its prepared
entities have all been adopted. A single indivisible GPU/model publication can
still exceed this budget; this is not a hard frame-time guarantee.

The two missing tiles were empty serialized trimeshes with unused mode bytes208
and98. The parser now retains an empty physical mesh regardless of that byte
only when faces/vertices/textures/draw counts are all zero. Nonempty unsupported
modes, bad ranges and bad indices remain rejected. This adaptation follows the
actual resource headers and native skip-empty renderability observations; it is
not an exhaustive original parser oracle.

## Verification receipts

All diagnostic runs use normal-heap CDB with four exception traps, unchanged
source checks and engine/lifetime-error scans. Original assets are read in place;
no proprietary model/texture files are copied into the source workspace.

| Receipt in reports/ | Result / scope |
|---|---|
|native-loading-adoption-baseline-v1 | 898 entities,16batches; close max1398.790ms; whole-run worst frame1408.516ms. |
|native-loading-adoption-workers-final-v1 | Same898entities,16batches; close max0.127ms; whole-run worst411.637ms;5checks; all16retirement jobs drained,pending0,forced drains0. |
|native-loading-adoption-workers-v2 | Earlier accepted worker run: close max0.130ms; worst207.388ms. Retained to show run variability. |
|native-loading-tiles-v1 |33checks: both original cached resources, all physical nodes, empty-mode variants, malformed nonempty geometry rejection, off-thread preparation and native geometry publication. |
|native-loading-adoption-quota-v1 |6checks: bounded publication, completed-owner retention, eventual exactly-once visible entities, shutdown drain. |
|native-loading-priority-v1 |46existing controlled-player/reference/streaming checks. |
|native-loading-screen-final-v2 |22checks plus visually inspected original artwork, actual Viewport shortcut routing, generation gates, camera/player/terrain requirements, random/custom row selection, error display, early dismissal and next-area restore. |
|native-session-loading-v1 | Default native launcher, owned localhost Prelude: loading automatically revealed after2043ms with9/9tiles,player/camera ready; authoritative movement/UI/finish passed;4retirement jobs drained. |
|native-loading-transitions-v2 | Two real authoritative door transitions, all objects complete; loading reveal2380/607/427ms across initial9tiles,100tiles,return9tiles. All three required milestones recorded;14retirement jobs drained,pending0. |
|native-session-loading-reconnect-v1 | Two default-launcher localhost connections; reveal1663/1669ms,authoritative movement/UI/finish passed;8retirement jobs drained,pending0. |
|native-loading-ui-regression-v1 |41original-art native desktop checks, preserving party/quickbar/map/menu controls and outgoing actions after the bounded GUI viewport change. |
|native-loading-raw-protocol-v1.log |7raw-delta/framing tests pass; the entry field remains ordinary decoded protocol metadata. |

The first older transition-harness run failed before catalog readiness because
the optional `resourceSources` fallback still dereferenced the missing original
message field for custom TLK. The native entry now consistently uses the resolved
source descriptor; failed `native-loading-transitions-v1` is retained. Session
reset also clears camera/raw-world state before a new connection, independently
of the loading screen's optional return action.

Offline capture inputs are sealed by existing `native-capture-input-cache-v1`
and its SHA256; resource bytes remain in their original external stores.
These runs are functional diagnostics with an editor preserved, not clean FPS
benchmarks. Whole-area loading still has remaining publication/terrain costs,
and the captured scene still produces particle-capability warnings with effects
off. Neither sustained60FPS nor elimination of every transition spike is claimed.
Failed intermediate reports are retained, not overwritten.

Before-change backup: `backups/native-loading-before-v1.zip`, SHA256
`79c19d973557d54944ce0ace336394c5f3504bd35d605735eb487f46baa60606`.
