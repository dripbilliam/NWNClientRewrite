extends SceneTree
# Read-only census of the first recorded original area and its captured MDL bytes.
const Definition=preload("res://systems/native_data/area_definition.gd")
const Service=preload("res://systems/native_data/asset_service.gd")
const ActorModel=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")

class CaptureCatalog extends RefCounted:
	var directory: String
	var resources: Dictionary
	var failure: String=""
	func get_resource(name: String, kind: int) -> PackedByteArray:
		var key:=name.to_lower()+":"+str(kind)
		if not resources.has(key):failure="Missing captured resource "+key;return PackedByteArray()
		var row: Dictionary=resources[key]
		var bytes:=FileAccess.get_file_as_bytes(directory.path_join("objects").path_join(str(row.sha256)))
		if bytes.size()!=int(row.bytes):failure="Captured source length mismatch "+key;return PackedByteArray()
		return bytes

func _initialize() -> void:call_deferred("run")
func run() -> void:
	var capture:=""
	var report:=""
	var target_area:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):capture=arg.substr(10)
		if arg.begins_with("--report="):report=arg.substr(9)
		if arg.begins_with("--area="):target_area=arg.substr(7).to_lower()
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(capture.path_join("catalog-1/manifest.json")))
	var catalog:=CaptureCatalog.new()
	catalog.directory=capture.path_join("catalog-1")
	catalog.resources=manifest.get("resources",{})
	var timeline:=FileAccess.open(capture.path_join("timeline.jsonl"),FileAccess.READ)
	var area: Dictionary={}
	while timeline!=null and not timeline.eof_reached():
		var line:=timeline.get_line()
		if not line.contains("raw-world-begin"):continue
		var event: Dictionary=JSON.parse_string(line)
		var candidate: Dictionary=event.get("value",{}).get("data",{}).get("area",{})
		if not candidate.is_empty() and (target_area.is_empty() or str(candidate.get("resRef","")).to_lower()==target_area):area=candidate;break
	var parser:=Definition.new()
	var scene: Dictionary=parser.load_network(catalog,area) if not area.is_empty() else {}
	var service:=Service.new()
	var rows: Array=[]
	var failures: Array=[]
	var part_count:=0
	var nonzero_count:=0
	var nonzero_placements:=0
	for name in scene.get("models",{}):
		var bytes: PackedByteArray=catalog.get_resource(str(name),2002)
		if bytes.is_empty():failures.append(catalog.failure);continue
		var decoded: Dictionary=service.decode_uncached(bytes,2002,ActorModel.SOURCE_DECODER,"")
		if not str(decoded.get("error","")).is_empty():failures.append(str(name)+": "+str(decoded.error));continue
		var parts: Array=[]
		var total:=0
		for part in decoded.value.nodes:
			var mesh: Dictionary=part.get("mesh",{})
			if not bool(mesh.get("native_tilefade_available",false)):continue
			total+=1
			if int(mesh.get("native_tilefade",0))!=0:parts.append({"name":part.get("name",""),"tilefade":mesh.native_tilefade,"source":mesh.get("native_tilefade_source",""),"vertices":mesh.get("vertices",PackedFloat32Array()).size()/3,"indices":mesh.get("indices",PackedInt32Array()).size(),"render":mesh.get("render",false)})
		part_count+=total
		nonzero_count+=parts.size()
		if not parts.is_empty():nonzero_placements+=scene.models[name].size()
		rows.append({"model":name,"source_sha256":Cache.digest(bytes),"placements":scene.models[name].size(),"tile_indices":scene.models[name].duplicate(),"physical_mesh_parts":total,"nonzero_parts":parts})
	service.free()
	var result: Dictionary={"area":area.get("resRef",""),"area_id":area.get("id",0),"tileset":area.get("tileset",""),"tiles":scene.get("tiles",[]).size(),"unique_models":scene.get("models",{}).size(),"model_rows":rows,"physical_mesh_parts":part_count,"nonzero_tilefade_parts":nonzero_count,"placements_with_nonzero_tilefade_model":nonzero_placements,"failures":failures,"success":not scene.is_empty() and failures.is_empty()}
	if not report.is_empty():
		var output:=FileAccess.open(report,FileAccess.WRITE)
		if output!=null:output.store_string(JSON.stringify(result,"  "));output.close()
	print("NWN80_TILEFADE_CENSUS "+JSON.stringify({"area":result.area,"tiles":result.tiles,"models":result.unique_models,"nonzero_parts":nonzero_count,"placements":nonzero_placements,"failures":failures.size()}))
	quit(0 if result.success else 1)
