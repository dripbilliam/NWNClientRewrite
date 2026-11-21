extends Node3D
# Direct counterpart of world_highlight_renderer.js. The visible model parts
# contribute their local boxes to one three-plane, per-instance colour draw.
const SHADER_CODE:="""
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_test_disabled, depth_draw_never, fog_disabled;
uniform float highlight_time = 0.0;
varying vec2 highlight_uv;
varying vec3 highlight_tint;
varying float highlight_facing;
void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 face_normal = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	highlight_facing = pow(abs(dot(face_normal, normalize(-view.xyz))), 2.0);
	highlight_uv = UV;
	highlight_tint = COLOR.rgb;
}
void fragment() {
	vec2 p = highlight_uv * 2.0 - 1.0;
	float glow = pow(max(0.0, 1.0 - dot(p, p)), 1.4);
	float alpha = glow * highlight_facing * (0.50 + 0.04 * sin(highlight_time * 4.0));
	ALBEDO = highlight_tint;
	ALPHA = alpha;
}
"""

var geometry: ArrayMesh
var material: ShaderMaterial
var draw: MultiMeshInstance3D
var instances: MultiMesh
var capacity:=0
var parts:=0
var entry_bounds: Dictionary={}
var revision:=0
var mesh_cache: Dictionary={}

func _ready() -> void:
	get_tree().node_added.connect(_hierarchy_changed)
	get_tree().node_removed.connect(_hierarchy_changed)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_hierarchy_changed):get_tree().node_added.disconnect(_hierarchy_changed)
	if get_tree().node_removed.is_connected(_hierarchy_changed):get_tree().node_removed.disconnect(_hierarchy_changed)
	clear()

func _hierarchy_changed(_node: Node) -> void:
	revision+=1

func _part_geometry() -> ArrayMesh:
	var positions:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var uvs:=PackedVector2Array()
	var order:=[0,1,2,0,2,3]
	var corners:=[Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]
	for axis in 3:
		for index in order:
			var point:=Vector3.ZERO
			var normal:=Vector3.ZERO
			var corner: Vector2=corners[index]
			point[(axis+1)%3]=corner.x
			point[(axis+2)%3]=corner.y
			normal[axis]=1.0
			positions.append(point)
			normals.append(normal)
			uvs.append(corner+Vector2(0.5,0.5))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=positions
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	var result:=ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func reserve(count: int) -> void:
	if count<=capacity:return
	if geometry==null:geometry=_part_geometry()
	if material==null:
		material=ShaderMaterial.new()
		var program:=Shader.new()
		program.code=SHADER_CODE
		material.shader=program
		material.render_priority=5
	if draw==null:
		draw=MultiMeshInstance3D.new()
		draw.name="Object highlights"
		draw.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		draw.ignore_occlusion_culling=true
		draw.material_override=material
		draw.set_meta("ignoreWorldPicking",true)
		add_child(draw)
	capacity=32
	while capacity<count:capacity*=2
	instances=MultiMesh.new()
	instances.transform_format=MultiMesh.TRANSFORM_3D
	instances.use_colors=true
	instances.mesh=geometry
	instances.instance_count=capacity
	instances.visible_instance_count=0
	draw.multimesh=instances
	# world_highlight_renderer.js sets frustumCulled=false for this whole
	# instanced draw; an enlarged AABB still culls at distant view origins.
	RenderingServer.instance_set_ignore_culling(draw.get_instance(),true)

func _gather(node: Node,result: Array) -> void:
	if node is MeshInstance3D and node.mesh!=null and node.has_meta("native_mesh_source"):
		result.append(node)
	for child in node.get_children():_gather(child,result)

func meshes(root: Node3D) -> Array:
	var record: Dictionary=mesh_cache.get(root,{})
	if int(record.get("revision",-1))!=revision:
		var found: Array=[]
		_gather(root,found)
		record={"revision":revision,"meshes":found}
		mesh_cache[root]=record
	return record.meshes

func mesh_visible(mesh: MeshInstance3D,root: Node3D) -> bool:
	if not is_instance_valid(mesh) or mesh.mesh==null or not mesh.has_meta("native_mesh_source"):return false
	var ancestor: Node=mesh
	while ancestor!=null:
		if ancestor is CanvasItem and not ancestor.visible:return false
		if ancestor is Node3D and not ancestor.visible:return false
		if ancestor==root:break
		ancestor=ancestor.get_parent()
	if bool(mesh.get_meta("native_transition_surface",false)) or bool(mesh.get_meta("native_object_hit_mesh",false)):return true
	if mesh.transparency>=0.99:return false
	for surface in mesh.mesh.get_surface_count():
		var value: Material=mesh.get_active_material(surface)
		# The old predicate requires a visible material with opacity > .01;
		# a surface without a material is not evidence that the part is visible.
		if value==null:continue
		if value is BaseMaterial3D and value.albedo_color.a>0.01:return true
		if value is ShaderMaterial:
			var alpha: Variant=value.get_shader_parameter("native_alpha")
			if alpha==null or float(alpha)>0.01:return true
	return false

func update(entries: Array,time_ms: float) -> void:
	parts=0
	entry_bounds.clear()
	# WorldHighlightView drops cached roots not selected this frame, including
	# the empty selection. Do this before the early no-parts branches.
	var used_roots: Dictionary={}
	for entry in entries:used_roots[entry.root]=true
	for root in mesh_cache.keys():
		if not used_roots.has(root):mesh_cache.erase(root)
	if entries.is_empty():clear();return
	var requested:=0
	for entry in entries:requested+=entry.meshes.size()
	if requested==0:clear();return
	reserve(requested)
	material.set_shader_parameter("highlight_time",time_ms/1000.0)
	for entry in entries:
		var root: Node3D=entry.root
		var box:=AABB()
		var has_box:=false
		for mesh in entry.meshes:
			if not mesh_visible(mesh,root):continue
			var local_box: AABB=mesh.get_aabb()
			if local_box.size==Vector3.ZERO:continue
			var world_box: AABB=mesh.global_transform*local_box
			box=box.merge(world_box) if has_box else world_box
			has_box=true
			var size: Vector3=local_box.size*1.75
			size=Vector3(maxf(0.07,size.x),maxf(0.07,size.y),maxf(0.07,size.z))
			var local_pose:=Transform3D(Basis.from_scale(size),local_box.get_center())
			var pose: Transform3D=global_transform.affine_inverse()*mesh.global_transform*local_pose
			instances.set_instance_transform(parts,pose)
			instances.set_instance_color(parts,entry.color.srgb_to_linear())
			parts+=1
		entry_bounds[int(entry.id)]=box if has_box else null
	instances.visible_instance_count=parts
	draw.visible=parts>0

func clear() -> void:
	parts=0
	entry_bounds.clear()
	if instances!=null:instances.visible_instance_count=0
	if draw!=null:draw.visible=false

func dispose() -> void:
	clear()
	mesh_cache.clear()
	if draw!=null:draw.queue_free()
	draw=null
	instances=null
	material=null
	geometry=null
	capacity=0
