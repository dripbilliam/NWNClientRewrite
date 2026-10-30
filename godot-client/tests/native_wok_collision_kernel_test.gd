extends "res://tests/native_projectile_scene_test.gd"
const Wok=preload("res://systems/native_data/tile_surface.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-surface-oracle-v1.json")); var catalog:=Catalog.new()
	check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original WOK install mounts read-only")
	var samples: Array=oracle.samples.slice(0,5).map(func(sample):return sample.name); samples.append("ttr01_g01_01"); var sources: Dictionary={}
	for resource in samples:
		var bytes:=catalog.get_resource(str(resource),2016); var parser:=Wok.new(); var mesh:=parser.parse_bytes(bytes)
		check(not mesh.is_empty() and parser.failure.is_empty(),"Original WOK decodes "+str(resource))
		if mesh.is_empty(): continue
		sources[resource]=digest(bytes)
		var world:=World.new(); root.add_child(world); var surface:=TerrainSurface.new(); world.add_child(surface); world.surface=surface; surface.done=true
		surface.table={"orderedRows":[{"Walk":"1"}]}; surface.meshes[resource]=mesh
		for orientation in 4:
			surface.definition={"width":1,"height":1,"tiles":[{"model":resource,"orientation":orientation,"position":Vector3(5,1.25,-5)}]}; surface.index_vertical_tiles()
			for i in 121:
				var xy:=Wok.canonical([M.f((i%11)-0.001),M.f(int(i/11)+0.001)],posmod(4-orientation,4)); var start: Array=[xy[0],xy[1],31.25]; var end: Array=[xy[0],xy[1],-28.75]
				var local:=Wok.canonical(xy,orientation); var a: Array=[local[0],local[1],30.0]; var b: Array=[local[0],local[1],-30.0]; var expected: Variant=null
				# Independent retained pre-optimization face traversal, with actual
				# decoded source planes, original order and the same material mask.
				for face_index in mesh.faces.size():
					if (int(mesh.materials[face_index])&63)==30: continue
					var face: Array=mesh.faces[face_index]; var hit: Variant=Polygon.hit([mesh.vertices[face[0]],mesh.vertices[face[1]],mesh.vertices[face[2]]],mesh.normals[face_index],mesh.constants[face_index],a,b)
					if hit!=null: expected={"hit":true,"position":[xy[0],xy[1],M.f(hit[2]+1.25)],"normal":Query.tile_normal(mesh.normals[face_index],orientation)}; b[2]=hit[2]
				if expected==null: expected={"hit":false,"position":[0.0,0.0,0.0],"normal":[0.0,0.0,0.0]}
				check(JSON.stringify(Query.trace(world,start,end,true))==JSON.stringify(expected),"Native WOK query matches original traversal "+str(resource)+"/"+str(orientation)+"/"+str(i))
		check(surface.collision_meshes.size()==1,"All placements reuse one immutable WOK collision snapshot "+str(resource))
		surface.close(); check(surface.collision_meshes.is_empty(),"Area close releases WOK collision snapshot "+str(resource)); world.free()
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"sourceSha256":sources,"scope":"2904 actual decoded original WOK queries against retained original polygon traversal across six resources, four quarter turns, finite rays, material mask, elevated placement, snapshot reuse and retirement. Full original BSP membership remains separate."},"\t")); file.close()
	print("NATIVE_WOK_COLLISION_KERNEL ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)

