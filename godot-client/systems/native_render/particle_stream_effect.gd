extends CompositorEffect
# Experimental native shared-stream raster pass. No normal world enables it.
# Native owns simulation packets, draw ranges, buffers and material caches.
var state_lock:=Mutex.new()
var native: RefCounted
var rd: RenderingDevice
var framebuffers: Dictionary={}
var failure:=""
var projection_sample: Array=[]
func _init() -> void:
	effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color=false; access_resolved_depth=false
func configure(value: RefCounted) -> void:
	state_lock.lock(); native=value; state_lock.unlock()
func _render_callback(stage: int,data: RenderData) -> void:
	if stage!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT: return
	state_lock.lock(); var consumer:=native; state_lock.unlock()
	if consumer==null: return
	if rd==null: rd=RenderingServer.get_rendering_device()
	if rd==null: return
	var buffers:=data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene:=data.get_render_scene_data()
	if buffers==null or scene==null: return
	var multisample:=buffers.get_msaa_3d()!=RenderingServer.VIEWPORT_MSAA_DISABLED
	for view in buffers.get_view_count():
		var color:=buffers.get_color_layer(view,multisample)
		var depth:=buffers.get_depth_layer(view,multisample)
		var key:=Vector2i(view,int(multisample))
		if not framebuffers.has(key) or framebuffers[key].color!=color or framebuffers[key].depth!=depth:
			if framebuffers.has(key) and rd.framebuffer_is_valid(framebuffers[key].rid): rd.free_rid(framebuffers[key].rid)
			var color_format:=rd.texture_get_format(color); var depth_format:=rd.texture_get_format(depth)
			if color_format.samples!=depth_format.samples or not color_format.usage_bits&RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT or not depth_format.usage_bits&RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT:
				state_lock.lock(); failure="Shared stream requires matching real color/depth attachments"; state_lock.unlock(); return
			var target:=rd.framebuffer_create([color,depth])
			if not target.is_valid():
				state_lock.lock(); failure="Shared stream framebuffer creation failed"; state_lock.unlock(); return
			framebuffers[key]={"color":color,"depth":depth,"rid":target,"samples":color_format.samples}
		# RenderSceneDataRD already applies depth/Y correction to this getter.
		# A second correction reverses winding and breaks clip-space depth.
		var projection:=scene.get_view_projection(view)
		var view_matrix:=Projection(scene.get_cam_transform().affine_inverse())
		if projection_sample.is_empty():
			state_lock.lock(); projection_sample=[projection*(view_matrix*Vector4(-16,0.1,-14.4,1)),scene.get_view_projection(view),scene.get_cam_transform()]; state_lock.unlock()
		var packed:=PackedFloat32Array()
		for column in [projection.x,projection.y,projection.z,projection.w,view_matrix.x,view_matrix.y,view_matrix.z,view_matrix.w]: packed.append_array(PackedFloat32Array([column.x,column.y,column.z,column.w]))
		consumer.call("draw",rd,framebuffers[key].rid,packed.to_byte_array(),int(framebuffers[key].samples))
		# Forward+ resolves before post-transparent compositor callbacks. Draw
		# against real MSAA depth/color, then refresh the color used downstream.
		if multisample: rd.texture_resolve_multisample(color,buffers.get_color_layer(view,false))
func snapshot() -> Dictionary:
	state_lock.lock(); var result:={"failure":failure,"projection_sample":str(projection_sample)}; state_lock.unlock(); return result
func _release_gpu(_held: RefCounted) -> void:
	if rd!=null:
		for entry in framebuffers.values():
			if rd.framebuffer_is_valid(entry.rid): rd.free_rid(entry.rid)
	framebuffers.clear()
func close() -> void:
	state_lock.lock(); var consumer:=native; native=null; state_lock.unlock()
	if consumer!=null: consumer.call("dispatch",3,{})
	RenderingServer.call_on_render_thread(Callable(self,"_release_gpu").bind(self))
