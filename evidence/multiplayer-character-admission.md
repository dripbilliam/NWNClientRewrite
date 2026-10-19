# Resource negotiation, character admission and area-stream start — 2026-10-17

The replacement probe resolves the original server's advertised campaign
resource, uploads an unchanged installed wizard BIC, receives native character
confirmation, decodes compressed module information with server-assigned area
IDs, sends the module-ready request, and receives ClientArea/object-update
messages. The final live run exchanged52 frames and disconnected cleanly.
World-message handlers, renderer/production UI integration and simultaneous play
with original clients remain open. This is admission progress, not playable
multiplayer acceptance. The full goal remains ACTIVE.

## Original targets and live evidence

Same read-only client89.8193.37-17 SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`,
server SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
Owned native server PID12956, isolated profile/Prelude/UDP127.0.0.1:5121.
User authorized captures and read-only observation; no process injection,
original binary edits or server extensions were used.

- `local-network-character-v1.json`: resource reply decoded/resolved, original
  `data/lcv/wizard.bic`35919 bytes uploaded, native P/2/5 confirms character.
  A148-byte persistent-compressed record was recorded as unimplemented at that
  point; its native plaintext is157-byte Module_Info. No area-ready sent yet.
- v2: resource gate, character confirmation, module-information decoding and
  module-ready all succeed;56 received frames include native P/4/1 ClientArea,
  P/5/1 object updates and player/GUI messages. No decompression/invalid-message
  failures. Server logs show join23:06:03 and clean leave23:06:23.
- v3: final source repeats the full flow with language read from installed TLK,
  corrected module clock field naming and distinct diagnostics;52 received frames,
  native character confirmed, module-ready sent, clean BNDM logout. Independent
  server join/leave23:12:17/23:12:29. Only unimplemented game-message diagnostics
  remain. The original server stayed responsive.

The BIC is sent as existing installation bytes. A GFF structure check precedes
upload; singleplayer semantic-import limitations do not gate network characters.
Our code does not rewrite its
stats, generate replacement IDs, validate on the server's behalf or run local
module AI/scripts. Native HandlePlayerToServerLoginMessage -> LoadCharacterStart
owns loading/validation. The native confirmation is distinct from transport ACKs.
Original installed assets are referenced/read, not manually copied into source.
The native server naturally owns its isolated runtime/profile files.

## Native resource schema

Status sender1404df850 in server mode2 writes an empty CExoString, followed by
PackModuleResourcesIntoMessage140483040. Modes0/1 instead emit empty P/1/2
(unavailable) or P/1/1(loading). Packet/request prefixes remain P(server) and
p(client); the empty status request is p/1/0, confirmed by458b90/45d140.

Advertisement::WriteToNetwork1401b3d40 / ReadFromNetwork1401b3320:
BOOL presence; if present, primary SHA1 CExoString, versionBYTE1, URL CExoString,
additional-countBYTE, then SHA1 CExoString/flagsBYTE/languageBYTE per manifest.
GFF owner1b1f20 labels the latter fields Flags/LanguageID. Native reader consumes
the version byte without interpreting it; the decoder preserves it. Invalid or
empty hashes remain empty values and cannot satisfy the resource gate.

SHA1 constructor140187d00 checks CRT strspn prefixes, not a full-string regex:
exactly40 leading hex characters are accepted if not40 zeros, even when followed
by a nonhex suffix;41 leading hex characters are rejected. Accepted bytes become
lowercase hex. Manifest::ShouldLoadOnClient1401b3c10 accepts language255 or exact
native TLK language when the talk-table/file provider exists. Higher language
integers do not get truncated to the manifest byte.

After advertisement: custom TLK CExoString at native module+88, NWM resource name
CExoString+450, HAK-countBYTE and ordered16-byte resrefs. Load/save instructions
140486269..27d associate+88 with Mod_CustomTlk;14047f05b..085 and4862c0..2d4
associate+450 with Mod_NWMResName. HAK names retain native wire casing. Native
advertisement/force-legacy branches govern whether HAK references are emitted;
the decoder reads the actual list rather than inferring requirements by module.

`network_resources.js` decodes this schema and gates admission on supplied file/
manifest resolvers. Missing/invalid resources/providers record diagnostics.
`installed_network_resources.mjs` inventories configured installation/profile
directories and matches names without joining server strings into paths. It
supports optional existing extensions, case-insensitive lookup, ordered resource
requirements and installed dialog.tlk language. This is an availability gate;
archive parsing/integrity remain the existing resource-loader responsibility.
An NWSync downloader/cache provider is still required; advertised manifests cannot
silently pass just because base-game files exist. No URL is fetched by this pass.

## Character ABI and module information

Handler140457850 reads DWORD byte count plus ReadVOIDPtr1402da400 for subtypes
1(local BIC),4(DM),19(create-server BIC), checks over/underflow, then calls native
LoadCharacterStart. Instructions457e5e..457e7d pass the exact pointer at stack20
and length at28; the wrapper is55bb90 and server owner564b10. `network_character`
implements these blob writers; only subtype1 was used in live testing. Server-vault
selection/creation and the UI owner remain to be integrated/verified separately.
Native senders confirm P/2/5, reject P/2/18 with reasonDWORD, and request a character
with empty P/2/16. The decoder preserves those meanings and rejection values.

Module_Info4dcf20 -> PackModuleIntoMessage482d40 writes: module resource name
(after path alias), localized display-name value, minutes-per-hourBYTE, entry-area
resref16, area-countDWORD and area ID/name records, official-campaignBYTE and
conditional server flags. Field+3b8 is Mod_MinPerHour, established at480a61..a80;
an early v2 capture label was corrected to minutesPerHour in final v3/source.
Localized names retain text or TLK strRef/gender without inventing resolved text.
Server flag semantics at158/164/168/16c remain explicit offset names pending
individual field research.

Optional flag availability calls CNWSPlayer::SatisfiesBuild4bd6d0 -> peer owner
24ff10. Its number/revision checks are independent lower bounds, not ordinary
lexicographic version ordering. Debug format0/pretend-old override decisions have
native fixtures; current message decoding uses the observed normal format1.

Module-ready p/3/2 is verified in HandlePlayerToServerModuleMessage459760. The
probe sends it only after resource readiness, native character confirmation and
module information. Native InitiateModuleForPlayer then supplies world messages.
No complete original-client starting-sequence/concurrency claim is made yet.

The final module info contains5 raw unsigned wire area IDs, including80000001.
The namespace bit is preserved by ReadOBJECTIDClient; no transport application/
crypto identity is substituted. World-object registry and64-bit effect/property
replication are still the next integration layer.

## Compression and verification

`network_message_inflater.mjs` implements UncompressMessage255c80's separate
block/persistent zlib paths: compressed bit2, stream bit0, LE32 expected output
at12, compressed bytes16 onward, maximum20MiB. A single inflater survives ordered
messages for the peer. Output bounds/failures are explicit; Node streams are
closed at teardown. Standard Node zlib performs the codec; the original server's
real compressed records provide independent integration evidence. Persistent
output is required to match declared length instead of exposing native undefined
tail bytes on malformed input. Failures receive dedicated decompression diagnostics.

- `inspect-native-network-resources.py`:9 actual status/resource serialization
  cases;11 SHA1-constructor cases;18 manifest-language cases;144 exact peer-build
  cases. Settings/module/vector ownership, final send, CRT span and hex conversion
  are documented captured boundaries; original decisions/scalar encoders execute.
  Finalv6 PASS. Initial fixture/hash/casing assumptions were corrected against
  actual native bytes; no test uses a particular campaign as its codec rule.
- `inspect-native-network-character.py`:8 original scalar-upload/login-handler
  executions, exact blob/pointer/length routing for local/create-server forms;
  native character validation itself is covered by the live native server.
  Unknown low padding bits are excluded from byte comparisons, as in the existing
  native writer evidence; no uninitialized bits are treated as semantic data.
- 37 focused network tests PASSv4: prior discovery/auth/frames plus resources,
  gates, native predicates, upload ABI, captured module/area-stream start, bounded
  block decoding and consecutive persistent compression. No full suite run.
- Client build PASSv2, existing bundle-size warning. Singleplayer simulation
  source is unchanged. The probe still has no renderer or production UI owner.

Credentials stay in memory/private input pipes; no full key, argv/environment
credential or raw pre-login auth body is written into reports. Authorized
post-login data captures remain local/ignored and are checkpointed as evidence.
Final source/capture audit:1976 text files checked,0 full-key occurrences.

## Next frontier

Implement P/4/1 ClientArea and P/5/1 object-update import into a server-authoritative
world store, then renderer/avatar/movement wiring. Existing singleplayer-native
area packing/message primitives are useful schema evidence, not permission to run
local AI/combat/scripts in multiplayer. Other observed unhandled codes are18/11,
2/12,52/3,10/2,10/1,18/20; each occurrence remains recorded. GUI object binding,
waypoint/entry handling, player list and remaining replication must follow native
owners, including server-assigned IDs and effect/property widths. NWSync/content
download, production connection lifecycle/UI and original-client concurrent play
remain required parts of the active objective.

Verified checkpoint `backups/multiplayer-character-admission-20261017-v1.zip`:
11849 files/190231968 bytes, every archived length/SHA256 verified. Writer19182
completed exit0;17 required new source/evidence/test entries present, no executable,
object/module/BIC asset, credential file or private server profile included.
Final structural-check change passed syntax check and8 focused admission tests.
This seal note was added after verification. Goal remains ACTIVE.
