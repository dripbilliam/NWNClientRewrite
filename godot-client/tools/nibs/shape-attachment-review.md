# Invisible polymorph body attachment fix

The live Nibs reproduction on 2026-11-13 replaced a 20-mesh Derro with
`invis_cr_160` and published zero meshes. The client had not requested an
elemental model. The original client visibly rendered an Earth Elemental.

The synced Arelith `appearance.2da` maps non-modular appearances 844 and 864
to `invis_cr_160`. `polymorph.2da` row 131 (Monolith Earth Elemental) selects
appearance 864. `tailmodel.2da` maps 341 to `c_earth` and 342 to
`c_eartheld`. The original `CNWSCreature::Polymorph` reads its selected form's
`AppearanceType` from `polymorph.2da` (REA evidence
`ev_2cc2c761730d62fb1c44d0f178092d6a01ef8ed2c849fccc86996dff3d7a3fb3`).
These table rows identify the model route, but the earlier live report does
not retain Nibs's received tail-model field, so its exact value remains to be
confirmed on a fresh live connection.

`CreatureAppearance.plan` returned immediately for every `MODELTYPE` other
than `P`, before it evaluated `fieldAA4`/`tailmodel` and `fieldAA8`/`wingmodel`.
The candidate moves that existing table-driven attachment selection before
the non-modular return; it does not hard-code any form or model ID. Modular
body planning retains the same attachment order and hide rules.

The [local report](../../.cache/nibs-shape-attachment-candidate-a.json) used
the installed Arelith NWSync manifest and original model assets. Appearance
844 with tail 341 assembled `invis_cr_160` + `c_earth`; appearance 864 with
tail 342 assembled `invis_cr_160` + `c_earthEld`. Each actor installed
successfully with 19 meshes and no assembly error. The model attachment
anchor `tail` exists in `invis_cr_160`. The existing network attachment test
passed 5/5. This is source/resource/actor assembly evidence, not live Nibs
acceptance or a visual/FPS measurement. A fresh Nibs Earth Elemental Shape
check should confirm the server supplies the tail-model field and that the
visible result matches the original client.
