extends Node3D
# Selection-only trigger surfaces, separate from the model streaming registry.
# Walking into the received polygon lets the original server activate travel.
const Policy=preload("res://systems/native_interaction_policy.gd")
const Surface=preload("res://systems/native_data/transition_surface.gd")
var registry
var area_id:=-1
var objects: Dictionary={}
var instances: Dictionary={}
var closed:=false
var stats:={"registered":0,"removed":0,"invalid":0}
class Target extends Node3D:
	var meshes: Array=[]
	var pick_surfaces: Array=[]
func configure(value,area: int) -> void: registry=value; area_id=area
func forget(id: int) -> void:
	if is_instance_valid(registry): registry.forget_entity(id)
	if instances.has(id): instances[id].queue_free(); instances.erase(id); stats.removed+=1
	objects.erase(id)
func receive(rows: Array,removed: Array=[],delta: bool=false) -> bool:
	if closed: return false
	var previous:=int(stats.registered)+int(stats.removed)
	if not delta:
		var retained: Dictionary={}
		for object in rows:
			if int(object.get("objectType",0))==7: retained[int(object.id)]=true
		for id in objects.keys():
			if not retained.has(id): forget(int(id))
	for id in removed:
		if objects.has(int(id)): forget(int(id))
	for object in rows:
		var id:=int(object.id)
		if int(object.get("objectType",0))!=7:
			if objects.has(id): forget(id)
			continue
		if not Policy.eligible(object,area_id):
			if objects.has(id): forget(id)
			continue
		if objects.has(id) and objects[id]==object: continue
		var data:=Surface.prepare(object)
		if objects.has(id): forget(id)
		if data.is_empty(): stats.invalid+=1; continue
		var target:=Target.new(); add_child(target)
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=data.vertices; arrays[Mesh.ARRAY_INDEX]=data.indices
		var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var visual:=MeshInstance3D.new(); visual.mesh=mesh
		var material:=StandardMaterial3D.new(); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=Color(0,0,0,0); material.cull_mode=BaseMaterial3D.CULL_DISABLED; material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
		visual.material_override=material; visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		material.set_meta("native_invisible_pick",true)
		var shape:=ConcavePolygonShape3D.new(); shape.set_faces(data.faces); shape.backface_collision=true
		visual.set_meta("native_pick_shape",shape); visual.set_meta("native_pick_bounds",data.bounds); target.add_child(visual); target.meshes=[visual]
		var raw_name: Variant=object.get("replicated",{}).get("name",{})
		var name:=str(raw_name.get("text","Area transition")) if raw_name is Dictionary else "Area transition"
		objects[id]=object; instances[id]=target
		registry.register_native(id,{"id":id,"name":name,"type":7,"eligible":true,"color":"#55ddff","destination":data.destination},target); stats.registered+=1
	return int(stats.registered)+int(stats.removed)!=previous
func close() -> void:
	if closed: return
	closed=true
	for id in objects.keys(): forget(int(id))
	registry=null
func _exit_tree() -> void: close()
