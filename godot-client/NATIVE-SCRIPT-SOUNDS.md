# Direct native server script sounds

2026-10-27. Server9/7 now reaches the direct native Godot audio owner. This is
component acceptance; actual-server/device/mixed-client acceptance remains open.
The user's interactive client was preserved. No automated server connection or
graphical workload was run for this change.

## Original behavior

Unchanged NWN:EE89.8193.37-17 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.

Original server4ccfe0 writes9/7 OBJECT_ID and CExoString. Client77c140 checks
stream state, looks up the source at77c9fb and rejects missing sources. The
77cb3e block calls virtual+58 for its creature cast and +18 for CNWCObject;
77ccba/77ccd2 checks the GUI owner/readiness. Playback77e330..77e3bb constructs
a16-byte CResRef, then uses CNWCObject position+38 when available; otherwise it
calls the nonpositional wrapper. Priority8, height0, delay0, volume0 (retain
source default127). This is a fixed-origin one-shot, not actor-owned voice+e8.

Read-only current disassembly is retained in
`../backups/animations/native-script-sound-gates-current.txt`.
`native-script-sound-class-casts-current.json` retains original RTTI/virtual
addresses and instructions. Registered CGameObject bases for module/area return
null from+18; creature/item/trigger/projectile/placeable/door/area-effect/map-pin/
store/sound return the CNWCObject base. Area/item's multiple-inheritance offsets
are explicit. Unknown proxy types are diagnosed, rather than assigned a guessed
2D or 3D cast. These are static observations, not full-handler runtime evidence.

The retained original network-audio corpus contains20 bounded77e330 executions
and15 format1 writer packets (plus other writer/wrapper/listener cases). The
native data test compares every one of those20 playback cases, including empty,
overlength, CP1252 and embedded-NUL names. Protocol tests run all15 packets
through the real decoder and new transport. Common GUI/admission remains a
separate integration boundary; the corpus does not execute all of77c140.

## Native route and cleanup

The protocol decoder retains raw CExoString bytes as well as its existing text.
RawScriptSounds forwards immutable decoded fields and the shared canonical
lifetime. It performs no sound-name selection, resource lookup, decoding or
playback. Keeping raw bytes until Godot's CResRef selection avoids converting an
embedded NUL into a Unicode replacement character before native truncation.

Godot script_sound.gd selects source class, sixteen-byte name and profile.
script_sound_world.gd uses a matching physical actor's current pose when one
exists, or the captured source fields for a nonrendered proxy. No physical model,
interaction/highlight registration or fake canonical object is required. A
known newer actor lifetime rejects an older request. Already-started one-shots
keep their fixed origin and may outlive source removal. Empty names do nothing.

The existing native effect asset worker, catalog precedence, WAV/BMU decoder,
listener, stream cache and mixer-retirement owner perform all preparation and
playback. Audio retirement remains part of the world scope; requests after
close/retirement are rejected. Source admission counts and actual audio playback
counts are distinct in diagnostics.

Native entry queues are bounded and area/generation gated. Existing session
connection fencing runs first. reset_session now clears pending_voice and
pending_script_sounds as well as combat/visual queues. This closes a real gap:
an undelivered old-connection voice could otherwise remain queued while the next
session reused an area/generation number.

## Verification and limits

Source-pinned CDB checks, headless/Dummy, terminal exit0; no final engine/lifetime
error or exception, sourceUnchanged=true:

| Report in reports/ | Checks |
| --- | ---: |
| native-script-sound-final-data-v1 |38|
| native-script-sound-final-world-v1 |15|
| native-script-sound-final-disconnect-v1 |13|
| native-script-sound-final-voices-v1 |27|

93 headless checks. World coverage uses authored PCM with real native asset IO,
independent3D/2D sources, an advancing Dummy clock, fixed origin after movement,
nonrendered proxies, stale serial/lifetime rejection, empty names and actual
stream/playback-reference retirement. Disconnect tests call the actual session
reset and cancellation fence. Existing original SSF/BMU voice regression passes.
`native-script-sound-transport-v1.tap` separately retains15 passing protocol and
existing audio checks; native-session-host.cjs syntax also passes.

The first data fixture failed because its test constructed a Godot string with
an embedded NUL; it then accessed an error result. Only that newly owned headless
process was stopped. The failed report is retained. Raw-byte native selection
corrects the demonstrated conversion boundary; final checks include the original
embedded-NUL observations and have no Unicode error.

Real9/7 emission, physical audibility/WASAPI, full original GUI/cast admission,
unknown client object subclasses, wider active custom resources and paired-client
gameplay are unaccepted. Global proxies absent from the protocol registry are
still rejected rather than fabricated. Original mixer voice limits/stealing,
quick-chat/captions, weapon sounds and broader audio owners remain separate
work. Historical shutdown AVs remain unexplained. Full gameplay goal incomplete.

The already-open user preview predates this source change. No restart or public
connection was made to apply the fix to that session.
