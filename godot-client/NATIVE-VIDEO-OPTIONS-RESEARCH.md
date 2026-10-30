# Resolution and UI Scaling — original data and arithmetic

The later [native windowed integration](NATIVE-VIDEO-OPTIONS.md) now enables
the Resolution page and implements its scale actions. This document preserves
the earlier data-only milestone; its disabled-button statements are historical.

This advances the unfinished Resolution child of
[in-game Options](NATIVE-INGAME-OPTIONS.md). The button remains disabled: this
milestone maps the original page and ports its scale arithmetic, but does not
yet provide a visible video page, display enumeration or real mode/scale
application. The complete [UI goal](NATIVE-UI-PARITY-GOAL.md) remains active.

## Source page and runtime classes

Original `options_vidmodes.gui` SHA256:
`2d0ce57ab852db31ad9d42812febd4a701344d542ca33245cc2dac7bffe6477c`.
`video_options_layout.gd` resolves its372x384 panel and all13 child controls,
including the three nested scale controls, from the active GUI/models. Models
and labels remain source-owned metadata, with exact callback identities.

Original constructor140822e40 and initializer140830160 establish:

| Control | Runtime binding / behavior |
| --- | --- |
| Apply |14082ef60: apply fixed/automatic GUI scale, write pending `ui.scale`, apply selected mode if changed, update GUI and window state. Parent stays open. |
| OK |14082f8d0: Apply, persist if applied, deactivate. |
| Cancel / X |14082f100: roll back pending `ui.scale` when never applied; otherwise persist applied resolution/refresh/scale, then deactivate. It is not an unconditional rollback after Apply. |
| VideoModeList | Original scrollbar; initially disabled.140831650 populates original mode strings with separate mode indices. Selection140832c70 computes the desired scale for that target mode and reduces a larger pending scale. Complete runtime enable/mode branches remain open. |
| IntDown / IntUp |14082feb0 /14082ff20: timer buttons, float32 subtraction/addition of0.1, then maximum-first/minimum-second clamp. |
| CurrRes / CurrScale / NewRes / IntLabel / IntEdit | Constructor140822b60 creates `CGuiCharGenLabel`, even where source GUI metadata has another stored type. `IntEdit` is a display label, not an editable numeric field. |

Frame captions/text hooks come from original resources. Status strings change
with current resolution, fullscreen/windowed state and scale, so stored TLK
captions alone cannot implement the page. Geometry resolves nested offsets;
moving an active GUI parent moves both its arrows and scale text. Missing
source controls/models fail explicitly instead of generating guessed widgets.

## Original scale rules

`desired_scale` executes the arithmetic of140074f70: minimum of float32
width/900 and height/700, subtract `fmodf(value,0.1f)`, then floor the lower bound
at1. Unconstrained mode returns4. Replacing this with decimal rounding or
`floor(value*10)/10` changes boundaries. For example, the actual original result
at1800x1400 is approximately1.9, while1801x1401 yields2.

`scale_step` preserves float32 addition/subtraction and maximum-first clamp
order, including an authored minimum above the maximum. `scale_update` follows
1400750a0: zero fixed override selects the computed maximum, otherwise clamp
the override to that maximum, enforce1, compute0.01f/scale and refresh fonts
when the float32 old/new difference has magnitude at least0.09. `fixed_override`
matches Apply: a pending scale within0.09 of the current maximum becomes zero
(automatic) internally, while the original configuration write still stores
the selected float promoted to a double. These are finite original cases;
the eventual settings owner still needs preference/input validation.

`scripts/inspect-native-video-scale.py` executes unchanged original x64
instructions offline in Unicorn. The original fmodf implementation executes
too. Only named configuration/string allocation, list query, font refresh,
GUI refresh and window-refresh lower boundaries are captured. Original
processes, profiles and network connections are untouched; display-mode
selection/change is excluded from this oracle.

Evidence under `../backups/animations`:

- `rea-native-video-options-v1.json`:11 function dossiers plus original vtable.
- `rea-native-video-scale-v1.json`:5 function dossiers and exact0.1f bytes.
- `rea-native-video-label-v1.json`: original label constructor dossier.
- `native-video-scale-observations-v2.json`:28 desired-scale,96 arrow,
  280 scale-update and33 Apply cases,437 total.

All target original client SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

## Verification and next work

`native-video-options-data-v3` passes463 source/geometry/original-instruction
checks under the native debugger. Every float32 output is compared by bits;
Apply's persisted double is compared to its exact captured bytes. The earlier
v1 receipt retained three false failures caused by JSON decimal parsing
changing an exact float-promoted double by one bit. The v2 oracle records the
original double bytes directly; the test also records those decimal conversion
observations. No native arithmetic was changed to accommodate the test.
The native Options input regression passes35 checks against the same source.

`tools/audit-native-video-options-plan.mjs` verifies these498 checks, source
pins, original dossiers/oracle, original GUI inventory identity and a read-back
rollback at `backups/native-video-options-plan-v1.zip`. This is data/research
acceptance only. Earlier Options acceptance remains historical for its exact
checkpoint; it does not certify a completed Resolution page.

Next implement the original-framed native owner, monitor/mode service,
pending-versus-applied settings and true Apply/OK/Cancel behavior. Propagate
UI scale through layout/input without reducing the3D viewport resolution,
retain source control proportions and default placement, return correctly to
both Options parents, and verify actual native input and original-client
behavior. Do not enable the menu button merely because this data test passes.
