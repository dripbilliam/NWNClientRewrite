extends "res://tests/native_drive_preview_lazy_fixture_test.gd"
# Private staged owner only. Reuse the independent legacy collision oracle and
# retained query transcripts with native floor AND obstacle bindings enabled.
var numeric_ledgers: Array=[]
var numeric_provenance: Dictionary={}
func footprint(width: float=1.0)->Dictionary:
	var value:=super.footprint(width);var original: Array=value.faces.duplicate(true)
	for index in 31:value.faces.append_array(original)
	return value
func make_world(indexed: bool=true)->Dictionary:
	var setup:=super.make_world(indexed)
	if not indexed:return setup
	var collision=setup.collision
	if not collision.has_method("prepare_numeric_payloads"):
		check(false,"Private reviewed owner overlay required");return setup
	collision.numeric_batch.configure()
	check(collision.numeric_batch.enabled,"Actual numeric owner capability enabled")
	numeric_provenance=collision.numeric_batch.provenance.duplicate(true)
	numeric_ledgers.append(collision.numeric_batch.counters)
	var mesh: Dictionary=setup.world.surface.meshes.floor
	var original: Dictionary=mesh.duplicate(true)
	for index in 31:
		for key in ["faces","materials","normals","constants"]:mesh[key].append_array(original[key])
	return setup
func dense_and_retirement()->void:
	var setup:=fixture();var world=setup.world;var collision=setup.collision
	var mesh: Dictionary=world.surface.meshes.floor;var original: Dictionary=mesh.duplicate(true)
	for index in 17:
		for key in ["faces","materials","normals","constants"]:mesh[key].append_array(original[key])
	check(mesh.faces.size()==1152,"Dense original floor has1152 ordered faces")
	var legacy=legacy_for(world)
	for key in collision.models:legacy.models[key]=collision.models[key]
	same_lines(collision,legacy,[[Vector3(1,7,0),Vector3(4,7,0)],[Vector3(2,1.5,0),Vector3(6,1.5,0)],[Vector3(8,1.5,0),Vector3(11,1.5,0)]],"Dense native floor and64-face PWK/DWK")
	var adapter=collision.numeric_batch
	check(adapter.counters.bindings>0 and adapter.counters.queries>0 and adapter.payload_bytes>0,"Actual owner uses bound native numeric payloads")
	check(adapter.entries.has("tile:0") and adapter.entries["tile:0"].faces==1152,"Native owner binds the full ordered1152-face payload")
	# The explicit adoption hook must bind already prepared caches too.
	adapter.clear();collision.prepare_numeric_payloads()
	check(adapter.entries.has("tile:0") and adapter.entries.has("object:2"),"Prepared geometry adoption explicitly binds existing tile and obstacle caches")
	world.receive_delta([], [2],1)
	check(not adapter.entries.has("object:2"),"Delta removal retires numeric obstacle before source eviction")
	var held: Callable=collision.query_preview(1,Vector3(1,7,0),Vector3(2,7,0),Vector3(1,7,0))
	check(held.call(Vector3(1,7,0),Vector3(2,7,0)),"Live numeric floor query succeeds before detach")
	var payload: Dictionary=collision.detach_prepared_data()
	check(not payload.tiles.is_empty() and adapter.entries.is_empty() and adapter.payload_bytes==0,"Detach retires all native bindings before transferring prepared script geometry")
	check(not held.call(Vector3(1,7,0),Vector3(2,7,0)),"Held query cannot act against detached tables")
	world.free()
func run()->void:
	geometry_and_paths();corner_and_radius();invalidations();pending_and_height();await collection_once();dense_and_retirement()
	var queries:=0;var bindings:=0
	for counters in numeric_ledgers:queries+=int(counters.queries);bindings+=int(counters.bindings)
	check(queries>0 and bindings>0,"Whole movement oracle actually executed native queries")
	var report_path:="";var expected_module:="";var expected_digest:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.substr(9)
		if arg.begins_with("--expect-module="):expected_module=arg.substr(16)
		if arg.begins_with("--expect-module-sha256="):expected_digest=arg.substr(23)
	check(not expected_module.is_empty() and expected_digest.length()==64 and numeric_provenance.get("sha256")==expected_digest and str(numeric_provenance.get("module_path","")).replace("\\","/").to_lower()==expected_module.replace("\\","/").to_lower(),"Whole-query oracle loaded the exact pinned private DLL")
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"queries":queries,"bindings":bindings,"provenance":numeric_provenance,"native_present":true,"scope":"Private native indexed owner: exact clear/path transcripts, independent legacy oracle, dense1152 floors,64-face obstacles, frame/source/lifetime fences, removal and prepared-data detach. No performance, rendering, FPS or server acceptance."}
	if not report_path.is_empty() and not FileAccess.file_exists(report_path):
		var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
