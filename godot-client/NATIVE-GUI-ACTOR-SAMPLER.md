# Animated native GUI texture sampling

The repeated character-chooser tab borders came from animated GUI meshes
missing their physical source identity during sampler publication. The texture
worker correctly loaded the original TXI, but the GUI renderer looked only for
`native_part_index` on a static mesh's parent. Animated actors put their meshes
under a shared rig holder, so that lookup returned-1 and used repeat defaults.

`actor_instance.gd` now preserves original model/part indices on each published
mesh. `native_item_icons.gd` reads that identity, retaining the existing static
Part fallback, to select the bitmap's original filter/mipmap/clamp settings.
The source mesh identity is independent of GPU texture sharing. This changes
private GUI material publication; ordinary world materials keep their policy.

The GUI processor revision is now `original-gui-sampler-v2`. Request identities
include that revision, so prepared bundles and finished images made before this
correction cannot bypass it. Original assets are unchanged; no screenshot or
guessed border is substituted.

## Evidence and validation

Original binary sampler instructions and their isolated execution observations
remain in root `backups/animations/rea-native-gui-sampler-v1.json` and
`native-gui-sampler-observations-v1.json`, described in
[the sampler investigation](NATIVE-GUI-SAMPLER.md). Installed MDL/raster/TXI
identities are retained in `reports/native-lobby-art-source-v2.json` and
`native-gui-sampler-tabs-animation-v1.json`.

The actual tab has UVs outside0–1 and its original TXI specifies clamp3,
filter0, mipmap0. Before correction, `native-gui-actor-sampler-before-v2`
recorded repeated bright center rows `[0,7,15,23]` for unchecked states and
`[0,7,15,23,31]` for checked states. The corrected render records `[0]` in all
five tested states. It observes actual published actor materials at
`frame_pre_draw`, with source indices1/3 and repeat disabled, not just an
isolated material helper. A second original tab resource also renders.

`native-gui-actor-sampler-after-v2` passes23 renderer checks;
`native-gui-actor-chooser-v1` passes63 graphical chooser/input/metadata checks;
`native-gui-actor-prework-v1` passes34 worker/cache dependency checks. The full
chooser screenshot was reviewed and the repeated outlines are absent. Original
checked/unchecked shape differences remain visible.

Retained diagnostic failures: before-v1 had a script type-syntax error;
before-v2 reproduced the repeated pixels but its material observation occurred
too early. After-v1 fixed the pixels but exposed that same observation timing
and an incorrect test assumption that these animated-UV models use actor
reuse. The final diagnostic observes publication at the render boundary and
checks the actual transient path. These failed runs are excluded from passing
totals. They do not establish a native memory fault or a renderer-cache fix.

The authoritative localhost regression and read-back-verified source checkpoint
are indexed by `tools/audit-native-gui-actor-sampler.mjs`.
`native-gui-actor-live-v1` passes207 checks:7 native login/admission,
18 real two-participant lobby-page,12 exact BIC record-input and170
authoritative gameplay/UI action checks against the owned original server.
There were no public connections or debugger exceptions; source pins stayed
unchanged, preview bytes were removed and all workers retired. This follow-up
totals327 passing checks. Full original GPU,
widget-state, scale, role, font/caption placement and whole-client UI parity
remain unaccepted. The previously retained startup heap exception, headless
Player List artwork failure and missing sealed-corpus TXIs remain unresolved.
