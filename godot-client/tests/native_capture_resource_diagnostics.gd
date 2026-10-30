extends SceneTree
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Model=preload("res://systems/native_data/binary_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-capture-input-v1.json")); var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture.input)); var catalog:=Capture.new(); var installed:=Catalog.new()
	if FileAccess.get_sha256(fixture.input)!=fixture.sha256 or not catalog.mount(data.capture,data.context,data.supplements) or not installed.mount_install(args.install): quit(1); return
	var report:={"scope":"Read-only resource identities/counts and invalid animation metadata; no asset payload copied","inputSha256":fixture.sha256,"models":[],"textures":[]}
	for name in ["plc_s03a","it_mscmedp_008"]:
		var bytes:=catalog.get_resource(name,2002); var parser:=Model.new(); var model:=parser.parse(bytes); var clips: Array=[]; var reader:=Binary.new(bytes)
		if bytes.size()>200 and reader.u32(0)==0:
			var at:=12+reader.u32(132); var count:=reader.u32(136)
			if count<1000 and reader.contains(at,count*4):
				for index in count:
					var clip:=12+reader.u32(at+index*4)
					if reader.contains(clip,196): clips.append({"name":reader.text(clip+8,64,true),"length":reader.f32(clip+112),"transition":reader.f32(clip+116)})
		var textures: Array=[]
		for node in model.get("nodes",[]):
			for texture in node.mesh.get("textures",[]):
				if not textures.has(texture): textures.append(texture)
		report.models.append({"name":name,"sha256":Cache.digest(bytes),"base_parse_failure":parser.failure,"clips":clips,"textures":textures})
	for name in ["ait_mscmedp_008","it_mscmedp_008"]:
		var capture_types: Array=[]; var installed_types: Array=[]
		for type in [3,6,2033,2059,2073]:
			if catalog.has_resource(name,type): capture_types.append(type)
			if installed.has_resource(name,type): installed_types.append(type)
		report.textures.append({"name":name,"recorded_miss":catalog.recorded_texture_miss(name),"captured_types":capture_types,"installed_types":installed_types})
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); print(JSON.stringify(report)); quit()
