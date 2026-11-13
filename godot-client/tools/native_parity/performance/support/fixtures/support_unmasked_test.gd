extends SceneTree
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Triangle=preload("res://systems/native_data/native_support_triangle.gd")
const OriginalTriangle=preload("res://reference_triangle.gd")
const OriginalGeometry=preload("res://reference_geometry.gd")
const Polygon=preload("res://systems/native_data/polygon_hit.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
var checks:=0
var errors: Array=[]
var cases: Array=[]

class NoNativeGeometry extends Geometry:
	func prepare_native() -> RefCounted:return null
	func prepare_native_unmasked_support() -> RefCounted:return null

class QueryErrorGeometry extends Geometry:
	func prepare_native_unmasked_support() -> RefCounted:
		# Real existing native class, deliberately queried before configuration.
		return ClassDB.instantiate("NwnSceneGeometry")

func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:errors.append(label)

func data(faces: Array) -> Dictionary:
	var vertices:=PackedFloat32Array();var indices:=PackedInt32Array()
	var planes:=PackedFloat32Array();var types:=PackedInt32Array()
	for entry: Dictionary in faces:
		var z:=float(entry.z);var slope:=float(entry.get("slope",0))
		var points: Array=[[-1.0,-1.0,z-slope],[1.0,-1.0,z+slope],[0.0,1.0,z]]
		var plane: Dictionary=Polygon.plane(points)
		for point: Array in points:
			indices.append(vertices.size()/3);vertices.append_array(PackedFloat32Array(point))
		planes.append_array(PackedFloat32Array([plane.normal[0],plane.normal[1],plane.normal[2],plane.constant]))
		types.append(int(entry.type))
	return {"vertices":vertices,"indices":indices,"native_planes":planes,"native_surface_types":types}

func same_answer(actual: Dictionary,expected: Dictionary,label: String) -> void:
	check(actual.available==expected.available,label+" availability")
	check(actual.get("hit")==expected.get("hit"),label+" hit")
	if actual.get("hit",false) and expected.get("hit",false):
		check(actual.position==expected.position,label+" exact f32 point")
		check(actual.normal==expected.normal,label+" exact f32 normal")

func compare_case(label: String,faces: Array,aabb: bool,start: Array,end: Array,expected_hit: bool,expected_z: float=0.0) -> void:
	var actual=Geometry.new();var fallback=NoNativeGeometry.new()
	var source:=data(faces);actual.configure(source);fallback.configure(source)
	var baseline: Dictionary=OriginalTriangle.nearest(fallback,start,end,{"node_is_aabb":aabb})
	var candidate: Dictionary=Triangle.nearest(actual,start,end,{"node_is_aabb":aabb})
	same_answer(candidate,baseline,label)
	check(candidate.available and candidate.hit==expected_hit,label+" original policy expected hit")
	# Analytical plane height is a policy assertion only; exact FLOAT equality
	# is asserted separately against the original GD operations above.
	if expected_hit:check(absf(candidate.position[2]-expected_z)<0.000001,label+" expected nearest plane")
	var compiled:=not OS.get_cmdline_user_args().has("--scene-geometry=gd") and Kernel.enabled()
	check(candidate.route==("compiled-raw" if compiled else ("gd-aabb-mask" if aabb else "gd-unmasked-trimesh")),label+" route")
	check(actual.surface_types==source.native_surface_types,label+" original material metadata retained")
	if compiled and not aabb:
		check(actual.native_geometry==null,label+" ordinary query leaves canonical owner cold")
		check(actual.native_support_preparations==1,label+" one cold support preparation")
	cases.append({"label":label,"route":candidate.route,"hit":candidate.hit,"position":candidate.get("position"),"normal":candidate.get("normal")})

func released_support_owner() -> WeakRef:
	# Exit the function to release GDScript expression temporaries as well as
	# the resource. A null assignment alone does not promise their lifetime.
	var geometry=Geometry.new();geometry.configure(data([{"z":1,"type":30}]))
	Triangle.nearest(geometry,[0,0,3],[0,0,-2],{"node_is_aabb":false})
	return weakref(geometry.native_support_geometry)

func run() -> void:
	var forced_gd:=OS.get_cmdline_user_args().has("--scene-geometry=gd") or not Kernel.enabled()
	if not forced_gd:check(Kernel.available() and ClassDB.class_exists("NwnSceneGeometry"),"exact copied DLL classes available")
	compare_case("ordinary30",[{"z":1,"type":30}],false,[0,0,3],[0,0,-2],true,1)
	compare_case("ordinary94",[{"z":1,"type":94}],false,[0,0,3],[0,0,-2],true,1)
	compare_case("aabb30",[{"z":1,"type":30}],true,[0,0,3],[0,0,-2],false)
	compare_case("aabb94",[{"z":1,"type":94}],true,[0,0,3],[0,0,-2],false)
	compare_case("ordinary mixed physical order",[{"z":0,"type":1},{"z":2,"type":30},{"z":1,"type":94}],false,[0,0,3],[0,0,-2],true,2)
	compare_case("aabb mixed physical order",[{"z":0,"type":1},{"z":2,"type":30},{"z":1,"type":94}],true,[0,0,3],[0,0,-2],true,0)
	compare_case("ordinary reverse face order",[{"z":2,"type":30},{"z":0,"type":1},{"z":1,"type":94}],false,[0,0,3],[0,0,-2],true,2)
	compare_case("inclusive edge",[{"z":1,"type":30}],false,[-1,-1,3],[-1,-1,-2],true,1)
	compare_case("back-to-front",[{"z":1,"type":30}],false,[0,0,-2],[0,0,3],false)
	compare_case("endpoint tie face order",[{"z":1,"type":0},{"z":1,"type":30,"slope":0.25}],false,[0,0,3],[0,0,-2],true,1)
	compare_case("endpoint tie reversed",[{"z":1,"type":30,"slope":0.25},{"z":1,"type":0}],false,[0,0,3],[0,0,-2],true,1)
	# Canonical owner remains masked before and after ordinary support warming.
	var g=Geometry.new();var source:=data([{"z":0,"type":1},{"z":2,"type":30}]);g.configure(source)
	var canonical_gd: Variant=g.nearest([0,0,3],[0,0,-2],true,false)
	var canonical: Variant=g.nearest([0,0,3],[0,0,-2],true,true)
	check(canonical==canonical_gd and absf(canonical.position[2])<0.000001,"canonical nearest remains masked")
	var support: Dictionary=Triangle.nearest(g,[0,0,3],[0,0,-2],{"node_is_aabb":false})
	check(support.hit and absf(support.position[2]-2)<0.000001,"same resource ordinary support includes face30")
	check(g.nearest([0,0,3],[0,0,-2],true,true)==canonical,"support cannot contaminate canonical nearest")
	check(g.surface_types==source.native_surface_types,"no canonical surface-table mutation")
	if not forced_gd:
		var canonical_owner: RefCounted=g.native_geometry
		var support_owner: RefCounted=g.native_support_geometry
		check(canonical_owner!=null and support_owner!=null and not is_same(canonical_owner,support_owner),"owners are separate RefCounted instances")
		check(canonical_owner.call("dispatch",2,{})!=support_owner.call("dispatch",2,{}),"native owner tokens differ")
		var prepared_token: int=support_owner.call("dispatch",2,{})
		check(is_same(g.prepare_native_unmasked_support(),support_owner) and g.native_support_preparations==1,"repeat preparation reuses one cold owner")
		var weak_canonical:=weakref(canonical_owner);var weak_support:=weakref(support_owner)
		canonical_owner=null;support_owner=null
		g.configure(data([{"z":4,"type":94}]))
		check(g.native_geometry==null and g.native_support_geometry==null and not g.native_attempted and not g.native_support_attempted,"configure resets both owners and attempt flags")
		check(g.native_support_preparations==0,"configure resets cold-preparation counter")
		check(weak_canonical.get_ref()==null and weak_support.get_ref()==null,"configure releases unretained native owners")
		var renewed: Dictionary=Triangle.nearest(g,[0,0,5],[0,0,-2],{"node_is_aabb":false})
		check(renewed.hit and absf(renewed.position[2]-4)<0.000001,"reconfigured resource uses new original faces")
		check(int(g.native_support_geometry.call("dispatch",2,{}))!=prepared_token,"reconfigure creates a new native owner lifetime")
		check(g.nearest([0,0,5],[0,0,-2],true,true)==null,"reconfigured canonical still excludes94")
		g=null
		check(released_support_owner().get_ref()==null,"resource destruction releases unmasked owner")
	# Missing optional unmasked method preserves compatibility and exact fallback.
	var legacy=OriginalGeometry.new();legacy.configure(data([{"z":1,"type":30}]))
	var legacy_answer: Dictionary=Triangle.nearest(legacy,[0,0,3],[0,0,-2],{"node_is_aabb":false})
	check(legacy_answer.available and legacy_answer.hit and legacy_answer.route=="gd-unmasked-trimesh","older geometry without optional method falls back safely")
	var absent=NoNativeGeometry.new();absent.configure(data([{"z":1,"type":94}]))
	var absent_answer: Dictionary=Triangle.nearest(absent,[0,0,3],[0,0,-2],{"node_is_aabb":false})
	check(absent_answer.available and absent_answer.hit and absent_answer.route=="gd-unmasked-trimesh","unavailable/failed preparation retains GD fallback")
	var unknown: Dictionary=Triangle.nearest(absent,[0,0,3],[0,0,-2],{})
	check(not unknown.available and unknown.reason=="Native support Part subtype unavailable","missing native Part provenance still unavailable")
	var invalid: Dictionary=Triangle.nearest(absent,[NAN,0,3],[0,0,-2],{"node_is_aabb":false})
	check(not invalid.available and invalid.reason=="Nonfinite support segment","nonfinite segment still unavailable")
	if not forced_gd:
		var query_error=QueryErrorGeometry.new();query_error.configure(data([{"z":1,"type":30}]))
		var failed: Dictionary=Triangle.nearest(query_error,[0,0,3],[0,0,-2],{"node_is_aabb":false})
		check(not failed.available and failed.reason=="Native collision query before configuration","native dispatch error remains explicit unavailable")
	else:
		check(not g.native_support_attempted and g.native_support_geometry==null,"explicit GD mode never prepares unmasked native owner")
	var result:={"marker":"PRIVATE_UNMASKED_SUPPORT","mode":"gd" if forced_gd else "native","checks":checks,"errors":errors,"cases":cases,"native_builds":0,"gpu_runs":0,"scope":"Small original-face policy and GD/native comparison, not world integration or performance"}
	var file:=FileAccess.open("res://result-"+result.mode+".json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print(JSON.stringify(result));quit(0 if errors.is_empty() else 1)
