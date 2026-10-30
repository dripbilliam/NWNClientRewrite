extends SceneTree
# Original resources stay in the installed archives. Only identities/counts
# enter this report; no model, texture or animation payload is exported.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Model=preload("res://systems/native_data/binary_model.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL: ",reason)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original native install mounts")
	var names: Array=catalog.resource_names(2002); names.sort(); var chosen: Array=[]; var tested:=0; var errors: Array=[]
	for name in names:
		var matches:=false
		for token in ["brazier","torch","portal","fount"]:
			if token in str(name).to_lower(): matches=true
		if not matches: continue
		var bytes:=catalog.get_resource(str(name),2002); var model: Dictionary={}; var error:=""
		if not catalog.failure.is_empty(): errors.append(catalog.failure); continue
		if bytes.size()>=4 and bytes.decode_u32(0)==0:
			var parser:=Model.new(); model=parser.parse(bytes); error=parser.failure
		else:
			var parser:=Ascii.new(); model=parser.parse(Binary.new(bytes).text(0,bytes.size())); error=parser.failure
		tested+=1
		if not error.is_empty(): errors.append({"name":name,"error":error}); continue
		var emitters: Array=model.nodes.filter(func(row):return row.has("emitter"))
		if emitters.is_empty(): continue
		chosen.append({"name":name,"sha256":Cache.digest(bytes),"nodes":model.nodes.size(),"emitters":emitters.size(),"textures":emitters.map(func(row):return str(row.emitter.get("texture",""))).filter(func(value):return value.to_lower() not in ["","null"])})
		if chosen.size()>=4 or tested>=64: break
	check(chosen.size()>=2,"At least two original emitter-bearing models are discovered natively")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog)
	var jobs: Dictionary={}; var delivered: Dictionary={}
	assets.completed.connect(func(id: int,result: Dictionary):delivered[id]=result)
	for sample in chosen:
		for decoder in ["actor-model","static-model"]:
			var selected: Dictionary=sample.duplicate(); selected.decoder=decoder
			jobs[assets.request(sample.name,2002,decoder)]=selected
	var deadline:=Time.get_ticks_msec()+30000
	while delivered.size()<jobs.size() and Time.get_ticks_msec()<deadline: await process_frame
	check(delivered.size()==jobs.size(),"Original emitter-bearing model jobs finish")
	var observations: Array=[]
	for id in jobs:
		var sample: Dictionary=jobs[id]; var result: Dictionary=delivered.get(id,{})
		var error:=str(result.get("error","unfinished")); check(error.is_empty(),"Original emitter model and texture preparation: "+str(sample.name)+": "+error)
		if not error.is_empty(): observations.append({"name":sample.name,"error":error}); continue
		check(int(result.thread)!=OS.get_main_thread_id(),"Original emitter preparation remains on worker")
		check(result.sha256==sample.sha256 and result.value.nodes.filter(func(row):return row.has("emitter")).size()==int(sample.emitters),"Original emitter identity/physical node count")
		for texture in sample.textures: check(result.emitter_textures.has(str(texture).to_lower()),"Original emitter bitmap prepares: "+str(texture))
		var channels:=0
		for clip in result.value.rig_asset.clips: channels+=clip.get("emitterTracks",[]).size()
		observations.append({"name":sample.name,"decoder":sample.decoder,"sha256":sample.sha256,"nodes":sample.nodes,"emitters":sample.emitters,"emitter_textures":result.emitter_textures.keys(),"emitter_channels":channels,"worker_ms":result.worker_ms})
	assets.close(); assets.queue_free(); await process_frame
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scanned_models":tested,"scan_errors":errors,"native_only":true,"network_connections":0,"scope":"Native original installed emitter fields/channels/textures; simulation and GPU particle rendering remain pending"}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n"); file.close(); print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
