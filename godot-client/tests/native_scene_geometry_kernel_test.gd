extends "res://tests/native_polygon_hit_test.gd"
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	if not Kernel.available(): quit(3); return
	var path:="res://../backups/animations/native-camera-polygon-observations.json"; var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data.target==BINARY_SHA and data.rows.size()==1876,"Original polyhit identity/count")
	var owner: RefCounted=ClassDB.instantiate("NwnSceneGeometry"); var index:=0
	for row in data.rows:
		var c: Dictionary=row.case; var vertices:=PackedFloat32Array()
		for vertex in c.vertices: vertices.append_array(PackedFloat32Array(vertex))
		var setup: Variant=owner.call("dispatch",0,{"vertices":vertices,"indices":PackedInt32Array([0,1,2]),"planes":PackedFloat32Array(c.normal+[c.constant]),"types":PackedInt32Array([0])})
		var result: Variant=owner.call("dispatch",1,{"start":M.values(c.start),"end":M.values(c.end)})
		check(setup==null and (result!=null)==bool(row.result) and (result==null or result.position.map(bits)==row.bits),"Compiled original polyhit exact case "+str(index)); index+=1
	var mesh:={"vertices":PackedFloat32Array(),"indices":PackedInt32Array(),"native_planes":PackedFloat32Array(),"native_surface_types":PackedInt32Array()}
	# Repeated heights, equal planes and excluded faces test physical winner order.
	for i in 160:
		var height:=M.f((i%7)*0.125); var x: float=i%10; var y: float=int(i/10)%10
		mesh.vertices.append_array(PackedFloat32Array([x,y,height,x+2,y,height,x,y+2,height])); mesh.indices.append_array(PackedInt32Array([i*3,i*3+1,i*3+2])); mesh.native_planes.append_array(PackedFloat32Array([0,0,1,-height])); mesh.native_surface_types.append(30 if i%11==0 else 0)
	var geometry:=Geometry.new(); geometry.configure(mesh)
	var rays: Array=[]
	for i in 256:
		var start:=M.values([(i%16)*0.7-1,int(i/16)*0.7-1,2]); var end:=M.values([start[0]+0.03125,start[1]-0.0625,-2]); rays.append([start,end])
		var fast: Variant=geometry.nearest(start,end,true); var reference: Variant=geometry.nearest(start,end,true,false)
		check(JSON.stringify(fast)==JSON.stringify(reference),"Packed mesh nearest position/normal/order case "+str(i))
	var timing: Dictionary={}
	for compiled in [false,true]:
		var began:=Time.get_ticks_usec()
		for ray in rays: geometry.nearest(ray[0],ray[1],true,compiled)
		timing["compiled_us" if compiled else "reference_us"]=Time.get_ticks_usec()-began
	# Reconfiguration replaces the private snapshot; it never retains scene nodes.
	geometry.configure({"vertices":PackedFloat32Array([0,0,1,2,0,1,0,2,1]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,-1]),"native_surface_types":PackedInt32Array([30])})
	check(geometry.nearest([0.25,0.25,2],[0.25,0.25,-1])==null,"Reconfiguration replaces native geometry and material mask")
	geometry.surface_types=PackedInt32Array([0]); geometry.configure({"vertices":geometry.vertices,"indices":geometry.indices,"native_planes":geometry.planes,"native_surface_types":geometry.surface_types})
	var configured_hit: Variant=geometry.nearest([0.25,0.25,2],[0.25,0.25,-1],true)
	check(configured_hit!=null and configured_hit==geometry.nearest([0.25,0.25,2],[0.25,0.25,-1],true,false),"Fresh native snapshot sees the newly configured collision face with original FLOAT rounding")
	var bad: Variant=owner.call("dispatch",0,{"vertices":PackedFloat32Array([0,0,0]),"indices":PackedInt32Array([0,1,2]),"planes":PackedFloat32Array([0,0,1,0]),"types":PackedInt32Array()})
	var after: Variant=owner.call("dispatch",1,{"start":[0,0,1],"end":[0,0,-1]})
	check(bad is Dictionary and bad.has("error") and after is Dictionary and after.has("error"),"Invalid native geometry clears prior snapshot instead of serving stale faces")
	var weak: WeakRef=weakref(owner); owner=null; geometry=null
	check(weak.get_ref()==null,"Native collision owner releases without scene ownership")
	await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(path),"timing":timing,"scope":"1876 unchanged original polygon cases exact FLOAT bits; 256 complete mesh comparisons with physical winner order, normals and material30, reconfiguration, invalid input and native release. Does not establish original scene/BSP membership parity or real-room FPS."},"\t")); file.close()
	print("NATIVE_SCENE_GEOMETRY_KERNEL ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
