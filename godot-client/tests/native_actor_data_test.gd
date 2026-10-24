extends SceneTree
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func i32_digest(values: Variant) -> String:
	return Cache.digest(PackedInt32Array(values).to_byte_array())
func f32_digest(values: Variant) -> String:
	return Cache.digest(PackedFloat32Array(values).to_byte_array())
func flat(values: Array) -> Array:
	var output: Array=[]
	for vector in values: output.append_array(vector)
	return output
func clip_checks(actual: Array,expected: Array,label: String) -> void:
	check(actual.size()==expected.size(),label+" original clip count")
	var by_name: Dictionary={}
	for clip in actual: by_name[clip.name]=clip
	for source in expected:
		check(by_name.has(source.name),label+" original clip: "+source.name)
		if not by_name.has(source.name): continue
		var clip: Dictionary=by_name[source.name]
		# Original MDL clocks are binary32. Decimal JSON oracle parsing can
		# differ by one binary64 ULP without changing either original float.
		check(PackedFloat32Array([clip.length,clip.transition])==PackedFloat32Array([source.length,source.transition]),label+" original binary32 duration/transition: "+source.name)
		check(JSON.stringify(clip.events)==JSON.stringify(source.events),label+" original events: "+source.name)
		check(clip.tracks.size()==source.tracks.size(),label+" original transform tracks: "+source.name)
		var tracks: Dictionary={}
		for track in clip.tracks: tracks[str(track.node).to_lower()+":"+str(track.property)]=track
		for original in source.tracks:
			var key:=str(original.node).to_lower()+":"+str(original.property)
			check(tracks.has(key),label+" original track binding: "+source.name+"/"+key)
			if not tracks.has(key): continue
			var track: Dictionary=tracks[key]; var values: Array=[]
			for frame in track.frames:
				values.append(frame.time); values.append_array(frame.value)
				if frame.has("in"): values.append_array(frame["in"]); values.append_array(frame["out"])
			check(track.interpolation==original.interpolation and track.frames.size()==int(original.frames) and f32_digest(values)==original.sha256,label+" exact original transform keys: "+source.name+"/"+key)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture.input)); var catalog:=Capture.new()
	check(FileAccess.get_sha256(fixture.input)==fixture.inputSha256 and catalog.mount(data.capture,data.context,data.supplements),"Original actor input/catalog integrity")
	var service:=Assets.new(); root.add_child(service); service.configure(catalog); service.cache_directory=ProjectSettings.globalize_path("user://native-prepared-v2")
	var observed: Dictionary={}; service.completed.connect(func(id: int,result: Dictionary): observed[id]=result)
	var jobs: Dictionary={}; var failures_before:=0
	for sample in fixture.samples:
		var bytes:=catalog.get_resource(sample.name,2002); var parser:=Actor.new(); var model:=parser.parse(bytes)
		check(catalog.failure.is_empty() and parser.failure.is_empty() and not model.is_empty(),"Original native actor parse: "+sample.name+" "+parser.failure)
		if model.is_empty(): continue
		check(Cache.digest(bytes)==sample.sha256 and model.nodes.size()==int(sample.nodes),"Original actor content/physical order: "+sample.name)
		check(model.supermodel==sample.supermodel and float(model.animation_scale)==float(sample.animationScale),"Original supermodel/scale: "+sample.name)
		clip_checks(model.animations,sample.clips,sample.name)
		var skins:=0
		for row in model.nodes:
			if row.has("skin"): skins+=1
		check(skins==sample.skins.size(),"Original skin count: "+sample.name)
		for original in sample.skins:
			var skin: Dictionary=model.nodes[int(original.part)].get("skin",{})
			check(not skin.is_empty(),"Original skin physical binding: "+sample.name)
			if skin.is_empty(): continue
			check(skin.weights.size()==int(original.vertices)*4 and f32_digest(skin.weights)==original.weightsSha256,"Exact original skin weights: "+sample.name)
			check(i32_digest(skin.boneIndices)==original.bonesSha256 and i32_digest(skin.boneConstantSlots)==original.slotsSha256,"Exact original skin indices/slots: "+sample.name)
			check(f32_digest(flat(skin.qboneRefInv))==original.qboneSha256 and f32_digest(flat(skin.tboneRefInv))==original.tboneSha256,"Exact original inverse-bind references: "+sample.name)
			check(i32_digest(skin.boneIndexTable)==original.indexTableSha256 and i32_digest(skin.boneConstantIndices)==original.constantsSha256,"Exact original bone tables: "+sample.name)
		# Inheritance is a real native-worker operation, including source reads.
		jobs[service.request(sample.name,2002,"actor-model",sample.get("options",{}))]=sample
	var deadline:=Time.get_ticks_msec()+120000
	while observed.size()<jobs.size() and Time.get_ticks_msec()<deadline: await process_frame
	check(observed.size()==jobs.size(),"All original actor inheritance worker jobs complete")
	for id in jobs:
		if not observed.has(id): continue
		var sample: Dictionary=jobs[id]; var result: Dictionary=observed[id]
		check(str(result.error).is_empty(),"Native inherited actor preparation: "+sample.name+" "+str(result.error))
		if not str(result.error).is_empty(): continue
		check(result.thread!=OS.get_main_thread_id(),"Original actor/ancestor decoding runs on native worker: "+sample.name)
		clip_checks(result.value.animations,sample.inheritedClips,sample.name+" inherited")
	service.close(); service.queue_free(); await process_frame
	var sources: Dictionary={}
	for file_name in ["systems/native_data/actor_model.gd","systems/native_data/asset_service.gd","systems/native_data/binary_model.gd","systems/native_data/ascii_model.gd","tests/native_actor_data_test.gd"]: sources[file_name]=FileAccess.get_sha256("res://"+file_name)
	var result:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"samples":fixture.samples.size(),"scope":"Original actor animation/skin/supermodel decoding; runtime character assembly still pending","sourceSha256":sources}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
