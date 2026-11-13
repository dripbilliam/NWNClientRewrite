extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
var received: Dictionary={}
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> bool:
	checks+=1
	if not value:failures.append(message)
	return value
func completed(id: int,value: Dictionary) -> void:received[id]=value
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Installed GUI resources mount read-only")
	var assets:=Assets.new();root.add_child(assets);assets.configure(catalog);assets.maximum_workers=2;assets.completed.connect(completed)
	var cases: Array=[]
	for icon in ["ir_cantrips","ir_level1","ir_level6","ir_level789"]:
		var location: Dictionary=catalog.raster_location(icon);check(not location.is_empty(),"Original replacement bitmap exists: "+icon)
		var id: int=assets.request("ctl_cg_btn_splvl",2002,"actor-model",{"texture_overrides":{"gui_replace01":icon},"relevant_tracks":true})
		var deadline:=Time.get_ticks_msec()+15000
		while not received.has(id) and Time.get_ticks_msec()<deadline:await process_frame
		if not check(received.has(id),"Native tab model+texture job completes: "+icon):continue
		var result: Dictionary=received[id];check(str(result.get("error","")).is_empty(),"Native tab resource bundle is available: "+str(result.get("error","")))
		if not str(result.get("error","")).is_empty():continue
		var layers: Array=[]
		for node in result.value.nodes:
			if not node.get("mesh",{}).is_empty():layers.append({"name":node.name,"render":node.mesh.get("render"),"textures":node.mesh.get("textures",[]),"alpha":node.mesh.get("alpha"),"orientation":node.get("orientation",[]),"position":node.get("position",[])})
		var clips: Array=result.value.get("rig_asset",{}).get("clips",[]).map(func(clip):return str(clip.name))
		var hashes: Dictionary={}
		for name in result.get("textures",{}):hashes[name]=result.textures[name].get("sha256","")
		var expected:=Cache.digest(catalog.get_resource(icon,int(location.type))) if not location.is_empty() else ""
		cases.append({"icon":icon,"layers":layers,"clips":clips,"textures":hashes,"expectedTextureSha256":expected,"rendered":false})
		check(result.get("textures",{}).has("gui_replace01") and hashes.get("gui_replace01")==expected,"Actual decoded replacement layer uses the requested bitmap bytes: "+icon)
	assets.close();assets.free();await process_frame;await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"Installed spell-level model animation/layer inventory and real native asset-service replacement texture bytes. No shader/raster pixels/UI input/server or original visual acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
