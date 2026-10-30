# Native server Details and password — partial migration

The main-flow browser now opens original SRV_SRVDETAILS instead of the interim
OK notice. Native Godot owns its frame, eleven readonly fields, six indicators,
scrolling colored description, Previous/Next, Connect and Close. The original
PLAYERPASSWORD child owns masked password input, Enter, Escape and cancellation.
Network and login requests continue through the existing protocol service.

Original evidence is in `../backups/animations/rea-native-server-details-v1.json`.
The Details constructor is 0x1408c3060; initialization 0x1408d4090; update
0x1408d33e0; description/build selection 0x1408d3150; Connect 0x1408ce150;
Close 0x1408ce020; Next/Previous 0x1408d0a50/0x1408d15f0. PLAYERPASSWORD
initialization is 0x1408d3c60. Disabled readonly checkboxes preserve the original
SetEnabled(false), then SetChecked ordering without accepting pointer input.
The source's repeated LegalCharCheck tag retains both checkbox and nested label.

Extended metadata uses the original six-byte BNDS request and BNDR reply:
header and port, three uint32-length-prefixed strings, then signed int16 game
type. Module description takes precedence over game details. A missing extended
reply preserves cached description and leaves unknown values blank. Game-type
captions come from installed GameSpyRooms.2DA and TLK. Description payloads
remain complete; list rows omit them to stay within the native transport bound.

Details appears immediately from known metadata and updates on query completion.
Close cancels its owned lookup, even before the busy acknowledgment arrives.
Late replies cannot revive a closed or superseded owner. Adjacent navigation
uses the complete filtered catalog, preserves endpoint identity across pages,
and never queries policy-blocked servers. Passwords are transient and cleared on
Cancel, dismissal, scope replacement or submission; the authoritative join still
uses the selected canonical endpoint.

Verified scoped receipts: `native-server-details-input-v2` (28 graphical input
checks), `native-server-details-pages-v1` (32 graphical page regressions), and
`native-server-details-service-v3.tap` (56 service/protocol checks, including the
existing sort/filter instruction oracles). The owned original server's extended
reply is `native-server-details-local-wire-v1.json`; it was captured on loopback
5125 without a public connection. The Details screenshot was visually reviewed.
`native-server-details-local-v1` also passed seven native admission checks and
170 authoritative gameplay actions, with unchanged sources and clean teardown.

Full UI and full browser/Details parity are **not complete**. Open work includes
truncated source-label wrapping/line spacing, exact PvP and local NWSync wording,
version compatibility/color rules, unavailable-server text, DM/platform variants,
source-client side-by-side comparisons at other scales/resolutions, GUI sound,
periodic refresh behavior and remaining admission/connection dialogs. Existing
page/filter milestone receipts describe their historical source versions.
