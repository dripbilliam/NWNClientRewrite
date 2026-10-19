# Server-authoritative area import

Target: installed, unchanged NWN:EE89.8193.37-17 `nwmain.exe`, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original dedicated server remains unchanged. This is protocol/store progress,
not demonstrated playable multiplayer or a renderer integration.

## Native evidence

`SendServerToPlayerArea_ClientArea1404cd9d0..1404ce035`, including calls
1404cdf3c..1404cdf98/1404cdfb6/1404cdff4, writes loading-screen INT,
position/facing FLOATs, transition BOOL, PackAreaIntoMessage, then P/4/1.
Retained analysis: `rea-network-area-client-sender.json`.
Existing original-code packer fixtures execute140363200..140364661,
ambient358750 and sound4f5120. Native/localized/scalar ownership is documented
in the existing area/message evidence and oracles. No original bytes changed.

`SendServerToPlayerGameObjUpdate_ObjControl1404d9b90..1404d9c2c` writes
PLAYER_ID DWORD at1404d9bc6, OBJECT_ID through WriteOBJECTIDServer at1404d9bd0,
then P/5/2 at1404d9c18. These are separate namespaces. Decoder coverage for this
envelope uses synthetic scalar fixtures plus sender analysis; the current live
probe did not receive P/5/2. P/18/11 has NOT been guessed to mean this message.
Retained analysis: `rea-network-object-control-sender.json`.

Client-side named receiver searches returned no matches; that is a symbol-search
limitation, not evidence that the original client has no receiver. Area decoder
parity is based on original sender executions and actual server packets.

## Implementation and validation

`network_area.js` imports area identity/localized-name descriptors, environmental
fields, clock, build-gated fog/grass data, tiles, map pins, sounds, placeable
lights and static placeables. Unclassified native fields retain offset keys;
localized descriptors retain strRef/gender for later TLK presentation. Unknown
trailing record counts fail explicitly. Counts/dimensions are bounded by the
received stream. Client OBJECT_IDs remain unsigned, including bit31.

`NetworkWorld` uses the existing native-compatible GameObjectArray with explicit
server IDs and preserved proxy identity. It validates the complete area object
batch before committing, and owns neither local scripts nor gameplay simulation.
Area/time/ObjControl handling is wired into the private protocol probe. It does
not create a competing ModuleSession. Reset replaces the connection registry.
Old-area cleanup/dynamic-object lifecycle remains for verified update handlers.

Validation:

- Ten original-code area bodies, five installed areas in both format modes:
  complete consumption and recovered native inputs, including tile fields,
  sound fields and static-placeable transforms.
- 393 compatible synthetic original packer cases accepted across build gates,
  fog/grass/pins/light branches;32 deliberate corrupt static flags rejected.
  Native counts nonzero flags but writes only exactly1, causing those corrupt
  fixtures to announce records they omit. No synthetic data overrides live IDs.
- Every truncation of the real ClientArea packet, extra bytes, forged dimensions
  and nonzero reserved trailing records rejected. Conflicting object types leave
  the existing world untouched; repeated entry retains proxy identities.
- Fresh original-server run: `local-network-character-v4.json`,51 received
  reliable frames,24 imported objects (one area, ten sounds, thirteen static
  placeables), nine starting-room tiles, server clock changes, clean BNDM logout.
  Native server log independently records join23:23:44 and leave23:23:56.
- 38 focused network tests PASS before the expanded synthetic test; final five
  area tests PASS after adding that case. Client build PASS (existing bundle-size
  warning). Logs: `network-area-tests-v1.txt`, `network-area-branch-tests-v1.txt`,
  `network-area-client-build-v1.txt`.
- Full-credential audit:1969 source/evidence/script/test and selected capture
  text files, zero occurrences. Credentials stayed in private in-memory input.

## Remaining work

P/5/1 dynamic object updates, local-player binding, player-list/GUI messages,
authoritative movement requests, actual renderer/UI connection, transitions and
all shared gameplay remain open. Current unhandled messages are still diagnosed:
18/11,2/12,52/3,10/2,10/1,5/1,18/20. Local server's preexisting empty-GFF-label
warning on last-player module reload remains unchanged. No original-client
concurrency validation has occurred. The multiplayer goal remains ACTIVE.

Post-seal checkpoint: `backups/multiplayer-area-import-20261017-v1.zip`,11865
files/190586180 bytes, every archived file length/SHA256 verified; all11 selected
source/evidence/capture entries present, no executable/object/BIC/module assets or
credential-profile files. Writer53385 exited0. This note and list formatting
were added after sealing.
