extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Model=preload("res://systems/native_render/effect_model.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original ammunition resources mount read-only")
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); var bundle: Dictionary={}
	service.completed.connect(func(_id,result):bundle.merge(result)); service.request("wamar_001",2002,"actor-model")
	var deadline:=Time.get_ticks_msec()+15000
	while bundle.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(str(bundle.get("error","unfinished")).is_empty(),"Original arrow prepares through native workers")
	var pool:=Pool.new(); pool.unshaded=true; var camera:=Camera3D.new(); root.add_child(camera); camera.position=Vector3(0,0,3); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2; camera.current=true
	if bundle.has("value"):
		for iteration in 12:
			var model:=Model.new(); root.add_child(model); check(model.load_model(bundle,pool),"Actual native arrow model admits "+str(iteration))
			model.play_effect_clip("travel01",1,0,0)
			var private_count:=0
			var pose=model.rigs.entities[0].models[0].native_owner.pose
			for part in pose.parts:
				for row in part.materials:
					for child in part.object.get_children():
						if child is MeshInstance3D and child.material_override==row.material and not pool.materials.values().has(row.material): private_count+=1
			check(private_count>0,"Controller animates actual private drawn material without mutating pool "+str(iteration))
			model.set_part_local_pose("root",[0.0,0.0,0.0],[1.0,0.0,0.0,0.0])
			model.rotation_degrees.y=90
			await RenderingServer.frame_post_draw
			if iteration==0:
				var shown:=root.get_texture().get_image(); var colors: Array=pool.materials.values().map(func(material):return material.albedo_color)
				for part in pose.parts:
					if part.fields.has(168): part.view.encode_float(168,0)
				pose.flush(); await RenderingServer.frame_post_draw
				var hidden:=root.get_texture().get_image(); var changed:=0
				for y in shown.get_height():
					for x in shown.get_width():
						if shown.get_pixel(x,y)!=hidden.get_pixel(x,y): changed+=1
				check(changed>2,"Native controller alpha changes actual arrow viewport pixels")
				check(pool.materials.values().map(func(material):return material.albedo_color)==colors,"Native controller leaves shared pool material colors intact")
			var weak: WeakRef=weakref(model); model.retire(); model=null
			await process_frame; await RenderingServer.frame_post_draw
			check(weak.get_ref()==null,"Arrow model is released after rendered retirement "+str(iteration))
	service.close(); service.free(); camera.free(); pool.clear(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual installed arrow/native rigs/manual impact pose and repeated rendered retirement; strict engine errors are separately captured, no server outcome synthesized"},"\t")); file.close()
	print("NATIVE_RANGED_MODEL_RETIREMENT ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
