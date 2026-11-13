extends "res://tests/native_parity_bridge_world_motion_test.gd"
# Actual two bridge MDLs recovered locally, with their live-renderer identities.
# Fixture-only presentation is disabled; all source geometry/transforms/material
# masks/provenance remain original and run through production support owners.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Query=preload("res://systems/native_render/projectile_scene.gd")
var completed: Dictionary={}
var asset_observations: Array=[]
func candidates(instance) -> Array:
	Query.prepare_parts(instance)
	var result: Array=[]
	for part: Dictionary in instance.get_meta("native_scene_parts"):
		var source_data: Dictionary=part.node.get_meta("native_mesh_source",{})
		if source_data.get("native_tilefade") in [2,4]:continue
		var geometry=part.data
		for at in range(0,geometry.indices.size(),3):
			if source_data.get("node_is_aabb")==true and geometry.surface_types.size()>at/3 and (int(geometry.surface_types[at/3])&63)==30:continue
			var triangle: Array=geometry.face(at);var points: Array[Vector3]=[]
			for point: Array in triangle:
				var world: Vector3=part.node.global_transform*Query.engine(point)
				points.append(Vector3(world.x,-world.z,world.y))
			var normal: Vector3=(points[1]-points[0]).cross(points[2]-points[0]);var projected_area:=normal.z*0.5
			var center: Vector3=(points[0]+points[1]+points[2])/3.0
			if projected_area<0.25 or center.x<0 or center.y<0 or center.x>=40 or center.y>=40:continue
			result.append({"part":int(source_data.get("part_index",-1)),"name":str(source_data.get("part_name","")),"face":at/3,"area":projected_area,"points":points,"center":center,"aabb":source_data.get("node_is_aabb")})
	result.sort_custom(func(a,b):return a.area>b.area if a.area!=b.area else a.part<b.part if a.part!=b.part else a.face<b.face)
	return result
func asset_case(result: Dictionary,identity: Dictionary) -> void:
	check(result.sha256==identity.sha256,"Prepared bridge source matches exact live renderer identity "+identity.name)
	var original: Dictionary=result.value;var retained: Dictionary=original.duplicate(true)
	var support: Dictionary=result.duplicate();support.value=original.duplicate(true);support.resource_name=identity.name
	for node: Dictionary in support.value.nodes:
		if node.get("mesh") is Dictionary and not node.mesh.is_empty():node.mesh.render=false;node.mesh.shadow=false
	var world=make_world(10+asset_observations.size(),35+asset_observations.size())
	publish(world,"actual-asset-lower-floor-"+identity.name,40,40,0,0,Vector3.ZERO)
	var template=world.pool.model_template(support)
	check(template!=null and world.pool.failure.is_empty(),"Actual source bridge pooled physical template prepares "+identity.name)
	if template==null:world.close();await process_frame;world.free();return
	var instance=template.create();world.terrain.add_child(instance);instance.position=Vector3(10,11,-10)
	world.terrain.instances[identity.name]=instance;world.terrain.collision_index.put(instance)
	var choices:=candidates(instance)
	check(choices.size()>=2,"Actual bridge has multiple substantial upward source faces "+identity.name)
	var rows: Array=[];var lifetime:=1
	for candidate: Dictionary in choices.slice(0,mini(6,choices.size())):
		var center: Vector3=candidate.center
		var target: Vector3=center+(candidate.points[0]-center)*0.15
		var row:=source(world,lifetime,center);var canonical:=row.duplicate(true);actor(world,row,lifetime>1)
		received_path(world,Vector3(target.x,target.y,0),lifetime)
		var samples: Array=[]
		for tick in 4:
			var previous: float=world.motion.objects[7].position.z
			step(world,0.005)
			var position: Vector3=world.motion.objects[7].position
			var expected: Dictionary=world.client_support_scene.query(position,previous)
			check(expected.available and expected.get("branch","") in ["original","negative_seam","positive_seam"],"Actual bridge source returns an executed support hit "+identity.name)
			check(expected.available and near(position.z,expected.position.z) and position.z>1,"Actual Motion keeps original bridge support above its lower floor "+identity.name)
			check(display_matches(world),"Actual World display uses source bridge Motion support "+identity.name)
			check(row==canonical and world.desired[7].object.replicated==canonical.replicated,"Walking actual bridge leaves received coordinates intact "+identity.name)
			samples.append({"received":canonical.replicated.position.duplicate(),"predicted":[position.x,position.y,position.z],"displayed":[world.instances[7].position.x,world.instances[7].position.y,world.instances[7].position.z],"support_branch":expected.get("branch","")})
		rows.append({"part":candidate.part,"part_name":candidate.name,"face":candidate.face,"projected_area":candidate.area,"aabb":candidate.aabb,"source_face_points":candidate.points.map(func(p):return [p.x,p.y,p.z]),"samples":samples})
		lifetime+=1
	check(original==retained,"Support-only draw flag adaptation never mutates decoded original model "+identity.name)
	check(world.surface.height_calls==0,"Actual source bridge uses no replacement WOK height "+identity.name)
	asset_observations.append({"resource":identity.name,"source_sha256":identity.sha256,"source_sha1":identity.sha1,"source_bytes":identity.bytes,"physical_parts":instance.parts.size(),"candidate_upward_faces":choices.size(),"placement":{"nwn":[10,10,11],"authored_fixture":true,"live_tile_pose_claim":false},"cases":rows,"support":world.client_support_scene.snapshot(),"scene_index":world.terrain.collision_index.snapshot()})
	world.close();await process_frame;await process_frame;world.free();await process_frame
func run() -> void:
	var manifest_file:="";var cache_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
		elif arg.begins_with("--assets-manifest="):manifest_file=arg.substr(18)
		elif arg.begins_with("--cache="):cache_path=arg.substr(8)
	if output.is_empty() or manifest_file.is_empty() or cache_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	if OS.get_cmdline_user_args().has("--existing-kernel"):
		retained_extension=load("res://native/particle_kernel.gdextension");check(retained_extension!=null and ClassDB.class_exists("NwnSceneIndex"),"Matched existing native library loads")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_file))
	check(manifest.get("version")==1 and manifest.get("files",[]).size()==2,"Exact two-resource local bridge fixture opens")
	var catalog:=Catalog.new();check(catalog.mount_directory(manifest.directory,10000000),"Private verified original source directory mounts read-only")
	var assets:=Assets.new();root.add_child(assets);assets.maximum_workers=1;assets.cache_directory=cache_path;assets.configure(catalog);assets.completed.connect(func(id,result):completed[id]=result)
	for identity: Dictionary in manifest.files:
		check(FileAccess.get_sha256(identity.file)==identity.sha256,"Private bridge bytes still match raw source/live renderer SHA256 "+identity.name)
		var id: int=assets.request(identity.name,2002,"mdl-original");check(id>=0,"Actual AssetService accepts source bridge "+identity.name)
		var deadline:=Time.get_ticks_msec()+10000
		while not completed.has(id) and Time.get_ticks_msec()<deadline:await process_frame
		check(completed.has(id),"Actual original-model preparation completes "+identity.name)
		if not completed.has(id):continue
		var result: Dictionary=completed[id];check(str(result.get("error","")).is_empty(),"Actual source bridge decode succeeds "+identity.name+":"+str(result.get("error","")))
		if not str(result.get("error","")).is_empty():continue
		await asset_case(result,identity)
	assets.close();assets.free();await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"assets":asset_observations,"serverConnections":0,"nativeBuilds":0,"gpuDraws":0,"scope":"Exact two MDLs identified by live renderer SHA256 and cached native manifest SHA1/size, prepared by actual AssetService and installed as actual pooled physical Parts. Source-driven upward-face points walk through production World/Motion/support/display; fixture placement/navigation/animation ports remain explicit, and visible drawing is disabled without changing source geometry. No claim of original native live tile pose/BSP tie/visual comparison."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("NATIVE_PARITY_BRIDGE_ACTUAL_ASSET ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
