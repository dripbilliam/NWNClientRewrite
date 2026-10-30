extends SceneTree
const Prepare=preload("res://systems/native_data/mesh_preparation.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func same(a: Variant,b: Variant) -> bool: return Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b))
func _initialize() -> void: call_deferred("run")
func authored(normals: bool=true,uv: bool=true) -> Dictionary:
	return {"vertices":PackedFloat32Array([-1,0,0,2,0,0,0,3,0,0,0,2]),"normals":PackedFloat32Array([0,0,1,0,0,1,0,0,1,0,1,0]) if normals else PackedFloat32Array(),"uv":[PackedFloat32Array([0,0,1,0,0,1,0.5,0.5])] if uv else [],"indices":PackedInt32Array([0,1,2,0,3,1]),"collision_indices":PackedInt32Array([0,1,2]),"native_surface_types":PackedInt32Array([0])}
func compare(raw: Dictionary,label: String,rigid: bool=false) -> Dictionary:
	var digest:=Cache.digest(var_to_bytes(raw)); var prepared:=Prepare.prepare(raw)
	check(str(prepared.error).is_empty() and not prepared.get("empty",false),label+": data-only preparation succeeds")
	if not str(prepared.error).is_empty() or prepared.get("empty",false): return {}
	check(Cache.digest(var_to_bytes(raw))==digest,label+": original mesh/planes/order remain immutable")
	var data:=raw.duplicate(); data.native_upload=prepared
	var reference:=Pool.new(); reference.use_prepared_geometry=false; reference.picking=true
	var candidate:=Pool.new(); candidate.use_prepared_geometry=true; candidate.picking=true
	var began:=Time.get_ticks_usec(); var a:=reference.geometry(digest,0,raw,rigid); var reference_ms:=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec(); var b:=candidate.geometry(digest,0,data,rigid); var candidate_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(a!=null and b!=null and reference.failure.is_empty() and candidate.failure.is_empty(),label+": both main-thread ArrayMesh paths publish")
	if a==null or b==null: return {}
	check(same(a.surface_get_arrays(0),b.surface_get_arrays(0)) and a.get_aabb()==b.get_aabb(),label+": published vertices/normals/UV/winding/bones/weights and bounds are exact")
	var pa=a.get_meta("native_pick_geometry"); var pb=b.get_meta("native_pick_geometry")
	check(same(pa.vertices,pb.vertices) and same(pa.indices,pb.indices) and pa.bounds==pb.bounds,label+": shared picking geometry stays exact")
	check(same(pa.cached_shape.get_faces(),pb.cached_shape.get_faces()),label+": actual interactive physics triangles stay exact")
	var ga=a.get_meta("native_scene_geometry"); var gb=b.get_meta("native_scene_geometry")
	check(same(ga.vertices,gb.vertices) and same(ga.indices,gb.indices) and same(ga.planes,gb.planes) and same(ga.surface_types,gb.surface_types) and ga.bounds==gb.bounds,label+": original collision order, FLOAT planes, material mask and conservative bounds stay exact")
	var rays_ok:=true
	for index in 25:
		var start: Array=[-1.0+index*0.16,0.5,3.0]; var end: Array=[start[0],0.5,-1.0]
		if JSON.stringify(ga.nearest(start,end,true))!=JSON.stringify(gb.nearest(start,end,true)): rays_ok=false
	check(rays_ok,label+": actual original nearest-face queries remain identical")
	var ha=reference.hidden_geometry(digest,0,raw); var hb=candidate.hidden_geometry(digest,0,data)
	check(ha!=null and hb!=null and same(ha.vertices,hb.vertices) and same(ha.indices,hb.indices) and ha.bounds==hb.bounds,label+": invisible hit-only geometry is preserved")
	check(candidate.stats.prepared_mesh_uses==1 and candidate.stats.main_mesh_preparations==0 and candidate.stats.prepared_hidden_uses==1,label+": prepared consumer actually skips main-thread conversion loops")
	check(candidate.geometry(digest,0,data,rigid)==b and candidate.stats.mesh_hits==1,label+": immutable GPU mesh sharing is unchanged")
	reference.clear(); candidate.clear()
	return {"reference_publication_ms":reference_ms,"prepared_publication_ms":candidate_ms,"vertices":prepared.positions.size(),"faces":prepared.indices.size()/3}
func worker(value: Dictionary) -> Dictionary: return Prepare.model(value)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var samples: Array=[]
	for normals in [false,true]:
		for uv in [false,true]:
			for rigid in [false,true]: samples.append(compare(authored(normals,uv),"Authored normals/UV/rigid "+str([normals,uv,rigid]),rigid))
	var filtered:=authored(); filtered.native_planes=PackedFloat32Array([0,0,1,0]); filtered.native_surface_types=PackedInt32Array([30]); compare(filtered,"Serialized collision planes and ignored material")
	var random:=RandomNumberGenerator.new(); random.seed=0x14007b0e7
	for trial in 16:
		var raw:=authored(trial%2==0,trial%3==0)
		for index in raw.vertices.size(): raw.vertices[index]=random.randf_range(-128,128)
		compare(raw,"Seeded general geometry "+str(trial))
	for mode in ["vertices","normals","uv","negative","range"]:
		var raw:=authored()
		match mode:
			"vertices": raw.vertices=PackedFloat32Array([0,0])
			"normals": raw.normals=PackedFloat32Array([0])
			"uv": raw.uv=[PackedFloat32Array([0])]
			"negative": raw.indices[0]=-1
			"range": raw.indices[0]=999
		var pool:=Pool.new(); pool.use_prepared_geometry=false; var mesh=pool.geometry(Cache.digest(mode.to_utf8_buffer()),0,raw)
		check(mesh==null and Prepare.prepare(raw).error==pool.failure,"Invalid stream keeps explicit original publication failure: "+mode); pool.clear()
	var raw:=authored(); var prepared:=Prepare.prepare(raw); prepared.revision="old"; raw.native_upload=prepared
	var bad:=Pool.new(); bad.use_prepared_geometry=true
	check(bad.geometry(Cache.digest("invalid-prepared".to_utf8_buffer()),0,raw)==null and not bad.failure.is_empty(),"Mismatched derived-data revision cannot silently publish")
	bad.clear()
	var model:={"nodes":[{"mesh":authored()},{"mesh":{}}]}; var thread:=Thread.new(); thread.start(worker.bind(model)); var result: Dictionary=thread.wait_to_finish()
	check(str(result.error).is_empty() and result.meshes==1 and result.thread!=OS.get_main_thread_id(),"Actual worker creates only data derivatives for complete source nodes")
	var stripped: Dictionary=model.nodes[0].mesh.duplicate(); stripped.erase("native_upload")
	check(same(stripped,authored()) and model.nodes.size()==2,"Worker keeps raw geometry and empty physical nodes intact")
	if args.has("catalog"):
		var catalog:=Recorded.new(); check(catalog.mount(args.catalog),"Strict captured source corpus mounts without fallback")
		for name in ["pme0_chest025","pme0_head001","pme0_footr012","temple_e2","p_idol_orc01","c_deeprothe_b"]:
			var bytes:=catalog.get_resource(name,2002); var actor:=Actor.new(); var value:=actor.parse(bytes)
			check(catalog.failure.is_empty() and actor.failure.is_empty(),"Original full actor parser preserves source/skin payload: "+name)
			var index:=0
			for node in value.get("nodes",[]):
				if node.mesh.is_empty() or node.mesh.indices.is_empty(): continue
				var sample:=compare(node.mesh,"Original "+name+" mesh "+str(index)); sample.name=name; samples.append(sample); index+=1
			check(index>0,"Actual original actor piece includes tested geometry: "+name)
	await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"Exact worker/main publication arrays, generated/authored normals, winding, rigid skin channels, actual pick shapes/hidden geometry and original collision queries; no full-world latency/FPS or original GPU sampling acceptance"},"\t")); file.close()
	print("NATIVE_MESH_PREPARATION ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
