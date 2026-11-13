# Original platform UI renderer startup connector

Pinned `nwmain.exe` SHA-256: `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

The CRT-connected main procedure `0x140046340` reaches `0x140a70a50` at direct callsite `0x140046da5`, after setting the window size and running `startup.txt`, before its `Update` loop. The startup helper initializes UI renderer globals and directly calls `0x140a6f9d0` at `0x140a70aee`. That callee initializes the UI draw context and compiles/links two OpenGL shader programs, obtains their uniform/attribute locations and initializes GPU buffers. This is one-time renderer preparation, not a repeated per-frame shader compile. Its existing downstream ledger remains conditional on the UI being used and drawn.

Exact instruction evidence: `0x140046da5` bytes `e8a69ca200`, target `0x140a70a50`, `ev_08ca770715a8398825b6d47d7f3bbd08216227b9e98da4c25e1ed49839321b04`; `0x140a70aee` bytes `e8ddeeffff`, target `0x140a6f9d0`, `ev_f078b0887b46c752d9aa031ca71c2454b41c5d8cd649c2ced1748287f0facedb`. Owner pseudocode: `ev_833c7aa9adb229ef33dd413c495d7c0f61fbec645c741d6268e78b62f252dd65` and `ev_69754b1afedf071d1d8718ad7ae8156dce2239821b089bba015e3ef8e299e361`; GPU setup pseudocode: `ev_faee64a092bd08c0f8a48f20e46fa3e4718facf1914d4368cd7004c1f12ad9d7`.
