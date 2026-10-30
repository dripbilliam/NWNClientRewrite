# Barter Offer and Accept artwork correction

The native trade window now visibly reflects each participant's received Offer
and Accept state, including a remote acceptance being retracted. The previous
window received and selected those states correctly but painted identical
artwork for checked and unchecked controls.

The original `ctl_btr_btn_acpt` model changes its mesh UVs to select different
rows of its texture atlas. `native_item_icons.gd` previously sampled only the
transform animation for a single named GUI state. It now uses the existing
native GUI pose composer when that state contains animated mesh channels.
This preserves original vertices, UVs, text hooks and material artwork; there
is no replacement highlight color or predicted trade state. Explicit composed
GUI poses and ordinary icons retain their existing paths. The prework processor
identity includes this renderer's source, so old persisted GUI pixels invalidate
without deleting unrelated caches.

The read-only original model inspection is
`reports/native-barter-button-animation-v2.json`; model SHA256 is
`7ffbf9fe54e206860a55ce7d9f2487140538ff324239ef2f4c9c30d5d725e60d`.
Original checkbox `SetChecked` at `1401e5ae0` selects `checkedup` or
`uncheckedup`; the saved binary evidence remains in
`../backups/animations/rea-native-barter-controls-v1.json`.

## Verification

- The retained baseline has exactly one failing pixel assertion: checked and
  unchecked Offer artwork are identical. With the correction, the native
  input suite passes all38 checks, including separate own/remote flags,
  rendered checked states, remote acceptance/retraction, pending acknowledgements
  and stale revisions.
- An owned original server at `127.0.0.1:5125` passes50 two-participant checks.
  The native client shows the real peer accepting and retracting, one-sided
  acceptance does not exchange items, both accepts complete the exchange, and
  cancellation in the opposite role returns items and reserved gold.
- The GUI pose regression passes69 checks, native Options input35, and native
  desktop input41. All accepted runs retain source hashes, debugger traps,
  normal heap, clean native exit and no script/lifetime error. The local-server
  run retains the existing particle wind-sampling warning; it has no script or
  native exception and leaves zero workers. This is not a particle fix.
- Authored own-offered/peer-accepted screenshots and the actual-server
  peer-accepted screenshot were reviewed. These tests use isolated native input
  and never move the physical cursor. No public server was contacted and no
  manual session was restarted.

`tools/audit-native-barter-button-states.mjs` verifies the current receipts and
rollback archive and writes the scoped acceptance index. The failed sandbox
fixture-read attempt `native-barter-gui-pose-v1` is retained and excluded;
the authorized read-only rerun is `native-barter-gui-pose-v2`.

Rollback: `backups/native-barter-button-states-v1.zip`, verified by read-back.
This checkpoint includes the current shared workspace, including independently
developed prework/settings work and the unfinished in-game Options candidate.
It does not accept those unrelated changes or the entire UI. Wider original
client comparison, all trade rejection/range/stack/custom-resource cases and
the [complete UI goal](NATIVE-UI-PARITY-GOAL.md) remain open. See the earlier
[barter milestone](NATIVE-BARTER.md) for protocol and ownership evidence.
