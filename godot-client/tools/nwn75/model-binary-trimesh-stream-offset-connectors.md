# Binary mesh stream-offset publication connectors

Pinned original `nwmain.exe` SHA256: `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. The [connector ledger](model-binary-trimesh-stream-offset-connectors-ledger.json) joins the already reached binary metadata copier `0x140078ab0` to fourteen exact `MdlNodeTriMesh` offset fields used by the [fifteen stream pool triplets](model-binary-trimesh-pool-streams.md). Binary AABB, Dangly and ordinary TriMesh node branches call the metadata copier, then the common stream builder `0x14007be10`. These joins are resource-load/geometry-publication work; they do not imply per-frame rebuilding.

`0x140078ab0` copies serialized dwords to node fields before the stream builder reads them. Its original body and complete write sequence are REA `ev_369f96f7ff970800e58d8518842e706e51223d2fc07fe461547b388fb21a1bee`. Each write below has separate exact instruction evidence in the ledger:

| Serialized offset | Node offset | Store site |
| --- | --- | --- |
| `0x21c` | `0x268` | `0x140078c9e` |
| `0x22c` | `0x280` | `0x140078cc2` |
| `0x234` | `0x288` | `0x140078cea` |
| `0x238` | `0x28c` | `0x140078cf6` |
| `0x23c` | `0x290` | `0x140078d02` |
| `0x240` | `0x294` | `0x140078d0e` |
| `0x244` | `0x298` | `0x140078d1a` |
| `0x248` | `0x29c` | `0x140078d26` |
| `0x24c` | `0x2a0` | `0x140078d32` |
| `0x250` | `0x2a4` | `0x140078d3e` |
| `0x254` | `0x2a8` | `0x140078d4a` |
| `0x258` | `0x2ac` | `0x140078d56` |
| `0x25c` | `0x2b0` | `0x140078d62` |
| `0x260` | `0x2b4` | `0x140078d6e` |

The [existing pool ledger](model-binary-trimesh-pool-streams-ledger.json) separately records each field's RequestPool/LockPool/UnlockPool triplet, including format gates, absent-offset sentinel `0xffffffff`, byte counts and kind 0/1 selection. Those conditions remain intact. The fifteenth marker `MdlNodeTriMesh+0x258 indexed list` is different: the stream builder uses a per-entry list from serialized `+0x210/+0x214`. The common stream builder `0x14007be10` instead reads serialized count `+0x214`; when positive, it grows/reuses node list `+0x258`, stores the grown pointer at `0x14007c36e` (`ev_d4710dca72b99bf7c39d3169f4de17367bbdbfb82df46f8d4dd69b735ea9d686`), and copies `4*count` bytes from serialized offset `+0x210` at `0x14007c397` (`ev_bc3d6ab5f2733cfb1eb729e78b367229283da46b3b673550cbe90f6c2af85959`). It then iterates positive list entries for kind-1 pool triplets. The zero-count route does not build that list. Actual asset subtype, serialized offset validity, pool allocation, GL upload and visible draw are runtime gates; no frequency follows from this static map.
