# Original-client coexistence — 2026-10-18

Status: demonstrated arrival, movement, replacement reconnect and one shared
spell on an unmodified Prelude server. Full multiplayer goal remains ACTIVE.

The user manually joined the owned vanilla server at192.168.0.21:5121 using
the Steam NWN:EE original client. Its title reports89.8193.37-17[26c6e573].
Computer Use observed character selection, area loading and live gameplay;
the user selected the character and performed the movement. Research binaries
and running processes were not patched or injected into. Server character
validation remained enabled; both sessions used different existing keys.

Capture v65: replacement wizard Spectorial Melimion connects before the original
character enters. Native10/2 announces player0, Zachario Arna, raw client object
ID0xfffffff8; the replacement is player1/object0xffffffff. The replacement
receives175 remote-character samples and seven distinct positions, walking1
and idle0. Two ordinary replacement movement requests receive server positions.
237 samples/6827 GPU frames, no runtime errors, clean disconnect.

Capture v66: replacement reconnects while the original client stays in the
world. Its hotbar Ctrl-F8 enters the shared spell targeter; a real production
canvas click selects the other current player by native player-list ID. The
test selector uses replicated player IDs, not names, module rules or an NPC
index. Exactly one native6/18 request sends spell100 and target0xfffffff8.
Server cast records repeat that target, and the server-prepared Light count
changes2->1.3619 GPU frames, no runtime errors, clean disconnect.

Original-client screen shows replacement leave/rejoin and both casting and
cast messages. It labels the spell unknown, so that text alone is not proof
of its identity; the captured native request/server cast record supplies it.
The user independently confirms: "light is following me." Retained original
comparison screenshot and replacement screenshots agree with a successful
shared cast. No client-side spell execution or spending was added.

New replay tests preserve player/control identities and the same remote proxy
through all captured wire updates. The second capture verifies the targeter,
request target, server cast and server-owned prepared-use change.37 affected
tests PASS(network-original-client-coexist-tests-v2.txt); harness syntax PASS.
An initial test incorrectly assumed spellbooks was an array; the assertion
now reads the actual indexed replicated store. No production bundle changed.

Still open: shared combat and transitions, reverse-direction casting, item
powers/preparation, full effects/audio, party/chat/status presentation and other
unsupported packets. Original party bar shows blank reserved PC slots; the
replacement currently labels unavailable roster IDs as objects. Successful
Light interoperability does not establish completeness of other spells or UI.

Files: local-network-renderer-v65/v66.json and diagnostic pairs; replacement
local-network-coexist-v65.png,local-network-coexist-late-v65.png,
local-network-coexist-cast-v66.png; original-network-coexist-cast-v66.jpg.
Private key/settings/server-profile material is excluded from checkpoints.

Verified checkpoint multiplayer-original-client-coexist-20261018-v1.zip:
13231 files/270005954 bytes, writer54031 terminal0, all entry lengths/SHA256
verified. Scope15 required present/forbidden0. Credential audit11748 files,
private hits0; the first sequential audit exceeded the tool time limit and was
replaced with a completed bounded parallel scan. This postseal note and scope
and completed audit records are outside the sealed archive. Server36824 and
original client14604 remain running; both replacement QA processes exited.
