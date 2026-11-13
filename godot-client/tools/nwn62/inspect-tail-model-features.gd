extends SceneTree
# Read-only original-source classification for a selective template predicate.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Service=preload("res://systems/native_data/asset_service.gd")
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var install:=""
	for arg in OS.get_cmdline_user_args():if arg.begins_with("--install="):install=arg.substr(10)
	var catalog: RefCounted=Catalog.new()
	if not catalog.mount_install(install):print("CATALOG_FAILED "+catalog.failure);quit(1);return
	var service: Node=Service.new();root.add_child(service)
	for name in ["ttu01_w07_01","ttu01_v06_01","gi_scrl","ttu01_r28_01","ttu01_x05_01","ttu01_v05_01","ttu01_w06_01","ttu01_w05_01","ttu01_x07_01","ttu01_g02_01"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2002)
		if bytes.is_empty():rows.append({"model":name,"error":catalog.failure});continue
		var decoded: Dictionary=service.actor_data(catalog,name,bytes,"",[])
		if not str(decoded.get("error","")).is_empty():rows.append({"model":name,"error":decoded.error});continue
		var model: Dictionary=decoded.value;var features: Array=[]
		for part in model.nodes:
			features.append({"name":str(part.get("name","")),"parent":str(part.get("parent","")),"features":part.get("features",[]),"has_light":part.has("light"),"has_emitter":part.has("emitter"),"has_reference":part.has("reference"),"mesh_class":str(part.get("mesh",{}).get("type","")),"render":part.get("mesh",{}).get("render",false),"textures":part.get("mesh",{}).get("textures",[])})
		rows.append({"model":name,"source_bytes":bytes.size(),"classification":str(model.get("classification","")),"node_count":model.nodes.size(),"features":features})
	print("NWN62_FEATURES "+JSON.stringify(rows))
	service.queue_free();quit(0)
