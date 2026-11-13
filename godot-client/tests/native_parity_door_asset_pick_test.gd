extends SceneTree
# Installed resources -> active worker decoder -> real rig -> physics/Camera
# selection. No native GUI, UDP connection, optimistic door state or GPU draw.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const ActorModel=preload("res://systems/native_data/actor_model.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Door=preload("res://tools/native_parity/doors/door_instance_candidate.gd")
const Registry=preload("res://tools/native_parity/doors/entity_registry_candidate.gd")
const Baseline=preload("res://systems/entity_registry.gd")
const Names=preload("res://systems/native_data/object_animation.gd")
var checks:=0
var failures: Array=[]
var report:=""
var install:=""
var cache_path:=""
var received: Dictionary={}
var rows: Array=[]
func progress(value: String) -> void:
	print("DOOR_PROGRESS: "+value)
	if report.is_empty():return
	var file:=FileAccess.open(report+".progress.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify({"phase":value,"checks":checks,"failures":failures}));file.close()

func _initialize() -> void:call_deferred("run")
func check(value: bool,context: String) -> void:
	checks+=1
	if not value and failures.size()<40:failures.append(context)
func engine(v: Vector3) -> Vector3:return Vector3(v.x,v.z,-v.y)
func metadata(model: Dictionary) -> Array:
	var result: Array=[]
	for node in model.get("nodes",[]):
		var mesh: Dictionary=node.get("mesh",{})
		if not mesh.is_empty():result.append({"name":str(node.name),"alpha":node.get("alpha"),"bounds":mesh.get("native_bounds"),"available":mesh.get("native_bounds_available"),"valid":mesh.get("native_bounds_valid"),"source":mesh.get("native_bounds_source"),"tilefade":mesh.get("native_tilefade"),"tilefade_available":mesh.get("native_tilefade_available")})
	return result

func request(service,name: String) -> Dictionary:
	var id: int=service.request(name,2002,"actor-model",{"relevant_tracks":true})
	check(id>=0,"active AssetService accepts installed actor-model "+name)
	if id<0:return {}
	var deadline:=Time.get_ticks_msec()+30000
	while not received.has(id) and Time.get_ticks_msec()<deadline:await process_frame
	check(received.has(id),"bounded worker completion "+name)
	if not received.has(id):return {}
	var result: Dictionary=received[id];received.erase(id)
	check(str(result.get("error","missing")).is_empty(),"installed actor-model succeeds "+name+": "+str(result.get("error")))
	return result

func cache_probe(service,catalog,name: String) -> Dictionary:
	progress("cache/before-source/"+name)
	var bytes: PackedByteArray=catalog.get_resource(name,2002)
	check(catalog.failure.is_empty() and not bytes.is_empty(),"actual installed MDL bytes "+name)
	if bytes.is_empty():return {}
	var source_sha:=Cache.digest(bytes);var decoder: String=ActorModel.SOURCE_DECODER
	var disk:=Cache.new();check(disk.configure(cache_path),"private disk cache opens")
	var old_disk:=Cache.key(source_sha,decoder+":2002:emitter-3:reference-1:clip-duration-1:classification-1:mesh-area-1:hit-faces-1:ambient-1:vertex-color-1")
	if service.mesh_preparation_enabled:old_disk=Cache.key(old_disk,service.mesh_revision())
	var sentinel:={"stale_metadata_less":true,"name":"stale","nodes":[],"animations":[]}
	check(disk.save_data(old_disk,source_sha,decoder,sentinel),"old metadata-less disk payload is actually seeded")
	var old_request:="decoded-native-v1:2002:"+decoder+":"+source_sha+":ambient-1:vertex-color-1"
	if service.mesh_preparation_enabled:old_request+=":"+service.mesh_revision()
	var store=catalog.decoded_cache();var generation: int=store.generation()
	store.save_data(old_request,old_request,{"result":{"value":sentinel,"error":"","sha256":source_sha}},generation)
	check(not store.load_data(old_request,generation).is_empty(),"old metadata-less decoded entry is actually seeded")
	var cold: Dictionary=service.decode(bytes,2002,decoder,cache_path,store)
	progress("cache/after-cold/"+name)
	check(str(cold.get("error","missing")).is_empty() and not cold.get("memory_decode_hit",true) and not cold.get("cache_hit",true) and not cold.get("value",{}).has("stale_metadata_less"),"new versioned model path refuses both old metadata-less identities "+name)
	if not cold.get("value") is Dictionary:return {}
	var expected:=metadata(cold.value)
	check(not expected.is_empty() and expected.all(func(row):return row.available==true and row.valid==true and row.tilefade_available==true),"actual decoded model retains bounds and tilefade provenance "+name)
	var warm: Dictionary=service.decode(bytes,2002,decoder,cache_path,store)
	progress("cache/after-memory/"+name)
	check(warm.get("memory_decode_hit",false) and metadata(warm.get("value",{}))==expected,"decoded-memory warm hit retains exact metadata "+name)
	# Keep the existing old entry/file as a witness. Clear only this fixture's
	# private decoded owner, then require the separately versioned disk hit.
	store.clear()
	var disk_warm: Dictionary=service.decode(bytes,2002,decoder,cache_path,store)
	progress("cache/after-disk/"+name)
	check(not disk_warm.get("memory_decode_hit",true) and disk_warm.get("cache_hit",false) and metadata(disk_warm.get("value",{}))==expected,"actual new disk warm hit retains metadata "+name)
	check(disk.load_data(old_disk,source_sha,decoder).get("stale_metadata_less",false),"old disk witness remains untouched")
	return {"source_sha256":source_sha,"source_bytes":bytes.size(),"binary":bytes.decode_u32(0)==0,"old_disk_identity":old_disk,"old_decoded_request":old_request,"metadata":expected}

func flush_physics() -> void:
	await physics_frame;await physics_frame;await process_frame

func camera_for(camera: Camera3D,part: Node3D,bounds: Dictionary) -> Vector2:
	var low: Array=bounds.min;var high: Array=bounds.max
	var center:=Vector3((low[0]+high[0])*0.5,(low[1]+high[1])*0.5,(low[2]+high[2])*0.5)
	var from:=part.global_transform*engine(Vector3(low[0]-5.0,center.y,center.z))
	var target:=part.global_transform*engine(center)
	camera.position=from;camera.look_at(target,Vector3.UP);camera.current=true
	return Vector2(root.size)*0.5

func pick_phase(door,camera: Camera3D,sam: Node3D,bounds: Dictionary,id: int,label: String,open_state: int,require_miss: bool) -> Dictionary:
	progress("pick/before-camera/"+label)
	var screen:=camera_for(camera,sam,bounds)
	var row:={"id":id,"type":10,"eligible":true,"label":"Installed "+label,"doorOpenState":open_state}
	var base:=Baseline.new();root.add_child(base);check(base.register_native(id,row,door),"baseline target registration "+label)
	await flush_physics()
	progress("pick/before-baseline/"+label)
	var before: Dictionary=base.pick(camera,screen)
	base.forget_entity(id);base.free();await flush_physics()
	var candidate:=Registry.new();root.add_child(candidate);check(candidate.register_native(id,row,door),"candidate target registration "+label)
	await flush_physics()
	progress("pick/before-candidate/"+label)
	var ray_origin:=camera.project_ray_origin(screen);var ray_end:=ray_origin+camera.project_ray_normal(screen)*camera.far
	var direct: Dictionary=door.native_door_pick(ray_origin,ray_end)
	print("DOOR_REGION: "+JSON.stringify({"label":label,"direct":direct,"snapshot":door.native_door_pick_snapshot(),"origin":ray_origin,"end":ray_end}))
	var after: Dictionary=candidate.pick(camera,screen)
	progress("pick/after-candidate/"+label)
	check(after.get("id",-1)==id and after.get("entity",{}).get("type")==10 and after.get("entity",{}).get("eligible",false),"actual Camera/physics picker returns exact eligible door ID "+label)
	if require_miss:
		check(before.get("id",-1)!=id,"baseline visible-mesh picker misses the opened doorway "+label)
		check(after.has("native_door_region"),"authored native region repairs that exact missing doorway target "+label)
	candidate.forget_entity(id);await flush_physics()
	progress("pick/before-removed/"+label)
	check(candidate.pick(camera,screen).get("id",-1)!=id,"removed registry lifetime is no longer targetable "+label)
	candidate.free()
	progress("pick/finished/"+label)
	return {"phase":label,"state":open_state,"baseline":int(before.get("id",-1)),"candidate":int(after.get("id",-1)),"native_region":after.get("native_door_region")}

func exercise(bundle: Dictionary,name: String,id: int,pool) -> Dictionary:
	progress("instance/before-new/"+name)
	var door:=Door.new();root.add_child(door)
	progress("instance/before-install/"+name)
	var installed: bool=door.install_door(bundle,pool,id,{"doorOpenState":0})
	progress("instance/after-install/"+name)
	check(installed,"actual installed door instance builds "+name+": "+door.failure)
	if not installed:door.free();return {}
	door.set_process(false);door.rigs.set_process(false)
	var nodes: Array=bundle.value.nodes;var sam_index:=-1
	for index in nodes.size():
		if str(nodes[index].name).to_lower()=="sam" and not nodes[index].mesh.is_empty():sam_index=index;break
	check(sam_index>=0,"actual alpha0 stable doorway Part exists "+name)
	if sam_index<0:door.retire();await process_frame;return {}
	var sam: Node3D=door.rigs.node_at(id,int(door.rigs.entities[id].model_parts[0][sam_index]))
	var source: Dictionary=nodes[sam_index].mesh;var bounds: Dictionary=source.native_bounds
	check(float(nodes[sam_index].alpha)==0.0 and source.native_bounds_available and source.native_bounds_valid,"actual stable alpha0 Part retains original bounds "+name)
	check(sam.has_meta("native_mesh_source") and sam.get_meta("native_mesh_source").native_bounds==bounds,"physical rig Part retains exact metadata "+name)
	var stable: Transform3D=sam.global_transform;var physical_id:=sam.get_instance_id()
	var camera:=Camera3D.new();root.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4;camera.near=0.05;camera.far=30
	var samples: Array=[]
	for stage: Dictionary in [{"state":0,"transition":-1,"rest":22,"label":"closed"},{"state":1,"transition":300,"rest":50,"label":"open1"},{"state":2,"transition":301,"rest":51,"label":"open2"}]:
		progress("instance/sample/"+name+"/"+stage.label)
		door.observe_door({"doorOpenState":stage.state})
		if stage.transition>=0:
			var length: float=door.rigs.clip_length(id,int(stage.transition))
			check(length>0 and door.rigs.entities[id].models[0].clip==Names.name(10,int(stage.transition)),"real opening clip selected "+name+"/"+stage.label)
			door.rigs._update(length*0.5)
			progress("instance/mid-updated/"+name+"/"+stage.label)
			check(sam.get_instance_id()==physical_id and sam.global_transform==stable,"alpha0 physical doorway does not follow moving leaf "+name+"/"+stage.label)
			samples.append(await pick_phase(door,camera,sam,bounds,id,name+"/"+stage.label+"-mid",int(stage.state),false))
			door.rigs._update(length*0.5+0.02);door._process(length+0.02)
			progress("instance/rest-selected/"+name+"/"+stage.label)
		door.rigs._update(0.05)
		check(door.rigs.entities[id].models[0].clip==Names.name(10,int(stage.rest)),"real opened/closed rest clip selected "+name+"/"+stage.label)
		check(sam.get_instance_id()==physical_id and sam.global_transform==stable,"stable physical doorway pose retained at rest "+name+"/"+stage.label)
		samples.append(await pick_phase(door,camera,sam,bounds,id,name+"/"+stage.label+"-rest",int(stage.state),stage.state!=0))
	door.position=Vector3(15,3,8);door.rotation.y=0.7
	samples.append(await pick_phase(door,camera,sam,bounds,id,name+"/transformed",2,true))
	var origin: Vector3=camera.project_ray_origin(Vector2(root.size)*0.5);var endpoint:=origin+camera.project_ray_normal(Vector2(root.size)*0.5)*camera.far
	var snapshot: Dictionary=door.native_door_pick_snapshot()
	door.retire();check(not door.native_door_pick(origin,endpoint).available,"retired actual instance refuses retained-region pick "+name)
	await process_frame;camera.free()
	var again:=Door.new();root.add_child(again);check(again.install_door(bundle,pool,id,{"doorOpenState":2}),"fresh reentry can reuse object ID under new lifetime "+name)
	check(again.get_instance_id()!=int(snapshot.owner_instance),"same network ID has new physical owner "+name)
	again.set_process(false);again.rigs.set_process(false)
	var new_sam: Node3D=again.rigs.node_at(id,int(again.rigs.entities[id].model_parts[0][sam_index]))
	var new_camera:=Camera3D.new();root.add_child(new_camera);new_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;new_camera.size=4;new_camera.far=30
	samples.append(await pick_phase(again,new_camera,new_sam,bounds,id,name+"/reentry",2,true))
	new_camera.free();again.retire();await process_frame
	return {"name":name,"samples":samples,"regions":snapshot}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
		elif arg.begins_with("--cache="):cache_path=arg.substr(8)
	if report.is_empty() or install.is_empty() or cache_path.is_empty() or FileAccess.file_exists(report):quit(2);return
	root.size=Vector2i(640,480)
	progress("catalog/before-mount")
	var catalog:=Catalog.new();check(catalog.mount_install(install),"original installed catalog mounts read-only: "+catalog.failure)
	if catalog.layers.is_empty():quit(3);return
	catalog.decoder_store=Store.new()
	var service:=Assets.new();root.add_child(service);service.maximum_workers=1;service.cache_directory=cache_path;service.configure(catalog)
	service.completed.connect(func(id,result):received[id]=result)
	var pool:=Pool.new();pool.picking=true;pool.unshaded=true
	var id:=31000
	for name: String in ["t_door01","t_door11"]:
		var proof:=cache_probe(service,catalog,name)
		progress("worker/before-request/"+name)
		var bundle: Dictionary=await request(service,name)
		progress("worker/after-request/"+name)
		if not str(bundle.get("error","missing")).is_empty():continue
		var warm: Dictionary=await request(service,name)
		check(warm.get("memory_cache_hit",false) and metadata(warm.get("value",{}))==metadata(bundle.value),"prepared-memory warm actor bundle retains metadata "+name)
		var result: Dictionary=await exercise(bundle,name,id,pool);result.cache=proof;rows.append(result);id+=1
	service.close();service.free();await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file==null:quit(4);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"models":rows,"active_worker_count":service.running.size() if is_instance_valid(service) else 0,"public_connections":0,"native_builds":0,"gpu_draws":0,"scope":"Installed binary/ASCII actor-model preparation, stale metadata identities, actual rig/physical Part and Camera/physics doorway selection; no server action outcome, broad UI action-label or original native GUI picking acceptance"},"  "));file.close()
	quit(0 if failures.is_empty() else 1)
