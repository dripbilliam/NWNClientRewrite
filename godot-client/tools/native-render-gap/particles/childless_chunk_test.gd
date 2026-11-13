extends "res://tests/native_particle_presentation_test.gd"
const ActualEmitter=preload("res://systems/native_render/particle_emitter.gd")
const Bounds=preload("res://systems/native_render/particle_bounds.gd")
class AdmissionOracle:
	extends ActualEmitter
	# Independent GD adapter oracle: reuse the existing proven ordinary analytic
	# + active-particle conservative sphere, only when actual current native
	# chunk views have no child. Chunk kind is restored before any simulation.
	func outside_view(camera: Camera3D) -> bool:
		for part: Dictionary in _state.active188.records:
			if not bool(part.get("nativeChunky",false)) or part.get("chunk78")!=null:return false
		var resource: String=str(_state.chunkName)
		_state.chunkName=""
		var rejected: bool=super.outside_view(camera)
		_state.chunkName=resource
		return rejected
func chunk_services(context: Dictionary,counts: Dictionary) -> Dictionary:
	return {"createChunkModel":func(_name: String) -> Variant:
		counts.created+=1;return null if bool(context.nil_child) else {"serial":counts.created},
		"chunkScene":func(_child: Variant,attached: bool) -> void:counts.events.append(["scene",attached]),
		"chunkScale":func(_child: Variant,factor: float,kind: int) -> void:counts.events.append(["scale",factor,kind]),
		"chunkPlay":func(_child: Variant,clip: String,speed: float,flags: int,time: float) -> void:counts.events.append(["play",clip,speed,flags,time]),
		"chunkPosition":func(_child: Variant,position: Array) -> void:counts.events.append(["position",position.duplicate()]),
		"chunkOrientation":func(_child: Variant,q: Array) -> void:counts.events.append(["orientation",q.duplicate()]),
		"destroyChunkModel":func(_child: Variant,flag: int) -> void:counts.events.append(["destroy",flag])}
func make_emitter(scene: Node3D,oracle: bool,context: Dictionary,counts: Dictionary,explosion: bool=false) -> Node3D:
	var part: Node3D=Node3D.new();scene.add_child(part)
	var emitter: Node3D=AdmissionOracle.new() if oracle else ActualEmitter.new()
	emitter.force_reference=oracle;emitter.source_path=NodePath("..");emitter.source_model_flags=4
	emitter.clock_provider=func() -> Dictionary:return {"clip":"default","time":context.time}
	emitter.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","flags":32,"chunkname":"PLC_Chunk_S01","texture":"NULL","birthrate":20.0,"lifeexp":0.2,"velocity":0.2,"randvel":0.1,"spread":0.0,"xsize":0.0,"ysize":0.0,"sizestart":0.1,"sizeend":0.1,"alphastart":1.0,"alphaend":1.0,"particlerot":0.0,"frameend":1.0}
	if explosion:
		emitter.original_properties.update="Explosion";emitter.original_properties.birthrate=3.0;emitter.original_properties.lifeexp=0.45;emitter.original_properties.flags=32|128
	emitter.channel_asset={"clips":[{"name":"default","length":1.0,"emitterTracks":[{"part":0,"property":"birthrate","frames":[{"time":0.0,"value":[20.0]},{"time":0.19,"value":[20.0]},{"time":0.2,"value":[0.0]},{"time":1.0,"value":[0.0]}]}]}]}
	if explosion:emitter.channel_asset={}
	emitter.physical_part=0;emitter.services=chunk_services(context,counts)
	part.add_child(emitter);emitter.set_process(false);emitter.rng.seed_value(131)
	check(emitter.failure.is_empty(),"Actual chunk emitter initializes without resource I/O")
	check((emitter.native_owner==null)==oracle,"Actual reference/native ownership route")
	return emitter
func actual_emitter_case() -> void:
	var scene: Node3D=Node3D.new();root.add_child(scene)
	var camera: Camera3D=Camera3D.new();scene.add_child(camera);camera.far=130;camera.current=true
	var context: Dictionary={"time":0.0,"nil_child":true}
	var a: Dictionary={"created":0,"events":[]};var b: Dictionary={"created":0,"events":[]}
	var reference: Node3D=make_emitter(scene,true,context,a);var candidate: Node3D=make_emitter(scene,false,context,b)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	check(not presentation.call("dispatch",0,{"id":candidate.get_instance_id(),"owner":candidate.native_owner,"providers":candidate.providers,"clock":candidate.clock_provider,"clip":"default","source_flags":4,"culling":true,"draw_enabled":false,"childless_chunk_admission":true}).has("error"),"Default-off childless route is explicitly enrolled")
	var deltas: Array=[0.1,0.1,0.1,0.1,0.5,0.0,0.1,0.1,0.1,0.1,0.1]
	var times: Array=[0.0,0.1,0.15,0.16,0.3,0.3,0.3,0.0,0.1,0.3,0.3]
	var proofs: Array=[];var rejected: Array=[]
	for frame: int in deltas.size():
		context.time=times[frame];context.nil_child=frame<2 or frame>=7
		var far: bool=frame in [1,3,6,8,10]
		camera.position=Vector3(2000 if far else 0,4,8);camera.look_at(Vector3(2000 if far else 0,0,0))
		if frame==10:
			reference.source_model_flags=-1;presentation.call("dispatch",4,{"id":candidate.get_instance_id(),"source_flags":-1})
		reference.tick(float(deltas[frame]),true)
		var output: Dictionary=presentation.call("dispatch",1,{"delta":deltas[frame],"view":Bounds.native_view(camera)})
		check(not output.has("error"),"Childless chunk shared frame succeeds "+str(frame))
		var info: Dictionary=presentation.call("dispatch",10,{"id":candidate.get_instance_id()})
		proofs.append(int(info.chunk_proof));rejected.append(bool(info.culled))
		check(reference.last_culled==bool(info.culled),"Current childless analytic/conservative admission matches independent GD adapter "+str(frame))
		check(same(without_ids(reference.state),without_ids(candidate.state)).is_empty(),"Exact chunk state/history/pools/latches "+str(frame)+" "+same(without_ids(reference.state),without_ids(candidate.state)))
		check(reference.rng.state==candidate.rng.state and reference.rng.draws==candidate.rng.draws,"Exact shared RNG draws and rejection freeze "+str(frame))
		check(same(a,b).is_empty(),"Exact chunk callbacks and retained-child lifecycle "+str(frame)+" "+same(a,b))
	check(proofs.has(1) and proofs.has(2) and proofs.has(5),"Empty, all-nil, and real-current-child fallback actually exercised")
	check(bool(rejected[1]) and not bool(rejected[3]) and bool(rejected[6]) and not bool(rejected[10]),"Nil active children cull; real child blocks cull; free child ignored; unknown classification falls back")
	var census: Dictionary=presentation.call("dispatch",14,{})
	check(census.entries.size()==1 and census.entries[0].resource=="PLC_Chunk_S01","Literal real chunk resource and chunk kind stay intact")
	presentation.call("dispatch",5,{});presentation=null;reference.retire();candidate.retire();reference=null;candidate=null;scene.free()
func explosion_command_case() -> void:
	var scene: Node3D=Node3D.new();root.add_child(scene)
	var camera: Camera3D=Camera3D.new();scene.add_child(camera);camera.far=130;camera.current=true
	var context: Dictionary={"time":0.0,"nil_child":true}
	var a: Dictionary={"created":0,"events":[]};var b: Dictionary={"created":0,"events":[]}
	var reference: Node3D=make_emitter(scene,true,context,a,true);var candidate: Node3D=make_emitter(scene,false,context,b,true)
	var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
	check(not presentation.call("dispatch",0,{"id":candidate.get_instance_id(),"owner":candidate.native_owner,"providers":candidate.providers,"clock":candidate.clock_provider,"source_flags":4,"culling":true,"draw_enabled":false,"childless_chunk_admission":true}).has("error"),"Explosion command owner registers")
	for frame: int in 6:
		context.time=float(frame)*0.1
		var far: bool=frame in [0,1,3,5]
		camera.position=Vector3(2000 if far else 0,4,8);camera.look_at(Vector3(2000 if far else 0,0,0))
		if frame==0:reference.detonate();presentation.call("dispatch",4,{"id":candidate.get_instance_id(),"detonate":true})
		if frame==3:
			reference.get_parent().position=Vector3(0.2,0.0,-0.1);candidate.get_parent().position=Vector3(0.2,0.0,-0.1)
		if frame==5:
			reference.source_model_flags=-1;presentation.call("dispatch",4,{"id":candidate.get_instance_id(),"source_flags":-1})
		reference.tick(0.1,true)
		var output: Dictionary=presentation.call("dispatch",1,{"delta":0.1,"view":Bounds.native_view(camera)})
		var info: Dictionary=presentation.call("dispatch",10,{"id":candidate.get_instance_id()})
		check(not output.has("error") and reference.last_culled==bool(info.culled),"Explosion current admission is exact "+str(frame))
		check(same(without_ids(reference.state),without_ids(candidate.state)).is_empty(),"Explosion detonate/history/inheritance/latch/pool exact "+str(frame)+" "+same(without_ids(reference.state),without_ids(candidate.state)))
		check(reference.rng.state==candidate.rng.state and reference.rng.draws==candidate.rng.draws and same(a,b).is_empty(),"Explosion RNG and child callbacks exact "+str(frame))
		if frame<2:check(int(candidate.state.detonate108)==1 and int(candidate.state.initialized208)==0 and b.created==0,"Rejected detonation stays latched without initializing/spawning")
		if frame==2:check(int(candidate.state.detonate108)==0 and b.created>0,"First admitted wrapper consumes the retained detonation exactly once")
	presentation.call("dispatch",5,{});presentation=null;reference.retire();candidate.retire();reference=null;candidate=null;scene.free()
func imported_proof_cases() -> void:
	var scene: Node3D=Node3D.new();root.add_child(scene)
	for mode: int in 5:
		var pose: Node3D=Node3D.new();scene.add_child(pose)
		var seed: Dictionary=make_owner(false,"fountain",0,false,false);seed.state.chunkName="real-resource";seed.state.birthRate=0.0
		var record: Dictionary=Init.create(seed.state,0.0,seed.providers)
		if mode in [1,2,3,4]:record.nativeChunky=mode!=2
		if mode in [1,2]:record.chunk78=null
		if mode==4:record.chunk78={"free_child":true}
		if mode==3:record.chunk78={"unknown_child":true}
		if mode==4:seed.state.free130={"records":[record],"capacity":1}
		else:seed.state.active188={"records":[record],"capacity":1}
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		check(not owner.call("dispatch",0,{"state":seed.state,"update":"fountain","compactRecords":true,"typedEmitter":true,"poseId":pose.get_instance_id(),"sourceId":pose.get_instance_id()},{}).has("error"),"Imported proof owner configures "+str(mode))
		var presentation: RefCounted=ClassDB.instantiate("NwnParticlePresentation")
		check(not presentation.call("dispatch",0,{"id":pose.get_instance_id(),"owner":owner,"providers":{},"source_flags":0,"culling":true,"childless_chunk_admission":true}).has("error"),"Imported owner registers "+str(mode))
		var census: Dictionary=presentation.call("dispatch",14,{})
		var expected: int=[3,2,4,5,1][mode]
		check(census.entries.size()==1 and int(census.entries[0].proof)==expected,"Authoritative active metadata proof/fallback, freepool excluded "+str(mode))
		presentation.call("dispatch",5,{});presentation=null;owner=null;seed.providers.clear();pose.free()
	scene.free()
func original_childless_radius() -> void:
	var path: String=ProjectSettings.globalize_path("res://../backups/animations/chunk-childless-radius-a.json").simplify_path()
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(corpus.get("binarySha256")==BINARY_SHA and corpus.get("radii",[]).size()==10 and bool(corpus.get("function",{}).get("unchangedComparedToExactPE",false)),"Fresh original unchanged CalculateRadius corpus identity")
	var accepted: int=0
	for row: Dictionary in corpus.radii:
		var input: Dictionary=row.input
		var chunks: Array=[]
		for index: int in input.chunks.size():chunks.append({"view":bool(input.get("chunk_views",[1,1,1])[index]),"child":input.chunks[index]})
		var actual: Dictionary=Bounds.calculate(input,int(input.get("source_flags",0)),input.get("wind",[0.0,0.0,0.0]),input.get("origin",[0.0,0.0,0.0]),null,chunks)
		check(PackedFloat32Array([float(actual.radius)]).to_byte_array().hex_encode()==row.radius_word,"Original chunk radius word "+str(accepted))
		if accepted<7:
			check(row.unrelatedFreeAndFutureReads.is_empty(),"Original did not inspect populated free/future memory "+str(accepted))
			var seed: Dictionary=make_owner(false,"fountain",0,false,false);seed.state.chunkName="real-resource"
			var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
			check(not owner.call("dispatch",0,{"state":seed.state,"parameters":input,"update":"fountain","compactRecords":true,"typedEmitter":true},{}).has("error"),"Typed childless analytic state configures")
			var native_radius: Dictionary=owner.call("dispatch",5,{"source_flags":4,"wind":[0.0,0.0,0.0]},{})
			check(PackedFloat32Array([float(native_radius.radius)]).to_byte_array().hex_encode()==row.radius_word,"Native analytic radius matches original actual childless row "+str(accepted))
			owner=null;seed.providers.clear()
		accepted+=1
	check(accepted==10,"All childless, positive live-child, and early-return original instruction cases exercised")
func run() -> void:
	var report: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(ClassDB.class_exists("NwnParticlePresentation"),"Private particle kernel loads")
	original_childless_radius();actual_emitter_case();explosion_command_case();imported_proof_cases()
	await process_frame;await process_frame
	var file: FileAccess=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Fresh active-childless chunk admission vs actual GD emitter with independently reused original analytic/conservative sphere; exact state/RNG/controllers/callback/lifetime, live child fallback and freechild exclusion; no GPU/FPS/authority claim"},"\t"));file.close();quit(0 if failures.is_empty() else 1)
