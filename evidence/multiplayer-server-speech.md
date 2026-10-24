# Server messages and one-liners — 2026-10-19

Core multiplayer continuation. Campaign play exposed invisible server-authored
instructions: unsupported9/12 packets contained Pavel's direction to Bim and
Bim's tutorial stages. A locked quest door is not overridden locally. Native
speech now feeds a read-only Messages/System log, preserving server text, IDs,
localization, context, sound resref and sound flags. Outbound chat, other chat
channels, voice/overhead presentation and full native window artwork remain
unfinished and are not claimed by this change.

Read-only target89.8193.37-17 nwmain SHA256
3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a;
nwserver SHA256
98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6.
Original binaries and Ghidra untouched. REA retains the large77c140 dossier;
rea-feedback-client-router-view.json reads its complete49631-character
pseudocode through inspect_analysis_view after the transport-size limit.
This is handler evidence, not a full-subsystem decompilation claim.

Client major9 ->14077c140. Minor5 reads only CExoString. Minors11/12 read
OBJECT_ID, context OBJECT_ID, native CExoLocString, CResRef16, BOOL and sound
OBJECT_ID. The native branch also chooses text/voice behavior; raw soundFlag
is preserved even though a nonempty resref overrides it in native presentation.
Other chat layouts (including sender position/name and strref-only variants)
remain outside the new decoder and continue to be diagnosed as unsupported.

Server1404d31c0 SendServerToPlayerChatMultiLang_Helper writes the complete
11/12 packet using actual scalar/OBJECT_ID/localized-string codecs. Its
type8 gate and one-liner flag select major9/minor11 or12. Complete original
writer oracle:64cases vary format0/1, custom/reference text, gender, one-liner,
soundFlag and empty/nonempty sound. Transport1404dc490 and locstring
destruction1401695b0 are captured lower boundaries; language lookup and real
localized-string selection execute. No live process or asset mutation.

Production validates both stream boundaries and preserves uint32 IDs. The
frontend resolves server-selected text using the existing installed TLK/token
adapter and provided context, never a local DLG graph or scripts. Empty native
speech control lines add no blank rows. Read-only source names come from the
canonical proxy; textContent prevents server strings becoming HTML. Messages
includes all implemented speech; System filters9/5. Local display history is
bounded200rows, while unsupported feature diagnostics retain their own journal.
History survives area transitions and resets at session entry/exit. Nonempty
sound/flag without an audio adapter records network.speech-audio-unhandled.
Native fallback to embedded TLK voice metadata is also not yet connected.

52focused tests pass, including32 format1 original packets and real captured
campaign one-liners, plus container/inventory/session/item-action/Examine
regressions. Full network integration milestone:246tests pass. Buildv1 passes
with existing size warning. Installed DOM UIv1 passes Messages/System filtering,
safe text, empty-line suppression, reset and existing spellbook/inventory/HUD
regressions. Earlier placeable UIv2 failed because the drag check waited only
30ms; a bounded wait for the actual async assignment corrected it (v3 pass).

Live v103 displays Bim's server-selected instructions with his canonical name
in the inspected PNG. It does not prove voice playback or outbound chat.
Campaign, placeable looting and subsequent progression results are recorded
in multiplayer-campaign-progression.md. No original-client concurrent
acceptance is inferred from a running original-client process.
