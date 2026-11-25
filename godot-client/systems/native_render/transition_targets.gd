extends Node3D
# Trigger surfaces, separate from the model streaming registry.
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
	const Highlight=preload("res://systems/native_render/transition_surface_highlight.gdshader")
	var meshes: Array=[]
	var pick_surfaces: Array=[]
	var highlight_vertices: PackedVector3Array
	var highlight_bounds: AABB
	var highlight_half_height:=0.0
	var highlight: MeshInstance3D

	func configure_highlight(vertices: PackedVector3Array,bounds: AABB,height: Variant) -> void:
		if (height is int or height is float) and is_finite(float(height)):
			highlight_half_height=absf(float(height))
			highlight_vertices=vertices
			highlight_bounds=bounds

	func set_hovered(hovered: bool) -> void:
		if hovered and highlight==null and highlight_half_height>0.0 and not is_queued_for_deletion():
			var center:=highlight_bounds.get_center()
			var offsets:=PackedVector3Array()
			for vertex in highlight_vertices:
				offsets.append(vertex-center)
			var material:=ShaderMaterial.new()
			material.shader=Highlight
			material.set_shader_parameter("polygon",offsets)
			material.set_shader_parameter("vertex_count",offsets.size())
			material.set_shader_parameter("half_height",highlight_half_height)
			# The box only bounds the projection. The shader clips the scene
			# depth to the original trigger's polygon and height.
			var box:=BoxMesh.new()
			box.size=highlight_bounds.size+Vector3.UP*(highlight_half_height*2.0)
			highlight=MeshInstance3D.new()
			highlight.mesh=box
			highlight.position=center
			highlight.material_override=material
			highlight.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(highlight)
		if highlight!=null:
			highlight.visible=hovered and not is_queued_for_deletion()

func configure(value,area: int) -> void: registry=value; area_id=area
func forget(id: int) -> void:
	if instances.has(id):
		var target: Target=instances[id]
		if is_instance_valid(registry) and registry.native_owners.get(id)==target: registry.forget_entity(id)
		target.set_hovered(false)
		target.queue_free()
		instances.erase(id)
		stats.removed+=1
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
		var replicated: Dictionary=object.get("replicated",{})
		var transition_flags: Variant=replicated.get("interactionFlags")
		# For a nontrap trigger, 1407b1d30 replaces the transition flag with
		# the first received bit. This only gates presentation here.
		if not transition_flags is Array or transition_flags.is_empty() or bool(transition_flags[0]):
			# 1407b1670 receives the half-height before the vertex count.
			target.configure_highlight(data.vertices,data.bounds,replicated.get("field40c"))
		var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=data.vertices; arrays[Mesh.ARRAY_INDEX]=data.indices
		var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var visual:=MeshInstance3D.new(); visual.mesh=mesh
		var material:=StandardMaterial3D.new(); material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.albedo_color=Color(0,0,0,0); material.cull_mode=BaseMaterial3D.CULL_DISABLED; material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
		visual.material_override=material; visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		material.set_meta("native_invisible_pick",true)
		var shape:=ConcavePolygonShape3D.new(); shape.set_faces(data.faces); shape.backface_collision=true
		visual.set_meta("native_pick_shape",shape); visual.set_meta("native_pick_bounds",data.bounds); target.add_child(visual); target.meshes=[visual]
		var raw_name: Variant=replicated.get("name",{})
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
