extends CompositorEffect
# Shared native particle raster pass.
# Native owns simulation packets, draw ranges, buffers and material caches.
var state_lock:=Mutex.new()
var native: RefCounted
var rd: RenderingDevice
var framebuffers: Dictionary={}
var soft_depth_enabled:=not OS.get_cmdline_user_args().has("--particle-soft-depth=off")
var depth_copy_shader:=RID()
var depth_copy_pipeline:=RID()
var depth_copy_sampler:=RID()
var depth_copy_failed:=false
var failure:=""
var projection_sample: Array=[]
var precipitation: RefCounted
var rain_haze: RefCounted
var weather: Dictionary={}
var weather_cover: CompositorEffect
var sun_shadow: Dictionary={}
var shadows_enabled:=true
var omni_shadow_atlas_available:=false
var precipitation_draws:=0
var cover_bakes:=0
var haze_builds:=0
const COPY_DEPTH: String = """#version 450
layout(local_size_x=8,local_size_y=8) in;
layout(set=0,binding=0) uniform sampler2D scene_depth;
layout(r32f,set=0,binding=1) uniform writeonly image2D depth_copy;
void main(){
	ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
	if(any(greaterThanEqual(pixel,imageSize(depth_copy))))return;
	imageStore(depth_copy,pixel,vec4(texelFetch(scene_depth,pixel,0).r));
}
"""
func _init() -> void:
	effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color=false; access_resolved_depth=false
func configure(value: RefCounted,cx: bool=false) -> void:
	state_lock.lock()
	native=value
	if cx:
		omni_shadow_atlas_available=ClassDB.class_exists("NwnParticleShadowAtlas")
		precipitation=preload("res://systems/native_render/cx_precipitation.gd").new()
		rain_haze=preload("res://systems/native_render/cx_rain_haze.gd").new()
	state_lock.unlock()
func set_weather(value: Dictionary,cover: CompositorEffect=null) -> void:
	state_lock.lock()
	weather=value
	weather_cover=cover
	state_lock.unlock()
func set_shadows_enabled(value: bool) -> void:
	state_lock.lock()
	shadows_enabled=value
	if not value: sun_shadow={}
	state_lock.unlock()
func set_sun_shadow(fits: Array[CompositorEffect],moving: Array[CompositorEffect]=[],focus: Vector3=Vector3.ZERO,radii: PackedFloat32Array=PackedFloat32Array(),strength: float=0.0) -> void:
	state_lock.lock()
	sun_shadow={} if fits.is_empty() and moving.is_empty() else {"fits":fits,"moving":moving,"focus":focus,"radii":radii,"strength":strength}
	state_lock.unlock()
func _sun_packet(state: Dictionary) -> Dictionary:
	if state.is_empty(): return {}
	var packed:=PackedFloat32Array()
	var enabled:=PackedFloat32Array([0.0,0.0])
	var result: Dictionary={}
	for index in 2:
		var fit: Dictionary={} if state.fits.is_empty() else state.fits[index].snapshot()
		var moving: Dictionary={} if state.moving.is_empty() else state.moving[index].snapshot()
		var matrix: Projection=fit.get("matrix",moving.get("matrix",Projection()))
		if not fit.is_empty():
			result["near" if index==0 else "far"]=fit.depth
			enabled[index]+=1.0
		# Sample moving depth only at the matrix under which it was rendered.
		if not moving.is_empty() and moving.matrix==matrix:
			result["moving_near" if index==0 else "moving_far"]=moving.depth
			enabled[index]+=2.0
		for column in [matrix.x,matrix.y,matrix.z,matrix.w]:
			packed.append_array(PackedFloat32Array([column.x,column.y,column.z,column.w]))
	if result.is_empty(): return result
	var focus: Vector3=state.focus
	packed.append_array(PackedFloat32Array([focus.x,focus.y,focus.z,state.strength,
		state.radii[0],state.radii[1],enabled[0],enabled[1]]))
	result.uniforms=packed.to_byte_array()
	return result
func _render_callback(stage: int,data: RenderData) -> void:
	if stage!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT: return
	state_lock.lock()
	var consumer:=native
	var active_weather:=weather
	var active_cover:=weather_cover
	var active_sun:=sun_shadow
	var active_shadows:=shadows_enabled
	state_lock.unlock()
	if consumer==null: return
	if rd==null: rd=RenderingServer.get_rendering_device()
	if rd==null: return
	var buffers:=data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene:=data.get_render_scene_data()
	if buffers==null or scene==null: return
	var multisample:=buffers.get_msaa_3d()!=RenderingServer.VIEWPORT_MSAA_DISABLED
	var cover: Dictionary=active_cover.snapshot() if active_cover!=null else {}
	var draw_weather:=not active_weather.is_empty() and (active_cover==null or not cover.is_empty())
	var sun_packet:=_sun_packet(active_sun) if active_shadows else {}
	if active_shadows and omni_shadow_atlas_available and consumer.call("has_omni_shadow_draw"):
		var shadow_atlas: Dictionary=ClassDB.class_call_static("NwnParticleShadowAtlas","snapshot",data)
		if not shadow_atlas.is_empty(): sun_packet.omni_atlas=shadow_atlas
	for view in buffers.get_view_count():
		var color:=buffers.get_color_layer(view,multisample)
		var depth:=buffers.get_depth_layer(view,multisample)
		var key:=view
		if not framebuffers.has(key) or framebuffers[key].color!=color or framebuffers[key].depth!=depth:
			if framebuffers.has(key): _release_target(framebuffers[key]); framebuffers.erase(key)
			var color_format:=rd.texture_get_format(color); var depth_format:=rd.texture_get_format(depth)
			if color_format.samples!=depth_format.samples or not color_format.usage_bits&RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT or not depth_format.usage_bits&RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT:
				state_lock.lock(); failure="Shared stream requires matching real color/depth attachments"; state_lock.unlock(); return
			var target:=rd.framebuffer_create([color,depth])
			if not target.is_valid():
				state_lock.lock(); failure="Shared stream framebuffer creation failed"; state_lock.unlock(); return
			framebuffers[key]={"color":color,"depth":depth,"rid":target,"samples":color_format.samples,
				"size":Vector2i(depth_format.width,depth_format.height),"copy":RID(),"copy_uniforms":RID()}
		# RenderSceneDataRD already applies depth/Y correction to this getter.
		# A second correction reverses winding and breaks clip-space depth.
		var projection:=scene.get_view_projection(view)
		var camera_transform:=scene.get_cam_transform()
		var view_matrix:=Projection(camera_transform.affine_inverse())
		if projection_sample.is_empty():
			state_lock.lock(); projection_sample=[projection*(view_matrix*Vector4(-16,0.1,-14.4,1)),scene.get_view_projection(view),scene.get_cam_transform()]; state_lock.unlock()
		var packed:=PackedFloat32Array()
		for column in [projection.x,projection.y,projection.z,projection.w,view_matrix.x,view_matrix.y,view_matrix.z,view_matrix.w]: packed.append_array(PackedFloat32Array([column.x,column.y,column.z,column.w]))
		var target: Dictionary=framebuffers[key]
		var soft_depth:=RID()
		if (soft_depth_enabled and consumer.call("has_soft_draw")) or not active_weather.is_empty():
			# Resolved MSAA depth is already separate. A single-sample depth image
			# cannot be sampled while attached, so keep a GPU copy for that pass.
			soft_depth=buffers.get_depth_layer(view,false) if multisample else _copy_depth(target)
		var haze_texture:=RID()
		var haze_terms:=Vector4.ZERO
		if rain_haze!=null and draw_weather and active_weather.kind==1 and active_weather.density>0.0:
			haze_terms=rain_haze.draw(rd,target,soft_depth,projection,camera_transform,active_weather,cover)
			if haze_terms!=Vector4.ZERO: haze_texture=rain_haze.volume
			state_lock.lock()
			haze_builds=rain_haze.builds
			if not rain_haze.error.is_empty(): failure=str(rain_haze.error)
			state_lock.unlock()
		consumer.call("draw",rd,target.rid,packed.to_byte_array(),int(target.samples),soft_depth if soft_depth_enabled else RID(),haze_texture,haze_terms,sun_packet)
		if precipitation!=null and draw_weather:
			var drawn: bool=precipitation.draw(rd,target,soft_depth,packed,camera_transform.origin,active_weather,cover)
			state_lock.lock()
			if drawn: precipitation_draws+=1
			else: failure=str(precipitation.error)
			cover_bakes=int(cover.get("bakes",0))
			state_lock.unlock()
		# Forward+ resolves before post-transparent compositor callbacks. Draw
		# against real MSAA depth/color, then refresh the color used downstream.
		if multisample: rd.texture_resolve_multisample(color,buffers.get_color_layer(view,false))
func snapshot() -> Dictionary:
	state_lock.lock(); var result:={"failure":failure,"projection_sample":str(projection_sample),"soft_depth_enabled":soft_depth_enabled,
		"precipitation_draws":precipitation_draws,"precipitation_active":not weather.is_empty(),"weather_cover_bakes":cover_bakes,
		"rain_haze_builds":haze_builds}; state_lock.unlock(); return result
func _copy_depth(target: Dictionary) -> RID:
	if depth_copy_failed: return RID()
	if not depth_copy_pipeline.is_valid():
		var source:=RDShaderSource.new()
		source.source_compute=COPY_DEPTH
		var spirv:=rd.shader_compile_spirv_from_source(source)
		if not spirv.compile_error_compute.is_empty():
			_set_failure(spirv.compile_error_compute)
			return RID()
		depth_copy_shader=rd.shader_create_from_spirv(spirv,"NWN particle depth copy")
		depth_copy_pipeline=rd.compute_pipeline_create(depth_copy_shader)
		depth_copy_sampler=rd.sampler_create(RDSamplerState.new())
		if not depth_copy_pipeline.is_valid() or not depth_copy_sampler.is_valid():
			_set_failure("Particle depth copy pipeline creation failed")
			return RID()
	if not target.copy_uniforms.is_valid():
		var format:=RDTextureFormat.new()
		format.format=RenderingDevice.DATA_FORMAT_R32_SFLOAT
		format.width=target.size.x
		format.height=target.size.y
		format.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT|RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		var image:=rd.texture_create(format,RDTextureView.new())
		if not image.is_valid():
			_set_failure("Particle depth copy allocation failed")
			return RID()
		var input:=RDUniform.new()
		input.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		input.binding=0
		input.add_id(depth_copy_sampler)
		input.add_id(target.depth)
		var output:=RDUniform.new()
		output.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE
		output.binding=1
		output.add_id(image)
		var uniforms:=rd.uniform_set_create([input,output],depth_copy_shader,0)
		if not uniforms.is_valid():
			rd.free_rid(image)
			_set_failure("Particle depth copy binding failed")
			return RID()
		target.copy=image
		target.copy_uniforms=uniforms
	var list:=rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list,depth_copy_pipeline)
	rd.compute_list_bind_uniform_set(list,target.copy_uniforms,0)
	rd.compute_list_dispatch(list,ceili(target.size.x/8.0),ceili(target.size.y/8.0),1)
	rd.compute_list_end()
	return target.copy
func _set_failure(message: String) -> void:
	depth_copy_failed=true
	state_lock.lock(); failure=message; state_lock.unlock()
func _release_target(entry: Dictionary) -> void:
	if rd.uniform_set_is_valid(entry.copy_uniforms): rd.free_rid(entry.copy_uniforms)
	if rd.texture_is_valid(entry.copy): rd.free_rid(entry.copy)
	if rd.framebuffer_is_valid(entry.rid): rd.free_rid(entry.rid)
func _release_gpu(_held: RefCounted) -> void:
	if rd!=null:
		if rain_haze!=null: rain_haze.release(rd)
		if precipitation!=null: precipitation.release(rd)
		for entry in framebuffers.values(): _release_target(entry)
		for handle in [depth_copy_pipeline,depth_copy_sampler,depth_copy_shader]:
			if handle.is_valid(): rd.free_rid(handle)
		rd=null
	framebuffers.clear()
func close() -> void:
	state_lock.lock(); var consumer:=native; native=null; weather={}; weather_cover=null; sun_shadow={}; state_lock.unlock()
	if consumer!=null: consumer.call("dispatch",3,{})
	RenderingServer.call_on_render_thread(Callable(self,"_release_gpu").bind(self))
