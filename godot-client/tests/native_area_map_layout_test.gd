extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Plan=preload("res://systems/native_data/area_map_layout.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-area-map-policy-observations-v1.json"); var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.frames.size()==576 and oracle.coordinates.size()==108,"Map observations pin the original binary and complete authored frame/coordinate corpus")
	for row in oracle.frames:
		var actual:=Plan.frame(int(row.width),int(row.height),Plan.PIXELS.find(int(row.zoom)),Vector2i(row.caps[0],row.caps[1])); var expected: Dictionary=row.output
		check(actual.error.is_empty() and actual.resource==expected.resource and actual.columns==int(expected.columns) and actual.rows==int(expected.rows),"Frame sizing matches unchanged original instructions: "+JSON.stringify([row.width,row.height,row.zoom,row.caps]))
	for row in oracle.coordinates:
		var actual:=Plan.local_to_world(int(row.width),int(row.height),int(row.zoom),row.local)
		var expected: Array=row.world.map(func(value):return Plan.M.f(float(value)))
		check(actual==expected,"Native map coordinate grouping matches original float32 results: "+JSON.stringify([row.width,row.height,row.zoom,row.local]))
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Installed original map models mount read-only")
	var source: Dictionary={}; var hashes: Dictionary={}; var names: Array=["pnl_mapgen_4x2","pnl_mapgen_10x10","pnl_mapgen_21x24"]+Plan.TOOLS.values()
	for name in names:
		var parser:=Actor.new(); var bytes: PackedByteArray=catalog.get_resource(name,2002); source[name]=parser.parse(bytes); hashes[name]=Cache.digest(bytes); check(parser.failure.is_empty(),"Original map attachment model decodes: "+name)
	for entry in [[1,1,0,Vector2(74,61),Vector2(64,32)],[10,10,1,Vector2(170,189),Vector2(160,160)],[64,64,2,Vector2(346,413),Vector2(336,384)]]:
		var definition:=Plan.frame(entry[0],entry[1],entry[2],Vector2i(21,24)); var actual:=Plan.parse(definition,source)
		check(actual.error.is_empty() and actual.size.distance_to(entry[3])<0.001 and actual.viewport.size.distance_to(entry[4])<0.001,"Original dynamic map frame and viewport retain actual source bounds: "+definition.resource)
		if actual.error.is_empty():
			check(actual.controls.upbutton.rect.position.distance_to(Vector2(19,2))<0.001 and actual.controls.downbutton.rect.position.distance_to(Vector2(36,2))<0.001 and actual.controls.pinbutton.rect.position.distance_to(Vector2(2,2))<0.001,"Generated map buttons use source attachment positions independent of generic containers")
			check(actual.controls.xbutton.rect.end.x<=actual.size.x+0.001 and actual.controls.upbutton.tooltip==0x10808 and actual.controls.downbutton.tooltip==0x10809 and actual.controls.pinbutton.tooltip==0x10807,"Original close bounds and three tool help references are preserved")
	check(Plan.frame(10,10,0,Vector2i(21,24)).zoom_out==false and Plan.frame(10,10,2,Vector2i(21,24)).zoom_in==false and Plan.PIXELS==[8,16,32],"Exactly three original zoom levels expose correct endpoint availability")
	check(not Plan.frame(0,10,0,Vector2i(21,24)).error.is_empty() and not Plan.frame(10,10,3,Vector2i(21,24)).error.is_empty() and Plan.local_to_world(1,1,0,[0,0,0]).is_empty(),"Unsupported map dimensions/zoom never silently invent source geometry")
	check(not Plan.parse(Plan.frame(10,10,1,Vector2i(21,24)),{}).error.is_empty(),"Missing server-selected source artwork stays an explicit error")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(path),"resourceSha256":hashes,"fullMapParity":false,"visibleMapNativeFrameAccepted":false,"publicConnections":0,"scope":"Native original dynamic area-map frame/zoom/attachment and unchanged coordinate instruction policy only. Actual UI, role pin routes, viewport cap updates, input and server outcomes remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
