extends SceneTree
# A detached small graph with per-placement local material and mutable metadata.
# Checks whether Node.duplicate can replace PackedScene.instantiate semantics.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var model:=Node3D.new();model.name="model"
	for n in 48:
		var part:=MeshInstance3D.new();part.name="part_"+str(n);model.add_child(part);part.owner=model
		part.mesh=BoxMesh.new()
		var material:=StandardMaterial3D.new();material.resource_local_to_scene=true;material.albedo_color=Color(float(n)/48.0,.2,.3)
		part.material_override=material;part.set_meta("mutable",{"list":[n]})
	var scene:=PackedScene.new();var pack_start:=Time.get_ticks_usec();var packed_ok:=scene.pack(model)==OK;var pack_us:=Time.get_ticks_usec()-pack_start
	var duplicate_start:=Time.get_ticks_usec();var direct:=model.duplicate();var duplicate_us:=Time.get_ticks_usec()-duplicate_start
	var scene_a:=scene.instantiate();var scene_b:=scene.instantiate();var direct_b:=model.duplicate()
	var p_a: MeshInstance3D=scene_a.get_node("part_0")
	var p_b: MeshInstance3D=scene_b.get_node("part_0")
	var d_a: MeshInstance3D=direct.get_node("part_0")
	var d_b: MeshInstance3D=direct_b.get_node("part_0")
	var report:={"pack_ok":packed_ok,"pack_us":pack_us,"duplicate_us":duplicate_us,"scene_material_private":not is_same(p_a.material_override,p_b.material_override),"direct_material_private":not is_same(d_a.material_override,d_b.material_override),"direct_material_away_from_source":not is_same(d_a.material_override,model.get_node("part_0").material_override),"scene_metadata_private":not is_same(p_a.get_meta("mutable"),p_b.get_meta("mutable")),"direct_metadata_private":not is_same(d_a.get_meta("mutable"),d_b.get_meta("mutable")),"direct_child_count":direct.get_child_count(),"scene_child_count":scene_a.get_child_count()}
	for node in [scene_a,scene_b,direct,direct_b,model]:node.free()
	print("NWN62_DUPLICATE_PROBE "+JSON.stringify(report))
	quit(0 if packed_ok else 1)
