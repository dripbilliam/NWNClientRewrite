# Native resource loading and caching parity

Active goal, started 2026-10-30. Target resource and world-loading performance
at least as fast as the original NWN executable. This covers all resources,
including models, textures/palettes/materials, animation/supermodels,
tiles/walkmeshes, audio/music, rules/2DA/TLK, GUI/fonts/icons, archives,
Workshop, NWSync and server overlays. It is not a menu-only optimization.

## User authorization

The user explicitly permits major foundational changes, provided backups are
made. Previous user-imposed experimental overrides or safeguards do not constrain
this investigation or testing. Keep a verified rollback checkpoint before each
significant architectural change; identify experimental failures separately from
accepted improvements. Use the original binary's methods as the primary reference.
These permissions do not make an unmeasured change a performance success.

## Work and acceptance

Compare native resource lookup, residency, request coalescing, source reads,
decompression, decoding, model dependencies, publication and release. Retain
unchanged data across catalogs without sharing server-specific resref bindings
or mutable live objects. Preserve server/mod precedence and content invalidation.

Measure comparable cold/warm startup, reconnect, area transition and first-use
streaming, including worst frame stalls. A passing functional fixture or a
faster warm catalog is not original-client loading or FPS parity. The goal stays
active until measured scope and remaining gaps are explicit.

## Current investigation

The pre-change same-process installed-resource baseline is retained in
`reports/native-resource-residency-baseline-v2.json`: three new catalog mounts
took approximately 1204, 1429 and 1541 ms. Each catalog missed the decoded class
table cache. The fixture checks exact source identities across nine resource
types; these are CPU timings in this environment, not original-executable times.

Experimental changes add content-validated resident archive indexes, shared
content-addressed native decoding and verified NWSync byte residency. Initial
tests caught a missing parser argument, a packed-byte ownership error and a
test which assumed more simultaneous worker slots than available. Failed
receipts remain in reports. These changes are not yet accepted.

Known-good pre-change rollback:
`backups/native-remove-menu-shortcut-v1.zip` (verified manifest).
The open manual game is preserved; current automated checks use offline/local
data and do not initiate a public connection.
