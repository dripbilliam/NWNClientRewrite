extends "res://tests/native_particle_schedule_test.gd"
const Actor=preload("res://systems/native_data/actor_model.gd")
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var authored: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var bytes:=FileAccess.get_file_as_bytes(str(authored.folder).path_join("channels.mdl")); bytes.encode_float(4212+112,-0.166666999459267)
	var parser:=Actor.new(); var model:=parser.parse(bytes)
	check(parser.failure.is_empty() and not model.is_empty(),"Negative-duration header does not discard valid model data")
	if not model.is_empty():
		check(model.animations.size()==1 and model.animations[0].get("deferred_invalid_duration",false) and M.f(model.animations[0].length)==M.f(-0.166666999459267),"Literal negative header and deferred source are retained")
		var rig:=parser.rig_asset(model)
		check(rig.clips.is_empty() and rig.unsupported.size()==1,"Unavailable duration never becomes clamped fake playback")
		check(model.nodes.size()==1 and model.nodes[0].has("emitter"),"Original physical model and emitter settings survive unavailable clip")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-capture-input-v1.json")); var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture.input)); var catalog:=Capture.new()
	check(FileAccess.get_sha256(fixture.input)==fixture.sha256 and catalog.mount(data.capture,data.context,data.supplements),"Original captured resource context verifies")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); var delivered: Dictionary={}; assets.completed.connect(func(id,result):delivered[id]=result)
	var id:=assets.request("plc_s03a",2002,"static-model"); var deadline:=Time.get_ticks_msec()+10000
	while not delivered.has(id) and Time.get_ticks_msec()<deadline: await process_frame
	var result: Dictionary=delivered.get(id,{}); check(str(result.get("error","unfinished")).is_empty(),"Actual captured stock placeable prepares natively despite unavailable damage clip")
	if result.has("value"):
		var clips: Array=result.value.rig_asset.clips.map(func(clip):return clip.name)
		check(clips==["die","dead","default"] and result.value.rig_asset.unsupported.size()==1,"Other original placeable clips remain available, negative damage remains explicit")
		check(result.value.nodes.any(func(node):return not node.mesh.get("indices",[]).is_empty()),"Actual original placeable geometry survives")
	assets.close(); assets.queue_free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Negative original binary clip header retained as unavailable playback; geometry/other clips/emitter prep preserved. Negative-duration playback semantics remain unimplemented."},"\t")); file.close()
	print("NATIVE_STATIC_CLIP ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
