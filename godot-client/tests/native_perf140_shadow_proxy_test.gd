extends SceneTree
const Proxy=preload("res://systems/native_render/static_shadow_proxy.gd")
const Template=preload("res://systems/native_render/model_template.gd")
var checks:=0
var failures: Array=[]
class Hit:
	extends Resource
	var vertices:=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.BACK])
	var indices:=PackedInt32Array([0,2,1])
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func fixture(count: int=2) -> Dictionary:
	var model:=Template.Placement.new();var rows: Array=[]
	for index in count:
		var part:=Node3D.new();part.position=Vector3(index*2,0.25*index,0);part.rotation.y=0.2*index;part.set_meta("native_part_index",index);model.add_child(part);model.parts.append(part)
		var hit:=Hit.new();var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=hit.vertices;arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]);arrays[Mesh.ARRAY_INDEX]=hit.indices
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);mesh.set_meta("native_pick_geometry",hit)
		var geometry:=MeshInstance3D.new();geometry.mesh=mesh;geometry.material_override=StandardMaterial3D.new();geometry.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;part.add_child(geometry);model.meshes.append(geometry)
		rows.append({"features":[],"mesh":{"shadow":true,"render":true,"normals":PackedFloat32Array([0,0,1,0,0,1,0,0,1])}})
	return {"model":model,"bundle":{"value":{"nodes":rows}},"material":StandardMaterial3D.new()}
func prepare(value: Dictionary) -> Dictionary:return Proxy.prepare(value.model,value.bundle,value.material)
func cases() -> void:
	var value:=fixture();var model=value.model;var plan:=prepare(value)
	check(plan.stats.accepted_meshes==2 and plan.groups.size()==1 and plan.members.size()==2,"Two opaque terrain parts become one shadow group")
	check(plan.stats.triangles==2 and plan.stats.vertices==6,"Original triangle and vertex coverage retained")
	check(model.meshes.all(func(mesh):return mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON),"Preparation does not alter original caster flags")
	if plan.groups.is_empty():model.free();return
	check(plan.groups[0].mesh.get_surface_count()==1,"One depth surface replaces the two caster surfaces")
	var mesh_ids: Array=model.meshes.map(func(mesh):return mesh.mesh.get_instance_id())
	var material_ids: Array=model.meshes.map(func(mesh):return mesh.material_override.get_instance_id())
	var transforms: Array=model.meshes.map(func(mesh):return var_to_bytes(mesh.get_parent().transform))
	var installed:=Proxy.install(model,plan)
	check(installed.installed and installed.source_casters==2 and installed.proxy_groups==1,"Complete plan installs atomically")
	check(model.meshes.all(func(mesh):return mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"Converted main surfaces stop submitting redundant shadow draws")
	check(model.meshes.map(func(mesh):return mesh.mesh.get_instance_id())==mesh_ids,"Normal meshes are preserved")
	check(model.meshes.map(func(mesh):return mesh.material_override.get_instance_id())==material_ids,"Normal materials are preserved")
	check(model.meshes.map(func(mesh):return var_to_bytes(mesh.get_parent().transform))==transforms,"Physical Part transforms are preserved")
	check(model.meshes.all(func(mesh):return mesh.mesh.get_meta("native_pick_geometry")!=null),"Original collision and pick data retained")
	var proxy: MeshInstance3D=model.get_child(model.get_child_count()-1)
	check(proxy.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and proxy.layers==1,"Proxy is shadow-only with unchanged light layer")
	check(not model.meshes.has(proxy),"Proxy never enters original render/picking enumeration")
	check(not Proxy.install(model,plan).installed,"Duplicate install does not disable/create more surfaces")
	model.free()
	for kind in ["alpha","scissor","grow","cull","hidden","mirror","singular","deform","missing-normal","source-off","one","changed-after-plan"]:
		var current:=fixture(1 if kind=="one" else 2);var geometry: MeshInstance3D=current.model.meshes[0]
		if kind=="alpha":geometry.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		elif kind=="scissor":geometry.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		elif kind=="grow":geometry.material_override.grow=true
		elif kind=="cull":geometry.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED
		elif kind=="hidden":geometry.get_parent().hide()
		elif kind=="mirror":geometry.get_parent().scale=Vector3(-1,1,1)
		elif kind=="singular":geometry.get_parent().scale=Vector3.ZERO
		elif kind=="deform":current.bundle.value.nodes[0].features=["dangly"]
		elif kind=="missing-normal":current.bundle.value.nodes[0].mesh.normals=PackedFloat32Array()
		elif kind=="source-off":current.bundle.value.nodes[0].mesh.shadow=false
		var before: Array=current.model.meshes.map(func(mesh):return mesh.cast_shadow)
		var prepared:=prepare(current)
		if kind=="changed-after-plan":
			geometry.position.x=1.0
			check(not Proxy.install(current.model,prepared).installed,"Changed cached pose falls back atomically")
		else:check(prepared.groups.is_empty() and not Proxy.install(current.model,prepared).installed,"Unsupported case keeps original shadow path: "+kind)
		check(current.model.meshes.map(func(mesh):return mesh.cast_shadow)==before,"Fallback preserves every original caster flag: "+kind)
		current.model.free()
	var layers:=fixture(4)
	for index in 4:layers.model.meshes[index].layers=1 if index<2 else 2
	var layered:=prepare(layers)
	check(layered.groups.size()==2 and layered.members.size()==4,"Different light layers remain separate depth groups")
	check(Proxy.install(layers.model,layered).installed,"All valid layer groups install")
	check(layers.model.get_children().filter(func(child):return child is MeshInstance3D).map(func(child):return child.layers)==[1,2],"Published layer masks match source groups")
	layers.model.free()
	var actor:=Node3D.new()
	check(Proxy.prepare(actor,{},StandardMaterial3D.new()).groups.is_empty(),"Unproven owner types reject without field access")
	check(not Proxy.install(actor,plan).installed,"Unproven owner cannot adopt a cached plan")
	actor.free()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	cases()
	await process_frame
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Static shadow proxy structural/atomic fallback contract only; visual, render-thread and full-area timing acceptance still required"}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
	print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
