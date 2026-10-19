# Multiplayer spell input and cast playback — 2026-10-18

Goal **ACTIVE / PROGRESS**. Previous turn completed verified quickbar assignment
and equipment input. Class-spell shortcuts now select actual targets, send native
cast requests, display replicated uses and play server-driven cast/conjure
animations. The original server consumes slots and executes scripts/effects.
Full multiplayer casting, wheel casting, innate/item powers, complete effects/
audio, other spell forms and original-client concurrency remain unfinished.

## Read-only target and executed evidence

NWN:EE89.8193.37-17 x64 nwmain SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`;
vanilla nwserver SHA256
`98951511ae7d06a251355f12d4f3e4b96269a2414fa3058e641afd70098690f6`.
REA session99283 reused. No binary/project edits, injection, patches, copied
game assets or NWNX extensions. Derived fixtures retain explicit boundaries.

- Native client804d00 routes ordinary-player input to7bf4e0. DM routing7babb0
  is separate and remains unimplemented. The ordinary envelope is6/18, with
  DWORD spell, BYTE class index/domain/metamagic, BYTE flags, optional object ID,
  optional FLOAT XYZ and the original spell's TargetType WORD50. Flags1/2/4 mean
  target/point/conversion. Both object and point can be present. Original
  magnitude2303d0 and positive sqrtf c7d6d8 determine point presence against
  FLOAT1e-5, before adding native FLOAT0.3 to Z. Zero/near-zero/signed coordinates,
  domain/meta widths and raw client IDs are preserved.
- Original complete4531b0 subtype18 reader checks overflow/underflow, spell and
  master metadata, optional target-word consistency, conversion eligibility,
  slot readiness and metamagic, then ActionManager1/AddCastSpellActions37d540.
  Client use-count admission is presentation only; the server still decides.
  `inspect-native-network-spell-input.py`:331 complete original sender/reader
  cases, formats0/1, target/point combinations, threshold edges, missing owners,
  metadata and conversion conditions. Scalar reads/writes, vector arithmetic
  and server branching execute. Control/config/spell/slot queries, transport,
  feedback and action insertion are captured lower boundaries; no actions or
  effects execute in this synthetic oracle. Build1/2 failed fixture setup or
  omitted a positive CRT dependency; finalv3 executes successfully.
- Client7f74d0 differs from server409160: it follows one master hop, confirms
  domains, adds active metamagic cost and counts ready records whose metamagic
  overlaps the requested mask (or any mask for requested0). Nonmemorizing
  classes return their replicated per-day BYTE. It performs no local spend.
  `inspect-native-network-spell-uses.py`:581 complete original count cases,
  missing spell/class, master replacement, per-day values, ready INT values,
  domain confirmation and overlapping meta masks. Spell/class/level/domain/
  metamagic-cost queries are captured; iteration and BYTE count are original.
  Finalv2 succeeds. Out-of-storage levels/cursor wrap remain explicit errors.
- Native PlayAnimation7fc7d0 type4 inserts500ms with FLOAT clip-length/500 speed.
  Receiver7833ae..78345e maps release17/18/19/20/61 to looping bases250/251/252/
  253/261, constructs a separate80-byte type4 target/spell record, then submits
  the original action. The receiver projection has static evidence; its type4
  fields are retained without giving unproven names to field38. The original
  playback math/routing is executed by `inspect-native-network-spell-animation.py`:
  240 cases across all five releases, moving/stationary states, length and flag
  values. Queries/queue insertion are captured; native body-model playback and
  GUI fields434/43c are separate owners. Finalv1 succeeds.

## Implementation

`network_spell_input.js` encodes6/18. Typed trusted-frame/session IPC obtains
TargetType from the selected module/HAK's active SPELLS table; renderer-supplied
metadata cannot override it. Current area/control and canonical object/item
targets are checked. No local script VM, AI, class-slot calculation, spell spend,
attack resolver or effect application runs. The server owns those operations.

`NetworkSpellTargeting` reuses the independently studied704720 preparation and
704640 mask/veto behavior. First child metadata sets a parent's targeter; the
original packed spell ID remains the submitted one. Auto-self follows metadata
and inventory mode. Actual pointer picking admits self, other creatures, items,
doors, placeables, triggers and ground through native masks. Escape/right-click
cancel. Area/disconnect resets and context guards discard stale selections.
Class/domain/meta fields use the original widget's3/4/6-bit packed widths.

Quickbar spell counts read replicated player spellbooks through7f74d0's client
algorithm, active class/domain/ruleset tables and existing native metadata.
Counts render2→1→0; spent widgets/function keys stop initiating casts. Assigning
an unavailable spell does not grant it. No spell ID/name, module or effect is
hardcoded in production. The installed wizard/Light selection is QA input only.

NetworkWorld emits type4 cast events for every transmitted release, including
repeated equal states. NetworkCombatPresentation uses the existing native queue
and signed countdown, mapped looping bases and original500ms speed. Queue delay
correction remains the separately verified native behavior. A cast record cannot
reuse a previous attack's hit/linked-action data. Conjure15/16 use the native clip
name/category mapping and server speed. Existing attack regressions still pass.

The shared ClientCastVisualPresentation accepts an optional animation projection;
singleplayer's default is unchanged. Multiplayer supplies client playback state
plus actual replicated spell/item/silent fields and race/gender. It reuses the
native cast driver, model attachment, asynchronous ownership and cleanup, with
no mutation of canonical server objects. Audio calls remain diagnosed rather
than silently pretending output; full effect/light and authored-event ownership
are still separate work.

## Real vanilla-server validation

Same owned Prelude server PID36824 at127.0.0.1:5121. Unchanged installed wizard.bic
was admitted. One-use encrypted private input keeps credentials out of files,
environment and argv. Offscreen GPU QA leaves the desktop untouched; all sessions
disconnect afterward. Original server and client binary hashes remain pinned.

v47 correctly entered target mode instead of auto-self: active Light TargetType
is43, so source data requires a choice. No cast was sent without a target. v48
used real browser pointer input to click the controlled character; server ready
slots changed2→1→0, and a third pre-gating request spent nothing. v49 added the
native client availability check: two cast requests, cancelled selection sends
nothing, spent key initiates no target/cast. Both had zero runtime error records;
body cast presentation was still logged as unimplemented at that stage.

Finalv50:12 UI steps, one assignment plus two cast packets,2277 GPU frames,
playing at the end, then clean disconnect. Server readiness again2→1→0, with
Escape cancellation and no third packet. Actual clips include conjure2, castup,
castuplp and pause1. Two conjure models load/play/destroy through the shared
controller; no active handles/controllers remain. Conjure/cast/rest screenshots
were visually inspected. Journal has **zero error records**; unsupported packet,
audio, effect/particle/material and other presentation warnings remain explicit.
The authored cast event at castup0.5s is still recorded as unmapped; it is not
silently treated as an attack hit. This one live spell is evidence of the complete
request/slot/body/conjure cycle, not proof that every spell/effect works.

## Next required work

Connect native wheel casting to the shared class/level/metamagic tree and native
client state. Client spell-gain7f6b20 has ability/specialization/prestige rules;
do not replace that gate with always-available choices. Innate/type44, item powers,
feat casting, memorization UI, advanced targeters/conversion paths, spell combat
messages, persistent/impact/light effects, authored cast event ownership and
actual audio still require integration and live verification. Wider combat and
simultaneous play with original clients remain part of the unchanged full goal.
Generic picker point/preview/LOS/cursor behavior needs fuller native comparison;
the present object point is the renderer ray hit. Packet arithmetic and target
admission are verified separately from that adapter.

Validation:95 focused network/shared singleplayer casting tests PASS
(`network-spell-input-tests-v12.txt`); production build PASS(v4, existing size
warning); harness syntax PASS. Credential audit2161 source/evidence/current-capture
files plus research stderr, private hits0. No full-suite claim or full-spell
completion claim is made from this focused milestone.

Verified checkpoint `multiplayer-spell-input-20261018-v1.zip`:12928 files,
240998164 bytes. Writer49379 finished terminal0; every entry length/SHA256
verified. Scope43 required present, forbidden0; only audited read-only REA stderr
is permitted from runtime-logs. Original server profile, binaries and assets are
excluded. Scope result and this postseal note are outside the sealed archive.
