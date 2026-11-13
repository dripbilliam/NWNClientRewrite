extends SceneTree
const Recipe=preload("res://systems/native_render/native_model_recipe.gd")
const Light=preload("res://systems/native_render/model_point_light.gd")
var checks:=0
var failures: Array=[]
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func compare(original: Node,copy: Node,fields: Array)->void:
	for field in fields:check(original.get(field)==copy.get(field),"Exact constructor/default or authored property survives sparse row: "+str(original.name)+"/"+str(field))
func run()->void:
	for authored in [false,true]:
		var source:=Node3D.new();var mesh:=MeshInstance3D.new();mesh.name="mesh";source.add_child(mesh);mesh.owner=source
		if authored:
			var nodes:={"name":"original_mesh","transform":Transform3D(Basis.IDENTITY,Vector3(2,3,4)),"visible":false,"top_level":true,"visibility_parent":NodePath(".."),"process_mode":Node.PROCESS_MODE_DISABLED,"process_priority":17,"process_physics_priority":-13,"process_thread_group":Node.PROCESS_THREAD_GROUP_SUB_THREAD,"process_thread_group_order":9,"process_thread_messages":3,"physics_interpolation_mode":Node.PHYSICS_INTERPOLATION_MODE_OFF,"unique_name_in_owner":true}
			var fields:={"mesh":ArrayMesh.new(),"skeleton":NodePath(".."),"material_override":StandardMaterial3D.new(),"material_overlay":StandardMaterial3D.new(),"cast_shadow":GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED,"layers":3,"extra_cull_margin":2.0,"custom_aabb":AABB(Vector3(-1,-2,-3),Vector3(3,4,5)),"lod_bias":1.5,"transparency":0.2,"gi_mode":GeometryInstance3D.GI_MODE_STATIC,"visibility_range_begin":2.0,"visibility_range_end":80.0,"visibility_range_begin_margin":1.0,"visibility_range_end_margin":5.0,"visibility_range_fade_mode":GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF,"ignore_occlusion_culling":true,"sorting_offset":3.0,"sorting_use_aabb_center":false}
			for field in nodes:mesh.set(field,nodes[field])
			for field in fields:mesh.set(field,fields[field])
		var recipe=load("res://.cache/nwn62/before/systems/native_render/native_model_recipe.gd").new() if OS.get_cmdline_user_args().has("--baseline") else Recipe.new();var captured: bool=recipe.capture(source);check(captured,"Sparse default/nondefault graph captures: "+recipe.failure)
		if not captured:source.free();continue
		var clone: Node3D=recipe.create();check(clone!=null,"Sparse graph creates")
		if clone==null:source.free();continue
		compare(source,clone,Recipe.NODE_FIELDS);compare(mesh,clone.get_child(0),Recipe.NODE_FIELDS);compare(mesh,clone.get_child(0),Recipe.MESH_FIELDS)
		if not authored:check(recipe._rows[1].fields.is_empty() and recipe._rows[1].node.size()<=2,"Pristine Mesh constructor properties produce zero redundant Mesh setters and only name/visibility Node values")
		clone.free();source.free()
	var unsupported:=Node3D.new();var primitive:=MeshInstance3D.new();primitive.mesh=BoxMesh.new();unsupported.add_child(primitive)
	var declined:=Recipe.new();check(not declined.capture(unsupported) and declined.failure=="recipe-unsupported-mesh","Primitive/runtime Mesh resources decline explicitly to faithful PackedScene fallback before ArrayMesh-only inspection")
	unsupported.free()
	var original:=Node3D.new();var material:=StandardMaterial3D.new()
	original.set_meta("private",{"array":[{"value":1,"resource":material}],"packed":PackedFloat32Array([1,2,3])})
	var validated:=Recipe.new();check(validated.capture(original),"Nested container/resource snapshot passes capture-time validation")
	var first:=validated.create();var second:=validated.create();var one: Dictionary=first.get_meta("private");var two: Dictionary=second.get_meta("private")
	check(not one.is_read_only() and not one.array.is_read_only() and not one.array[0].is_read_only(),"Native duplicated frozen snapshots become placement-private mutable containers at every depth")
	one.array[0].value=99;one.packed[0]=99
	check(two.array[0].value==1 and original.get_meta("private").array[0].value==1 and two.packed[0]==1 and original.get_meta("private").packed[0]==1,"Nested and packed-array mutation cannot escape one cloned placement")
	check(one.array[0].resource==material and two.array[0].resource==material,"Native deep container duplication keeps immutable pool Resource identity shared")
	for authored_visible in [false,true]:
		var light_root:=Node3D.new();var source_light:=Light.new()
		source_light.set_meta("native_model_light_properties",{"radius":0.0,"multiplier":1.0})
		source_light.visible=authored_visible;light_root.add_child(source_light)
		var light_recipe:=Recipe.new();check(light_recipe.capture(light_root),"Unadmitted model light captures")
		if light_recipe.snapshot().nodes>0:
			var light_clone:=light_recipe.create();check(light_clone!=null and light_clone.get_child(0).visible==authored_visible,"Light configure restores exact authored visibility after cloning")
			if light_clone!=null:light_clone.free()
		light_root.free()
	material.resource_local_to_scene=true
	check(validated.begin_create()==null and validated.failure=="recipe-local-resource","A late shared Resource ownership-policy change still declines cloning before creating nodes")
	material.resource_local_to_scene=false;var restored:=validated.create();check(restored!=null,"Restored shared Resource policy permits a fresh private placement")
	first.free();second.free();restored.free();original.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Every declared Node/Mesh field at constructor defaults and explicitly authored nondefaults; shared resources and complete clone values; sparse row omits redundant constructor setters. Headless correctness only."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
