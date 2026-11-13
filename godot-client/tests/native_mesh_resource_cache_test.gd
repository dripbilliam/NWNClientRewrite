extends SceneTree
const Codec=preload("res://systems/native_render/native_mesh_resource_cache.gd")
const Store=preload("res://systems/native_data/prepared_resource_store.gd")
class ScriptedMesh:
	extends ArrayMesh
	var original_marker:=91
class Metadata:
	extends Resource
	var original_marker:=37
var checks:=0
var failures: Array=[]
var measurements: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func source_mesh() -> ArrayMesh:
	var mesh:=ScriptedMesh.new();var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3(2,0,0),Vector3(0,0,-2)]);arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.UP,Vector3.UP,Vector3.UP]);arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN]);arrays[Mesh.ARRAY_COLOR]=PackedColorArray([Color.RED,Color.GREEN,Color.BLUE]);arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,2,1]);mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,StandardMaterial3D.new());mesh.set_meta("native_pick_geometry",Metadata.new());mesh.set_meta("original_metadata",{"nested":[Metadata.new()],"marker":14});mesh.custom_aabb=AABB(Vector3(-1,-1,-3),Vector3(4,2,4));return mesh
func drain(codec) -> bool:
	var deadline:=Time.get_ticks_msec()+10000
	while Time.get_ticks_msec()<deadline:
		codec.poll(8,1.0)
		if codec.reads.is_empty() and codec.writes.is_empty():return true
		await process_frame
		OS.delay_msec(1)
	return false
func clean_surface(mesh: ArrayMesh) -> Array:
	var surfaces: Array=mesh.get("_surfaces").duplicate(true)
	for value in surfaces:value.erase("material")
	return surfaces
func run() -> void:
	var report:="";var cache_root:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--cache-root="):cache_root=arg.substr(13)
	if report.is_empty() or cache_root.is_empty() or FileAccess.file_exists(report):quit(2);return
	var source:=source_mesh();var before:=clean_surface(source);var script_before: Script=source.get_script();var material_before:=source.surface_get_material(0);var metadata_before: Variant=source.get_meta("native_pick_geometry")
	var source_sha:="1".repeat(64);var parent_sha:="2".repeat(64)
	var base_key:=Codec.key_for(source_sha,3,"converter-v1",{"rigid_skin":false},[parent_sha])
	check(Codec.valid_key(base_key),"Source/dependency/converter key is valid")
	check(base_key!=Codec.key_for(source_sha,4,"converter-v1",{"rigid_skin":false},[parent_sha]),"Physical mesh index changes identity")
	check(base_key!=Codec.key_for(source_sha,3,"converter-v2",{"rigid_skin":false},[parent_sha]),"Converter revision changes identity")
	check(base_key!=Codec.key_for(source_sha,3,"converter-v1",{"rigid_skin":true},[parent_sha]),"Geometry policy changes identity")
	check(base_key!=Codec.key_for(source_sha,3,"converter-v1",{"rigid_skin":false},["3".repeat(64)]),"Inherited dependency changes identity")
	check(base_key!=Codec.key_for(source_sha,3,"converter-v1",{"rigid_skin":false},[parent_sha],"array-mesh"),"Different prepared payload formats do not alias")
	check(Codec.key_for(source_sha,3,"converter-v1",{"a":true,"b":2},[parent_sha,source_sha])==Codec.key_for(source_sha,3,"converter-v1",{"b":2,"a":true},[source_sha,parent_sha,parent_sha]),"Flags and dependency ordering have canonical identity")
	check(Codec.key_for("bad",3,"converter-v1")=="" and Codec.key_for(source_sha,3,"converter-v1",{"bad":Metadata.new()})=="","Missing/non-data cache identities are rejected")
	var unknown_version:={"major":4,"minor":6,"patch":0,"status":"stable","build":"custom_build","hash":"unknown"}
	var unknown_key:=Codec.key_for(source_sha,3,"converter-v1",{},[],"packed-buffers","",unknown_version)
	check(Codec.engine_identity("",unknown_version)==[Codec.REVISION,4,6,0,"stable","custom_build","unknown",""],"Engine identity retains full version tuple even when the custom binary reports an unknown hash")
	for field in ["major","minor","patch","status","build","hash"]:
		var changed:=unknown_version.duplicate();changed[field]=int(changed[field])+1 if changed[field] is int else str(changed[field])+"-changed"
		check(unknown_key!=Codec.key_for(source_sha,3,"converter-v1",{},[],"packed-buffers","",changed),"Engine tuple "+field+" change invalidates native draw buffers")
	check(unknown_key!=Codec.key_for(source_sha,3,"converter-v1",{},[],"packed-buffers","d".repeat(64),unknown_version),"Optional once-computed executable fingerprint changes native draw identity")
	check(Codec.key_for(source_sha,3,"converter-v1",{},[],"packed-buffers","unknown")=="","Invalid exact executable fingerprint is rejected")
	for mode in ["packed-buffers","array-mesh"]:
		var store:=Store.new();check(store.configure(cache_root.path_join(mode)),"Real prepared store configures "+mode)
		check(store.snapshot().budget_bytes==25*1024*1024*1024,"Default store budget is25GiB, without preallocating disk")
		var codec:=Codec.new();check(codec.configure(store,mode),"Native codec configures "+mode)
		var key:=Codec.key_for(source_sha,3,"converter-v1",{"rigid_skin":false},[parent_sha],mode)
		check(codec.take_ready(key)==null,"Unavailable data stays unavailable")
		var buffers:=codec.snapshot_draw_buffers(source)
		if mode=="packed-buffers":
			var envelope:=Resource.new();envelope.set_meta(Codec.BUFFER_METADATA,{"revision":Codec.REVISION,"engine":Codec.engine_identity(),"key":key,"mesh":buffers})
			check(codec._accepted_resource(envelope,key),"Packed envelope accepts matching full engine tuple")
			var wrong_stamp:=Codec.engine_identity();wrong_stamp[2]=int(wrong_stamp[2])+1;envelope.get_meta(Codec.BUFFER_METADATA).engine=wrong_stamp
			check(not codec._accepted_resource(envelope,key),"Packed envelope rejects another engine version even when its reported hash could match")
		check(Codec.valid_buffers(buffers) and buffers.surfaces==before,"Snapshot retains native packed geometry and omits material dependencies")
		check(source.get_script()==script_before and source.surface_get_material(0)==material_before and source.get_meta("native_pick_geometry")==metadata_before,"Snapshot never mutates original Script, material or physical metadata")
		var clean:=codec.private_draw_copy(source)
		check(clean!=source and Codec.pure_mesh(clean) and clean_surface(clean)==before and clean.custom_aabb==source.custom_aabb,"Private builtin duplicate preserves packed buffers and bounds while stripping scripts/materials/metadata")
		check(not Codec.pure_mesh(source),"Original scripted metadata owner is distinct from cache artifact")
		check(codec.queue_save(key,source),"Native compressed write is queued "+mode)
		check(await drain(codec),"Asynchronous save/publication completes "+mode)
		check(codec.stats.writes_completed==1 and codec.stats.writes_failed==0,"Real store published exactly one artifact "+mode)
		check(source.get_script()==script_before and source.surface_get_material(0)==material_before and source.get_meta("native_pick_geometry")==metadata_before and clean_surface(source)==before,"Saved cache leaves live source unchanged")
		var path:=store.lookup(key);check(not path.is_empty(),"Committed artifact is discoverable")
		var bytes:=0
		if not path.is_empty():
			var file:=FileAccess.open(path,FileAccess.READ);bytes=file.get_length();check(file.get_buffer(4).get_string_from_ascii()=="RSCC","Artifact uses Godot compressed binary resource encoding");file.close()
		check(codec.prefetch(key)=="loading","Read request queues a worker lease front-end")
		check(codec.prefetch(key)=="loading" and codec.reads.size()==1,"Concurrent same-key requests share one native load")
		check(codec.take_ready(key)==null,"Taking an unfinished resource never waits")
		check(await drain(codec) and codec.state(key)=="ready","Only completed threaded native resource becomes ready")
		var loaded:=codec.take_ready(key)
		check(loaded!=null and loaded!=source and Codec.pure_mesh(loaded),"Loaded draw resource is detached, built-in and metadata-free")
		if loaded!=null:check(clean_surface(loaded)==before and loaded.custom_aabb==source.custom_aabb,"Compressed round trip preserves exact native draw buffers and authored bounds")
		check(codec.take_ready(key)==null,"Ready ownership transfers once")
		if loaded!=null:loaded.set_meta("native_scene_geometry",Metadata.new())
		check(codec.prefetch(key)=="loading" and await drain(codec),"Second load can finish after current consumer adds private physical metadata")
		var second:=codec.take_ready(key)
		check(second!=null and second!=loaded and Codec.pure_mesh(second),"Next load is isolated from prior consumer mutation and global resource cache")
		var missing:="a".repeat(64)
		check(codec.prefetch(missing)=="loading" and await drain(codec) and codec.state(missing)=="missing" and codec.take_ready(missing)==null,"Missing prepared resource cleanly selects original-factory fallback")
		var bad_key:="b".repeat(64);var ticket:=store.begin_write(bad_key);check(not ticket.is_empty(),"Malformed-type fixture obtains an owned staging ticket")
		var foreign:=Resource.new();foreign.set_meta("unrelated","data")
		if not ticket.is_empty():check(ResourceSaver.save(foreign,ticket.path,ResourceSaver.FLAG_COMPRESS)==OK and store.commit_write(ticket),"Foreign builtin resource fixture publishes without arbitrary Script data")
		check(codec.prefetch(bad_key)=="loading" and await drain(codec) and codec.state(bad_key)=="failed" and codec.take_ready(bad_key)==null,"Wrong typed/schema resource is rejected with explicit fallback")
		check(codec.stats.loads_failed>=1,"Unsupported artifact is observable")
		var corrupt_key:="c".repeat(64);check(codec.queue_save(corrupt_key,source) and await drain(codec),"Owned corruption fixture starts with a real published artifact")
		var corrupt_path:=store.lookup(corrupt_key)
		if not corrupt_path.is_empty():
			var corrupt:=FileAccess.open(corrupt_path,FileAccess.READ_WRITE);corrupt.seek(0);corrupt.store_buffer("BAD!".to_ascii_buffer());corrupt.close()
		check(codec.prefetch(corrupt_key)=="loading" and await drain(codec) and codec.take_ready(corrupt_key)==null,"Corrupt binary envelope falls back before native resource parsing")
		var stale:=Codec.new();check(stale.configure(store,mode),"Independent asynchronous owner configures")
		check(stale.prefetch(key)=="loading","Retirement fixture queues a real read-start worker")
		stale.close();check(await drain(stale) and stale.close() and stale.ready.is_empty(),"Retiring prefetch drains worker/engine load and releases lease without publishing a stale resource")
		check(codec.stats.save_gpu_meshes_created==(0 if mode=="packed-buffers" else 2),"Save-side GPU duplicate count distinguishes packed buffers and ArrayMesh comparison")
		check(not codec.stats.prefetch_worker_threads.is_empty() and not codec.stats.prefetch_worker_threads.has(OS.get_main_thread_id()),"Filesystem lease/header/request work executes off the presentation thread")
		check(not codec.stats.write_worker_threads.is_empty() and not codec.stats.write_worker_threads.has(OS.get_main_thread_id()),"Begin/save/commit filesystem work executes off the presentation thread")
		measurements.append({"mode":mode,"artifact_bytes":bytes,"codec":codec.snapshot(),"scope":"Authored correctness timings; no GPU or representative performance claim"})
		check(codec.close() and store.close(),"Codec and actual store close with no pending read/write tickets")
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"measurements":measurements,"scope":"Real native compressed resource and prepared-store correctness, async worker front-end, original mutation isolation and corrupt/unsupported/missing fallback; no production integration or performance acceptance"},"\t")+"\n");file.close();print("NATIVE_MESH_RESOURCE_CACHE ",checks," checks ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
