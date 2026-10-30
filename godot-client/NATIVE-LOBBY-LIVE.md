# Native pregame roster — owned live check

The Server Info/Player List path now has a two-participant check against the
original hidden local server at 127.0.0.1:5125. The native observer stays at
character selection while a second protocol-only participant uploads an owned
test BIC, enters the area and disconnects. Original installed BICs stay read-only.
Protected participant keys pass through the existing private pipe and are not
written into test scripts, reports, command lines or client settings.

`test-native-actions.ps1 -LobbyPages` is an explicit opt-in prelude to the existing
authoritative action suite. It requires a separate protected participant key and
the isolated standard fixture. Normal client launch/admission is unchanged. The
native probe uses actual viewport pointer events on source page tabs and rows;
it does not move/capture the physical mouse. Windows remain unfocused and use
the secondary display. Its roster screenshot was reviewed.

The 16 live checks verify original Server Info/version/running status, the real
subscription, received addition/name/class levels/raw ID/portrait, disabled-row
input, disconnect removal, stop/reopen and final stop before normal admission.
The host separately requires real49/1 and49/2 outbound requests and matching
49/3 addition/removal records for the displayed ID. At that proof point the
observer has not submitted a character and has zero world entities. The second
participant is closed before the observer's ordinary gameplay checks begin.

The first live screenshot exposed numeric transport formatting: a class level
appeared as 15.0. JSON decodes integer protocol fields as Godot floats. A shared
native integer formatter now covers roster/server-info, chooser record numeric
fields and Server Details. Unknown/malformed numeric values stay blank. Chooser
and Details fixtures now round-trip through JSON, and the live probe checks
visible integer class levels and the endpoint text instead of only DTO values.

Final receipts:

- `native-lobby-live-input-v2`:32 graphical Server Info/Player List checks.
- `native-lobby-live-record-v2`:25 graphical chooser/partial-record checks.
- `native-lobby-live-details-v1`:31 graphical Details/password checks.
- `native-lobby-live-startup-v2`:12 original-resource startup/menu routes.
- `native-lobby-live-local-v3`:16 live roster checks, separate authoritative
  packet/observer-state validation,7 native admission and170 gameplay/UI checks.
- 46 protocol/session/discovery/private-participant parser tests.

These 339 scoped checks do not complete the overall UI. The local server/client
and second participant closed cleanly, workers retired, sources stayed unchanged
during the checks and client public/Arelith connections were zero. The archive
audit verifies these receipts and the retained failure below.

`native-lobby-live-local-v2` passed all 16 roster checks but failed the existing
blood-pixel comparison (zero changed pixels despite a received hit, active blood
particles and no preparation errors). Its failed receipt is retained. The
unchanged full rerun v3 passed that same assertion and all 170 action checks.
No production particle change or assertion weakening was made. This establishes
an intermittent observation; its root cause and complete blood-rendering/timing
parity remain unaccepted. The existing pending-wind warning is also not fixed.

Still required: complete original-client pixel/gesture/role/scale/audio and large
dialog-font comparison, late text invalidation, original selection keyboard and
automatic-selection behavior, local metadata/pregeneration/editing, the remaining
record pages/fields and every other open UI surface. Live review also shows the
pregame chat/debug loading presentation needs phase gating. The fourth pregame
record tab is Spells (TLK5215), not biography: callback88aa00 constructs9c1220
with PNL_CHRSHT_SKIL2 in mode0. Its implementation is still pending.

Reproduce with a fresh run name and protected key files:

```powershell
& ./godot-client/tools/test-native-actions.ps1 -Run UNIQUE -LobbyPages -Profile `
  -ProtectedKeyFile PATH_TO_PROTECTED_OBSERVER_KEY `
  -BarterPeerKeyFile PATH_TO_PROTECTED_PARTICIPANT_KEY
```

The legacy `BarterPeerKeyFile` parameter supplies the separate private test
participant channel; this mode does not open a barter. No public endpoint can be
supplied to the participant helper. Keep the entire UI goal active.
