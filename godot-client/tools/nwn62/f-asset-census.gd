extends SceneTree
# Read-only census for the original installed model sources seen in saved pack peaks.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Service=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const NAMES=["ttu01_a02_03","ttu01_h17_01","ttu01_v06_01","ttu01_w07_01","ttu01_l07_02","gi_scrl","plc_fungus1","px2_d06","plc_cndl03","ttu01_v07_01"]

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var install:=""
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="):install=arg.substr(10)
		if arg.begins_with("--report="):report=arg.substr(9)
	var catalog: RefCounted=Catalog.new()
	if not catalog.mount_install(install):
		push_error("catalog: "+catalog.failure);quit(1);return
	var service: Node=Service.new()
	root.add_child(service)
	var rows: Array=[]
	var failed: Array=[]
	for name in NAMES:
		var bytes: PackedByteArray=catalog.get_resource(name,2002)
		if bytes.is_empty():failed.append(name+": missing source "+catalog.failure);continue
		var decoded: Dictionary=service.actor_data(catalog,name,bytes,"",[])
		if not str(decoded.get("error","")).is_empty():failed.append(name+": decode "+str(decoded.error));continue
		var features: Dictionary={}
		var textures: Dictionary={}
		for part in decoded.value.nodes:
			for feature in part.get("features",[]):features[feature]=int(features.get(feature,0))+1
			for texture in part.get("mesh",{}).get("textures",[]):textures[str(texture).to_lower()]=true
		rows.append({"model":name,"source_sha256":Cache.digest(bytes),"source_bytes":bytes.size(),"parts":decoded.value.nodes.size(),"features":features,"texture_count":textures.size()})
	service.queue_free()
	var value: Dictionary={"rows":rows,"failed":failed,"success":failed.is_empty()}
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(value,"  "));file.close()
	print("NWN62_F_ASSET_CENSUS "+JSON.stringify(value))
	quit(0 if failed.is_empty() else 1)
