extends SceneTree
# Deferred integration fixture. Requires the private five-file height overlay
# and its new native DLL. It never joins a server or renders a world.
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Terrain=preload("res://systems/native_render/terrain_surface.gd")
const Cache=preload("res://systems/native_render/terrain_height_cache.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
var checks:=0
var failures: Array=[]
var corpus_queries:=0
class ThreadProbe:
	extends RefCounted
	func sample(native: RefCounted,cache: RefCounted,source: Dictionary,table: Dictionary,data: Dictionary)->Dictionary:
		# Shared inputs are immutable throughout this bounded worker call.
		# The worker does not touch the SceneTree or the test's result arrays.
		var configured: Variant=native.call("configure",data)
		var queried: Variant=native.call("query",8.0,2.0)
		native.call("retire")
		var state: Variant=native.call("snapshot")
		var cached: Variant=cache.call("calculate","thread",source,table,[8.0,2.0])
		cache.call("invalidate","thread");cache.call("clear");cache.call("close")
		return {"configured":configured,"queried":queried,"native":state,"cached":cached,"cache":cache.call("snapshot")}
func _initialize()->void:call_deferred("run")
func check(value: bool,label: String)->void:
	checks+=1
	if not value and failures.size()<50:failures.append(label)
func bits(value: float)->PackedByteArray:
	var output:=PackedByteArray();output.resize(8);output.encode_double(0,value);return output
func floor_mesh()->Dictionary:
	return {"vertices":[[0.0,0.0,9.0],[10.0,0.0,9.0],[10.0,10.0,9.0],[0.0,0.0,2.0],[10.0,0.0,2.0],[10.0,10.0,2.0]],"faces":[[0,1,2],[3,4,5]],"normals":[[0.0,0.0,1.0],[0.0,0.0,1.0]],"constants":[-9.0,-2.0],"materials":[0,1]}
func flags()->Dictionary:return {"orderedRows":[{"Walk":"0"},{"Walk":"1"}],"defaultValue":"0"}
func native_requested()->bool:return OS.get_cmdline_user_args().has("--terrain-height=native") and not OS.get_cmdline_user_args().has("--terrain-height=script")
func unsupported_mesh()->Dictionary:
	# Reject at the actual GDS packer's type boundary. A fractional Float such
	# as 0.1 passes packing; any later exact-f32 rejection belongs to the native
	# kernel and should not be assumed by a packer/fallback fixture.
	var source:=floor_mesh();source.vertices[0][0]=0
	return source
func pack(source: Dictionary,table: Dictionary)->Dictionary:
	var values:=PackedFloat64Array();var mask:=PackedByteArray()
	for index in source.faces.size():
		for corner in source.faces[index]:values.append(float(source.vertices[corner][0]));values.append(float(source.vertices[corner][1]))
		for component in source.normals[index]:values.append(float(component))
		values.append(float(source.constants[index]));mask.append(1 if Surface.walkable(table,int(source.materials[index])) else 0)
	return {"faces":values,"walk":mask,"maximum_bytes":16*1024*1024}
func native_lifetime()->void:
	var native: RefCounted=ClassDB.instantiate(&"NwnTerrainHeight");var source:=floor_mesh();var data:=pack(source,flags())
	var result: Variant=native.call("configure",data)
	check(result is Dictionary and result.get("supported",false),"Native typed numeric configuration")
	check(native.call("query",8.0,2.0) is float and native.call("query",8.0,2.0)==2.0,"Actual double Variant query selects lower walkable physical plane")
	data.faces.fill(0.0);data.walk.fill(0)
	check(native.call("query",8.0,2.0)==2.0,"Numeric input arrays are detached after configuration")
	check(not native.call("configure",pack(source,{"orderedRows":[{"Walk":"0"},{"Walk":"0"}]})).get("supported",false) and native.call("query",8.0,2.0)==2.0,"Configured owner cannot rebind to another material source")
	check(native.call("query",INF,0.0)==null,"Unsupported query is missing, never valid zero")
	var zero: Variant=native.call("query",-100.0,-100.0)
	check(zero is float and bits(zero)==bits(0.0),"Valid no-face zero remains distinct from missing")
	check(native.call("query",NAN,0.0)==null,"NaN query remains unsupported rather than no-face zero")
	var snapshot: Dictionary=native.call("snapshot");snapshot.state=999;snapshot.faces=0
	check(native.call("snapshot").state==1 and native.call("query",8.0,2.0)==2.0,"Cold native diagnostics cannot mutate live calculations")
	native.call("retire")
	check(native.call("query",8.0,2.0)==null and native.call("snapshot").state==2 and native.call("snapshot").faces==0,"Retirement makes an old owner permanently unavailable")
	check(not native.call("configure",pack(source,flags())).get("supported",false),"Retired owner never resolves a replacement binding")
	for malformed in [{},{"faces":[],"walk":PackedByteArray(),"maximum_bytes":1000},{"faces":PackedFloat64Array([0.0]),"walk":PackedByteArray(),"maximum_bytes":1000}]:
		var rejected: RefCounted=ClassDB.instantiate(&"NwnTerrainHeight");var reply: Variant=rejected.call("configure",malformed)
		check(reply is Dictionary and not reply.get("supported",false) and rejected.call("query",1.0,1.0)==null,"Malformed numeric source unavailable")
		check(not rejected.call("configure",pack(source,flags())).get("supported",false),"Failed source owner is terminal too")
	var limited: RefCounted=ClassDB.instantiate(&"NwnTerrainHeight");var small:=pack(source,flags());small.maximum_bytes=1
	check(not limited.call("configure",small).get("supported",false) and limited.call("query",1.0,1.0)==null,"Native owner payload bound fails to missing")
	var zero_source:=floor_mesh();zero_source.constants=[0.0,0.0]
	var signed_zero: RefCounted=ClassDB.instantiate(&"NwnTerrainHeight");var admitted: Variant=signed_zero.call("configure",pack(zero_source,flags()))
	var expected_zero:=Surface.height(zero_source,flags(),[8.0,2.0]);var actual_zero: Variant=signed_zero.call("query",8.0,2.0)
	check(admitted is Dictionary and admitted.get("supported",false) and actual_zero is float and bits(actual_zero)==bits(expected_zero),"Valid selected-plane signed zero preserves original arithmetic bits")
	signed_zero.call("retire");limited.call("retire")
func thread_isolation()->void:
	var source:=floor_mesh();var table:=flags();var data:=pack(source,table)
	var native: RefCounted=ClassDB.instantiate(&"NwnTerrainHeight");var configured: Variant=native.call("configure",data)
	check(configured is Dictionary and configured.get("supported",false),"Thread fixture configures its owner on main")
	var cache:=Cache.new();cache.calculate("thread",source,table,[8.0,2.0])
	var native_before: Variant=native.call("snapshot");var cache_before:=cache.snapshot()
	var probe:=ThreadProbe.new();var worker:=Thread.new();var started:=worker.start(probe.sample.bind(native,cache,source,table,data))
	check(started==OK,"Bounded owner-thread probe starts")
	if started!=OK:native.call("retire");cache.close();return
	var result: Variant=worker.wait_to_finish()
	check(result is Dictionary and not contains_object(result),"Worker returns detached numeric results only")
	if result is Dictionary:
		check(result.configured is Dictionary and not result.configured.get("supported",false) and result.configured.get("reason")==2,"Off-thread configure is explicitly unavailable")
		check(result.queried==null and result.cached==null,"Off-thread native and cache queries are missing")
		check(result.native is Dictionary and not result.native.get("supported",false) and result.native.get("reason")==2,"Off-thread native snapshot does not inspect live mutable calculations")
		check(result.cache is Dictionary and result.cache=={"available":false,"supported":false},"Off-thread cache snapshot is a fixed unavailable view")
	check(var_to_bytes(native.call("snapshot"))==var_to_bytes(native_before),"Off-thread configure/query/retire leave native owner and counters unchanged")
	check(var_to_bytes(cache.snapshot())==var_to_bytes(cache_before),"Off-thread invalidate/clear/close leave main cache scope unchanged")
	check(native.call("query",8.0,2.0)==2.0,"Main-thread owner remains usable after rejected worker access")
	native.call("retire");cache.close()
func original_height(owner,point: Vector3,previous: float)->float:
	if not owner.ready():return previous
	var x:=floori(point.x/10.0);var y:=floori(point.y/10.0)
	if x<0 or y<0 or x>=int(owner.definition.width) or y>=int(owner.definition.height):return previous
	var tile: Dictionary=owner.definition.tiles[y*int(owner.definition.width)+x]
	var local:=Surface.canonical([Surface.f(Surface.f(point.x)-Surface.f(Surface.f(x)*10)),Surface.f(Surface.f(point.y)-Surface.f(Surface.f(y)*10))],int(tile.orientation))
	return Surface.f(Surface.height(owner.meshes[tile.model],owner.table,local)+Surface.f(tile.position.y))
func compare(owner,point: Vector3,previous: float,label: String)->void:
	var expected:=original_height(owner,point,previous);var actual: float=owner.height(point,previous)
	check(bits(actual)==bits(expected),label+" exact original outer/inner height bits")
func publication_and_caller()->void:
	var owner:=Terrain.new();root.add_child(owner);owner.set_process(false)
	owner.meshes={"floor":floor_mesh()};owner.table=flags();owner.definition={"width":2,"height":1,"tiles":[{"model":"floor","orientation":0,"position":Vector3(5,7,-5)},{"model":"floor","orientation":1,"position":Vector3(15,13.5,-5)}]}
	compare(owner,Vector3(8,2,1000),37,"Unready retains previous Z")
	check(owner.stats.queries==0 and owner.snapshot().height_calculations.configured==0,"Unready performs no inner preparation/query")
	owner.done=true
	for orientation in 4:
		owner.definition.tiles[0].orientation=orientation
		for point in [Vector3(8,2,1000),Vector3(2,8,-1000),Vector3(10,2,999),Vector3(18,2,0),Vector3(-1,0,0),Vector3(20,0,0),Vector3(0,10,0)]:compare(owner,point,-37,"Quarter-turn/elevation/outside "+str(orientation))
	var requested:=native_requested()
	var first: Dictionary=owner.snapshot().height_calculations
	check(first.enabled==requested,"Caller uses explicit launch-time route")
	if requested:check(first.configured==1 and first.active_owners==1 and first.native_hits>0,"Two placements/orientations share one immutable mesh/table calculation")
	else:check(first.configured==0 and first.native_queries==0,"Script default performs no native height work")
	var query_count: int=owner.stats.queries;var cache_queries: int=first.native_queries
	owner.stats.errors.append({"reason":"fixture required-source failure"});compare(owner,Vector3(8,2,0),-99,"Required source error retains previous")
	check(owner.stats.queries==query_count and owner.snapshot().height_calculations.native_queries==cache_queries,"Unready error adds no query or native work")
	owner.stats.errors.clear();owner.definition.tiles[0].orientation=0
	var replacement:=floor_mesh();replacement.constants=[-4.0,-6.0]
	owner.requests[101]="floor";owner.prepared(101,{"error":"","value":replacement,"cache_hit":false,"worker_ms":0.0})
	if requested:check(owner.snapshot().height_calculations.active_owners==0,"Mesh publication retires typed calculations before replacement")
	compare(owner,Vector3(8,2,0),999,"Replaced same-name mesh")
	if requested:check(owner.snapshot().height_calculations.configured==2,"Replacement gets a fresh immutable owner")
	var next_table:=flags();next_table.orderedRows[1].Walk="0"
	owner.requests[102]="@surfacemat";owner.prepared(102,{"error":"","value":next_table,"cache_hit":false,"worker_ms":0.0})
	compare(owner,Vector3(8,2,0),999,"Server surface table replacement changes physical pass")
	check(owner.height(Vector3(8,2,0),999)==11.0,"All-denied table uses first stored plane plus original elevation")
	# Even same-reference owner republishes must invalidate. No per-query table
	# scan is added to support out-of-owner arbitrary internal dictionary writes.
	next_table.orderedRows[1].Walk="1";owner.requests[103]="@surfacemat";owner.prepared(103,{"error":"","value":next_table,"cache_hit":false,"worker_ms":0.0})
	compare(owner,Vector3(8,2,0),999,"Same-reference table republish boundary")
	var unsupported:=replacement.duplicate(true);unsupported.vertices[0][0]=0
	owner.requests[104]="floor";owner.prepared(104,{"error":"","value":unsupported,"cache_hit":false,"worker_ms":0.0})
	var fallback_before: Dictionary=owner.snapshot().height_calculations
	compare(owner,Vector3(8,2,0),999,"Unsupported typed source retains original caller fallback")
	compare(owner,Vector3(8,2,0),999,"Same unsupported binding repeats only original query")
	if requested:
		var fallback_after: Dictionary=owner.snapshot().height_calculations
		check(fallback_after.unsupported_bindings==fallback_before.unsupported_bindings+1 and fallback_after.fallback_queries==fallback_before.fallback_queries+2,"Unsupported preparation is memoized, two caller queries use two explicit fallbacks")
	var detached: Dictionary=owner.detach_prepared_data()
	check(owner.snapshot().height_calculations.entries==0 and owner.snapshot().height_calculations.active_owners==0,"Detach retires native owners before raw worker payload")
	check(not contains_object(detached),"Deferred payload contains no native Resource/Node")
	owner.close();check(owner.snapshot().height_calculations.closed,"Close is terminal for calculation owner");owner.free()
func failed_and_republished_sources()->void:
	var owner:=Terrain.new();root.add_child(owner);owner.set_process(false)
	owner.done=true;owner.meshes={"floor":floor_mesh()};owner.table=flags();owner.definition={"width":1,"height":1,"tiles":[{"model":"floor","orientation":0,"position":Vector3(5,0,-5)}]}
	compare(owner,Vector3(8,2,0),91,"Initial publication fixture")
	var before: Dictionary=owner.snapshot().height_calculations;var queries: int=owner.stats.queries
	owner.requests[801]="floor";owner.prepared(801,{"error":"fixture required-source failure","value":{},"cache_hit":false,"worker_ms":0.0})
	check(owner.snapshot().height_calculations.entries==0 and owner.snapshot().height_calculations.active_owners==0,"Errored model publication retires calculation before readiness failure")
	compare(owner,Vector3(8,2,0),91,"Errored publication retains previous Z")
	check(owner.stats.queries==queries and owner.snapshot().height_calculations.native_queries==before.native_queries,"Errored publication makes no fallback or native height query")
	owner.stats.errors.clear();compare(owner,Vector3(8,2,0),91,"Old valid source after caller clears fixture error")
	if native_requested():check(owner.snapshot().height_calculations.configured==before.configured+1,"Recovered immutable source gets a fresh owner after error invalidation")
	var same_source: Dictionary=owner.meshes.floor;same_source.constants[1]=-5.0
	owner.requests[802]="floor";owner.prepared(802,{"error":"","value":same_source,"cache_hit":false,"worker_ms":0.0})
	check(owner.snapshot().height_calculations.entries==0,"Same-reference mesh republish invalidates typed calculations")
	compare(owner,Vector3(8,2,0),91,"Same-reference mesh republish uses changed plane")
	check(owner.height(Vector3(8,2,0),91)==5.0,"Republished plane is not served by the old immutable owner")
	var state_before: Dictionary=owner.snapshot().height_calculations
	owner.prepared(999,{})
	check(var_to_bytes(owner.snapshot().height_calculations)==var_to_bytes(state_before),"Unknown completion IDs cannot invalidate a current binding")
	owner.close();var closed_before: Dictionary=owner.snapshot().height_calculations
	owner.requests[803]="floor";owner.prepared(803,{})
	check(var_to_bytes(owner.snapshot().height_calculations)==var_to_bytes(closed_before),"Late completion cannot reopen a closed calculation scope")
	owner.free()
func contains_object(value: Variant)->bool:
	if value is Object:return true
	if value is Dictionary:
		for key in value:
			if contains_object(key) or contains_object(value[key]):return true
	elif value is Array:
		for child in value:
			if contains_object(child):return true
	return false
func cache_limits()->void:
	if not native_requested():return
	var cache:=Cache.new();cache.maximum_entries=0
	check(cache.calculate("floor",floor_mesh(),flags(),[8.0,2.0])==null and cache.snapshot().budget_fallback==1,"Entry bound falls back explicitly")
	cache=Cache.new();cache.maximum_bytes=1
	check(cache.calculate("floor",floor_mesh(),flags(),[8.0,2.0])==null and cache.snapshot().active_owners==0,"Payload bound falls back explicitly")
	cache=Cache.new();var unsupported:=unsupported_mesh();var unsupported_table:=flags()
	check(cache.calculate("floor",unsupported,unsupported_table,[8.0,2.0])==null,"Integer-coordinate source is rejected by the packer and preserves old-function fallback")
	check(cache.calculate("floor",unsupported,unsupported_table,[8.0,2.0])==null and cache.snapshot().unsupported_bindings==1 and cache.snapshot().invalidations==0,"Unchanged unsupported binding does not rebuild every query")
	cache.clear();check(cache.snapshot().entries==0,"Failure memo retires with source scope")
	# The unchanged edge expression can perform int64-minus-int64 before its
	# first f32 conversion. Rounding endpoints to PackedFloat64 first would
	# erase this unit edge and incorrectly admit the degenerate triangle.
	var large: int=1<<60
	var integer_mesh:={"vertices":[[large+1,0.0,0.0],[large+2,0.0,0.0],[large+1,1.0,0.0]],"faces":[[0,1,2]],"normals":[[0.0,0.0,1.0]],"constants":[-3.0],"materials":[0]}
	var integer_table:={"orderedRows":[{"Walk":"1"}],"defaultValue":"0"};var integer_point:=[float(large),0.5]
	check(bits(Surface.height(integer_mesh,integer_table,integer_point))==bits(0.0),"Original integer endpoint subtraction precedes f32 rounding")
	check(cache.calculate("integers",integer_mesh,integer_table,integer_point)==null and cache.snapshot().active_owners==0,"Integer-authored source coordinates preserve old arithmetic through explicit fallback")
	cache=Cache.new();var source:=floor_mesh();var table:=flags()
	check(cache.calculate("floor",source,table,[8.0,2.0])==2.0,"Valid cache numeric result")
	var view:=cache.snapshot();view.entries=999;view.active_owners=0
	check(cache.snapshot().entries==1 and cache.snapshot().active_owners==1,"Cache cold numeric snapshot is detached")
	source.normals=source.normals.duplicate(true)
	check(cache.calculate("floor",source,table,[8.0,2.0])==2.0 and cache.snapshot().configured==2 and cache.snapshot().invalidations==1,"Exact source-array replacement invalidates even same mesh dictionary")
	cache.close();check(cache.calculate("floor",source,table,[8.0,2.0])==null and cache.snapshot().active_owners==0,"Closed cache never rebinds")
func cache_identity_and_missing()->void:
	if not native_requested():return
	var cache:=Cache.new();var source:=floor_mesh();var table:=flags()
	check(cache.calculate("floor",source,table,[8.0,2.0])==2.0,"Identity fixture configures one immutable source")
	for field in ["vertices","faces","normals","constants","materials"]:
		var before:=cache.snapshot();source[field]=source[field].duplicate(true)
		var value: Variant=cache.calculate("floor",source,table,[8.0,2.0])
		check(value is float and bits(value)==bits(Surface.height(source,table,[8.0,2.0])) and cache.snapshot().configured==before.configured+1 and cache.snapshot().invalidations==before.invalidations+1,"Array identity replacement retires binding: "+field)
	var before_rows:=cache.snapshot();table.orderedRows=table.orderedRows.duplicate(true)
	check(cache.calculate("floor",source,table,[8.0,2.0])==2.0 and cache.snapshot().configured==before_rows.configured+1,"Material row-array identity replacement gets a fresh calculation")
	var before_default:=cache.snapshot();table.defaultValue="-1"
	check(cache.calculate("floor",source,table,[8.0,2.0])==2.0 and cache.snapshot().configured==before_default.configured+1,"Material default replacement invalidates its source binding")
	var invalid_before:=cache.snapshot()
	for point in [[],[null,2.0],[INF,2.0],["8",2.0],[8.0,NAN]]:check(cache.calculate("floor",source,table,point)==null,"Invalid query stays missing before native invocation")
	var invalid_after:=cache.snapshot()
	check(invalid_after.fallback_queries==invalid_before.fallback_queries+5 and invalid_after.native_queries==invalid_before.native_queries and invalid_after.configured==invalid_before.configured,"Invalid queries do not prepare or invoke native calculations")
	var zero: Variant=cache.calculate("floor",source,table,[-100.0,-100.0])
	check(zero is float and bits(zero)==bits(0.0),"Cache distinguishes valid zero from invalid/missing coordinates")
	var other:=floor_mesh();var other_table:=flags();check(cache.calculate("other",other,other_table,[8.0,2.0])==2.0,"Independent source binding exists in same scope")
	var two:=cache.snapshot();cache.invalidate("floor")
	check(cache.snapshot().active_owners==1 and cache.snapshot().entries==1 and cache.snapshot().invalidations==two.invalidations+1,"Named invalidation retires only that binding")
	check(cache.calculate("other",other,other_table,[8.0,2.0])==2.0 and cache.snapshot().configured==two.configured,"Unrelated immutable source remains a cache hit")
	var one:=cache.snapshot();cache.invalidate("missing")
	check(var_to_bytes(cache.snapshot())==var_to_bytes(one),"Missing binding invalidation has no scope side effect")
	check(not contains_object(cache.snapshot()),"Cache diagnostics contain no source or native objects")
	cache.close()
func golden(args: Dictionary)->void:
	if not args.has("corpus"):return
	check(str(args.get("corpus-sha",""))=="3990535cc41d46046a288aaf91e8e77536a619a9415e7734ff5ff7bed2cdb54d" and FileAccess.get_sha256(str(args.corpus))==str(args["corpus-sha"]),"Authenticated original ce2d golden corpus")
	if not failures.is_empty():return
	var file:=FileAccess.open(str(args.corpus),FileAccess.READ);file.big_endian=false
	check(file.get_buffer(8).get_string_from_utf8()=="NWNHGT01","Golden binary schema")
	var count:=file.get_32();check(count==472,"Accepted original golden case count")
	if count!=472:file.close();return
	for index in count:
		var label:=file.get_buffer(file.get_16()).get_string_from_utf8();var faces:=file.get_32();var queries:=file.get_32()
		if faces>100000 or queries==0 or queries>100000:check(false,"Golden dimensions bound");break
		var values:=PackedFloat64Array();values.resize(faces*10);var walk:=PackedByteArray();walk.resize(faces)
		for face in faces:
			for component in 10:values[face*10+component]=file.get_double()
			walk[face]=file.get_8()
		var native: RefCounted=ClassDB.instantiate(&"NwnTerrainHeight");var admission: Variant=native.call("configure",{"faces":values,"walk":walk,"maximum_bytes":16*1024*1024})
		for query in queries:
			var x:=file.get_double();var y:=file.get_double();var expected:=file.get_double();file.get_8();file.get_32();file.get_8();var policy:=file.get_8()
			var actual: Variant=native.call("query",x,y);corpus_queries+=1
			if policy==0:check(actual==null,"Golden unsupported stays missing "+label)
			elif policy==1:check(admission is Dictionary and admission.get("supported",false) and actual is float and bits(actual)==bits(expected),"Native adapter exact original Godot height bits "+label)
			else:check(false,"Golden support policy")
		native.call("retire")
	check(file.get_position()==file.get_length() and corpus_queries==21084,"Full authenticated corpus consumed without trailing/omitted queries");file.close()
func run()->void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(str(args.report)):quit(2);return
	check(DisplayServer.get_name()=="headless","Deferred integration fixture runs without a graphics device")
	check(Kernel.enabled() and Kernel.available(),"Explicit compiled-kernel switch loads the private extension before class admission")
	check(ClassDB.class_exists(&"NwnTerrainHeight"),"New separate numeric provider actually loaded")
	if ClassDB.class_exists(&"NwnTerrainHeight"):native_lifetime();thread_isolation();publication_and_caller();failed_and_republished_sources();cache_limits();cache_identity_and_missing();golden(args)
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"corpus_queries":corpus_queries,"native_requested":OS.get_cmdline_user_args().has("--terrain-height=native") and not OS.get_cmdline_user_args().has("--terrain-height=script"),"activation":{"pid":OS.get_process_id(),"display":DisplayServer.get_name(),"executable":OS.get_executable_path(),"kernel_enabled":Kernel.enabled(),"class":ClassDB.class_exists(&"NwnTerrainHeight"),"library_file":ProjectSettings.globalize_path("res://.cache/native-kernel/nwn-particle-kernel.dll")},"scope":"Deferred separate height-class numeric/outer-caller/publication/lifecycle/cache/bounds and optional authenticated golden oracle. No server, GPU, clean latency or visual acceptance."}
	var output:=FileAccess.open(str(args.report),FileAccess.WRITE)
	if output!=null:output.store_string(JSON.stringify(result,"  ")+"\n");output.close()
	print(JSON.stringify({"success":result.success,"checks":checks,"corpus_queries":corpus_queries,"failures":failures}));quit(0 if failures.is_empty() else 1)
