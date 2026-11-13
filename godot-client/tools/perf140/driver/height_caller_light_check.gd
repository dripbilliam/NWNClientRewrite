extends SceneTree
# No world, renderer, native build, server or FPS measurement. Mount only the
# two selected GDS source overrides in this process; never edit their parent.
var checks:=0
var failures: Array=[]
var arguments: Dictionary={}
var output: Dictionary={"scope":"Selected GDS caller/cache parse and script/unsupported-fallback smoke checks only; new native class is not built or tested","native_class_tested":false,"worlds_loaded":0,"server_connections":0,"fps_measured":false}
func check(value: bool,reason: String)->void:
	checks+=1
	if not value:failures.append(reason)
func _initialize()->void:run.call_deferred()
func finish()->void:
	output.success=failures.is_empty();output.checks=checks;output.failures=failures
	var file:=FileAccess.open(str(arguments.report),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(output,"\t")+"\n");file.close()
	print(JSON.stringify({"success":output.success,"checks":checks,"failures":failures,"fps_measured":false}));quit(0 if output.success else 1)
func contains_object(value: Variant)->bool:
	if value is Object:return true
	if value is Dictionary:
		for item in value.values():
			if contains_object(item):return true
	elif value is Array:
		for item in value:
			if contains_object(item):return true
	return false
func packing_checks(cache,mesh: Dictionary,table: Dictionary)->void:
	var before:=checks
	var data: Dictionary=cache._pack(mesh,table)
	check(data.get("faces") is PackedFloat64Array and data.get("walk") is PackedByteArray,"Native input uses the declared packed ABI types")
	check(data.faces==PackedFloat64Array([0,0,10,0,10,10,0,0,1,-2,0,0,10,10,0,10,0,0,1,-2]),"Physical face order, XY, plane and constant stream are exact")
	check(data.walk==PackedByteArray([1,1]),"Original material classification encoded once per physical face")
	var changed:=mesh.duplicate(true);changed.vertices[0][0]=3.125
	check(data.faces[0]==0.0,"Packed numeric input is detached from later source edits")
	var reference_surface: Variant=load("res://systems/native_data/tile_surface.gd")
	for value in [true,false,null,"-1.5","0","1","****",2,-2.25]:
		var materials:={"orderedRows":[{"Walk":value}],"defaultValue":"0"}
		var encoded: Dictionary=cache._pack(mesh,materials)
		var expected:=1 if reference_surface.walkable(materials,0) else 0
		check(not encoded.is_empty() and encoded.walk==PackedByteArray([expected,expected]),"Packed mask retains canonical custom material conversion: "+str(value))
	var unusual:=mesh.duplicate(true);unusual.materials=[-1,17]
	check(cache._pack(unusual,{"orderedRows":[],"defaultValue":"2"}).walk==PackedByteArray([1,1]),"Missing material rows retain table default")
	var negative_bytes:=PackedByteArray([0,0,0,0,0,0,0,128])
	var negative: float=negative_bytes.decode_double(0)
	var signed:=mesh.duplicate(true);var vertex: Array=[];vertex.append(negative);vertex.append(0.0);vertex.append(2.0);signed.vertices[0]=vertex
	var input_bits:=PackedByteArray();input_bits.resize(8);input_bits.encode_double(0,signed.vertices[0][0])
	var packed_bits: PackedByteArray=cache._pack(signed,table).faces.to_byte_array().slice(0,8)
	output.signed_zero={"input":input_bits.hex_encode(),"packed":packed_bits.hex_encode()}
	check(input_bits==negative_bytes,"Signed-zero source uses decoded bits rather than a potentially coalesced literal")
	check(packed_bits==input_bits,"Packing preserves actual negative zero bits")
	var huge:=1<<60
	var integer_source:=mesh.duplicate(true);integer_source.vertices[0][0]=huge+1
	check(cache._pack(integer_source,table).is_empty(),"Integer-authored XY conservatively uses original arithmetic")
	check(reference_surface.edge([huge+1,0.0],[huge+2,1.0],float(huge),0.5)==0.5,"Original int64 subtraction can retain a unit edge lost by double packing")
	var malformed:=mesh.duplicate(true);malformed.faces[0][0]=-1
	check(cache._pack(malformed,table).is_empty(),"Invalid source index is unavailable")
	malformed=mesh.duplicate(true);malformed.normals.pop_back()
	check(cache._pack(malformed,table).is_empty(),"Incomplete plane data is unavailable")
	malformed=mesh.duplicate(true);malformed.constants[0]=INF
	check(cache._pack(malformed,table).is_empty(),"Nonfinite source cannot become a valid zero")
	var nan_table:={"orderedRows":[{"Walk":"nan"}],"defaultValue":"0"}
	var nan_expected:=1 if reference_surface.walkable(nan_table,0) else 0
	var nan_packed: Dictionary=cache._pack(mesh,nan_table)
	output.nan_material={"original_walkable":nan_expected,"valid_float_token":"nan".is_valid_float()}
	check(not nan_packed.is_empty() and nan_packed.walk==PackedByteArray([nan_expected,nan_expected]),"Unrecognized nan token preserves original material classification")
	var empty:={"vertices":[],"faces":[],"normals":[],"constants":[],"materials":[]}
	var empty_data: Dictionary=cache._pack(empty,table)
	check(not empty_data.is_empty() and empty_data.faces.is_empty() and empty_data.walk.is_empty(),"Valid empty geometry remains distinct from unsupported data")
	output.packing_checks=checks-before
func run()->void:
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:arguments[pair[0]]=pair[1]
	if not arguments.has("report") or not arguments.has("overlay") or FileAccess.file_exists(str(arguments.report)):quit(2);return
	check(DisplayServer.get_name()=="headless","Must remain headless")
	var manifest_file:=str(arguments.overlay)
	check(FileAccess.get_sha256(manifest_file)=="a89f2889d7288c3225d9fff963bc6d5c9358be56e38044567f158663ba21d5a1","Frozen height source overlay identity")
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_file))
	if not manifest is Dictionary or not failures.is_empty():finish();return
	check(manifest.parent.sha256=="7a4a6a2728886b5d0de135e13e66ae829426414cac70289231fafd1974a7cb74","Frozen clear parent identity")
	check(ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")==str(manifest.parent.project).replace("\\","/").simplify_path().trim_suffix("/"),"Use the pinned existing parent project")
	var caller:="systems/native_render/terrain_surface.gd"
	var cache:="systems/native_render/terrain_height_cache.gd"
	check(not ResourceLoader.has_cached("res://"+caller) and not ResourceLoader.has_cached("res://"+cache),"No old caller/cache may be loaded before source overlay")
	if not failures.is_empty():finish();return
	var parent_caller:=FileAccess.get_sha256("res://"+caller)
	var pack_path:=str(arguments.report).trim_suffix(".json")+".pck"
	check(not FileAccess.file_exists(pack_path),"Preserve existing small pack")
	var packer:=PCKPacker.new()
	check(packer.pck_start(pack_path)==OK,"Start a two-script process-only overlay")
	var packed:=0
	for row: Dictionary in manifest.outputs:
		if str(row.relative) not in [caller,cache]:continue
		var source:=manifest_file.get_base_dir().path_join("overlay").path_join(row.relative)
		check(FileAccess.get_sha256(source)==row.sha256,"Exact selected source: "+str(row.relative))
		check(packer.add_file("res://"+str(row.relative),source)==OK,"Pack selected source")
		packed+=1
	check(packed==2 and packer.flush()==OK,"Exactly two GDS overrides packed")
	if not failures.is_empty():finish();return
	check(ProjectSettings.load_resource_pack(pack_path,true),"Mount source overrides for this process only")
	if arguments.has("compile-fixture"):
		var fixture:=str(arguments["compile-fixture"])
		var expected:=str(arguments.get("compile-fixture-sha256",""))
		check(expected.length()==64 and FileAccess.get_sha256(fixture)==expected,"Selected deferred fixture source identity")
		if not failures.is_empty():finish();return
		var fixture_script: Variant=load(fixture)
		check(fixture_script is GDScript and fixture_script.can_instantiate(),"Deferred native fixture compiles without being instantiated or executed")
		output.fixture_compile={"file":fixture,"sha256":FileAccess.get_sha256(fixture),"executed":false,"native_class_tested":false}
		if not failures.is_empty():finish();return
	var caller_script: Variant=load("res://"+caller)
	check(caller_script is GDScript and caller_script.can_instantiate(),"Integrated caller and cache parse")
	if not failures.is_empty():finish();return
	var terrain: Variant=caller_script.new();root.add_child(terrain);terrain.set_process(false)
	check(terrain.height(Vector3.ZERO,17.25)==17.25 and terrain.stats.queries==0,"Unready caller keeps previous height without counting a query")
	terrain.definition={"width":1,"height":1,"tiles":[{"model":"fixture","orientation":0,"position":Vector3(0,1.125,0)}]}
	terrain.table={"orderedRows":[{"Walk":"1"}],"defaultValue":"0"}
	terrain.meshes={"fixture":{"vertices":[[0.0,0.0,2.0],[10.0,0.0,2.0],[10.0,10.0,2.0],[0.0,10.0,2.0]],"faces":[[0,1,2],[0,2,3]],"normals":[[0.0,0.0,1.0],[0.0,0.0,1.0]],"constants":[-2.0,-2.0],"materials":[0,0]}}
	terrain.done=true
	check(terrain.ready(),"Synthetic data owner ready without creating a world")
	for orientation in 4:
		terrain.definition.tiles[0].orientation=orientation
		check(terrain.height(Vector3(2.5,6.25,0),17.25)==3.125,"Original script outer quarter turn/elevation: %d"%orientation)
	check(terrain.height(Vector3(-0.125,1,0),17.25)==17.25 and terrain.stats.outside_queries==1,"Outside query keeps previous height")
	check(not ClassDB.class_exists(&"NwnTerrainHeight"),"This gate tests unsupported fallback, not an unverified native class")
	if not failures.is_empty():terrain.free();finish();return
	# Force the opt-in branch only inside this isolated smoke fixture. The real
	# native DLL is unchanged/absent, so the canonical old function must supply it.
	terrain._height_calculations.enabled=true
	for index in 3:check(terrain.height(Vector3(2.5,6.25,0),17.25)==3.125,"Unavailable native calculation preserves original result")
	var snapshot: Dictionary=terrain._height_calculations.snapshot()
	check(snapshot.unsupported_bindings==1 and snapshot.binding_hits==2 and snapshot.fallback_queries==3 and snapshot.native_queries==0,"Unsupported immutable binding is memoized; query fallback remains explicit")
	packing_checks(terrain._height_calculations,terrain.meshes.fixture,terrain.table)
	var payload: Dictionary=terrain.detach_prepared_data()
	check(not contains_object(payload) and terrain._height_calculations.snapshot().entries==0,"Detach clears calculation bindings and yields no native/Node objects")
	terrain.close();check(terrain._height_calculations.snapshot().closed,"Close is terminal")
	terrain.free()
	check(FileAccess.get_sha256(str(manifest.parent.project).path_join(caller))==parent_caller,"Parent caller source was never edited")
	output.overlay_sha256=FileAccess.get_sha256(manifest_file);output.pack_sha256=FileAccess.get_sha256(pack_path)
	output.unsupported_snapshot=snapshot
	finish()
