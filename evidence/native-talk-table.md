# Native talk-table fetch and script getter

Target: NWN:EE89.8193.37-17 x64, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install/project remain read-only. REA FetchInternal/GetStrByStrRef
dossiers and independent disassembly identify the owners below.

`FetchInternal140198c60..1994b7` now has a shared byte-oriented implementation.
It preserves raw text bytes, sound RESREF and FLOAT duration bits; checks global
overrides before files; selects base/custom and male/female file pointers; uses
per-file caches only for parseflag0; and preserves native warning/fallback order.
Female range/entry-seek/entry-read failure resets the shared gender to0 and
recurses. Text-seek/zero-length failures have their separate clear/warning paths.
Missing base clears text/sound and returns0. Missing custom formats native
BadStrRef(signedRef). Duration storage is preserved on branches that do not write
it. Cold successful raw text fetches insert owned records into that file's cache.

**Correction to the earlier investigation:** invalid0xffffffff reference or
invalid gender clears text/sound, preserves duration and returns **1**, not0.
The first targeted comparison caught this mistake. Original branch joins
`14019945f: mov r15d,1`; the product and historical notes are now corrected.
Native oracle output was not changed to fit the implementation.

`GetStringByStrRef239`, wrapper `140530e20..530f64`, sets BYTE gender0/1
(other inputs0), calls FetchInternal with parseflag0, copies explicit-length
text and pushes it. The shared gender persists after calls, including fallback.
Ordinary raw file strings are not token-expanded; global overrides still invoke
ParseStr. That lower token owner remains explicitly unavailable and diagnosed.
Transfer failure contracts remain-639/-638.

`TalkTableRuntime` owns this server state independently of the UI display cache.
Selected language files are supplied before module startup and can be reloaded
from Tools. Native OpenFile primary `1401995b0..19999a` supports the missing-
female alias to male, while a corrupt opened female file invalidates the pair;
the runtime preserves that distinction instead of swallowing parse errors.
This OpenFile conclusion has static original-code evidence plus runtime tests,
not a complete original OpenFile/resource-resolver execution oracle. The current
host imports selected loose TLK V3.0 files through the existing strict header
parser. Full native TLK resource/disk resolution, legacy header admission and
OpenFile StringTokens loading remain open. Missing files and parse failures
remain recorded. Unknown uninitialized short-read bytes are rejected explicitly;
they are not replaced with invented native text. Non-Western script presentation
is diagnosed while the VM retains its existing bijective Western byte projection.

`inspect-native-talk-table.py` captures **604 complete original fetch/getter
cases**, executing native InitFromCharArray/STR_RES assignment as well. File I/O
and metadata, hash helpers, Format/RESREF assignment, token parsing, allocation,
memcpy/free, logging and VM transfers are explicit lower boundaries. Authored
short-read allocations have known0xa5 fill; no real uninitialized-heap claim.
Tests compare status, record bytes, duration bits, cache writes, I/O calls,
warnings, parser calls and persistent gender. Separate runtime tests cover
base/custom pairs, alias/fallback, corruption, missing resources and unsupported
token parsing. No proprietary strings or TLK assets are copied into reports.

Installed Prelude uses actual English dialog.tlk (112,228 entries): **27 parsed
NCS queries PASS**, including omitted gender, cached reads and unchanged object
ID allocation. Nine entry lengths/hashes are recorded, not their text. Full
**1,780 tests PASS**, build PASS, rendered casting UI regression PASS (spellbook,
radial self-cast, slot use, F2 targeting, animations, cancellation, Counterspell).
The rendered regression verifies language loading and casting, not every new
getter/fallback branch. Auditv42: **71 unbound commands /22 missing resources**.
Four impact-script dependencies now reach this owner; complete Deck/crafting/
mount behavior, spellcasting, combat and campaign readiness remain unfinished.
