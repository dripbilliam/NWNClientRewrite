extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const TARGET="Aligned_to_Particle_Dir"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var install:=""
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
		elif arg.begins_with("--report="): report=arg.substr(9)
	if install.is_empty() or report.is_empty() or FileAccess.file_exists(report): quit(2); return
	var catalog:=Catalog.new()
	if not catalog.mount_install(install): print("CATALOG_FAILURE ",catalog.failure); quit(1); return
	var names: Array=catalog.resource_names(2002); names.sort()
	var found: Array=[]; var scanned:=0; var parsed:=0; var emitters:=0; var failures:=0
	var started:=Time.get_ticks_msec()
	for name in names:
		if Time.get_ticks_msec()-started>=2040000: break # 34-minute scan bound.
		var bytes:=catalog.get_resource(str(name),2002); scanned+=1
		if bytes.is_empty() or not catalog.failure.is_empty(): failures+=1; continue
		var model: Dictionary={}
		if bytes.size()>=4 and bytes.decode_u32(0)==0:
			var parser:=Actor.new(); model=parser.parse(bytes)
		else:
			var parser:=Ascii.new(); model=parser.parse(Binary.new(bytes).text(0,bytes.size()))
		if model.is_empty(): failures+=1; continue
		parsed+=1
		for node: Dictionary in model.nodes:
			if not node.has("emitter"): continue
			emitters+=1
			if str(node.emitter.get("render",""))==TARGET:
				found.append({"model":str(name),"sha256":Cache.digest(bytes),"node":str(node.name),"update":str(node.emitter.get("update","")),"flags":int(node.emitter.get("flags",0)),"render":TARGET})
		if not found.is_empty(): break
		if scanned%24==0: await process_frame
		if scanned%2000==0: print("MODE_ALIGNED_SCAN ",scanned,"/",names.size()," parsed=",parsed," emitters=",emitters)
	var result:={"success":true,"requested":names.size(),"scanned":scanned,"parsed":parsed,"emitters":emitters,"failures":failures,"found":found,"elapsed_ms":Time.get_ticks_msec()-started,"complete":scanned==names.size(),"gpu_execution":false}
	var file:=FileAccess.open(report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close(); quit(0)
