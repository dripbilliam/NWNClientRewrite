# Original poison and disease health variants

Party health now selects the original `percentage`, `poison`, `disease` or
`diseasepoison` animation from received multiplayer flags. This restores the
original health artwork for both the controlled portrait and member portraits,
including changes where HP itself stays constant. It does not infer an
affliction from an effect icon, a spell, local simulation or an unrelated field.

The original creature update reader140781e80 reads the party block's disease
BOOL first, then poison. The existing protocol reader names these
`replicated.party.field8B4` and `field8B0` respectively. Original setters
1408538e0/140853930 feed portrait fields+15c/+158; original helper140854740
selects the four clip names. `CGuiStatusBar::SetCustomStatusAnimation1401eb7c0`
clamps finite percentages to0–100 and samples the selected clip at percent/30.
The native `party_health.gd` projection preserves this order and float32 timing.
No protocol reader or JS rendering flow was added.

`native_status_bar.gd` now tracks desired, pending and published clip names
beside their percentages. A mode change at the same HP therefore publishes new
art. It keeps one request in flight and coalesces bursts to the latest complete
state; a64-change same-HP burst is verified to issue one final pose request.
Unknown HP still hides the visual. Native diagnostics expose desired/published
mode and percentage without mutating received HP or sending gameplay messages.

## Evidence

`scripts/inspect-native-party-health.py` executes original140854740 and
1401eb7c0 instructions in the existing pinned offline emulator. Only GUI model
publication and scene refresh are captured. It runs144 finite cases across
signed/nonzero poison/disease flags and below/within/above-range percentages.
`backups/animations/native-party-health-observations-v1.json` retains selected
clip, clamped float bits and animation-time float bits for every case.

`backups/animations/rea-native-party-health-variants-v1.json` retains the
original helper/setters, leader callback research and the complete79,947-character
creature update pseudocode across its two retained pages. Original client SHA256
is `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

Current unchanged-source debugger receipts:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-health-variants-oracle-final-v1` |148| Exact original mode/clamp/time bits plus raw field mapping/invalid private input guards |
| `native-health-variants-ui-final-v1` |55| Existing44 HUD checks plus both portraits/all four actual original variants; distinct native pixels; unchanged HP/ownership; no gameplay requests; same-HP coalescing |
| `native-health-variants-desktop-final-v1` |41| Existing native desktop/actions regression |
| `native-health-variants-character-final-v1` |55| Shared character resize/art regression |
| `native-health-variants-retirement-final-v1` |13| Native render retirement |
| `native-health-variants-playability-final-v1` |1314| Existing headless aggregation |
| `native-health-variants-actions-final-v1` |99| Existing original-server authoritative regression at localhost5125 |

The local-server regression validates existing action compatibility; it does
**not** claim a live poison/disease application scenario. Mode rendering is
checked with authored raw replicated state, independent original instructions
and active original model clips. Native screenshots cover each mode. Physical
mouse capture/warping and public connections are not used.

Full party/HUD/health parity remains false. Original-client visual/input
comparison, affliction transitions on a live original server, all disclosure,
role/associate/DM/possession cases, locator/status/leader indicators, exact name/
font/tooltip behavior and nonfinite original inputs remain unaccepted. The earlier
intermittent blood-model viewport assertion stays open separately. General
porting remains deferred under the full UI parity goal.
