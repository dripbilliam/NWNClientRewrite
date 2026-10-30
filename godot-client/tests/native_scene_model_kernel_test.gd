extends "res://tests/native_projectile_scene_test.gd"
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
func exhaustive(model,start: Array,end: Array) -> Variant:
	var best: Variant=null; var limit: Array=end
	for node in model.meshes:
		if not is_instance_valid(node): continue
		var data=node.mesh.get_meta("native_scene_geometry"); var transform: Transform3D=node.global_transform; var inverse:=transform.affine_inverse()
		var hit: Variant=data.nearest(Query.native(inverse*Query.engine(start)),Query.native(inverse*Query.engine(limit)),true,false)
		if hit!=null:
			best={"position":M.values(Query.native(transform*Query.engine(hit.position))),"normal":M.values(Query.native((inverse.basis.transposed()*Query.engine(hit.normal)).normalized()))}; limit=best.position
	return best
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	check(Kernel.available(),"Compiled model collision is available")
	var empty:=Model.new(); root.add_child(empty)
	check(Query.prepare_model(empty)==null and empty.has_meta("native_scene_model_attempted"),"Geometry-free scene model records the attempted preparation and retains null fallback")
	check(Query.prepare_model(empty)==null and not empty.has_meta("native_scene_model"),"Repeated empty preparation does not fabricate a native model or issue missing-metadata errors")
	check(Query.model_hit(empty,[0,0,2],[0,0,-2],true)==null,"Compiled query falls back safely for geometry-free original scene members")
	empty.free()
	var geometry:=Geometry.new(); geometry.configure({"vertices":PackedFloat32Array([0,0,0,2,0,0,0,2,0]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,0]),"native_surface_types":PackedInt32Array([0])})
	var model:=Model.new(); root.add_child(model)
	for i in 8:
		var mesh:=MeshInstance3D.new(); model.add_child(mesh); mesh.mesh=ArrayMesh.new(); mesh.mesh.set_meta("native_scene_geometry",geometry); model.meshes.append(mesh)
	var rays: Array=[]
	for frame in 120:
		# Pose changes intentionally happen within the same engine frame. Native
		# caches must read current Parts, not trust a once-per-frame time stamp.
		model.position=Vector3(sin(frame*0.1)*3,frame*0.01,cos(frame*0.04)*2)
		for i in model.meshes.size():
			model.meshes[i].transform=Transform3D(Basis(Vector3.RIGHT,frame*0.003+i*0.01).scaled(Vector3(1+i*0.1,2,0.75)),Vector3(i*2.5,i*0.125,-i*0.5))
		var part: Node3D=model.meshes[frame%8]
		for offset in [Vector3(0.25,0,-0.25),Vector3.ZERO,Vector3(2,0,0),Vector3(5,0,-5)]:
			var start:=Query.native(part.global_transform*(offset+Vector3(0,3,0))); var end:=Query.native(part.global_transform*(offset-Vector3(0,3,0)))
			check(JSON.stringify(Query.model_hit(model,start,end,true))==JSON.stringify(exhaustive(model,start,end)),"Native model matches exhaustive original faces with current same-frame Part pose "+str(frame)+"/"+str(offset))
			rays.append([start,end])
	check(model.has_meta("native_scene_model"),"Actual native model query path was exercised")
	var owner: RefCounted=model.get_meta("native_scene_model"); var weak: WeakRef=weakref(model)
	model.free(); await process_frame
	check(weak.get_ref()==null and owner.call("dispatch",1,{"start":[0,0,2],"end":[0,0,-2]})==null,"Retained diagnostic owner skips freed scene identities without retaining or dereferencing Parts")
	var bad: Variant=owner.call("dispatch",0,{"parts":[{"node":1,"geometry":-1,"low":[0,0,0],"high":[1,1,1]}]})
	check(bad.has("error") and owner.call("dispatch",1,{"start":[0,0,2],"end":[0,0,-2]}).has("error"),"Stale geometry token rejects configuration and clears previous model state")
	owner=null; geometry=null; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"480 native model queries vs exhaustive script original polygon tests, eight actual moving/scaled Parts, physical face/Part order, edges, same-frame poses, freed node identities and stale geometry tokens. Original BSP membership remains separate."},"\t")); file.close()
	print("NATIVE_SCENE_MODEL_KERNEL ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)

