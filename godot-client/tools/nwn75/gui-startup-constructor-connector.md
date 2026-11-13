# Original GUI manager startup connector

Pinned `nwmain.exe` SHA-256: `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

The client inner-runtime constructor at `0x1406e3c80` is already connected to the CRT root in the native tree. Its `0x1406e46d9` instruction is `e8 f2 15 b1 ff`, a direct call to `0x1401f5cd0` (`CGuiMan::CGuiMan`). The decompiled owner allocates a `0x2b8`-byte GUI manager, invokes this constructor when the allocation succeeds, then stores the result in `g_pGuiMan`. This connects the existing GUI manager constructor branch, including Overlay/MouseOverlay scene views and mouse/logo Gob models, to client startup. It does not show that those GUI objects draw in every frame; update and draw gates remain separate.

Evidence: Ghidra `procedure_references(0x1401f5cd0, incoming)` `ev_4c8a07cdfab6904211e3eff7f57c95eab4d2b3db336436fb44589aacb7f72822`; exact instruction `ev_6092eb8945bc5b5867dd7d935f401bea975d541fc20a2e1db6c3b32dfc255450`; owner decompile `ev_2077c327f0ba1d2bd5fb8fb7aead9506ad5d79409ab6a2e8aba3381261d45b3a`.

The remaining disconnected GUI ledger sources include interior instruction addresses, multiple-address labels and data/vtable addresses. Their graph disconnection is not by itself evidence of missing runtime branches. Classify each by containing function, callsite or alternate root before adding another connector.
