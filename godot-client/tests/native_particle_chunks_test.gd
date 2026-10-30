extends SceneTree
const Chunks=preload("res://systems/native_render/particle_chunks.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
var checks:=0
var failures: Array=[]
var calls: Array=[]
var created: Array=[]
var scene_off:=0
var played:=0
var destroyed:=0
var scaled:=0
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func normalized(value: Variant) -> Variant:
	if value is float or value is int: return PackedFloat32Array([float(value)]).to_byte_array().hex_encode()
	if value is Array: return value.map(normalized)
	return value
func base(delta: float) -> Dictionary: calls.append(["baseInitialize",delta,1.0]); return {"age":0.0}
func captured_create(name: String,present: bool) -> Variant: calls.append(["create",name,"",0]); return "chunk0" if present else null
func captured_position(child: String,position: Array) -> void: calls.append(["position",int(child.trim_prefix("chunk")),position])
func captured_orientation(child: String,orientation: Array) -> void: calls.append(["orientation",int(child.trim_prefix("chunk")),orientation])
func original_case(row: Dictionary) -> void:
	calls=[]; var c: Dictionary=row.case
	var p:={"baseCreate":base,"baseInitialize":func(_part,delta,factor): calls.append(["baseInitialize",delta,factor]),"createChunkModel":captured_create.bind(c.model),"chunkScene":func(_child,attached): calls.append(["scene",attached]),"chunkScale":func(_child,factor,kind): calls.append(["scale",factor,kind]),"chunkPlay":func(_child,name,speed,flags,time): calls.append(["play",name,speed,flags,time]),"destroyChunkModel":func(_child,flag): calls.append(["delete",flag]),"chunkPosition":captured_position,"chunkOrientation":captured_orientation}
	var e:={"chunkName":"authored_chunk"}; var part:={"chunk78":"chunk0" if c.model else null}
	match str(c.operation):
		"construct": part=Chunks.construct(e,float(c.delta),p)
		"initialize": Chunks.initialize(part,float(c.delta),float(c.factor),p)
		"destroy": Chunks.destroy(part,p)
		"render":
			var source_fade: float=NAN if c.sourceFade==null else float(c.sourceFade)
			e={"source50":{"instance":{"fade":source_fade}} if c.source else null,"instance100":{"fade":c.fade},"particleRot":c.rotation,"active188":{"records":[]}}
			for index in 2: e.active188.records.append({"chunk78":"chunk"+str(index) if c.model else null,"position10":[1+index,2-index,3+index],"direction4c":[3,0,4] if index==0 else [0,0,2],"rotation1c":float(c.rotation)+index*0.25,"stopped70":c.stopped})
			Chunks.render(e,p)
	check(normalized(calls)==normalized(row.calls) and (c.operation=="render" or (part.get("chunk78")!=null)==bool(row.chunk)),"Complete original chunk owner trace/state: "+str(c))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-particle-chunks-v1.json"))
	check(evidence.rows.size()==110 and evidence.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Original bounded chunk owner corpus identity")
	for row in evidence.rows: original_case(row)
	var folder:=OS.get_temp_dir().path_join("nwn-native-chunks-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); DirAccess.make_dir_recursive_absolute(folder)
	var file:=FileAccess.open(folder.path_join("authored_chunk.mdl"),FileAccess.WRITE)
	file.store_string("newmodel authored_chunk\nbeginmodelgeom authored_chunk\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n0.3 0 0\n0 0 0.3\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 1 0 1 2 0\nendnode\nendmodelgeom authored_chunk\nnewanim impact authored_chunk\nlength 1\ntranstime 0\nanimroot authored_chunk\nnode dummy root\nparent NULL\npositionkey 2\n0 0 0 0\n1 0 0 0.1\nendnode\ndoneanim impact authored_chunk\n"); file.close()
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Authored native chunk model catalog mounts")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); var bundles: Array=[]; assets.completed.connect(func(_id,result):bundles.append(result)); assets.request("authored_chunk",2002,"actor-model")
	var deadline:=Time.get_ticks_msec()+10000
	while bundles.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	if bundles.is_empty() or not str(bundles[0].error).is_empty(): check(false,"Authored chunk model prepares through native worker"); assets.close(); assets.queue_free(); quit(1); return
	check(true,"Authored chunk model prepares through native worker")
	var pool:=Pool.new(); pool.unshaded=true; var host:=Node3D.new(); root.add_child(host); var camera:=Camera3D.new(); host.add_child(camera); camera.position=Vector3(2,3,5); camera.look_at(Vector3.ZERO); camera.current=true
	var source:=Node3D.new(); host.add_child(source); source.scale=Vector3.ONE*2
	var emitter:=Emitter.new(); emitter.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","flags":0,"texture":"absent_unused_quad","chunkname":"authored_chunk","birthrate":8.0,"lifeexp":0.25,"velocity":0.5,"particlerot":1.5,"sizestart":1.0,"alphaStart":1.0,"xgrid":1,"ygrid":1}; emitter.source_path=NodePath("..")
	emitter.services={"createChunkModel":func(_name):
		var actor:=Actor.new(); host.add_child(actor); actor.top_level=true
		if not actor.install([{"bundle":bundles[0],"initial_clip":"","follow":false}],pool,0,{}): actor.retire(); return null
		created.append(actor); return actor,
		"chunkScene":func(actor,attached): actor.visible=attached; actor.process_mode=Node.PROCESS_MODE_INHERIT if attached else Node.PROCESS_MODE_DISABLED; scene_off+=0 if attached else 1,
		"chunkScale":func(actor,factor,_kind): actor.scale=Vector3.ONE*factor; scaled+=1,
		"chunkPlay":func(actor,name,speed,flags,time):
			var model: Dictionary=actor.rigs.entities[0].models[0]
			if not actor.rigs.play_native(0,0,name,speed,flags,time): actor.rigs._play(model,name,flags==1,speed,time,true)
			if model.clip==name: played+=1,
		"chunkPosition":func(actor,position): actor.global_position=Vector3(position[0],position[2],-position[1]),
		"chunkOrientation":func(actor,q): actor.quaternion=Quaternion(q[1],q[3],-q[2],q[0]),
		"destroyChunkModel":func(actor,_flag): actor.retire(); destroyed+=1}
	source.add_child(emitter); emitter.set_process(false)
	check(emitter.failure.is_empty(),"Explicit native model services admit a chunk emitter without a fabricated missing quad bitmap")
	var moving:=false; var private_meshes:=false
	for frame in 120:
		emitter.tick(1.0/60.0)
		if not created.is_empty(): moving=moving or created[0].position.length()>0.01
		if created.size()>1: private_meshes=created[0]!=created[1] and created[0].rigs!=created[1].rigs and created[0].meshes[0].mesh==created[1].meshes[0].mesh
		await process_frame
	var state:=emitter.snapshot()
	check(state.failure.is_empty() and state.frames==120 and state.allocated>0 and state.vertices==0,"Coupled native chunk physics advances with no quad vertices")
	check(moving and private_meshes and played>created.size() and scaled==played and scene_off>0,"Private original-data chunk models move, play impact and recycle after detach with shared immutable meshes")
	check(created.all(func(actor):return actor.scale.is_equal_approx(Vector3.ONE*2)),"Chunk initialize applies the original source factor to model scale")
	var tracked: Array=created.map(func(actor):return weakref(actor)); emitter.retire(); check(destroyed==created.size(),"Retirement destroys active and pooled private chunk models exactly once")
	assets.close(); assets.queue_free(); host.queue_free(); await process_frame; await process_frame; pool.clear()
	check(tracked.all(func(reference):return reference.get_ref()==null),"No private chunk model survives retirement")
	file=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_rows":evidence.rows.size(),"runtime":state,"models_created":created.size(),"impact_plays":played,"scene_detaches":scene_off,"destroyed":destroyed,"network_connections":0,"scope":"Bounded original chunk owners with explicit lower providers; coupled actual native emitter/kernel, authored worker/model/mesh/clip services. Automatic live-world chunk asset/service binding, original pixels and full effects/performance remain incomplete"},"\t")); file.close(); print("NATIVE_PARTICLE_CHUNKS ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
