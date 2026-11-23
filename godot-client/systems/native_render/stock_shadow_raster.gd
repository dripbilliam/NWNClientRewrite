extends RefCounted

const ShaderCode = preload("res://systems/native_render/stock_shadow_shader_code.gd")
const NEUTRAL_STENCIL := 0x7f
const FIRST_BUCKETS := [13, 14]
const PROJECTION_LIGHT_BUCKETS := [13, 11, 14, 12]

class Light:
	var position := Vector3.ZERO
	var radius := 0.0
	var shadow_radius := 0.0
	var vertical_displacement := 0.0
	var fade := 1.0
	var dynamic_projection_light := false
	var buckets: Dictionary[int, Array] = {}

	func source() -> Vector4:
		if radius > 1000.0:
			var direction := -position.normalized() if position != Vector3.ZERO else Vector3.LEFT
			return Vector4(direction.x, direction.y, direction.z, -1.0)
		return Vector4(position.x, position.y, position.z + vertical_displacement,
			shadow_radius if shadow_radius > 0.0 else radius)

class VolumeDraw:
	var vertices := RID()
	var indices := RID()
	var model_to_world := Transform3D.IDENTITY
	var world_z_clip := -20.0

var _rd: RenderingDevice
var _framebuffer := RID()
var _vertex_format := -1
var _camera_buffer := RID()
var _volume_camera := RID()
var _plane_camera := RID()
var _volume_pass := RID()
var _volume_fail := RID()
var _plane := RID()
var _stencil_reset := RID()
var _plane_buffers: Array[RID] = []
var _local_plane_arrays: Array[RID] = []
var _directional_plane_arrays: Array[RID] = []
var _plane_slot := 0
var _height := 0
var _resources: Array[RID] = []

func attach(device: RenderingDevice, color: RID, depth: RID,
		front_face: RenderingDevice.PolygonFrontFace) -> bool:
	release()
	if device == null or not color.is_valid() or not depth.is_valid():
		return false
	var depth_format := device.texture_get_format(depth)
	if depth_format.format not in [RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT,
			RenderingDevice.DATA_FORMAT_D32_SFLOAT_S8_UINT]:
		return false
	var color_format := device.texture_get_format(color)
	if (depth_format.height != color_format.height or depth_format.width != color_format.width
			or depth_format.samples != color_format.samples or depth_format.array_layers != 1):
		return false

	_rd = device
	_height = depth_format.height
	_framebuffer = _keep(_rd.framebuffer_create([color, depth]))
	if not _framebuffer.is_valid():
		release()
		return false
	var attribute := RDVertexAttribute.new()
	attribute.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	attribute.stride = 16
	_vertex_format = _rd.vertex_format_create([attribute])
	var volume_shader := _shader(ShaderCode.VOLUME_VERTEX, ShaderCode.VOLUME_FRAGMENT)
	var plane_shader := _shader(ShaderCode.PLANE_VERTEX, ShaderCode.PLANE_FRAGMENT)
	var reset_shader := _shader(ShaderCode.RESET_VERTEX, ShaderCode.VOLUME_FRAGMENT, false)
	if not volume_shader.is_valid() or not plane_shader.is_valid() or not reset_shader.is_valid():
		release()
		return false
	_camera_buffer = _keep(_rd.uniform_buffer_create(160))
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER
	uniform.add_id(_camera_buffer)
	_volume_camera = _keep(_rd.uniform_set_create([uniform], volume_shader, 0))
	_plane_camera = _keep(_rd.uniform_set_create([uniform], plane_shader, 0))
	var raster := RDPipelineRasterizationState.new()
	raster.front_face = front_face
	raster.cull_mode = RenderingDevice.POLYGON_CULL_DISABLED
	var samples := RDPipelineMultisampleState.new()
	samples.sample_count = depth_format.samples
	var format := _rd.framebuffer_get_format(_framebuffer)
	_volume_pass = _keep(_rd.render_pipeline_create(volume_shader, format, _vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLE_STRIPS, raster, samples, volume_stencil(false), _blend(false)))
	_volume_fail = _keep(_rd.render_pipeline_create(volume_shader, format, _vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLE_STRIPS, raster, samples, volume_stencil(true), _blend(false)))
	_plane = _keep(_rd.render_pipeline_create(plane_shader, format, _vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, raster, samples, plane_stencil(), _blend(true)))
	_stencil_reset = _keep(_rd.render_pipeline_create(reset_shader, format, -1,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, raster, samples, _reset_stencil(), _blend(false)))
	if not (_volume_pass.is_valid() and _volume_fail.is_valid() and _plane.is_valid()
			and _stencil_reset.is_valid() and _volume_camera.is_valid() and _plane_camera.is_valid()):
		release()
		return false
	return true

func volume_vertex_format() -> int:
	return _vertex_format

func begin_frame(world_to_view: Transform3D, view_to_clip: Projection, near: float, far: float,
		camera_z: float, focus_z: float, pitch: float, fog: Vector2, fog_enabled: bool) -> Error:
	if _rd == null or near <= 0.0 or far <= near or (fog_enabled and fog.y <= fog.x):
		return ERR_INVALID_PARAMETER
	var limit := fog.y if fog_enabled else far
	var projected_y := limit * tan(deg_to_rad(89.99 - pitch)) - (camera_z - focus_z) * sin(deg_to_rad(pitch))
	var fade_point := maxf(projected_y / limit + 0.5, 0.01)
	var camera_data := _matrix_bytes(Projection(world_to_view))
	camera_data.append_array(_matrix_bytes(view_to_clip))
	camera_data.append_array(PackedFloat32Array([near, far, maxf(camera_z, focus_z), 1.0 / _height,
		fade_point, fog.x, 1.0 / (fog.y - fog.x) if fog_enabled else 0.0, 0.0]).to_byte_array())
	_plane_slot = 0
	return _rd.buffer_update(_camera_buffer, 0, camera_data.size(), camera_data)

func draw_local(lights: Array[Light], camera: Vector3, focus_z: float, level: float) -> Error:
	if _rd == null:
		return ERR_UNCONFIGURED
	# All plane data must be uploaded before beginning the shared draw list.
	var planes: Array[RID] = []
	for index in range(lights.size() - 1, -1, -1):
		var light := lights[index]
		var points := PackedVector4Array() if light.radius > 1000.0 else plane_vertices(
			light, camera, focus_z, Vector2.ZERO, 0.0, level)
		var plane := _upload_plane(points) if not points.is_empty() else RID()
		if not points.is_empty() and not plane.is_valid():
			return ERR_CANT_CREATE
		planes.append(plane)
		if light.radius > 1000.0:
			break
	var draw := _rd.draw_list_begin(_framebuffer)
	# RenderShadows(0, true) clears before any light, even if the list is empty.
	_clear_stencil(draw)
	for offset in planes.size():
		var light := lights[lights.size() - 1 - offset]
		_draw(draw, light, PROJECTION_LIGHT_BUCKETS if light.dynamic_projection_light else FIRST_BUCKETS, planes[offset])
		if light.radius > 1000.0:
			break
		_clear_stencil(draw)
	_rd.draw_list_end()
	return OK

func draw_static(light: Light, build_volume: bool, camera: Vector3, focus_z: float,
		horizontal_forward: Vector2, fog_end: float, level: float) -> Error:
	if _rd == null:
		return ERR_UNCONFIGURED
	if light == null:
		return OK
	var points := plane_vertices(light, camera, focus_z, horizontal_forward, fog_end, level)
	var plane := _upload_plane(points) if not points.is_empty() else RID()
	if not points.is_empty() and not plane.is_valid():
		return ERR_CANT_CREATE
	var draw := _rd.draw_list_begin(_framebuffer)
	_draw(draw, light, [9, 10] if build_volume else [], plane)
	_rd.draw_list_end()
	return OK

func release() -> void:
	if _rd != null:
		for index in range(_resources.size() - 1, -1, -1):
			_rd.free_rid(_resources[index])
	_resources.clear()
	_plane_buffers.clear()
	_local_plane_arrays.clear()
	_directional_plane_arrays.clear()
	_vertex_format = -1
	_rd = null

static func volume_stencil(depth_fail: bool) -> RDPipelineDepthStencilState:
	var state := RDPipelineDepthStencilState.new()
	state.enable_depth_test = true
	state.depth_compare_operator = RenderingDevice.COMPARE_OP_GREATER_OR_EQUAL
	state.enable_stencil = true
	state.front_op_compare = RenderingDevice.COMPARE_OP_ALWAYS
	state.back_op_compare = RenderingDevice.COMPARE_OP_ALWAYS
	state.front_op_write_mask = 0xff
	state.back_op_write_mask = 0xff
	if depth_fail:
		state.front_op_depth_fail = RenderingDevice.STENCIL_OP_DECREMENT_AND_CLAMP
		state.back_op_depth_fail = RenderingDevice.STENCIL_OP_INCREMENT_AND_CLAMP
	else:
		state.front_op_pass = RenderingDevice.STENCIL_OP_INCREMENT_AND_CLAMP
		state.back_op_pass = RenderingDevice.STENCIL_OP_DECREMENT_AND_CLAMP
	return state

static func _reset_stencil() -> RDPipelineDepthStencilState:
	var state := RDPipelineDepthStencilState.new()
	state.enable_stencil = true
	state.front_op_compare = RenderingDevice.COMPARE_OP_ALWAYS
	state.back_op_compare = RenderingDevice.COMPARE_OP_ALWAYS
	state.front_op_pass = RenderingDevice.STENCIL_OP_REPLACE
	state.back_op_pass = RenderingDevice.STENCIL_OP_REPLACE
	state.front_op_reference = NEUTRAL_STENCIL
	state.back_op_reference = NEUTRAL_STENCIL
	state.front_op_write_mask = 0xff
	state.back_op_write_mask = 0xff
	return state

static func plane_stencil() -> RDPipelineDepthStencilState:
	var state := RDPipelineDepthStencilState.new()
	state.enable_stencil = true
	# GL_LEQUAL compares the reference to the attachment, hence 128 <= stencil.
	state.front_op_compare = RenderingDevice.COMPARE_OP_LESS_OR_EQUAL
	state.back_op_compare = RenderingDevice.COMPARE_OP_LESS_OR_EQUAL
	state.front_op_reference = 0x80
	state.back_op_reference = 0x80
	state.front_op_compare_mask = 0xff
	state.back_op_compare_mask = 0xff
	state.front_op_write_mask = 0
	state.back_op_write_mask = 0
	return state

static func plane_vertices(light: Light, camera: Vector3, focus_z: float, horizontal_forward: Vector2,
		fog_end: float, level: float) -> PackedVector4Array:
	var source := light.source()
	var radius := light.shadow_radius if light.shadow_radius > 0.0 else light.radius
	var triangles := PackedVector4Array()
	if light.radius > 1000.0:
		if radius <= 0.0:
			return triangles
		var along := horizontal_forward.normalized() if horizontal_forward != Vector2.ZERO else Vector2.RIGHT
		var across := Vector2(along.y, -along.x) * 10000.0
		along *= fog_end if fog_end > 0.0 else 10000.0
		var origin := Vector2(camera.x, camera.y)
		var far_plane_z := 2.0 * minf(camera.z - 1.0, focus_z) - focus_z
		var a := origin + along + across
		var b := origin + along - across
		var c := origin - along + across
		var d := origin - along - across
		var alpha := _plane_alpha(level * light.fade)
		var v0 := Vector4(a.x, a.y, focus_z, alpha)
		var v1 := Vector4(b.x, b.y, focus_z, alpha)
		var v2 := Vector4(c.x, c.y, far_plane_z, alpha)
		var v3 := Vector4(d.x, d.y, far_plane_z, alpha)
		return PackedVector4Array([v0, v1, v2, v2, v1, v3])
	var z := minf(source.z - 1.0, focus_z)
	var delta_z := source.z - z
	var plane_radius := sqrt(absf(radius * radius - delta_z * delta_z))
	if plane_radius <= 0.0 or radius == 0.0:
		return triangles
	var alpha := _plane_alpha(level * light.fade * (plane_radius / radius))
	var center := Vector4(source.x, source.y, z, alpha)
	var previous := Vector4(source.x + plane_radius, source.y, z, 0.0)
	for index in range(1, 10):
		var angle := float(index) * 0.69813174
		var point := Vector4(source.x + cos(angle) * plane_radius, source.y + sin(angle) * plane_radius, z, 0.0)
		triangles.append(center)
		triangles.append(previous)
		triangles.append(point)
		previous = point
	return triangles

static func _plane_alpha(amount: float) -> float:
	return float(int(amount * 255.0) & 0xff) / 255.0

static func _matrix_bytes(matrix: Projection) -> PackedByteArray:
	var values := PackedFloat32Array()
	for axis in [matrix.x, matrix.y, matrix.z, matrix.w]:
		values.append_array(PackedFloat32Array([axis.x, axis.y, axis.z, axis.w]))
	return values.to_byte_array()

func _draw(draw: int, light: Light, buckets: Array, plane_vertices_rid: RID) -> void:
	var source := light.source()
	for bucket: int in buckets:
		var volumes: Array = light.buckets.get(bucket, [])
		if volumes.is_empty():
			continue
		_rd.draw_list_bind_render_pipeline(draw, _volume_fail if bucket in [10, 12, 14] else _volume_pass)
		_rd.draw_list_bind_uniform_set(draw, _volume_camera, 0)
		for volume: VolumeDraw in volumes:
			var push := _matrix_bytes(Projection(volume.model_to_world))
			push.append_array(PackedFloat32Array([source.x, source.y, source.z, source.w,
				volume.world_z_clip, 0.0, 0.0, 0.0]).to_byte_array())
			_rd.draw_list_set_push_constant(draw, push, push.size())
			_rd.draw_list_bind_vertex_array(draw, volume.vertices)
			_rd.draw_list_bind_index_array(draw, volume.indices)
			_rd.draw_list_draw(draw, true, 1)
	if plane_vertices_rid.is_valid():
		_rd.draw_list_bind_render_pipeline(draw, _plane)
		_rd.draw_list_bind_uniform_set(draw, _plane_camera, 0)
		_rd.draw_list_bind_vertex_array(draw, plane_vertices_rid)
		_rd.draw_list_draw(draw, false, 1)

func _clear_stencil(draw: int) -> void:
	# RD's depth/stencil attachment clear replaces both aspects. Use stencil
	# replacement so the shadow passes see the original world depth.
	_rd.draw_list_bind_render_pipeline(draw, _stencil_reset)
	_rd.draw_list_draw(draw, false, 1, 3)

func _upload_plane(points: PackedVector4Array) -> RID:
	if _plane_slot == _plane_buffers.size():
		# A local light has the largest plane: nine triangles.
		var buffer := _keep(_rd.vertex_buffer_create(27 * 16))
		if not buffer.is_valid():
			return RID()
		var local_vertices := _keep(_rd.vertex_array_create(27, _vertex_format, [buffer]))
		var directional_vertices := _keep(_rd.vertex_array_create(6, _vertex_format, [buffer]))
		if not local_vertices.is_valid() or not directional_vertices.is_valid():
			return RID()
		_plane_buffers.append(buffer)
		_local_plane_arrays.append(local_vertices)
		_directional_plane_arrays.append(directional_vertices)
	var bytes := points.to_byte_array()
	var slot := _plane_slot
	_plane_slot += 1
	if _rd.buffer_update(_plane_buffers[slot], 0, bytes.size(), bytes) != OK:
		return RID()
	return _local_plane_arrays[slot] if points.size() == 27 else _directional_plane_arrays[slot]

func _blend(color_enabled: bool) -> RDPipelineColorBlendState:
	var attachment := RDPipelineColorBlendStateAttachment.new()
	attachment.write_r = color_enabled
	attachment.write_g = color_enabled
	attachment.write_b = color_enabled
	attachment.write_a = color_enabled
	if color_enabled:
		attachment.enable_blend = true
		attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_SRC_ALPHA
		attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
		attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_SRC_ALPHA
		attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE_MINUS_SRC_ALPHA
	var blend := RDPipelineColorBlendState.new()
	blend.attachments = [attachment]
	return blend

func _shader(vertex: String, fragment: String, use_camera: bool = true) -> RID:
	var source := RDShaderSource.new()
	var header := "#version 450\n" + (ShaderCode.CAMERA if use_camera else "")
	source.source_vertex = header + vertex
	source.source_fragment = header + fragment
	var binary := _rd.shader_compile_spirv_from_source(source)
	for stage in [RenderingDevice.SHADER_STAGE_VERTEX, RenderingDevice.SHADER_STAGE_FRAGMENT]:
		var error := binary.get_stage_compile_error(stage)
		if not error.is_empty():
			push_error(error)
			return RID()
	return _keep(_rd.shader_create_from_spirv(binary))

func _keep(resource: RID) -> RID:
	if resource.is_valid():
		_resources.append(resource)
	return resource
