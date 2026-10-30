# Native item Examine details

2026-10-26. Feature integration resumed while particle/GPU testing is paused at
the user's request. No graphical client or server was started for this work.

The default native client now projects disclosed item properties instead of
showing the previous placeholder warning. `native_data/item_property_text.gd`
uses the active `itempropdef.GameStrRef`, subtype `Name`, subtype overrides for
`CostTableResRef`/`Param1ResRef`, `iprp_costtable.Name` and
`iprp_paramtable.TableResRef`. Property type/subtype/cost are WORD values and
the parameter is the received BYTE. No stock property/spell lists are embedded.
Native TLK/custom TLK and server text overrides resolve the labels.

`native_gameplay_ui.gd` requests dependent 2DAs through the current native
catalog/asset workers, deduplicates requests and admits up to eight new requests
per completion batch. Initial description/facts show immediately. These jobs
are separate from the startup table gate, so they do not hold the chat/dialog
message queue. Missing content records a diagnostic and leaves independently
valid details visible. Closing the view or changing its target cannot reopen it
from a late result. `server_examine.gd` refreshes details without raising the
window, moving it, or resetting an unrelated portrait.

Item type comes from existing canonical item metadata, not the first reply INT.
Charges appear only when identified and positive; received weight is in tenths
of a pound. Value, usability and minimum level appear only when disclosed by the
server. Unidentified replies do not reveal canonical cached property lists.
No property effects, prices, identification or use eligibility are computed
locally, and no new server request/protocol implementation was introduced.

## Original evidence and limits

Read-only NWN:EE89.8193.37-17, nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original AddProperty at`0x1408965e0` is retained in
`../backups/animations/rea-examine-item-property-ui.json`; item GUI at
`0x140899040` and reader at`0x14079a1e0` are indexed in
[the existing Examine evidence](../evidence/multiplayer-examine.md).
The old JS view was read as reference only; native runtime imports none of it.

This closes the ordinary property/fact display gap, not complete native Examine
parity. Original AC-type suffixes and the extra usable-property suffix/styling,
item portrait/layout parity, broader mod content and actual original-server
visual acceptance remain open. Server-side gameplay outcomes are unchanged.

## Verification

- `reports/native-examine-item-details-v1.json`:15 headless actual UI/async
  completion checks. Custom subtype/cost/parameter overrides, zero/absent
  override rules, unknown labels, independent valid rows, item fact disclosure,
  unidentified properties, target/revision guards, and stacking/position pass.
- `reports/native-examine-item-original-v1.json`:11 read-only original resource
  checks. The historically server-disclosed Greater Magic Bag tuple32/0/4/255
  resolves the original -80% text; ordinary ability bonus resolves Strength/+2.
  Source resource hashes are recorded in the report.
- `reports/native-examine-text-regression-v1.json`:1025 existing native
  TLK/token/RGB, raw chat/dialog/creature Examine, portrait publication and stale
  generation checks pass headlessly. This is not GPU visual acceptance.

All three debugger proofs have clean exits, unchanged sources and no engine or
lifetime errors. Public connections:0. Actual localhost inventory → Examine,
visual layout and server/custom-resource gameplay checks are queued until live
testing is authorized again. Full gameplay migration remains active/incomplete.

Source checkpoint: `backups/native-examine-item-details-v1.zip` with verified
read-back file hashes in its adjacent manifest.
