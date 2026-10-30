extends SceneTree
const BinaryModel=preload("res://systems/native_data/binary_model.gd")
const AsciiModel=preload("res://systems/native_data/ascii_model.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Emitter=preload("res://systems/native_data/emitter_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Template=preload("res://systems/native_render/model_template.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func properties(actual: Dictionary,expected: Dictionary,label: String) -> void:
	for name in expected:
		var present:=actual.has(name); check(present,label+" retains "+str(name))
		if not present: continue
		var a: Variant=actual[name]; var b: Variant=expected[name]
		if b is Array: check(PackedFloat32Array(a)==PackedFloat32Array(b),label+" vector matches original source: "+str(name))
		elif b is float or b is int: check(PackedFloat32Array([a])==PackedFloat32Array([b]),label+" number matches original source: "+str(name))
		else: check(a==b,label+" string matches original source: "+str(name))
func clips(actual: Array,expected: Array,label: String) -> void:
	check(actual.size()==expected.size(),label+" clip count")
	for index in mini(actual.size(),expected.size()):
		var clip: Dictionary=actual[index]; var original: Dictionary=expected[index]
		check(clip.name==original.name and PackedFloat32Array([clip.length,clip.transition])==PackedFloat32Array([original.length,original.transition]),label+" clip identity/clocks")
		check(JSON.stringify(clip.events)==JSON.stringify(original.events),label+" original events")
		check(clip.emitter_tracks.size()==original.tracks.size(),label+" emitter channel count")
		for track_index in mini(clip.emitter_tracks.size(),original.tracks.size()):
			var track: Dictionary=clip.emitter_tracks[track_index]; var source: Dictionary=original.tracks[track_index]; var values:=PackedFloat32Array()
			for frame in track.frames:
				values.append(frame.time); values.append_array(PackedFloat32Array(frame.value))
				if frame.has("in"): values.append_array(PackedFloat32Array(frame["in"])); values.append_array(PackedFloat32Array(frame["out"]))
			check(track.node==source.node and track.property==source.property and track.interpolation==source.interpolation and track.frames.size()==int(source.frames) and Cache.digest(values.to_byte_array())==source.sha256,label+" exact emitter frames/Bezier handles: "+str(source.property))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var folder:=str(fixture.folder)
	for sample in fixture.staticSamples:
		var bytes:=FileAccess.get_file_as_bytes(folder.path_join(sample.name)); var parser:=BinaryModel.new(); var model:=parser.parse(bytes)
		check(parser.failure.is_empty() and model.nodes.size()==1 and model.nodes[0].features.has("emitter"),"Authored binary emitter parses")
		if model.is_empty(): continue
		check(Cache.digest(bytes)==sample.sha256,"Authored binary identity retained")
		properties(model.nodes[0].emitter,sample.expected,"Binary "+str(sample.name))
		var actual: Dictionary=model.nodes[0].emitter; var header: Dictionary=sample.originalHeader
		check(PackedFloat32Array([actual.deadspace,actual.blastradius,actual.blastlength])==PackedFloat32Array(header.floats),"Header agrees with stored original binary reader floats")
		check([int(actual.xgrid),int(actual.ygrid),int(actual.spawntype),int(actual.twosidedtex),int(actual.loop),int(actual.flags)]==header.ints.map(func(value):return int(value)&0xffffffff),"Header agrees with stored original binary reader integer/flag bit patterns")
		check([actual.update,actual.render,actual.blend,actual.texture,actual.chunkname]==header.strings and int(actual.renderorder)==int(header.order),"Header agrees with stored original binary reader strings/order")
		for relocation in sample.relocations: check(Emitter.runtime_controller(int(relocation.disk))==int(relocation.runtime),"Controller relocation agrees with original dispatcher")
		check(float(model.nodes[0].alpha)==1 and actual.fps==12,"Emitter FPS controller never becomes mesh opacity")
	var actor:=Actor.new(); var dense:=actor.parse(FileAccess.get_file_as_bytes(folder.path_join(fixture.dense.name)))
	check(actor.failure.is_empty(),"All binary emitter channels parse")
	if not dense.is_empty(): properties(dense.nodes[0].emitter,fixture.dense.expected,"All channels"); clips(dense.animations,fixture.dense.clips,"Binary animation")
	var ascii:=actor.parse(FileAccess.get_file_as_bytes(folder.path_join(fixture.ascii.name)))
	check(actor.failure.is_empty(),"Original ASCII emitter properties/animation parse")
	if not ascii.is_empty():
		properties(ascii.nodes[1].emitter,fixture.ascii.expected,"ASCII"); clips(ascii.animations,fixture.ascii.clips,"ASCII animation")
		var rig:=actor.rig_asset(ascii)
		check(rig.clips[0].emitterTracks.size()==3 and rig.clips[0].emitterTracks.all(func(row):return row.part==1),"Native rig retains emitter channels with physical part ownership")
		check(rig.clips[0].tracks.is_empty(),"Emitter numbers never become transform/scale tracks")
	var malformed:=FileAccess.get_file_as_bytes(folder.path_join("header0.mdl")); malformed.encode_u32(4,400); malformed.encode_u32(244+88,0); malformed.encode_u32(244+100,0); var bad:=BinaryModel.new()
	check(bad.parse(malformed).is_empty() and not bad.failure.is_empty(),"Truncated original emitter extension is rejected")
	var source:=AsciiModel.new()
	check(source.parse("newmodel bad\nbeginmodelgeom bad\nnode emitter bad\nbirthrate nope\nendnode\nendmodelgeom bad\n").is_empty() and not source.failure.is_empty(),"Malformed original emitter number is rejected")
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Native authored emitter resource directory mounts")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog)
	var delivered: Dictionary={}; assets.completed.connect(func(id: int,result: Dictionary):delivered[id]=result)
	var requests: Array=[]
	for colors in [[0,1,2,3,4,5,6,7,8,9],[9,8,7,6,5,4,3,2,1,0]]: requests.append(assets.request("ascii",2002,"actor-model",{"palette_colors":colors}))
	requests.append(assets.request("ascii",2002,"static-model"))
	var deadline:=Time.get_ticks_msec()+10000
	while delivered.size()<requests.size() and Time.get_ticks_msec()<deadline: await process_frame
	check(delivered.size()==requests.size(),"Native actor/static emitter worker jobs finish")
	for id in requests:
		var result: Dictionary=delivered.get(id,{})
		check(not result.is_empty() and str(result.get("error","unfinished")).is_empty(),"Native emitter worker prepares model/texture")
		if not result.has("emitter_textures"): continue
		check(int(result.thread)!=OS.get_main_thread_id(),"Emitter model/texture preparation is native worker work")
		var raster: Dictionary=result.emitter_textures.get(fixture.texture.name,{})
		check(raster.get("sha256")==fixture.texture.sha256 and Cache.digest(raster.value.mips[0].data)==fixture.texture.pixelsSha256,"Original emitter texture and RGBA survive color options")
		check(result.value.rig_asset.clips[0].emitterTracks.size()==3,"Prepared rig keeps original emitter channels")
	var missing_id:=assets.request("missing",2002,"static-model"); var broken_id:=assets.request("broken",2002,"static-model")
	deadline=Time.get_ticks_msec()+10000
	while (not delivered.has(missing_id) or not delivered.has(broken_id)) and Time.get_ticks_msec()<deadline: await process_frame
	var missing_result: Dictionary=delivered.get(missing_id,{})
	check(str(missing_result.get("error","unfinished")).is_empty() and missing_result.get("emitter_textures",{}).get("absent_bitmap",{"not_missing":true}).is_empty(),"Absent emitter bitmap does not reject the original model or invent a raster")
	check(missing_result.get("dependencies",[]).any(func(row):return row.get("role")=="emitter" and row.get("missing",false) and row.name=="absent_bitmap"),"Absent emitter dependency is explicitly reported")
	check(delivered.has(broken_id) and not str(delivered[broken_id].error).is_empty(),"Present corrupt emitter raster is not silently substituted")
	assets.close(); assets.queue_free(); await process_frame
	var source_bundle:={"sha256":"1".repeat(64),"animation_sources":[{"name":"parent","sha256":"2".repeat(64)}]}; var pool_options:={"unshaded":false,"texture_filter":0}
	var source_key:=Template.identity(source_bundle,pool_options); source_bundle.animation_sources[0].sha256="3".repeat(64)
	check(Template.identity(source_bundle,pool_options)!=source_key,"Changed inherited animation data invalidates immutable model template identity")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"originalReaderBinarySha256":fixture.originalBinarySha256,"native_only":true,"network_connections":0,"scope":fixture.scope}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
