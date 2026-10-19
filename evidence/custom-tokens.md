# Native custom-token state and synchronization

This storage increment is now supplemented by [parser/client text work](talk-token-parser.md).
The earlier ParseStr limitation below is historical; network/client import and
remaining presentation/context limits are still open in the newer evidence.

Target remains NWN:EE89.8193.37-17 x64, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Original install and Ghidra project remain unchanged. REA dossiers and independent
original disassembly establish the following table, command and packet owners.

`CTlkTable::SetCustomToken14019a5d0..19a7f0` ignores signed-negative IDs;
binary-searches ascending UINT IDs; replaces an existing owned string in place;
or allocates/copies/inserts a new physical record. String initialization clears
a leading NUL but preserves later NULs and stored length. `custom_tokens.js`
models these logical records independently of canonical game OBJECT_ID storage.
The byte-copy adapter now also owns Buffer-backed inputs; Buffer.slice would
otherwise retain a mutable view, contrary to the native string-copy owner.

`ExecuteCommandSetCustomToken140540570..5406a1` pops INT then string. Its
transfer failure code is unusually **-638**, not-639. Only IDs>9 call the table
setter, protecting0..9 at the script layer. The lower table owner can admit0..9.
After a valid update it samples player-list endpoints and sends to each player
whose game object exists. Send failure does not stop later clients and does not
undo the server mutation. Neither player area nor script OBJECT_SELF selects
token recipients.

`SendServerToPlayerSetCustomToken1404df990..4dfa5f` creates storedLength+8
with the recipient PLAYER_ID, writes INT32 token ID and an owned CExoString32,
then sends major0x32/minor1 if payload generation succeeds. Creation size uses
the original string length even when the owning copy later clears a leading
NUL. The protected packet owner and scalar codec remain separate.

SetCustomToken284 is now bound. Server tokens and local client tokens are separate
tables. A local native-scalar body projection decodes ID/string into the recipient
client table; it supplies no invented canonical actor ID as a transport PLAYER_ID.
Absent transport metadata uses an explicitly absent0xffffffff host context,
not a reconstructed network send. Complete original client receiver/network and
dialogue ParseStr presentation remain unavailable and durably diagnosed. Tokens
being stored/synchronized does not mean their display pipeline is finished.

`inspect-native-custom-tokens.py` executes **975 complete original cases**:
table setter, script wrapper, packet coordinator and original InitFromCharArray.
Vector construction/destruction, allocation/free/memcpy, VM transfers, player
lookup, scalar message writers and transport are captured lower boundaries.
Tests compare sorted records, guards, owned bytes, packet calls, leading/embedded
NULs and failure behavior. The existing scalar codec has separate native tests;
its local roundtrip is integration evidence, not an original-client oracle.

Installed Prelude NCS probe, finalv2, passes insertion/replacement, protected and
negative IDs, CP1252/C1 byte aliases, NUL cases, server/client agreement and no
canonical ID allocation. Complete **1,785 tests PASS; build PASS**. Auditv43:
**70 unbound commands /22 missing resources**. The preceding talk-table increment
also passed the rendered casting regression; no new rendered token-expansion
claim is made. Four impact dependencies now reach token storage, while complete
Deck/Rod/crafting spells, spellcasting, combat and the campaign remain open.

Next: native ParseStr `140199e20..19a420`, token-name hash14018d1a0 and active
StringTokens data/callback ownership. REA and original disassembly are captured;
no parser implementation or complete token vocabulary is claimed here.
