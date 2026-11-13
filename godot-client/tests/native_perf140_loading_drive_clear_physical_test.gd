extends SceneTree
# Deferred isolated regression entry. No graphics, world, network or worker.
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Collision=preload("res://systems/native_render/drive_collision_indexed.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
class Floor:
	extends Node
	var definition:={"width":1,"height":1}
	var calls: Array=[]
	func height(point: Vector3,previous: float)->float:calls.append([point,previous]);return 0.0
class Owner:
	extends Node
	var surface
var checks:=0
var failures: Array=[]
var sources: Array=[]
var ray_queries:=0
var native_resources:=0
var clear_activation: Dictionary={}
func check(value: bool,label: String)->void:
	checks+=1
	if not value and failures.size()<50:failures.append(label)
func _initialize()->void:call_deferred("run")
func digest(bytes: PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func tri(a: Vector3,b: Vector3,c: Vector3,walk: bool=true)->Dictionary:
	var value:=Collision.triangle(a,b,c);value.walk=walk;return value
func mode_isolation()->void:
	var native: RefCounted=ClassDB.instantiate(&"NwnSceneGeometry")
	var physical:={"vertices":PackedFloat32Array([0,0,0,10,0,0,0,10,0]),"indices":PackedInt32Array([0,1,2]),"planes":PackedFloat32Array([0,0,1,0]),"types":PackedInt32Array([0])}
	var ray:={"start":[1.0,1.0,3.0],"end":[1.0,1.0,-3.0]}
	check(native.call("dispatch",0,physical)==null,"Original physical configure return contract")
	var token: Variant=native.call("dispatch",2,{})
	var expected: Variant=native.call("dispatch",1,ray)
	check(token is int and token>0 and expected is Dictionary and expected.position==[1.0,1.0,0.0],"Original physical identity and ray are live")
	var drive_query:={"a":Vector2(1,1),"b":Vector2(2,1),"radius":0.3,"low":-0.1,"high":2.0}
	check(not native.call("dispatch",4,drive_query).get("supported",false),"Physical data cannot masquerade as drive data")
	var setup: Dictionary=native.call("dispatch",3,{"triangles":[tri(Vector3.ZERO,Vector3(10,0,0),Vector3(0,10,0))],"tile":true,"maximum_bytes":1024})
	check(setup.get("supported",false),"Optional drive batch configured")
	check(native.call("dispatch",2,{}).has("error") and native.call("dispatch",1,ray).has("error"),"Drive-only mode has no usable physical identity/query")
	check(native.call("dispatch",4,drive_query).get("supported",false),"Drive query uses configured typed source")
	check(native.call("dispatch",0,physical)==null and native.call("dispatch",2,{})==token and var_to_bytes(native.call("dispatch",1,ray))==var_to_bytes(expected),"Physical restore keeps original token and exact ray bytes")
	check(not native.call("dispatch",4,drive_query).get("supported",false),"Physical restore retires drive calculations")
	physical.types=PackedInt32Array([30]);native.call("dispatch",0,physical)
	check(native.call("dispatch",1,ray)==null,"Original physical material30 exclusion remains")
func script_clear_route()->void:
	var owner:=Owner.new();root.add_child(owner);var floor:=Floor.new();owner.add_child(floor);owner.surface=floor
	var collision:=Collision.new();owner.add_child(collision);collision.world=owner;collision.set_process(false)
	collision.tiles[0]=[tri(Vector3.ZERO,Vector3(10,0,0),Vector3(10,10,0)),tri(Vector3.ZERO,Vector3(10,10,0),Vector3(0,10,0))]
	var expected_native: bool=OS.get_cmdline_user_args().has("--drive-clear=native")
	check(collision.drive_native_cache.enabled==expected_native,"Launch-time clear route matches requested flag")
	var a:=Vector3(1,1,0);var b:=Vector3(2,1,0)
	var reference: bool=collision._drive_clear_reference(a,b,0.3,1.8,[],[],[]);var reference_calls:=var_to_bytes(floor.calls);floor.calls=[]
	var selected: bool=collision._drive_clear_unprofiled(a,b,0.3,1.8,[],[],[])
	check(reference and selected==reference and var_to_bytes(floor.calls)==reference_calls,"Selected branch keeps free-floor result and exact two original height calls")
	var face:=tri(Vector3(1.5,0,-1),Vector3(1.5,10,-1),Vector3(1.5,10,3),false)
	var shape:={"signature":[1],"triangles":[face],"min":face.min,"max":face.max}
	floor.calls=[];collision.stats={"queries":0,"blocked":0,"reasons":{}}
	reference=collision._drive_clear_reference(a,b,0.3,1.8,[shape],[],[]);var previous:=var_to_bytes(collision.stats);reference_calls=var_to_bytes(floor.calls)
	floor.calls=[];collision.stats={"queries":0,"blocked":0,"reasons":{}}
	selected=collision._drive_clear_unprofiled(a,b,0.3,1.8,[shape],[],[])
	check(not reference and selected==reference and var_to_bytes(collision.stats)==previous and var_to_bytes(floor.calls)==reference_calls,"Selected branch keeps exact object denial and height side effects")
	if expected_native:check(collision.drive_native_cache.stats.configured>0 and collision.drive_native_cache.stats.queries>0,"Native opt-in actually configured/queried typed loops")
	else:check(collision.drive_native_cache.entries.is_empty() and collision.drive_native_cache.stats.queries==0,"Script control performs no native drive preparation/query")
	clear_activation={"requested":expected_native,"enabled":collision.drive_native_cache.enabled,"configured":collision.drive_native_cache.stats.configured,"queries":collision.drive_native_cache.stats.queries,"last_height_calls":floor.calls.size()}
	owner.free()
func reference_hit(mesh: Dictionary,start: Array,end: Array)->Variant:
	var limit: Array=end.duplicate();var result: Variant=null
	for index in mesh.faces.size():
		if (int(mesh.materials[index])&63)==30:continue
		var face: Array=mesh.faces[index];var hit: Variant=Polygon.hit([mesh.vertices[face[0]],mesh.vertices[face[1]],mesh.vertices[face[2]]],mesh.normals[index],mesh.constants[index],start,limit)
		if hit!=null:result={"position":hit,"normal":mesh.normals[index]};limit=hit
	return result
func original_wok(args: Dictionary)->void:
	var catalog
	var names: Array=[]
	var expected_hashes: Dictionary={}
	if args.has("catalog"):
		catalog=Recorded.new();check(catalog.mount(str(args.catalog)),"Sealed WOK catalog mounts read-only")
		names=Array(str(args.get("models","ttu01_w06_01,ttu01_a01_01,ttu01_a01_02,ttu01_a01_03,ttu01_a02_01,ttu01_a02_02")).split(",",false))
	elif args.has("fixture"):
		var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(args.fixture)))
		check(fixture is Dictionary and fixture.get("install") is String and fixture.get("samples") is Array,"Existing original-surface descriptor")
		if not fixture is Dictionary or not fixture.get("install") is String or not fixture.get("samples") is Array:return
		catalog=Catalog.new();check(catalog.mount_install(str(fixture.install)),"Original WOK installation mounts read-only")
		for sample in fixture.samples.slice(0,5):names.append(str(sample.name));expected_hashes[str(sample.name)]=str(sample.sha256)
		names.append("ttr01_g01_01")
	else:check(false,"An explicit read-only original/recorded WOK source is required");return
	if not failures.is_empty():return
	check(not names.is_empty() and names.size()<=8,"Bounded original WOK corpus")
	if names.is_empty() or names.size()>8:return
	for name in names:
		var bytes: PackedByteArray=catalog.get_resource(str(name),2016);var hash:=digest(bytes)
		check(not bytes.is_empty() and catalog.failure.is_empty(),"Original WOK bytes "+str(name))
		if expected_hashes.has(name):check(hash==expected_hashes[name],"Original fixture byte identity "+str(name))
		var parser:=Surface.new();var source:=parser.parse_bytes(bytes)
		check(parser.failure.is_empty() and not source.is_empty(),"Original physical WOK decodes "+str(name))
		if source.is_empty():continue
		sources.append({"resource":name,"type":2016,"sha256":hash,"faces":source.faces.size()})
		var vertices:=PackedFloat32Array();var indices:=PackedInt32Array();var planes:=PackedFloat32Array()
		for vertex in source.vertices:vertices.append_array(PackedFloat32Array(vertex))
		for index in source.faces.size():indices.append_array(PackedInt32Array(source.faces[index]));planes.append_array(PackedFloat32Array(source.normals[index]+[source.constants[index]]))
		var geometry:=Geometry.new();geometry.configure({"vertices":vertices,"indices":indices,"native_planes":planes,"native_surface_types":PackedInt32Array(source.materials)})
		var native_resource: RefCounted=geometry.prepare_native()
		check(native_resource!=null,"Existing physical Geometry Resource actually uses native operations "+str(name))
		if native_resource!=null:native_resources+=1
		for orientation in 4:
			for query in 121:
				var xy:=Surface.canonical([Surface.f((query%11)-0.001),Surface.f(int(query/11)+0.001)],posmod(4-orientation,4));var local:=Surface.canonical(xy,orientation)
				var start: Array=[local[0],local[1],30.0];var end: Array=[local[0],local[1],-30.0]
				var expected: Variant=reference_hit(source,start,end);var actual: Variant=geometry.nearest(start,end,true,true);ray_queries+=1
				if expected==null:check(actual==null,"Physical no-hit matches retained predicate "+str(name))
				else:check(actual is Dictionary and var_to_bytes(actual.position)==var_to_bytes(expected.position) and var_to_bytes(actual.normal)==var_to_bytes(expected.normal),"Physical point/normal bits and source-order ray reduction "+str(name))
func run()->void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(str(args.report)):quit(2);return
	check(Kernel.enabled() and Kernel.available(),"Explicit supported compiled-kernel switch actually activates the private provider")
	check(ClassDB.class_exists(&"NwnSceneGeometry"),"Private native geometry provider available")
	if ClassDB.class_exists(&"NwnSceneGeometry"):mode_isolation();script_clear_route();original_wok(args)
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"rays":ray_queries,"sources":sources,"native_resources":native_resources,"native_clear_requested":OS.get_cmdline_user_args().has("--drive-clear=native"),"clear_activation":clear_activation,"activation":{"pid":OS.get_process_id(),"display":DisplayServer.get_name(),"executable":OS.get_executable_path(),"kernel_enabled":Kernel.enabled(),"native_class":ClassDB.class_exists(&"NwnSceneGeometry"),"library_file":ProjectSettings.globalize_path("res://.cache/native-kernel/nwn-particle-kernel.dll")},"scope":"Deferred offline physical-WOK native point/normal/original-predicate regression and distinct script/native clear route/mode isolation. No world rendering, server, clean timing or visual acceptance."}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print(JSON.stringify({"success":result.success,"checks":checks,"rays":ray_queries,"failures":failures}));quit(0 if failures.is_empty() else 1)
