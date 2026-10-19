# Native substring and vector magnitude helpers

Target: NWN:EE89.8193.37-17 x64, original executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
REA command dossiers and independent original disassembly agree. Read-only
research; original executable and original Ghidra project remain unchanged.

FindSubString `1403136a0..31378e` pops two strings and, only with argc>=3,
an integer offset (otherwise0). `CExoString::Find14016aea0..16af05` rejects
null buffers, negative offset and offset greater than stored byte length.
It calls original `strstr140c422bc..c424bb` starting at that offset. Thus an
embedded NUL limits the search from that starting point; an offset after an
earlier NUL can still find later stored bytes. Matching is case-sensitive and
returns a byte offset, not a Unicode UTF-16 index. Script strings retain the
existing Western byte codec, including the Node/browser C1 aliases.

Representation limit: the replacement VM has semantic string values. Native
null-backed empty and explicitly allocated-empty CExoStrings can yield different
Find results. The helper follows ordinary null-backed empty strings; the oracle
retains four allocated-empty representation cases separately, without claiming
they match the semantic VM. Full native string-buffer ownership and all producer
representations remain open. Native StackPopString `1402861b0` moves buffer,
length and capacity verbatim; it does not prove all producers canonicalize empty
buffers. This limitation must remain visible during subsequent VM work.

VectorMagnitude `14054ab00..54ab5f` calls leaf `1402303d0..23040c`.
It squares in f32, adds X+Y then Z in f32 and calls native sqrtf for positive
squared length. Zero or unordered squared length returns fresh+0. Overflow
returns Infinity; nonzero underflow can return0. No double-precision hypot or
render-basis coordinate conversion substitutes for the original arithmetic.
The verified direct jump into sqrtf is separate from the leaf CFG; the initial
CFG request rejected that nonlocal tail, and is not complete-function evidence.

`inspect-native-find-magnitude.py` captures **1,477 original cases**: full
FindSubString/VectorMagnitude wrappers and native Find/strstr/magnitude/sqrt
lowers. Typed VM transfers, string ownership and floating-status notification
are captured boundaries. There are **1,473 semantic comparisons/contracts** plus
the four separate allocated-empty representation observations. SSE dispatch0,
round-nearest/no FTZ; no whole-VM or CRT errno/status claim. Golden tests cover
byte aliases, omitted offset, NULs, overflow/underflow, NaN/Infinity and transfer
failure codes-639/-638. The installed probe passes actual parsed NCS dispatch
with omitted/explicit offsets and FLOAT results; canonical IDs are unchanged.

**1,770 full tests PASS; build PASS; installed probe PASS.** Auditv40:
**74 unbound commands /22 missing resources**. These helpers remove dependencies
from Slayer, mount, Deck of Many Things and Clone Fist impact scripts; complete
spell behavior is not established by binding presence. Speech-by-reference still
requires queued action and native message owners; its REA research dossiers do
not constitute an implementation. Full spell/combat/campaign work remains open.
