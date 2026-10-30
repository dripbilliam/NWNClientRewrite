# Pregame Feats — partial record migration

The [pregame Skills follow-up](NATIVE-PREGAME-SKILLS.md) now shares this source
list owner and supersedes the disabled-Skills state below. Its later checkpoint
and evidence leave Spells, complete Character statistics and full UI open.

The character chooser's original Feats tab now opens a native list and description
page. Local/server BIC feat identities come from the native preview worker. Active
`feat.2da`, TLK and overrides supply names, descriptions, icons and successor
admission. No JavaScript display/rules path or gameplay renderer was added.
Inspection sends no fabricated casting or feat-granting request.

`native_lobby_record_feats.gd` owns the original mode-zero `PNL_CHRSHT_SKIL2`,
`CTL_CHRSHT_DESC`, `CTL_CHR_BTNLSTBX`, `CTL_CHR_BTN_FEAT` and scrollbar models.
Source hooks place the fixed description above the scrolling list. Rows retain
34-pixel artwork,36-pixel advance,32-square icons and Galahad14 text. The tall
background is cropped at native density. Mode zero places the list bottom at
the page bottom, with its scrollbar endpoint14 pixels above that; it does not
inherit the in-game11-pixel footer inset. Character and Feats share only their
header/title/tabs; switching does not rescale either body or cover Play/Cancel.

The existing original-validated native feat admission/order helper is reused.
Selection updates active description text. Returning to an unchanged page retains
selection and scroll. Changed BIC identity/connection/text publication retires
obsolete selection; held tab/row input cannot target its replacement. Hiding and
closing retire held input and both scrollbar owners. Keyboard/repeat behavior
is not claimed complete by these pointer checks.

## Original evidence

Binary SHA256 is `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only dossiers are retained at root `backups/animations/`:

- `rea-native-pregame-record-pages-v1.json`:22 functions covering mode-specific
  Skills/Feats/Spells construction/data/selection. Pregame Feats callback is
  `1409c0db0`; `1409c01a0` constructs the page, `1409c04b0` selects help.
- `rea-native-pregame-record-geometry-v1.json`: source list-height/resize rules.
  Existing `rea-native-character-record-owner-v1.json` retains `14088acb0`,
  which omits the0.11 adjustment in mode zero.
- `native-pregame-feat-observations-v1.json`:15 cases execute unchanged original
  `1409c0db0` instructions, with external UI/name/rule services captured. They
  match existing gameplay admission, including owned successors and secondary
  duplicates. `scripts/inspect-native-pregame-feats.py` reproduces this oracle.

The same research confirms that Skills needs its source eligibility/value data,
and Spells includes summary rows based on spell-gain and ability/class rules,
besides known spells. Neither page is approximated with a guessed list here.

## Verification and remaining work

Current source-pinned receipts under `reports/`:

| Run | Checks | Scope |
| --- | ---: | --- |
| `native-lobby-record-feats-v6` |41| Original oracle plus actual native BIC/UI input, active definitions/overrides, stale input, both scrollbars,125-percent input and clean retirement |
| `native-lobby-record-preview-v2` |15| Native preview/text publication and original record controls |
| `native-lobby-record-chooser-v2` |25| Chooser selection/activation/New/Cancel and remaining unavailable controls |
| `native-lobby-record-pages-v1` |32| Existing Server Info/Player List input and state |
| `native-lobby-record-phase-v1` |22| Pregame/gameplay visibility and input ownership |
| `native-lobby-record-startup-v1` |12| Original entry routes with no connection |
| `native-lobby-record-local-v1` |201| Six actual Feats tab/row/return checks before seven admission,18 roster and170 authoritative gameplay/UI checks on original localhost5125 |
| `native-lobby-record-service-v1` |55| Protocol/lobby/raw-source service regressions |

These403 scoped checks do not establish full record/UI or stability parity.
Original-scale and125-percent native images were reviewed. Windows stayed
unfocused on secondary screen0, primary2. Public connections were zero. The owned
local client/server exited normally; preview sources and workers were retired.
`tools/audit-native-lobby-record.mjs` verifies these scopes and the rollback at
`backups/native-lobby-record-v1.zip`.

Retained failures: Feats-v1 failed test type inference; Feats-v2 hit a native heap
access violation with a Unicode parsing error before the preview source existed.
Its cause is **unresolved**, not declared fixed by later green runs. Feats-v3
clicked scrollbar arrows before source artwork was ready; the test now waits for
the same readiness that enables those controls. Subsequent Feats-v4/v5/v6 passed.
Chooser-v1 retained an obsolete assertion that every additional record tab was
disabled; v2 instead requires Feats enabled and Skills/Spells disabled. Earlier
GUI capture/sampler and intermittent blood-pixel failures also remain open.

Still required: original-client side-by-side comparison, all gestures/keyboard/
audio/roles/scales, exact selected/hover/pressed styling and cropping, complete
BIC primary/bonus import coverage, Skills and Spells pages, derived character
combat stats, local metadata/editing and every other open UI surface. Full UI
parity and general porting remain blocked on that completion audit; the overall
goal stays active. A verified checkpoint is a rollback, not acceptance of the
unresolved startup exception or complete UI stability.
