# Immediate and queued string-reference speech

Target: NWN:EE89.8193.37-17 x64, executable SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Read-only original-code research; the original executable/install and Ghidra
project remain unchanged. REA warm session65686 was revalidated successfully.

The shared wrapper `ExecuteCommandSpeakStrRef140546970..546bc8` handles
SpeakStringByStrRef691 and ActionSpeakStringByStrRef240. Successful typed pops
precede command-mode1, low-byte object-array status0 and AsObject checks. Native
exclusions are exactly refs0x24/0xcf90/0x9e33/0xbe3/0xbd8. Volume1 maps to channel10,
volume2 to9, everything else to8. Immediate691 ignores commandability; queued240
requires nonzero object+ec and queues native action33 with two INT parameters,
ref and channel, using group65535 (ordinary AddAction group allocation).

Full action `AIActionSpeakStrRef1404a70e0..4a784c`, with Tracy disabled, casts to
creature and calls ActivityManager(2), SetActivity(1,0), then sends the stored
reference/channel and returns2 regardless of send result. The runtime invokes
the existing shared activity owners, retaining their diagnosed unsupported
branches; it does not synthesize completed activity changes. Action33 now goes
through the shared object action loop for creature and noncreature CNWSObjects.

Recipient coordinator `1404d3320..4d359f` sends channel9 through native special
recipient0xfffffff7 and returns sendResult&1. Channels8/10 use20m/3m respectively;
other channels return0. Missing source lookup/object returns1. Same-area viewers
are tested with f32 Y²+X²+Z² and inclusive radius. Null areas may compare equal.
The player-list endpoints are sampled once. Bitwise accumulated send failure
does not stop subsequent sends (unlike the separate QuickChat coordinator).

Protected writer `1404d4660..4d46fd` creates size8, player0xffffffff, flag1;
writes server OBJECT_ID then DWORD32 strref; sends major9/minor-channel only
after successful payload generation. `speech_strref.js` separates these native
coordinators from lower lookups, activities, scalar message codec and transport.

`inspect-native-speech-strref.py` captures **5,084 complete original cases**
covering wrappers, queued action, radius/shout and protected packet coordinator.
Golden tests compare calls, cast counts, native guards, negative/raw inputs,
inclusive radius, area identity, failure accumulation and packet transfer order.
The native scalar writers, activity effects, queue allocator, VM and transport
are explicit captured lower boundaries; they are not proved by this oracle.
Original scalar codec has its existing separate native tests. A local body
roundtrip checks its integration, without claiming an original-client oracle.

The local runtime uses native scalar packet bodies and preserves separate
canonical actor and client wire references. It supplies no invented transport
PLAYER_ID. Immediate/queued NCS probes in installed Prelude pass, including
excluded refs, commandability, action parameters, actual shared-loop completion
and unchanged canonical allocation cursor. The UI log resolves current loaded
talk-table text and records missing references. Full native client TLK token/
voice/lip/overhead behavior remains incomplete and durably diagnosed. Shout's
local client-list projection is explicitly diagnosed; full network special-
recipient routing is not established. Existing SpeakString remains an older
approximation, not fixed by this strref increment. GetStringByStrRef is still
unbound; its native owner has now been located at140530e20.

**1,774 tests PASS, build PASS, installed probe PASS.** Rendered spellbook,
radial self-cast, slot consumption, F2 targeting, casting animations, cancellation
and Counterspell radial regression PASS (`speech-strref-casting-ui-v1.txt`).
The rendered regression does not itself generate new strref speech; NCS/native/
UI-log checks cover that addition. Auditv41: **72 unbound /22 missing resources**.
Nine immediate speech dependencies and one queued dependency now reach these
owners; complete affected spells, combat and the campaign remain unfinished.
