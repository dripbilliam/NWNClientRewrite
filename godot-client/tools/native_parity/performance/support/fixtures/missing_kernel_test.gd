extends SceneTree
const Geometry=preload("res://systems/native_render/scene_geometry.gd")
const Triangle=preload("res://systems/native_data/native_support_triangle.gd")
var checks:=0
var errors: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:errors.append(label)
func run() -> void:
	check(not ClassDB.class_exists("NwnSceneGeometry"),"fresh process has no native geometry class")
	var geometry=Geometry.new()
	geometry.configure({"vertices":PackedFloat32Array([-1,-1,1,1,-1,1,0,1,1]),"indices":PackedInt32Array([0,1,2]),"native_planes":PackedFloat32Array([0,0,1,-1]),"native_surface_types":PackedInt32Array([30])})
	var answer: Dictionary=Triangle.nearest(geometry,[0,0,3],[0,0,-2],{"node_is_aabb":false})
	check(answer.available and answer.hit and answer.position==[0.0,0.0,1.0] and answer.route=="gd-unmasked-trimesh","actual missing DLL falls back to ordinary unmasked GD")
	check(geometry.native_support_attempted and geometry.native_support_geometry==null and geometry.native_support_preparations==0,"missing kernel caches unavailable cold attempt")
	check(not geometry.native_support_reason.is_empty(),"missing-kernel diagnostic remains explicit")
	var repeat: Dictionary=Triangle.nearest(geometry,[0,0,3],[0,0,-2],{"node_is_aabb":false})
	check(repeat==answer,"repeat missing-kernel query preserves same fallback without reloading")
	var result:={"marker":"PRIVATE_UNMASKED_MISSING_KERNEL","checks":checks,"errors":errors,"expected_dependency_diagnostic":true,"scope":"One deliberate missing copied DLL, isolated project only"}
	var file:=FileAccess.open("res://result-missing.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close()
	print(JSON.stringify(result));quit(0 if errors.is_empty() else 1)
