extends MeshInstance3D

# World-space quads produced by the original-derived worker. This owner uploads
# whole packed streams; there is no GDScript physics or per-vertex frame loop.
const MAX_VERTICES := 196608
var capacity := 0
var vertex_count := 0
var epoch := -1
var sequence := -1
var stream_layout: Dictionary = {}
var retired := false
var source_texture: Texture2D
var additive := false
var two_sided := false
var engine_lighting := false
var draw_material: Material
static var lighting_shaders: Dictionary = {}

func configure(texture: Texture2D, owner_epoch: int, use_additive: bool = false, double_sided: bool = false, scene_lighting: bool = false) -> void:
	retire()
	retired = false
	sequence = -1
	stream_layout.clear()
	source_texture = texture
	epoch = owner_epoch
	additive = use_additive
	two_sided = double_sided
	engine_lighting = scene_lighting
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	transform = Transform3D.IDENTITY
	top_level = true

func _allocate(next_capacity: int) -> bool:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	vertices.resize(next_capacity)
	colors.resize(next_capacity)
	uvs.resize(next_capacity)
	colors.fill(Color(0, 0, 0, 0))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var dynamic := ArrayMesh.new()
	dynamic.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	var format: int = dynamic.surface_get_format(0)
	stream_layout = {
		"vertexStride": RenderingServer.mesh_surface_get_format_vertex_stride(format, next_capacity),
		"attributeStride": RenderingServer.mesh_surface_get_format_attribute_stride(format, next_capacity),
		"colorOffset": RenderingServer.mesh_surface_get_format_offset(format, next_capacity, Mesh.ARRAY_COLOR),
		"uvOffset": RenderingServer.mesh_surface_get_format_offset(format, next_capacity, Mesh.ARRAY_TEX_UV)
	}
	if stream_layout != {"vertexStride": 12, "attributeStride": 12, "colorOffset": 0, "uvOffset": 4}:
		return false
	# Texture/blend/lighting are immutable until configure(). Buffer growth
	# must not repeatedly allocate and retire a material/shader binding.
	if draw_material == null: draw_material = _material()
	dynamic.surface_set_material(0,draw_material)
	mesh = dynamic
	capacity = next_capacity
	return true

func _material() -> Material:
	if engine_lighting:
		var key := str(additive)+str(two_sided)
		if not lighting_shaders.has(key):
			var shader := Shader.new()
			# Point-sampled native particle tint is replaced by Godot scene
			# lighting, an explicit engine visual difference. No surface-normal
			# Lambert term: weather quads represent lit points, not solid faces.
			shader.code = "shader_type spatial; render_mode depth_draw_never,shadows_disabled,specular_disabled,"+("blend_add" if additive else "blend_mix")+","+("cull_disabled" if two_sided else "cull_front")+";\nuniform sampler2D original_texture : source_color,filter_linear_mipmap;\nvoid fragment(){vec4 value=texture(original_texture,UV)*COLOR; ALBEDO=value.rgb; ALPHA=value.a; SPECULAR=0.0;}\nvoid light(){DIFFUSE_LIGHT+=ATTENUATION*LIGHT_COLOR/PI;}"
			lighting_shaders[key] = shader
		var lit := ShaderMaterial.new();lit.shader = lighting_shaders[key];lit.set_shader_parameter("original_texture",source_texture)
		return lit
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	# The retained stream has Three/OpenGL front-face winding. Godot's front
	# triangles are clockwise; invert cull selection, preserving exact UV/RGBA
	# vertex order rather than reordering every worker-produced triangle.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED if two_sided else BaseMaterial3D.CULL_FRONT
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = false
	material.albedo_texture = source_texture
	material.disable_receive_shadows = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material

func apply_frame(owner_epoch: int, next_sequence: int, count: int, next_capacity: int, positions: PackedByteArray, attributes: PackedByteArray, bounds: AABB) -> bool:
	if retired or owner_epoch != epoch or next_sequence <= sequence:
		return false
	if count < 0 or count % 6 != 0 or next_capacity < count or next_capacity < capacity or next_capacity > MAX_VERTICES or next_capacity % 6 != 0 or positions.size() != next_capacity * 12 or attributes.size() != next_capacity * 12:
		return false
	if count > 0 and (not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x < 0 or bounds.size.y < 0 or bounds.size.z < 0):
		return false
	if next_capacity > capacity and not _allocate(next_capacity):
		return false
	if capacity > 0:
		RenderingServer.mesh_surface_update_vertex_region(mesh.get_rid(), 0, 0, positions)
		RenderingServer.mesh_surface_update_attribute_region(mesh.get_rid(), 0, 0, attributes)
		custom_aabb = bounds.grow(0.001) if count > 0 else AABB()
	sequence = next_sequence
	vertex_count = count
	visible = count > 0
	return true

func retire() -> void:
	retired = true
	visible = false
	mesh = null
	draw_material = null
	source_texture = null
	capacity = 0
	vertex_count = 0
