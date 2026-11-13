extends "res://tests/native_drive_spatial_adapter_test.gd"
const Cache=preload("res://systems/native_render/drive_clear_cache.gd")
class CountingSurface:
	extends Node
	var calls: Array=[]
	var definition:={"width":2,"height":2}
	var z:=0.0
	func height(point: Vector3,previous: float)->float:calls.append([point,previous]);return z
class Owner:
	extends Node
	var surface
func tri(a: Vector3,b: Vector3,c: Vector3,walk: bool=true)->Dictionary:
	var result:=Collision.triangle(a,b,c);result.walk=walk;return result
func native_batch(triangles: Array,tile_mode: bool)->RefCounted:
	var native: RefCounted=ClassDB.instantiate(&"NwnSceneGeometry")
	var result: Dictionary=native.call("dispatch",3,{"triangles":triangles,"tile":tile_mode,"maximum_bytes":1024*1024})
	check(result.get("supported",false),"Native batch admission")
	return native
func native_request(native: RefCounted,a: Vector2,b: Vector2,radius: float=0.3,low: float=-0.1,high: float=2.0,tile_mode: bool=true)->Dictionary:
	return native.call("dispatch",4 if tile_mode else 5,{"a":a,"b":b,"radius":radius,"low":low,"high":high})
func loop_oracles()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=0x913ab751
	for index in 1800:
		var points: Array=[]
		for corner in 3:points.append(Vector3(rng.randf_range(-20,20),rng.randf_range(-20,20),rng.randf_range(-3,3)))
		if index%13==0:points[1]=points[0]
		if index%19==0:points[2]=points[1]
		if index%23==0:points.reverse()
		var face:=tri(points[0],points[1],points[2])
		var a:=Vector2(rng.randf_range(-20,20),rng.randf_range(-20,20));var b:=a if index%17==0 else Vector2(rng.randf_range(-20,20),rng.randf_range(-20,20))
		var native:=native_batch([face],true);var result:=native_request(native,a,b)
		var expected: Array=[];var span: Vector2=Collision.interval(a,b,face)
		if span.x<=span.y:expected.append(span)
		check(result.get("supported",false) and not result.get("blocked",true) and var_to_bytes(result.get("intervals"))==var_to_bytes(expected),"Actual engine Vector2 span exact bits "+str(index))
		face.walk=false;native=native_batch([face],false);result=native_request(native,a,b,float(index%15)/16.0,-0.1,2.0,false)
		check(result.get("supported",false) and result.blocked==Collision.hits(a,b,face,float(index%15)/16.0,-0.1,2.0),"Actual engine capsule triangle decision "+str(index))
	# The source is copied into the calculation owner, never borrowed after config.
	var source: Array=[tri(Vector3(3,0,-1),Vector3(3,10,-1),Vector3(3,10,3),false)]
	var native:=native_batch(source,false);var before:=native_request(native,Vector2(1,1),Vector2(4,1),0.3,-0.1,2,false)
	source[0].a=Vector3(100,100,100);source.clear()
	check(var_to_bytes(native_request(native,Vector2(1,1),Vector2(4,1),0.3,-0.1,2,false))==var_to_bytes(before),"Native calculations detach original mutable array/dictionaries")
	for malformed in [null,{},[{}],[{"a":Vector3.ZERO,"b":Vector3.ZERO,"c":Vector3.ZERO,"min":Vector3.ZERO,"max":Vector3.ZERO,"walk":1}],[tri(Vector3(INF,0,0),Vector3.ZERO,Vector3.ONE)]]:
		var response: Dictionary=native.call("dispatch",3,{"triangles":malformed,"tile":true,"maximum_bytes":1024})
		check(not response.get("supported",false),"Malformed optional batch explicitly unavailable")
		check(not native_request(native,Vector2.ZERO,Vector2.ONE).get("supported",false),"Rejected replacement cannot reuse stale configured data")
	native=native_batch([tri(Vector3.ZERO,Vector3(10,0,0),Vector3(0,10,0))],true)
	for query in [{"a":Vector2(INF,0),"b":Vector2.ONE,"radius":0.3,"low":0.0,"high":2.0},{"a":Vector2.ZERO,"b":Vector2.ONE,"radius":-1.0,"low":0.0,"high":2.0},{"a":Vector2.ZERO,"b":Vector2.ONE,"radius":0.3,"low":2.0,"high":0.0},{"a":Vector2.ZERO}]:
		check(not native.call("dispatch",4,query).get("supported",false),"Unsupported arithmetic/query uses explicit fallback")
	check(not native_request(native,Vector2.ZERO,Vector2.ONE,0.3,0,2,false).get("supported",false),"Wrong mode does not reinterpret calculations")
func direct_fixture()->Dictionary:
	var owner:=Owner.new();root.add_child(owner);var surface:=CountingSurface.new();owner.add_child(surface);owner.surface=surface
	var collision:=Collision.new();owner.add_child(collision);collision.set_process(false);collision.world=owner;collision.drive_native_cache.enabled=true
	for y in 2:
		for x in 2:
			var p:=Vector3(x*10,y*10,0)
			collision.tiles[y*2+x]=[tri(p,p+Vector3(10,0,0),p+Vector3(10,10,0)),tri(p,p+Vector3(10,10,0),p+Vector3(0,10,0))]
	return {"owner":owner,"surface":surface,"collision":collision}
func compare_clear(setup: Dictionary,from: Vector3,to: Vector3,radius: float,height: float,obstacles: Array=[],creatures: Array=[],pending: Array=[],label: String="")->void:
	var collision=setup.collision;var surface=setup.surface
	collision.stats={"queries":0,"blocked":0,"reasons":{}};surface.calls=[]
	var old: bool=collision._drive_clear_reference(from,to,radius,height,obstacles,creatures,pending)
	var old_state: PackedByteArray=var_to_bytes(collision.stats);var old_calls: PackedByteArray=var_to_bytes(surface.calls)
	collision.stats={"queries":0,"blocked":0,"reasons":{}};surface.calls=[]
	var actual: bool=collision._drive_clear_compiled(from,to,radius,height,obstacles,creatures,pending)
	check(old==actual and var_to_bytes(collision.stats)==old_state,label+" exact result/query count/first denial/denial endpoints")
	check(var_to_bytes(surface.calls)==old_calls,label+" exact original height order/arguments/count, no fallback resample")
func clear_oracles()->void:
	var setup:=direct_fixture();var collision=setup.collision
	var wall:=tri(Vector3(4,0,-1),Vector3(4,10,-1),Vector3(4,10,3),false)
	var shape:={"signature":[1],"triangles":[wall],"min":wall.min,"max":wall.max}
	compare_clear(setup,Vector3(1,1,0),Vector3(8,1,0),0.3,1.8,[shape],[],[Vector2(2,1)],"Pending before every other stage")
	check(setup.surface.calls.is_empty(),"Pending denial skips both original height calls")
	compare_clear(setup,Vector3(1,1,0),Vector3(8,1,0),0.3,1.8,[shape],[{"point":Vector2(2,1),"radius":0.6}],[],"Creature before height/tile/object")
	check(setup.surface.calls.is_empty(),"Creature denial skips both original height calls")
	compare_clear(setup,Vector3(1,1,0),Vector3(8,1,0),0.3,1.8,[shape],[],[],"Object wall after floor coverage")
	check(setup.surface.calls.size()==2 and str(collision.stats.last_blocked.reason)=="object_polygon","Object path preserves exactly two height calls and reason")
	for radius in [0.0,1.0/64.0,0.3,12.0,-1.0]:
		for height in [0.0,1.8,1000.0,-1.0]:compare_clear(setup,Vector3(1,1,-1000),Vector3(8,1,1000),radius,height,[shape],[],[],"Large/unknown-Z/invalid-size "+str(radius)+"/"+str(height))
	var rng:=RandomNumberGenerator.new();rng.seed=0x326ca31
	for index in 600:
		var from:=Vector3(rng.randf_range(-1,21),rng.randf_range(-1,21),rng.randf_range(-5,5));var to:=from+Vector3(rng.randf_range(-4,4),rng.randf_range(-4,4),0)
		compare_clear(setup,from,to,float(index%13)/16.0,1.8,[shape],[],[],"Seeded full clear "+str(index))
	# An unsupported native tile must only fall back its triangle loop, after heights.
	var bad: Array=collision.tiles[0].duplicate(true);bad[0].a.x=NAN;collision.drive_native_cache.forget("tile:0");collision.tiles[0]=bad
	compare_clear(setup,Vector3(1,1,0),Vector3(2,1,0),0.3,1.8,[],[],[],"NaN native rejection keeps script behavior")
	check(collision.drive_native_cache.stats.unsupported>0,"Malformed native batch fallback actually exercised")
	setup.owner.free()
func calculation_lifetimes()->void:
	var cache:=Cache.new();cache.enabled=true
	var source: Array=[tri(Vector3.ZERO,Vector3(10,0,0),Vector3(0,10,0))]
	var a: RefCounted=cache.batch("tile:0",source,true)
	check(a!=null and cache.bytes>0,"Bounded calculation cache admission")
	check(is_same(a,cache.batch("tile:0",source,true)),"Immutable source identity retains exact calculation")
	var replacement:=source.duplicate(true);var b: RefCounted=cache.batch("tile:0",replacement,true)
	check(b!=null and not is_same(a,b),"Array replacement invalidates even if equal contents")
	replacement.append(replacement[0]);var c: RefCounted=cache.batch("tile:0",replacement,true)
	check(c!=null and not is_same(c,b),"Changed source count invalidates")
	a=null;b=null;var weak:=weakref(c);c=null;cache.clear()
	check(weak.get_ref()==null and cache.entries.is_empty() and cache.bytes==0,"Clear retires native owner and payload charge")
	cache.maximum_bytes=1;check(cache.batch("tile:0",source,true)==null and cache.bytes==0,"Payload budget falls back without partial retained ownership")
	cache.maximum_bytes=1024*1024;cache.maximum_entries=0;check(cache.batch("tile:0",source,true)==null,"Entry budget explicit fallback")
	var setup:=make_world();var world=setup.world;var collision=setup.collision;collision.drive_native_cache.enabled=true
	collision.publish_model("chest:placeable",{"states":[footprint()]});collision.publish_model("gate:door",{"states":[footprint(),{"vertices":[],"faces":[]}]})
	world.receive([creature(1,Vector2(1,1)),object(2,Vector2(4,1)),object(3,Vector2(9,1),10)],1)
	collision.query(1).call(Vector3(2,1.5,0),Vector3(6,1.5,0))
	var configured: int=collision.drive_native_cache.stats.configured
	world.receive_delta([creature(7,Vector2(40,40))],[],1)
	check(collision.drive_native_cache.entries.size()>0 and collision.drive_native_cache.stats.configured==configured,"Same-scope unrelated delta does not clear retained typed geometry")
	var key: String=collision.drive_native_cache.object_key(collision.objects[2]);check(collision.drive_native_cache.entries.has(key),"Object calculation actually retained")
	world.receive_delta([], [2],1)
	check(not collision.drive_native_cache.entries.has(key),"Removal releases calculations before source owner retirement")
	var old_tile: RefCounted=collision.drive_native_cache.entries["tile:0"].native
	world.generation+=1;collision.ensure_spatial_scope()
	check(collision.drive_native_cache.entries.is_empty(),"New area generation clears all calculation references")
	check(old_tile!=null,"An explicit consumer may retain detached old calculation, never rebound")
	world.free()
func physical_mode_isolation()->void:
	var native: RefCounted=ClassDB.instantiate(&"NwnSceneGeometry")
	var physical:={"vertices":[0.0,0.0,0.0,10.0,0.0,0.0,0.0,10.0,0.0],"indices":[0,1,2],"planes":[0.0,0.0,1.0,0.0],"types":[0]}
	var ray:={"start":[1.0,1.0,3.0],"end":[1.0,1.0,-3.0]}
	check(native.call("dispatch",0,physical)==null,"Original physical configure keeps its return contract")
	var token: Variant=native.call("dispatch",2,{})
	var expected: Variant=native.call("dispatch",1,ray)
	check(token is int and token>0 and expected is Dictionary and expected.position==[1.0,1.0,0.0],"Original identity and physical ray remain usable")
	check(not native_request(native,Vector2.ZERO,Vector2.ONE).get("supported",false),"Physical batch cannot be interpreted as drive geometry")
	var result: Dictionary=native.call("dispatch",3,{"triangles":[tri(Vector3.ZERO,Vector3(10,0,0),Vector3(0,10,0))],"tile":true,"maximum_bytes":1024})
	check(result.get("supported",false),"Same Resource can explicitly replace physical mode with drive mode")
	check(native.call("dispatch",2,{}).has("error") and native.call("dispatch",1,ray).has("error"),"Drive-only mode cannot leak its token as usable physical geometry")
	check(native.call("dispatch",0,physical)==null and native.call("dispatch",2,{})==token and var_to_bytes(native.call("dispatch",1,ray))==var_to_bytes(expected),"Physical restoration keeps identity and exact ray result")
	check(not native_request(native,Vector2.ZERO,Vector2.ONE).get("supported",false),"Physical restoration destroys prior drive calculations")
func run()->void:
	check(ClassDB.class_exists(&"NwnSceneGeometry"),"Compiled optional class exists")
	if ClassDB.class_exists(&"NwnSceneGeometry"):
		loop_oracles();clear_oracles();calculation_lifetimes();physical_mode_isolation()
		# Existing full/delta/door/lifetime/streaming owners exercise compiled clear.
		lifecycle();streaming_motion()
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Private optional clear-only typed triangle loops, actual engine-vector exact spans and full-script clear ordering/results, failure fallback without repeated heights, calculation cache isolation/bounds/lifecycle and existing World full/delta/door/movement/removal tests. No height optimization, server, visual or performance claim."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var output:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);output.store_string(JSON.stringify(result,"  "));output.close()
	print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
