# Native inventory gold, containers and barter refusals — partial parity

Follow-up: [native player barter](NATIVE-BARTER.md) now verifies real local
two-player item/currency exchange and cancellation refunds with original controls.
The refusal-only evidence below remains the earlier gold milestone.

The original inventory gold button140856190 opens an `INV_STACKSPLIT` amount
dialog using the received gold balance. Its positive confirmation callback
140856340 creates a private `CGuiPlayerGoldSource` drag with `IR_BUY`. The drop
callback140855e80 accepts ground, creatures, placeables and container items.
Creature targets start barter; this does not directly give currency to an NPC.
Sender1407bdc70 writes client OBJECT_ID, signed32-bit amount and placement BOOL,
then ground XYZ for OBJECT_INVALID and optional repository BYTE coordinates.
It sends message8/1. Gold balances and actual transfer results remain server-owned.

## Amount-control follow-up

The shared gold/stack amount editor now follows the original decimal-prefix
parser and signed32 arithmetic instead of Godot's generic integer conversion.
Examples: `1e9` confirms1; `12.5` confirms12; very long positive strings saturate
before the opening-maximum cap. Up applies only its native upper bound; Down
applies only its lower bound. Even the original signed-overflow display behavior
is retained. Nonpositive confirmation still dismisses without a request.
The original numeric character gate rejects characters above ASCII57; inherited
control/navigation shortcuts are preserved rather than filtered as text. The
invented ten-character limit is removed. Full clipboard, IME, caret and localized
keyboard parity are not established by these ordinary native key-input checks.

Arrow presses apply one immediate change. The original timer waits strictly
more than500000 microseconds before its first repeat and strictly more than50000
thereafter, discards elapsed excess, and performs at most one repeat per tick.
Moving a held pointer outside restores the up pose and suspends repeat; reentry
uses accumulated elapsed time. Release, confirmation, cancellation and context
retirement stop the native repeat owner. No balance or item-count prediction is
introduced by this change.

Visual review also found the amount title shifted and clipped. Original
CGuiObject/CGuiLabel construction leaves the constrained-width flag unset;
CGuiLabel::LoadGffData only applies source width/height for that flag. Its normal
StringGob instead aligns the complete caption around its source position.
The amount title now uses that unconstrained source anchor, including after the
original bitmap font is installed. The full `How many items?` title is visible.
This correction is scoped to the amount dialogs; other imported labels still
need their own constructor/flags/width/wrapping audit.

Evidence: `rea-native-amount-dialog-v1.json` and
`native-amount-dialog-observations-v2.json` under `backups/animations`.
The latter retains500 original arithmetic callbacks with the original CRT parser,
200 timer cases,133 numeric-key gates, and original timer construction/down.
NUL inputs retain their complete input bytes plus the consumed C-string prefix
so Godot's JSON reader can load the evidence without unsupported NUL strings.
The v1 oracle and first failed native receipt remain separate diagnostics.
Original text/GUI/audio/mouse publication and CRT C-locale setup are captured
boundaries; no physical pointer, live original client or public server is used.

`native_amount_dialog_ui_test.gd` drives the actual original controls in an
isolated SubViewport: typing, Enter/Escape, arrows, hold-boundary timing,
pointer exit/reentry, long and signed values, private drags and item splits.
The final scoped acceptance is retained in
`reports/native-amount-dialog-acceptance-v1.json` when verified. Local original
server checks additionally exercise parsed `1.9`→1 stack splitting and `7.9`→7
gold transfer, as well as existing ground/container/refusal and two-player paths.
These do not establish every auxiliary input dialog, role, scale, sound
preference, source font/language or original-client side-by-side behavior.

Read-only original NWN EE89.8193.37-17 x64 SHA256:
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Evidence: `backups/animations/rea-inventory-frame-interaction-v1.json`,
`rea-inventory-gold-amount-v1.json` and `native-gold-transfer-observations-v1.json`.
The last file is96 executions of the unchanged original sender and scalar/ID
writers under the existing read-only emulator harness; only transport is captured.
It is not a live transfer or complete server-handler oracle.

The native port reads active original GUI/MDL resources, including nested arrow
controls, through native workers. Original poses retain their own raster bounds.
Button captions are child labels above the original artwork: drawing the raster
in the Button draw signal otherwise covered the built-in caption. All selects
the opening balance; arrows increment/decrement with hold repeat. Confirmation
caps to the opening maximum, as shown by original assembly omitted from the
decompiler's pseudocode. Zero cancels without a drag.

The private drag carries generation/area/controlled-actor identity and a serial.
Balance, target and container identity are revalidated on drop. A native full-screen
drop receiver is visible only while dragging and stays behind normal menus.
World destinations use the existing native physics picker and UI blocking checks;
ordinary container repositories use the original target/default placement flag;
the coordinate-bearing variant belongs to player barter. Open container identity
is sufficient even when a separate bag-owner record is unavailable; other item
destinations require received player/current-container membership and the active
base-item Container flag. Escape,
closing inventory and world-context changes cancel the drag. No transfer edits
local balance or item ownership. JavaScript changes are protocol serialization/
validation only; the dialog, artwork, input and picking are native Godot.

Godot's [Viewport API](https://docs.godotengine.org/en/4.5/classes/class_viewport.html)
provides cancellation of a forced drag, avoiding a synthetic click or physical
cursor movement during teardown.

## Current evidence and remaining acceptance

`node --test test/network-gold-transfer-native.test.js` verifies48 native-format
packets against the96 original-format cases and stale context/balance/target
rejection without balance mutation. The remaining48 oracle cases exercise the
original's other message format; the replacement uses format1.
Final-source scoped receipts:

| Receipt | Scope |
| --- | --- |
| native-gold-protocol-final-v1.tap |25 offline protocol test groups, including original gold/rejection packets, stale state and inventory/runtime regressions. |
| native-gold-playability-final-v1 |1314 native gameplay routing/rules checks. |
| native-gold-frame-ui-final-v1 |157 graphical checks: actual amount/arrow/All/Cancel/OK input, actual GUI ground/container drops, zero amount, Escape, stale generation, original pose dimensions and worker cleanup. Screenshot inspected. |
| native-gold-desktop-final-v1 |41 broader native desktop/HUD/map/menu checks. |
| native-gold-radial-final-v1 |32 original radial artwork/input checks. |

Native debugger receipts use four exception traps, normal heap, unchanged source
and no caught native exception or script/lifetime error. The GUI input test uses
the existing isolated manually notified SubViewport, without moving the physical
cursor or taking focus. Those authored input checks are distinct from the live
original-server acceptance below.

`native-gold-actions-v6` passes79 full original-server checks, including actual
gold ground drop, a new replicated physical gold heap, pickup restoring the
authoritative balance, and the original rejection/refund when attempting NPC
barter. Existing equipment/casting/advancement/attack/facing/impact/cancellation
checks also pass. Native exit0, unchanged source, no caught exception/UI errors,
workers0 and public connections0. `native-gold-actions-v10` extends this to85 checks,
including a real container gold deposit/withdrawal, restored balance and native
container closure. Its exit/source/debugger/workers/public-connection checks
are also clean. `native-gold-actions-final-v1` repeats all85 checks on the final
source, with exit0, debugger armed/no caught exception, source unchanged,
workers0 and public connections0. Both successful85-check runs include real
rendered attack facing, impacts and server cancellation after the currency cycle.

Initial local runs are retained failures. V1 left the test spellbook visible.
V2-v4 ran all drop checks in the same frame as store closure, before the native
merchant panel retired; the probe now waits for the actual visual retirement.
V5 incorrectly expected a direct NPC gift. Read-only original receiver14044f460,
TransferGold1403a5720 and StartBarter1403a4d40 show the real barter/rejection path.
The non-PC rejection restores the temporary gold item to the donor, giving net
zero currency change. The test expectation was corrected from that evidence,
not by editing live balances or bypassing menu blocking.

V7 selected a decorative placeable instead of the authored inventory chest;
v8 used an incorrect fixture name. The probe now identifies the actual received
`Native container chest` by its authored name. V9 completed deposit/withdrawal
but exposed the host's missing actor ID on container requests. The host now
supplies its current controlled identity to the existing session validator.
Inventory request validation failures also return the typed rejection to the
native inventory notice/pending-state owner. V10 verifies container closure
through that corrected path. No original server executable or gameplay rules
were changed to obtain these results.

That investigation exposed the missing35/11 rejection decoder. Original server
sender1404ceef0 and client handler140770640 retain the original operation/reason/
target fields and reason1..6 TLK references.216 original sender cases,108 in the
replacement's native message format, verify the decoder and truncated-input
rejection. Native chat now displays the actual localized refusal with target
token context. Other barter state/repository operations and full player-to-player
barter UI remain required migration work; these tests do not claim that feature.

Earlier failed diagnostics are retained: playability-v1 named a nonexistent test;
v2 exposed a conflicting inherited `ready` signal name; frame-ui-v1 contained
two test assertion signature mistakes and an untyped diagnostic variable.
None are accepted successful receipts. Original clients/editor and existing
owned servers are preserved; all connection tests are isolated loopback only.

Rollback: before `backups/native-inventory-frame-v1.zip`; after
`backups/native-inventory-gold-v1.zip`. The archive is read back and every source
entry is verified. `reports/native-gold-acceptance-v1.json` ties final native
source pins, protocol sources/oracles and the checkpoint together. The full
UI/combat goal remains active; player barter, other original window layouts,
broader mixed-client behavior and untested custom-resource variants remain open.
