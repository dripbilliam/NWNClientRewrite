# Native multiplayer spell notifications

CC18/8 packets now feed the same native-derived decision tree used in local play.
The formatter has synchronous and asynchronous service drivers; packet decoding
and text/resource providers differ, but template selection and token ordering
have one implementation. Notifications do not start animations, resolve spells,
spend slots, mutate hit points or create canonical objects. Existing replicated
cast/animation/effect messages remain responsible for those presentations.

## Original evidence and boundaries

Read-only installed NWN:EE89.8193.37-17 win64 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
See `client-spell-message.md` for the original complete bounded CC8 receive case
1407760c1..1407766bd, server writer1404cf090 and prior1536client/1280server cases.

New `inspect-native-spell-feedback-wire.py` executes180 whole original CC8 writer
cases with actual native scalar, OBJECT_ID, CExoString, localized-string and
GetWriteMessage encoders. CC getters, item lookup, string copies/cleanup,
allocator and final transport are captured lower boundaries in synthetic memory.
The original binary, running original client and vanilla server are unchanged.
No original game assets/binaries are copied into the workspace.

Matrix: three source IDs (includingffffffff and OBJECT_INVALID), three spell IDs
(including signed-negative lookup cases), both identified/cast flags and five
item/name states. Item presence does not transmit an item ID. Unidentified base
type is BYTE even on this build; localized names may contain either inline bytes
or gender/STRREF. Inline localized entries override the base STRREF on the server.
Only unowned low bits of the final packet tail are excluded from comparisons.
Original reference/inline rules are retained, rather than inferred from English.

New REA checks confirm name wrapper1406abfc0 forwards to1406d83f0. Local-player
wrapper1406ac1a0 ->1406d8ad0 ->1406ab9e0 ->1406d8100 looks up the controlled ID in
the canonical object array and returns only a creature. Client object reader
1409737c0 copies the full uint32; localized reader1409735f0 uses FetchInternal
with parse0. The network adapter therefore keeps transmitted IDs and copied
names; it does not try to find a consumed item in the world.

Active `spells.2da` Name/AltMessage and active `baseitems.2da` Name supply lookup
metadata. Installed/server-overridden talk tables supply templates. Client custom
tokens0..2 share state with CC11 and server50/1 updates, in serialized message
order. Alternate messages preserve prior token1/2. Name and surrounding message
colors remain nested native byte RGB text spans. Invalid spells produce the
native empty display result, omitted by the current log widget.

## Validation

Focused tests compare real180packetbytes, strict truncation/trailing rejection,
all1536original synchronous receive cases,512 successful asynchronous formatting
paths,1280typed original writer cases, consumed/unknown item names, alternate
templates, signed invalid IDs, active rule changes, server TLK overrides, shared
tokens, canonical nonmutation and disconnect during asynchronous name fetch.

Installed-resource Electron HUD fixture passes with actual cantrip name/template,
cyan local name and purple surrounding message, existing chat/system panes and
other HUD checks. Screenshot visually inspected. This fixture does not cast or
send packets to the server. Broader tests/build and live acceptance are recorded
below when complete; running v112 predates this source pass.

## Remaining scope

This is spell-notification presentation, not completion of combat/spellcasting.
Native generic CC11 complex branches, attack logs/floating results and network
combat/spatial audio remain outstanding. Full item/store/placeable fallback
names, exact log widget typography and duplicate join notices need further work.
The full multiplayer goal remains active, including shared original-client play.


## Verified checkpoint and live acceptance

Checkpoint multiplayer-spell-feedback-20261019-v1.zip VERIFIED14892files/423012802bytes; writer15651 terminal0 consumed. Independent audit68767 terminal0:14893entries/33required/0missing/forbidden/duplicates/new credential candidates,43changed/new text scanned, every entry hash/length checked.317relevant tests and build PASS; existing bundle-size warning only.

SEALED real vanilla-server UI test v113/PID45572: local-network-spell-feedback-v113.json,48wiremessages,7actual UI actions, finalclosed, no failure/sampleFailure. Spellbook Light100 was dragged to empty quickbar34, activated, then targeted through the self portrait. Native30/2 shortcut assignment and6/18 spell-cast request were sent. Two actual incoming18/8 packets decode to cast-start and release for canonical sourceffffffff; correct installed names/native colors render. Server-replicated prepared Light records go2ready to1ready. Actor clips observed nwreadyr/conjure2/castup/castuplp/pause1; authored conjure visual loads/plays/destroys. These observations do not prove full spell/audio parity. Original33744 remained connected on server20964; its display was not controlled or inspected during this test. Screenshots inspected.

LIVE passive v114/PID13380 playing m0q1a alongside Scary Bill(original33744) on server20964; zero errors, unsupported game packets, failed objects or sampler failures in startup window; echo replies9. No automated actions scheduled. v114 report unsealed while open. Prior v112/PID9036 closed normally; sealed local-network-feedback-v112.json has192wiremessages. Acceptance/snapshots are post-checkpoint: network-spell-feedback-acceptance-v1.json. Full goal ACTIVE.

Next investigation: remaining generic CC11 formatting owners and other native CC18 minors for attack/damage/floating feedback. network-cc-feedback-minor-owner-map-v1.json and rea-cc-feedback-dispatch-all-minors.json map all24 jump targets; only8and11 are connected so far. CC3 writer includes two OBJECT_IDs and build-gated13/32 optional14-bit WORDs, but its semantics/presentation have not yet been validated. Retained whole branch assembly is client-cc-receiver-dispatch-v1.txt. No server patch/NWNX/local combat simulation introduced.
