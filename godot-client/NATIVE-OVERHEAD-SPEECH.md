# Native overhead speech

Ordinary received speech now has a native Godot presentation path, independent
of the optional class, feat, spell and inventory table queue. It uses the same
original popup resource family and font owner as hover/nameplate captions.
The implementation is integrated; live visual acceptance remains pending.

## Original behavior

The pinned original `nwmain` is documented in
[NATIVE-OVERHEAD-CHAT-POLICY.md](NATIVE-OVERHEAD-CHAT-POLICY.md). Its receiver
`77c140`, object wrapper `766450` and popup methods `6e8360/6e9590/6e98a0`
establish the channel, text, font, placement and lifetime policy. Popup registry
construction/destruction and overlap `6e8880` are retained separately.

- One popup per speaker lifetime. New speech replaces the previous speech.
- Registered native defaults are full background and large dialog text; original
  font variants, markup, native
  fitting capacities, optional original background and portrait artwork.
- A GUI-delta timer based on the final native byte string: normally 4–12 seconds,
  with the original localized channel factor and forced TLK duration branch.
- No ordinary floating-text rise, fade, arbitrary outline or screen clamp.
- Speech temporarily takes the nameplate's popup; expiry releases that priority
  without bringing back older speech. Cached hover captions remain separate.
- Nearby speech and hover popups use native ordered overlap arithmetic. Logical
  construction ordinals survive deactivation/view reuse until the source ends.

Script floating feedback 93/94 and combat numbers are separate original
systems. The subsequent [dedicated script-floating owner](NATIVE-SCRIPT-FLOATING.md)
implements the traced native queue, timer, pose, font and optional log echo.
Combat digits and complete cross-system queue/visual parity remain separate.

## Owners and integration

`tools/native-text-event-scope.cjs` attaches only received-state provenance to
the unchanged decoded packet. Source identity comes from the existing canonical
object/replication owners. Localized channels 11/12 also carry a separate token
context witness; it cannot borrow a later entity that reuses that ID.

`native_session_world.gd.native_text_connection()` supplies the accepted
connection. A text event cannot select a connection or advance the session.
`native_live_world.gd` supplies the current visual and stamps its identity at
the existing instance adoption/update boundary. `overhead_speech_anchor.gd`
uses the model head hook/height and actual current visual transform, including
non-interactable speakers. It never substitutes an interaction AABB or an
invented position for an unloaded model.

`native_gameplay_ui.gd` owns:

- `native_overhead_speech.gd`: received events, latest pending text and
  pooled passive views;
- `native_nameplate_resources.gd`: shared original popup models;
- `native_overhead_popup_registry.gd`: small logical popup construction registry,
  the single shared GUI clock/current-caption record and weak active-view
  references, shared with `native_hud.gd`.

The new owner runs after camera/movement at priority 100 only while text is
pending or active. The shared clock/layout runs at priority 110 only while
registered clocks or offered views remain. It projects active speakers, without copying or scanning the world
each frame. Detailed profiling includes `callback_overhead_text` and
`callback_overhead_layout`. Font/layout work runs when content or assets change;
the position loop does not rebuild the popup model or font resources.

`native_data/overhead_speech_scope.gd`, `overhead_speech_rules.gd` and
`overhead_speech_state.gd` keep provenance, original policy and presentation
state separate. Payloads/views are detached. The existing entity world store
remains authoritative.

## Lifetime and loading

Connection, area generation, area ID and both native/client-known object
lifetimes must match. Removal, redisclosure, ID reuse, reconnect and transition
cannot retarget old speech. The token context has an independent witness.
Pre-snapshot speech can wait only under an explicitly accepted connection;
subsequent area admission must match. Loading fonts/models/text does not restart
the timer. Missing data remains unavailable.

The native client can retain fading creature/placeable models after Delete.
Our existing world path currently removes those models immediately. Therefore
the adapter retires their old popups with the actual world visual; this work
does not implement the native retained-model fade.

## Validation and remaining checks

Receipts and their exact copied input hashes are under `reports/` and
`.cache/overhead-*`. Tests cover original recorded packets through the actual
decoder/Host and Gameplay dispatch, source/context ID reuse, first-snapshot
ordering, replacement/expiry, actual fonts/original popup geometry, anchors,
shared HUD caption arbitration, original overlap arithmetic and lifecycle.
Isolated functional tests do not establish screenshot, GPU or server acceptance.
Original-local-server checks are recorded separately below. No public world
connection or chat send was made for these tests.

The original-local-server ordinary-speech proof is retained in
[the received acceptance](reports/native-ordinary-speech-received-acceptance-v1.json).
It covers two real Talk packets, the actual model-head anchor/font/Bubble/registry,
same-popup replacement and natural expiry. That run explicitly used mode1/font14;
it does not prove the registered native defaults or later hot-settings changes.

Strict native text parsing and the actual override/localized call order are
documented in [the text receipt contract](NATIVE-ORDINARY-SPEECH-TEXT.md).
The persisted controls and complete live-setting integration have separate
receipts; do not treat a preference-control test as proof that every popup owner
is connected. The native hot-change contract is in
[the mode/font dossier](NATIVE-OVERHEAD-MODE-CHANGE.md).

## Current native-method integration

Hot mode/font changes now reach the constructed popup owners, including dormant
ones. Mode changes refit the actual current caption and restart the native timed
flag; font-only changes preserve its wraps, bounds and clock. Cached owner names
remain separate from current speech. Expiry follows the native ToggleOff default;
an unavailable CR-relative caption provider stays explicitly unknown. See
[the current settings corrections](NATIVE-POPUP-HOT-SETTINGS-CORRECTIONS.txt).

Delayed text adoption records the GUI frame already accounted for, so the shared
clock does not consume that frame twice. A popup waiting for its model sleeps
until the existing visual-publication event wakes it; no idle polling is added.
Admitted hover labels now share the native head-anchor projection and round once,
without an AABB, viewport clamp or behind-camera rejection. Offline inspection
has a separate compatibility path. See [hover projection](NATIVE-HOVER-PROJECTION.txt)
and the source-backed [item anchor](NATIVE-OVERHEAD-ITEM-ANCHOR-ADDENDUM.md).

Current isolated checks include received/HUD140, text receipts29, TLK-family
publication20, literal/log branches38, settings34, handoff17 and item anchors30.
These overlapping scopes are not an aggregate parity score. Exact source hashes
and individual limitations remain in their immutable proof files.

The [current original-local-server acceptance](NATIVE-ORDINARY-SPEECH-CURRENT-ACCEPTANCE.md)
adds two real Talk packets, fresh native mode2/font16, actual model-head/Bubble
publication, same-popup replacement, one shared Registry clock and natural expiry.
All15 ordinary checks and the separate inherited ScriptFloating gates pass.
The [current methods checkpoint](reports/native-overhead-native-methods-checkpoint-v3.json)
pins that run separately from the isolated checks and unchanged border geometry
proof. No native screenshot or GPU acceptance is claimed.

Remaining work includes a manual native-client comparison, asynchronous
adaptation versus native synchronous model availability, unavailable retained
parser/provider state and remote special object clocks. Nonidentity world-item
visual-transform sampling is not supplied by this anchor adapter. The broader
chat/area-edge goal remains active.

## Header and atmosphere follow-up

The [next checkpoint](reports/native-overhead-native-methods-checkpoint-v4.json)
adds the actual native channel-label fetch path and explicit remote wire names.
They are captured beside the shared body receipt before the existing queue.
Base labels remain raw at gender0/parseFlag0, while runtime overrides use the
native parser without a controlled-character context. Split remote names retain
their exact separator, including an empty/empty split. The real Gameplay/Chat
integration passes33 checks; body38, receipt29 and received/HUD140 also pass on
the current graph. See [the header integration contract](NATIVE-SPEECH-HEADERS-INTEGRATION.txt).

At checkpoint v4, canonical local actor names remained on the previous adapter. The native actor's
stored-name slots and constructor/override state are distinct from party labels;
neither a first snapshot nor the existing lifetime tokens prove construction.
The [boundary audit](NATIVE-ORDINARY-SPEECH-NAME-OWNER-ADDENDUM.md) identifies the
remaining authoritative commit hook. This is unfinished native parity, not an
assumption that missing actor state is empty.

The final [original-local-server check](NATIVE-ORDINARY-SPEECH-NATIVE-HEADERS-ACCEPTANCE.md)
passes on this updated graph and accepts the actual initial atmosphere header.
It proves real Talk replacement/expiry and fixed-day atmosphere publication;
it does not send all prefix variants, change the server's day/night phase or
establish native raster pixels.

## Stored actor-name follow-up

The [current actor-name integration](NATIVE-ACTOR-NAME-INTEGRATION.md) adds the
accepted typed-construction/reuse boundary identified above. Private protocol
provenance and exact receipt-time state reach a native Godot stored-name owner;
no renderer node, party label or first snapshot invents constructor defaults.
The current Gameplay/Chat gate passes122 checks, including names retained across
coalesced updates, removals and ID reuse, and successful empty names. The owned
original-local-server check also observes both actual Talk rows using the current
stored character name. Its receipt is separate from authored fixture evidence.

The previous adapter remains only for explicitly unproven owners, including
generic/imported or BIC-loaded state whose DisplayName transfer is unknown.
Historical checkpoints and their limits remain intact. Visual acceptance,
special object clocks, retained-model fade and the broader goals are unfinished.

The subsequent [model-key correction](reports/native-live-world-name-signature-v2.json)
also follows the original P400 boundary: changing a creature name refreshes its
state/name consumers without rebuilding the model. A private shallow projection
omits only that name; equipment, physical appearance and opaque non-creature
tuples retain their existing invalidation. The actual CPU World/planner test
first reproduced 12 failures, then passed the same 63 assertions plus nine
compatibility cases. [Checkpoint v6](reports/native-overhead-native-methods-checkpoint-v6.json)
keeps this 72-check result separate from the preceding original-local-server
run and lists every changed imported dependency. No FPS or visual parity claim
is made by the correction.

The [remote clock port](NATIVE-REMOTE-CLIENT-CLOCKS.md) now admits received
module3/minor9 and retains it in recordings. Standalone native Godot timer and
pause-selector components pass 7,242 checks, but remain unimported: native
process-clock initialization, absolute counter source, ordered early delivery,
object reset stamps and T2 GUI integration still need their complete runtime
path. Current ScriptFloating nominal time is not claimed as special-clock
parity. [Checkpoint v7](reports/native-overhead-native-methods-checkpoint-v7.json)
keeps protocol, component and original lifecycle evidence separate.

## Local graphical observation and clock staging checkpoint v9

The owned original-local graphical run completed its 120-second lifecycle and
cleaned up its server. Actual state observations include one retained, visible
ordinary speech popup through expiry and all 300 planned decorative border tiles.
Computer Use stopped on physical Escape before active-speech/perimeter pixel
acceptance; no further visible or input work followed. Original comparison,
readability, camera traversal and performance are not accepted by this run.

New metadata accurately separates a stimulus-free observation probe from
automated admission and unknown session-input provenance. The historical run
is unchanged. Static metadata checks pass 5/5 and PowerShell AST parsing is clean.
The ordered clock-ingress helper passes 15 Node tests; the lazy per-object AI
stamp component passes 786 headless assertions, separately retaining 90 native
caller cases and 48 authored eager frames/89 lazy queries. Neither component is
activated by the main client. Original construction evidence excludes the
internal-BIC-preview alias hypothesis at inspected boundaries while retaining
strict uncertainty for external typed-owner history and ambiguous D+A reuse.

See [current status and remaining integration](NATIVE-OVERHEAD-CURRENT-STATUS.md)
and `reports/native-overhead-native-methods-checkpoint-v9.json`. The goal remains
active; clocks/GUI ownership, retained-deletion behavior, full visual acceptance
and the broader level-up/UI requirements remain unfinished. Test counts are
not a native parity percentage or an FPS claim.
