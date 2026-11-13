extends SceneTree
# Prepared for a private accepted DLL/project. Not run during source-only work.
const Frozen=preload("res://tools/native-drive-numeric/frozen_drive_collision_indexed.gd")
const Adapter=preload("res://systems/native_render/drive_numeric_batch.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func face(a: Vector3,b: Vector3,c: Vector3,walk: bool)->Dictionary:
	var tri: Dictionary=Frozen.triangle(a,b,c);tri.walk=walk;return tri
func expected(rows: Array,a: Vector2,b: Vector2,radius: float,low: float,high: float,tile: bool)->Dictionary:
	var spans: Array=[]
	for tri in rows:
		if tile and tri.walk:
			var span: Vector2=Frozen.interval(a,b,tri)
			if span.x<=span.y:spans.append(span)
		elif Frozen.hits(a,b,tri,radius,low,high):return {"blocked":true,"intervals":[]}
	return {"blocked":false,"intervals":spans}
func bytes(spans: Array)->PackedByteArray:
	return PackedVector2Array(spans).to_byte_array()
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var report_path:="";var expected_module:="";var expected_digest:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.substr(9)
		if arg.begins_with("--expect-module="):expected_module=arg.substr(16)
		if arg.begins_with("--expect-module-sha256="):expected_digest=arg.substr(23)
	if not report_path.is_empty() and FileAccess.file_exists(report_path):quit(2);return
	var adapter:=Adapter.new();adapter.configure()
	var caps:={"version":1,"schema":Adapter.SCHEMA,"supported":true,"abi":1,"float_bytes":4,"double_bytes":8,"math":"engine-vector2-f32-strict-f64","floor":true,"obstacle":true,"height":false}
	check(Adapter.valid_capabilities(caps),"complete capabilities")
	for key in caps:
		var bad: Dictionary=caps.duplicate();bad.erase(key);check(not Adapter.valid_capabilities(bad),"missing capability "+key)
	for malformed in [null,[],{},0,{"version":1,"schema":Adapter.SCHEMA,"supported":true},caps.merged({"height":true},true),caps.merged({"float_bytes":8},true),caps.merged({"version":2},true)]:
		check(not Adapter.valid_capabilities(malformed),"malformed capability")
	if "--expect-absent" in OS.get_cmdline_user_args():
		check(not adapter.enabled,"missing new class keeps fallback")
		check(adapter.query("unknown",Vector2.ZERO,Vector2.ONE,0.2,0,2,true).is_empty(),"missing class query fallback")
	else:
		check(adapter.enabled,"private sidecar capability required")
		check(not expected_module.is_empty() and expected_digest.length()==64,"Explicit private loaded module pins required")
		check(str(adapter.provenance.get("module_path","")).replace("\\","/").to_lower()==expected_module.replace("\\","/").to_lower() and adapter.provenance.get("sha256")==expected_digest,"Actual loaded native module path and bytes equal staged pins")
		check(adapter.provenance.get("extensions",[]).has("res://native/drive_numeric/private.gdextension"),"Godot loaded the pinned private descriptor")
		if adapter.enabled:run_native(adapter)
	adapter.clear();check(adapter.payload_bytes==0 and adapter.entries.is_empty(),"retired all bindings")
	var result:={"success":failures.is_empty(),"suite":"drive-numeric-frozen-v1","checks":checks,"failures":failures,"native_present":ClassDB.class_exists(Adapter.CLASS_NAME),"height_accelerated":false,"provenance":adapter.provenance,"scope":"Actual engine frozen numeric correctness only; no FPS or performance measurement."}
	if not report_path.is_empty():
		var file:=FileAccess.open(report_path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
func run_native(adapter)->void:
	var rng:=RandomNumberGenerator.new();rng.seed=0x915b6c
	var boundaries: Array=[Vector2(-0.0,0.0),Vector2(0,0),Vector2(1,1),Vector2(1.0000001192092896,0.00000001),Vector2(-0.00001,1),Vector2(0.0000001,-0.0000001)]
	for case_index in 256:
		var rows: Array=[]
		for index in 12:
			var a:=Vector3(rng.randf_range(-4,4),rng.randf_range(-4,4),rng.randf_range(-1,1))
			var b:=Vector3(rng.randf_range(-4,4),rng.randf_range(-4,4),rng.randf_range(-1,1))
			var c:=Vector3(rng.randf_range(-4,4),rng.randf_range(-4,4),rng.randf_range(-1,1))
			if index%5==0:c=b
			if index%7==0:a=Vector3(-0.0,0,0);b=Vector3(1,0,0);c=Vector3(0,1,0)
			rows.append(face(a,b,c,index%4!=0))
		for tile in [true,false]:
			var key:="oracle";adapter.bind(key,rows,tile)
			for query_index in 12:
				var a: Vector2=boundaries[query_index] if query_index<boundaries.size() else Vector2(rng.randf_range(-5,5),rng.randf_range(-5,5))
				var b: Vector2=a if query_index==0 else Vector2(rng.randf_range(-5,5),rng.randf_range(-5,5))
				var radius:=0.0 if query_index%3==0 else 0.3
				var reference:=expected(rows,a,b,radius,-0.1,2.1,tile)
				var actual: Dictionary=adapter.query(key,a,b,radius,-0.1,2.1,tile)
				check(not actual.is_empty(),"native query supported")
				if actual.is_empty():continue
				check(actual.blocked==reference.blocked,"frozen blocker")
				if tile:check(bytes(actual.intervals)==bytes(reference.intervals),"frozen ordered interval bytes")
			adapter.invalidate(key)
	var owner: Variant=ClassDB.instantiate(Adapter.CLASS_NAME)
	var input:=Adapter.request();input.triangles=[];input.tile=true;input.maximum_bytes=1
	check(not owner.dispatch(1,input).supported,"native budget rejection")
	input.maximum_bytes=1024;input.triangles=[face(Vector3(INF,0,0),Vector3.ZERO,Vector3.ONE,true)]
	check(not owner.dispatch(1,input).supported,"nonfinite binding rejection")
	check(not owner.dispatch(4,Adapter.request()).supported,"height explicitly unsupported")
	check(owner.dispatch(5,Adapter.request()).supported,"native retire")
	check(owner.dispatch(5,Adapter.request()).supported,"native repeated retire")
	check(not owner.dispatch(6,Adapter.request()).configured,"native snapshot retired")
	# Adversarial finite inputs use the same independent script oracle, retaining
	# winding, exact ordered interval bytes and narrow-phase boundaries.
	var special: Array=[
		face(Vector3.ZERO,Vector3.RIGHT,Vector3.UP,true),
		face(Vector3.UP,Vector3.RIGHT,Vector3.ZERO,true),
		face(Vector3(-0.0,0,0),Vector3.ZERO,Vector3.ZERO,true),
		face(Vector3.ZERO,Vector3(1,0.0000001,0),Vector3(2,0.0000002000001,0),true),
		face(Vector3(-10000000,-10000000,-1),Vector3(10000000,-10000000,1),Vector3(0,10000000,0),true),
		face(Vector3(0.5,-1,1),Vector3(0.5,1,1),Vector3(0.5,1,2),false)]
	var lines: Array=[[Vector2.ZERO,Vector2.ZERO],[Vector2(-0.0,0),Vector2(1,1)],[Vector2(0.5,-1),Vector2(0.5,1)],[Vector2(-2,0),Vector2(2,0)],[Vector2(-10000000,0),Vector2(10000000,0)]]
	for tile in [true,false]:
		adapter.bind("edge",special,tile)
		for line in lines:
			for radius in [0.0,0.0000001,0.3,1.2]:
				for bounds in [[-0.1,1.0],[1.0,1.0],[1.0000001,2.0]]:
					var reference:=expected(special,line[0],line[1],radius,bounds[0],bounds[1],tile)
					var actual: Dictionary=adapter.query("edge",line[0],line[1],radius,bounds[0],bounds[1],tile)
					check(not actual.is_empty(),"Adversarial finite native query supported")
					if actual.is_empty():continue
					check(actual.blocked==reference.blocked,"Adversarial exact blocker boundary")
					if tile:check(bytes(actual.intervals)==bytes(reference.intervals),"Adversarial frozen winding/degenerate/finite interval bytes")
		adapter.invalidate("edge")
	# Native entry bounds and invalidated immutable identities must never leave a
	# usable stale owner or repeatedly allocate when a payload is unsupported.
	adapter.bind("replace",[special[0]],true)
	var old_owner=adapter.entries.replace.owner
	adapter.bind("replace",[special[5]],false)
	check(not old_owner.dispatch(6,Adapter.request()).configured and not adapter.entries.replace.tile,"Immutable source replacement retires the previous native owner")
	adapter.invalidate("replace")
	for index in Adapter.MAXIMUM_ENTRIES:adapter.bind("bound:"+str(index),[special[0]],true)
	adapter.bind("overflow",[special[0]],true)
	check(adapter.entries.size()==Adapter.MAXIMUM_ENTRIES and adapter.payload_bytes<=Adapter.MAXIMUM_BYTES and adapter.query("overflow",Vector2.ZERO,Vector2.ONE,0,0,2,true).is_empty(),"Bounded native entry capacity follows script fallback")
	adapter.clear()
	adapter.bind("invalid",[face(Vector3(INF,0,0),Vector3.ZERO,Vector3.ONE,true)],true)
	var rejected: int=adapter.counters.rejected
	var invalid_source: Array=adapter.entries.invalid.source
	adapter.bind("invalid",invalid_source,true)
	check(adapter.counters.rejected==rejected and adapter.entries.invalid.owner==null and adapter.payload_bytes==0,"Rejected exact immutable source is remembered without a native payload")
	check(adapter.query("invalid",Vector2.ZERO,Vector2.ONE,0,0,2,true).is_empty(),"Rejected binding follows the original script inner loop")
	adapter.clear()
