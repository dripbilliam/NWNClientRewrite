extends "res://tests/nwn65_rig_skin_publisher_test.gd"
# Short graphical skin correctness check only; no frame-time/FPS measurement.
var maximum_vertex_error:=0.0
func run() -> void:
	if DisplayServer.get_name()=="headless":check(false,"Graphical skin check requires a renderer");finish();return
	if not ClassDB.class_exists("NwnRigSkinPublisher"):check(false,"Native publisher available");finish();return
	var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(0,2,10);camera.look_at(Vector3(0,1,0));camera.current=true
	var ordinary:=setup(false,false,false);var candidate:=setup(true,false,false)
	for frame in 12:
		for row in [ordinary,candidate]:
			row.entry.nodes[0].quaternion=Quaternion.from_euler(Vector3(frame*0.03,frame*0.07,frame*-0.017))
			if frame==3:row.rigs.set_manual_pose(1,row.entry.nodes[1],Vector3(0.2,-0.7,0.3),Quaternion(Vector3.RIGHT,0.17))
			if frame==7:row.rigs._play(row.entry.models[0],"turn",true,-0.5,0.4,true)
			row.rigs._update(0.0625)
		await process_frame
		await RenderingServer.frame_post_draw
		check(var_to_bytes(capture(ordinary))==var_to_bytes(capture(candidate)),"Exact graphical-frame CPU pose/event/attachment state "+str(frame))
		for index in ordinary.entry.skins.size():
			var original_mesh: MeshInstance3D=ordinary.entry.skins[index].mesh
			var optimized_mesh: MeshInstance3D=candidate.entry.skins[index].mesh
			var original_skin: ArrayMesh=original_mesh.bake_mesh_from_current_skeleton_pose()
			var optimized_skin: ArrayMesh=optimized_mesh.bake_mesh_from_current_skeleton_pose()
			check(original_skin!=null and optimized_skin!=null,"Both original/native skins bake from actual renderer")
			if original_skin==null or optimized_skin==null:continue
			var original_vertices: PackedVector3Array=original_skin.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var optimized_vertices: PackedVector3Array=optimized_skin.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var error:=0.0
			for vertex in original_vertices.size():error=maxf(error,original_vertices[vertex].distance_to(optimized_vertices[vertex]))
			maximum_vertex_error=maxf(maximum_vertex_error,error)
			check(error<0.0004,"Original/native sparse GPU skin vertices match "+str(frame)+"/"+str(index))
	for row in [ordinary,candidate]:row.rigs.forget_entity(1);row.host.free();row.clear()
	camera.free();await process_frame
	coverage.append("Vulkan renderer actual baked sparse weighted/unweighted skin vertices, animation/manual/reverse/attachments/force reentry")
	finish()

func finish() -> void:
	var report:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"coverage":coverage,"maximum_vertex_error":maximum_vertex_error,"renderer":DisplayServer.get_name(),"scope":"Actual graphical renderer sparse weighted/unweighted skin vertex parity and exact CPU state against original scalar setters. No whole-client visual/Arelith or FPS acceptance."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.substr(9),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(report,"\t")+"\n")
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
