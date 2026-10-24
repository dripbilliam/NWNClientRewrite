# Transformed creature attachment animation

The user's live scene snapshot identifies controlled object4294967091,
appearance864, resources invis_cr_160/c_golstone, animation0 and clip:null.
This ties the missing cpause1/cwalk/crun diagnostics to the controlled actor.

Offline cached Arelith resources identify appearance864 as Invisible_CreatureL_160,
MODELTYPE=LWT. Its model has seven nodes and no clips; production returns no
animator for it. The visible c_golstone has idle, movement, cast and attack clips.
Cached tailmodel338 selects it. That ID is a reproduction choice, not disclosed
by the user's live snapshot. Stock elemental inherited clips also load normally.

Scene playback, combat ownership and gait timing assumed models[0] was animated.
The relay only forwarded successful body playback, so a clipless invisible body
never drove the visible attachment. This is an adapter error, not missing content.

The scene now retains an animated body's ownership, or selects an animated
robe/tail/wing attachment when the body has no clips. Base/action/keyboard
playback, hit events, gait clocks and snapshots share that selected animator.
Hierarchy, palettes, scopes and authoritative appearance remain intact. Other
attachments retain the existing relay. Removal clears listeners and instances.
This focused adapter correction is not a complete native multi-Gob playback port.
The read-only9ddd00 inspection from this task describes a different effect owner
and is not evidence for the creature correction.

`scripts/probe-transformed-creature-animation.mjs` uses production scene/combat/
animator code and cached resources, including a null body animator. Eight checks
pass: attachment hit events, idle/walk/run, cast/attack, keyboard playback and
reversion with cleanup. Zero HTTP requests, joins or scene animation failures.
The existing real-resource robe/helmet/mount integration also passes (43 assets,
pause1/walk/1hslashl, replacement/removal). No proprietary assets copied.

Thirty-five focused tests pass; build index-BMf_1UOk.js/index-8ID_vg9F.css passes.
Derived reports under backups/animations: creation-experience-elemental-animation-
catalog-v1.json, creation-experience-transformed-animation-v1.json,
creation-experience-transformed-robe-regression-v1.json,
transformed-animation-focused-v2.txt and transformed-animation-build-v1.txt.
Offline checks do not establish live visual acceptance. No running session was
interrupted or driven; restart the client to load the build. Goal remains paused,
changes unsealed after checkpoint49.
