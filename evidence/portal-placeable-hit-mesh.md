# Portal placeables: retain hidden hit geometry

The user clarified that the side portals are ordinary interactable entities
whose Use scripts can open a server dialog. The earlier transition-region patch
does not solve that interaction path. A user-supplied actual click snapshot has
`blocked:null`, `targeting:false`, `objectId:null` at ground point
`[3.925129553860487,0,-15.667957436012706]`: the renderer selected ground rather
than an object. Their screenshot identifies the entity under the particle mound.
The snapshot does not identify its exact server object ID or model name.

## Evidence

Read-only target NWN:EE89.8193.37-17 x64, SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
Part::HitCheck14008fd80 and PartTriMesh::HitCheckGeom1400905b0 retain a distinct
triangle/bounds hit path. The latter supports expanded bounding-box queries as
well as triangle queries. These captures do not establish a complete native
mouse mask/box expansion/highlight match.

Offline active cached resources, with HTTP refused, show:

* `plc_portal2`: a render0 `damage` trimesh with12 vertices/20 faces and emitters;
  no PWK in that active resource context.
* `plc_d07`: a hidden render-false `Box54` trimesh with24 vertices/12 faces;
  no PWK in that context.

`buildObject` correctly omits those nodes from rendering, but the client had no
separate selection geometry for them. Raycastable visible triangles therefore
cannot select these models. The metadata is `portal-placeable-resources-v2.json`;
probe-v1 incorrectly queried `node.vertices` rather than `node.verts` and is not
counted as mesh evidence. No proprietary geometry or asset bytes are saved.

## Change

`placeable_hit_mesh.js` retains actual hidden trimesh faces under their original
indexed model nodes for network placeables. Their material stays invisible,
with color/depth writes disabled. Transforms follow the existing node and model
hierarchy. No invented hitbox, visual change, PWK fallback or client portal
activation is introduced. Picking bypasses material-visibility rejection only
for these tagged meshes belonging to a live, explicitly usable placeable.
Unusable/static scenery remains unselectable through this hidden-geometry path.
Removal/model replacement disposes the mesh and material.

The same geometry supplies hover/Tab highlight bounds. Normal placeable cursor,
Examine/radial Use, original object ID and existing useObjectRequest remain the
interaction path. This is independent of transition triggers; a nearer regular
portal object wins over an overlapping transition surface. Ordinary wall
occlusion still applies. The server decides whether Use opens a dialog.

## Validation and remaining check

94 focused checks pass (`placeable-hit-mesh-focused-v1.txt`) for picking, normal
Use request, ownership, hidden-material preservation, highlighting, overlap
priority, walls, usability changes, deletion/disposal, radial actions and prior
portal/trigger/targeting/session behavior. Build passes
(`placeable-hit-mesh-build-v1.txt`), `index-CuKCya71.js` / `index-8ID_vg9F.css`.

`probe-portal-placeable-input.mjs` uses the actual cached Arelith models in the
production NetworkScene with authored fixture object IDs/poses. Both models
resolve to type9, cursor25 and `object.use`, with one hidden hit mesh each,
zero issues and zero HTTP attempts (`portal-placeable-input-v1.json`). This is
not a capture of the particular live portal or proof its script opened a dialog.

No active client was restarted and no public-server input/join was automated.
The corrected build still needs a user-controlled click on the live side portal
after restarting, to verify object selection and the server's dialog response.
