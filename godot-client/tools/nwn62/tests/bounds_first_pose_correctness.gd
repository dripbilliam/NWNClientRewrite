extends SceneTree

const Template=preload("res://systems/native_render/model_template.gd")
class Source:
	extends Node3D
	var meshes: Array=[]
	var pick_surfaces: Array=[]

var checks:=0
var failures: Array[String]=[]
var report:=""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	call_deferred("run")

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)

func make_source(count: int) -> Source:
	var source:=Source.new()
	var parents: Array[Node3D]=[]
	for index in 7:
		var parent:=Node3D.new()
		(source if index==0 else parents[int((index-1)/2)]).add_child(parent)
		parent.position=Vector3(index*0.17,-index*0.11,index*0.07)
		parent.quaternion=Quaternion.from_euler(Vector3(index*0.03,index*-0.05,index*0.02))
		parent.scale=Vector3(1.0+index*0.01,0.9+index*0.02,1.1-index*0.01)
		parents.append(parent)
	for index in count:
		var parent: Node3D=parents[index%parents.size()]
		var mesh:=MeshInstance3D.new();parent.add_child(mesh)
		mesh.position=Vector3(index*0.013,index*-0.02,index*0.009)
		mesh.quaternion=Quaternion(Vector3.UP,index*0.007)
		var geometry:=ArrayMesh.new()
		geometry.set_meta("native_scene_geometry",{"indices":[0,1,2],"bounds":AABB(Vector3(-0.4,-0.2,-0.3),Vector3(1.2,0.9,0.7))})
		mesh.mesh=geometry;source.meshes.append(mesh)
	var pick:=Node3D.new();parents[3].add_child(pick)
	var hidden:=ArrayMesh.new()
	hidden.set_meta("native_scene_geometry",{"indices":[0,1,2],"bounds":AABB(Vector3(-1.0,-0.8,-0.2),Vector3(1.1,1.3,0.6))})
	pick.set_meta("native_pick_geometry",hidden);source.pick_surfaces.append(pick)
	return source

func original_surface_bounds(source: Source,node: Node) -> Dictionary:
	var result:={"valid":false,"bounds":AABB()};var data=null
	if node is MeshInstance3D:data=node.mesh.get_meta("native_scene_geometry",null)
	elif node.has_meta("native_pick_geometry"):data=node.get_meta("native_pick_geometry").get_meta("native_scene_geometry",null)
	if data==null or data.indices.is_empty():return result
	var box: AABB=data.bounds;var local:=AABB(Vector3(box.position.x,box.position.z,-box.end.y),Vector3(box.size.x,box.size.z,box.size.y));var pose:=Transform3D.IDENTITY;var parent: Node=node
	while parent!=source and parent!=null:
		if parent is Node3D:pose=parent.transform*pose
		parent=parent.get_parent()
	result.bounds=pose*local;result.valid=true;return result

func inspect(count: int) -> void:
	var source:=make_source(count)
	var expected:={"valid":false,"bounds":AABB()}
	for node in source.meshes+source.pick_surfaces:
		var plain: Dictionary=original_surface_bounds(source,node)
		var reduced: Dictionary=Template.scene_surface_bounds(source,node)
		check(var_to_bytes(plain)==var_to_bytes(reduced),"Exact surface bounds with %d meshes"%count)
		if plain.valid:
			expected.bounds=expected.bounds.merge(plain.bounds) if expected.valid else plain.bounds
			expected.valid=true
	check(var_to_bytes(Template.scene_bounds(source))==var_to_bytes(expected),"Exact aggregate bounds with %d meshes"%count)
	source.free()

func run() -> void:
	inspect(4)
	inspect(80)
	var result:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Detached model collision bounds: original versus first-pose direct assignment, small and large branching hierarchies. No loading latency or FPS timing."}
	if not report.is_empty():
		var file:=FileAccess.open(report,FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify(result,"\t")+"\n")
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
