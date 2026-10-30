extends "res://tests/native_particle_schedule_test.gd"
const Bounds=preload("res://systems/native_render/particle_bounds.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const BinaryModel=preload("res://systems/native_data/binary_model.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
func word(value: float) -> String: return PackedFloat32Array([value]).to_byte_array().hex_encode()
func create_emitter(world: Node3D) -> Node3D:
	var part:=Node3D.new(); world.add_child(part)
	var out:=Emitter.new(); out.force_reference=true; out.source_path=NodePath(".."); out.source_model_flags=0
	out.original_properties={"update":"Fountain","render":"Normal","blend":"Normal","flags":32,"xgrid":1,"ygrid":1,"birthrate":20,"lifeexp":2,"velocity":0.2,"sizestart":0.1,"sizeend":0.1,"alphastart":1,"alphaend":1}
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); out.original_texture=ImageTexture.create_from_image(image)
	part.add_child(out); out.set_process(false); return out
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var path:=ProjectSettings.globalize_path("res://").path_join("../backups/animations/native-emitter-admission-observations-v2.json").simplify_path()
	var bytes:=FileAccess.get_file_as_bytes(path); var corpus: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
	check(corpus.binarySha256==BINARY_SHA and corpus.radii.size()==105 and corpus.spheres.size()==48 and corpus.admissions.size()==60,"Pinned unchanged original radius/plane/full-callback corpus")
	for index in corpus.radii.size():
		var row: Dictionary=corpus.radii[index]; var input: Dictionary=row.input; var chunks: Array=[]
		for child_index in input.get("chunks",[]).size(): chunks.append({"view":bool(input.get("chunk_views",[1,1,1])[child_index]),"child":input.chunks[child_index]})
		var actual:=Bounds.calculate(input,int(input.get("source_flags",0)),input.get("wind",[0.0,0.0,0.0]),input.get("origin",[0.0,0.0,0.0]),input.get("target"),chunks)
		check(word(actual.radius)==row.radius_word,"Exact original radius word "+str(index)+" "+word(actual.radius)+" != "+str(row.radius_word))
		check(word(actual.acceleration)==word(row.acceleration),"Exact original radius acceleration "+str(index))
	for index in corpus.spheres.size():
		var row: Dictionary=corpus.spheres[index]; var input: Dictionary=row.input
		check(word(Bounds.above_plane(input.point,input.radius,input.plane))==row.word,"Exact original sphere-plane word "+str(index))
	for index in corpus.admissions.size():
		var row: Dictionary=corpus.admissions[index]; var input: Dictionary=row.input; var admitted:=true
		for plane in input.planes:
			if Bounds.above_plane(input.origin,input.radius,plane)>0: admitted=false; break
		check(admitted==bool(row.admitted) and bool(row.identity_valid),"Complete original BSP callback admission, strict tangency and rotating start plane "+str(index))
	var source:="#MAXMODEL ASCII\nnewmodel flags\n%s\nbeginmodelgeom flags\nnode dummy root\nparent NULL\nendnode\nendmodelgeom flags\ndonemodel flags\n"
	for row in [["",0],["classification TiLe",2],["classification character",4],["classification effect",1],["classification effects",1],["classification door",8],["classification door\nclassification UNKNOWN",8]]:
		var parser:=Ascii.new(); var model:=parser.parse(source%str(row[0]))
		check(parser.failure.is_empty() and int(model.get("classification_flags",-1))==int(row[1]),"Original ASCII classification mapping "+str(row[0]))
	for flags in [0,1,2,4,8,255]:
		var data:=PackedByteArray(); data.resize(12+232+112); data.encode_u32(4,232+112); data.encode_u32(84,232); data.encode_u32(88,1); data[20]=102; data[12+0x72]=flags; data[12+232+32]=114; data.encode_u32(12+232+108,1)
		var parser:=BinaryModel.new(); var model:=parser.parse(data)
		check(parser.failure.is_empty() and int(model.get("classification_flags",-1))==flags,"Serialized model+72 retained as original runtime+92 "+str(flags))
	var world:=Node3D.new(); root.add_child(world); var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(0,1,10); camera.look_at(Vector3.ZERO); camera.current=true
	var out=create_emitter(world); var reference=create_emitter(world); reference.frustum_enabled=false
	out.tick(0.1); reference.tick(0.1)
	check(out.failure.is_empty() and out.frames==1 and not out.last_culled and out.state.active188.records.size()>0,"Visible native emitter simulates and publishes actual quads")
	var before: PackedByteArray=var_to_bytes(out.state); var draws: int=out.rng.draws; var sequence: int=out.sequence
	camera.position=Vector3(2000,1,10); camera.look_at(Vector3(2000,0,0)); await process_frame
	out.tick(0.25)
	# Source transform/controller inputs can refresh; particle state and history
	# are not advanced, aged, randomized, allocated or uploaded offscreen.
	check(out.last_culled and out.culled_frames==1 and out.frames==1 and not out.surface.visible,"Offscreen sphere omits simulation/publication and hides the retained surface")
	check(var_to_bytes(out.state)==before and out.rng.draws==draws and out.sequence==sequence,"Rejected frame preserves particle state/history/RNG/upload sequence")
	check(out.elapsed>=0.35,"Original controller clock still advances outside draw admission")
	camera.position=Vector3(0,1,10); camera.look_at(Vector3.ZERO); await process_frame
	out.tick(0.1); reference.tick(0.1)
	check(not out.last_culled and out.surface.visible and out.frames==2 and out.failure.is_empty(),"Camera return resumes visible moving emitter")
	check(var_to_bytes(out.state)==var_to_bytes(reference.state) and out.rng.draws==reference.rng.draws,"Return uses current delta with no accumulated simulation catch-up")
	camera.position=Vector3(2000,1,10); camera.look_at(Vector3(2000,0,0)); await process_frame
	out.source_model_flags=-1; out.tick(0.1)
	check(not out.last_culled and out.frames==3 and out.culling_fallbacks>0,"Unknown original classification retains simulation")
	out.source_model_flags=0; out.state.chunkName="unbound-fixture"
	check(not out.outside_view(camera),"Chunk bounds explicitly retain the existing simulation path")
	out.state.chunkName=""; out.services.moveParticles=func(_e,_d):pass
	check(not out.outside_view(camera),"Custom movement with unknown bounds retains simulation")
	out.services.clear(); out.source_model_flags=1
	check(out.bounds.radius_for(out.parameters,1)==1000.0,"Original effect-model bound is 1000, never the small basic radius")
	camera.position=Vector3(0,1,10); camera.look_at(Vector3.ZERO); await process_frame
	check(Bounds.outside(camera,Vector3(100,0,0),0.1) and not Bounds.outside(camera,Vector3(100,0,0),150),"Sphere crossing viewport edge stays admitted even when its center is outside")
	var edge:=Vector3(9,0,0); camera.fov=10; var narrow:=Bounds.outside(camera,edge,0.1); camera.fov=120
	check(narrow and not Bounds.outside(camera,edge,0.1),"Same-frame camera projection change invalidates retained planes")
	var template:=Template.new(); var pool:=Pool.new(); var model: Dictionary=Ascii.new().parse(source%"classification effect")
	# The actual template/instance resource pipeline must retain the new byte.
	model.nodes[0].emitter=out.original_properties.duplicate(true); model.nodes[0].features=["emitter"]
	check(template.build({"sha256":"admission-authored","value":model},pool),"Emitter template prepares with retained source classification")
	var clone=template.create(); world.add_child(clone); var cloned=clone.find_child("native_emitter",true,false)
	check(cloned!=null and cloned.source_model_flags==1,"Packed template preserves exported original model classification")
	var metrics: Dictionary=out.snapshot(); out.retire(); reference.retire(); clone.retire(); template=null; pool.clear(); pool=null; world.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_sha256":hash_bytes(bytes),"metrics":metrics,"publicConnections":0,"scope":"213 unchanged-original radius/plane/full-BSP-callback observations, original classification parsing, actual native GPU emitter leave/re-enter, no RNG/state catch-up, conservative fallbacks and packed-template ownership. Godot camera planes; not exact original BSP/frustum construction, global translucent order or full effects/performance acceptance."},"\t")); file.close()
	print("NATIVE_PARTICLE_ADMISSION ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
func hash_bytes(bytes: PackedByteArray) -> String:
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); return hash.finish().hex_encode()
