extends CompositorEffect
# Original inc_postpr_gam: pow(displayColor, Gamma/2.2). Godot's linear
# framebuffer requires a reversible transfer around that operation. UI is later.
# Neutral 2.2 owns no GPU resources and performs no pass. No finite-resolution LUT.
const NEUTRAL:=2.2
const Post=preload("res://systems/native_render/native_postprocess.gd")
const SOURCE="""#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(rgba16f, set=0, binding=0) uniform restrict image2D color_image;
#ifdef NWN_TONE
//NATIVE_TONE_CODE
#endif
layout(push_constant, std430) uniform Params { vec4 values; } params;
vec3 to_display(vec3 c) {
	return mix(1.055*pow(c,vec3(1.0/2.4))-0.055,12.92*c,lessThan(c,vec3(0.0031308)));
}
vec3 to_linear(vec3 c) {
	return mix(pow((c+0.055)/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(0.04045)));
}
vec3 retail_tonemap(vec3 color) {
	float peak=max(color.r,max(color.g,color.b));
	if(peak>1.0){
		float excess=(peak-1.0)/peak;
		color=vec3(peak)-(vec3(peak)-color)*(1.0-excess*excess);
	}
	return color;
}
void main() {
	ivec2 pixel=ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(pixel,imageSize(color_image)))) return;
	vec4 value=imageLoad(color_image,pixel);
	vec3 display=params.values.y>0.5?value.rgb:to_display(max(value.rgb,vec3(0.0)));
	// Keep the original power operator, including its driver boundary at 0^0.
	vec3 adjusted=display;
#ifdef NWN_TONE
	int flags=int(tone.w);
	if((flags&4)!=0)adjusted=nwn_contrast(adjusted);
	if((flags&8)!=0)adjusted=nwn_vibrance(adjusted);
	if((flags&16)!=0)adjusted=pow(adjusted,vec3(params.values.x/2.2));
#else
	adjusted=pow(adjusted,vec3(params.values.x/2.2));
#endif
	if(params.values.y>0.5)adjusted=retail_tonemap(adjusted);
	imageStore(color_image,pixel,vec4(to_linear(adjusted),value.a));
}
"""
var state_lock:=Mutex.new()
var gamma_value:=NEUTRAL
var surface_output:=false
var closed:=false
var failure:=""
var passes:=0
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var bindings: Dictionary={}
var post_options: Dictionary={}
var post_revision:=0
var post_frame:=PackedFloat32Array()
var tone_shader: RID
var tone_pipeline: RID
var midpoint_shader: RID
var midpoint_pipeline: RID
var midpoint_binding: RID
var midpoint_input: RID
var midpoint_output: RID
var midpoint_passes:=0
var midpoint_uploads:=0
var uploaded_frame:=PackedByteArray()
var cpu_midpoint_enabled:=OS.get_environment("NWN71_CPU_MIDPOINT")=="1"
var cpu_tone_bytes:=PackedByteArray()
var prewarm_enabled:=OS.get_environment("NWN71_GAMMA_PREWARM")=="1"
var prewarm_gamma_requested:=false
var prewarm_tone_requested:=false
var prewarm_gamma_completed:=false
var prewarm_tone_completed:=false
var prewarm_gamma_ms:=0.0
var prewarm_tone_ms:=0.0
func _init() -> void:
	effect_callback_type=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color=true; set_meta("native_final_color",true); enabled=false
static func valid_value(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
static func bounded(value: float) -> float: return clampf(value,0.0,1000.0)
func set_gamma(value: float) -> void:
	if not is_finite(value): return
	state_lock.lock(); gamma_value=bounded(value); var active:=not closed and (surface_output or absf(gamma_value-NEUTRAL)>=.00009); state_lock.unlock()
	enabled=active
	if active: _schedule_prewarm(false)
func set_surface_output(value: bool) -> void:
	# Research-only: all 3D drawing families must use the native gamma carrier.
	# Existing worlds never select this merely by selecting enhanced lighting.
	state_lock.lock(); surface_output=value
	if not value: post_options.clear();post_frame=PackedFloat32Array();cpu_tone_bytes=PackedByteArray();post_revision+=1
	var active:=not closed and (surface_output or absf(gamma_value-NEUTRAL)>=.00009); state_lock.unlock()
	enabled=active
	if value and active:
		_schedule_prewarm(false)
		_schedule_prewarm(true)
func _schedule_prewarm(tonal: bool) -> void:
	if not prewarm_enabled: return
	state_lock.lock()
	var requested:=prewarm_tone_requested if tonal else prewarm_gamma_requested
	var enqueue:=not closed and not requested
	if enqueue:
		if tonal: prewarm_tone_requested=true
		else: prewarm_gamma_requested=true
	state_lock.unlock()
	if enqueue: RenderingServer.call_on_render_thread(Callable(self,"_prewarm_on_render_thread").bind(tonal,self))
func _prewarm_on_render_thread(tonal: bool,_held: RefCounted) -> void:
	state_lock.lock()
	var active:=not closed and (surface_output if tonal else (surface_output or absf(gamma_value-NEUTRAL)>=.00009))
	state_lock.unlock()
	if not active: return
	if rd==null: rd=RenderingServer.get_rendering_device()
	if rd==null: return # The normal callback retains the original preparation path.
	var started:=Time.get_ticks_usec()
	var prepared:=prepare(tonal)
	var elapsed:=(Time.get_ticks_usec()-started)/1000.0
	state_lock.lock()
	if tonal:
		prewarm_tone_completed=prepared
		prewarm_tone_ms=elapsed
	else:
		prewarm_gamma_completed=prepared
		prewarm_gamma_ms=elapsed
	state_lock.unlock()
func set_postprocess(options: Dictionary) -> bool:
	var selected: Dictionary={}
	if not options.is_empty():
		var mask: Variant=options.get("mask")
		if not mask is int or mask<0 or (mask&~28)!=0:return false
		selected={"mask":mask,"intensity":options.get("intensity",0.0),"midpoint":options.get("midpoint",.4),"vibrance":options.get("vibrance",0.0)}
		for key in ["intensity","midpoint","vibrance"]:
			if not valid_value(selected[key]) or not is_finite(Vector3(float(selected[key]),0,0).x):return false
	state_lock.lock()
	if closed or (not selected.is_empty() and not surface_output):state_lock.unlock();return false
	post_options=selected;post_revision+=1;post_frame=PackedFloat32Array()
	if not selected.is_empty() and (int(selected.mask)&4)==0:
		post_frame=Post.empty_frame();post_frame[17]=selected.midpoint;post_frame[18]=selected.intensity;post_frame[19]=selected.vibrance
	if cpu_midpoint_enabled:
		cpu_tone_bytes=Post.midpoint_tone_cpu(post_frame,int(selected.mask)).to_byte_array() if not post_frame.is_empty() else PackedByteArray()
	state_lock.unlock();return true
func postprocess_state() -> Dictionary:
	state_lock.lock();var result:={"options":post_options.duplicate(),"revision":post_revision,"retail":surface_output};state_lock.unlock();return result
func publish_postprocess_frame(frame: PackedFloat32Array,revision: int) -> bool:
	if frame.size()!=Post.FLOATS or frame[3]!=floorf(frame[3]) or frame[3]<0 or frame[3]>Post.MAX_LIGHTS:return false
	for value in frame:if not is_finite(value):return false
	var next:=frame.duplicate()
	state_lock.lock()
	if closed or not surface_output or post_options.is_empty() or revision!=post_revision:state_lock.unlock();return false
	next[17]=post_options.midpoint;next[18]=post_options.intensity;next[19]=post_options.vibrance
	if not cpu_midpoint_enabled:
		post_frame=next;state_lock.unlock();return true
	var mask:=int(post_options.mask)
	state_lock.unlock()
	var tone_bytes:=Post.midpoint_tone_cpu(next,mask).to_byte_array()
	state_lock.lock()
	if closed or not surface_output or post_options.is_empty() or revision!=post_revision:state_lock.unlock();return false
	post_frame=next;cpu_tone_bytes=tone_bytes
	if cpu_midpoint_enabled:midpoint_passes+=1
	state_lock.unlock();return true
func fail(message: String) -> void:
	state_lock.lock(); failure=message; state_lock.unlock()
func prepare(tonal: bool=false) -> bool:
	if tonal:return prepare_tone()
	if pipeline.is_valid(): return true
	var source:=RDShaderSource.new(); source.language=RenderingDevice.SHADER_LANGUAGE_GLSL; source.source_compute=SOURCE
	var spirv:=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty(): fail(spirv.compile_error_compute); return false
	shader=rd.shader_create_from_spirv(spirv)
	if not shader.is_valid(): fail("Native gamma shader creation failed"); return false
	pipeline=rd.compute_pipeline_create(shader)
	if not pipeline.is_valid(): fail("Native gamma pipeline creation failed"); return false
	return true
func prepare_tone() -> bool:
	if tone_pipeline.is_valid():return true
	var source:=RDShaderSource.new();source.source_compute=SOURCE.replace("#version 450","#version 450\n#define NWN_TONE 1").replace("//NATIVE_TONE_CODE",Post.PIXEL_CODE)
	var spirv:=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():fail(spirv.compile_error_compute);return false
	tone_shader=rd.shader_create_from_spirv(spirv)
	if not tone_shader.is_valid():fail("Native tonal shader creation failed");return false
	tone_pipeline=rd.compute_pipeline_create(tone_shader)
	if not tone_pipeline.is_valid():fail("Native tonal pipeline creation failed");return false
	if cpu_midpoint_enabled:
		midpoint_output=rd.storage_buffer_create(16)
		if not midpoint_output.is_valid():fail("Native CPU midpoint output storage creation failed");return false
		return true
	source=RDShaderSource.new();source.source_compute=Post.MIDPOINT_SOURCE;spirv=rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():fail(spirv.compile_error_compute);return false
	midpoint_shader=rd.shader_create_from_spirv(spirv)
	if not midpoint_shader.is_valid():fail("Native contrast midpoint shader creation failed");return false
	midpoint_pipeline=rd.compute_pipeline_create(midpoint_shader)
	if not midpoint_pipeline.is_valid():fail("Native contrast midpoint pipeline creation failed");return false
	midpoint_input=rd.storage_buffer_create(Post.FLOATS*4);midpoint_output=rd.storage_buffer_create(16)
	if not midpoint_input.is_valid() or not midpoint_output.is_valid():fail("Native contrast midpoint storage creation failed");return false
	var input:=RDUniform.new();input.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;input.binding=0;input.add_id(midpoint_input)
	var output:=RDUniform.new();output.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;output.binding=1;output.add_id(midpoint_output)
	midpoint_binding=rd.uniform_set_create([input,output],midpoint_shader,0)
	if not midpoint_binding.is_valid():fail("Native contrast midpoint binding creation failed");return false
	return true
func _render_callback(stage: int,data: RenderData) -> void:
	if stage!=EFFECT_CALLBACK_TYPE_POST_TRANSPARENT: return
	state_lock.lock(); var value:=gamma_value; var retail:=surface_output;var frame:=post_frame;var options:=post_options.duplicate();var tone_bytes:=cpu_tone_bytes; var stopped:=closed or not failure.is_empty(); state_lock.unlock()
	if stopped or (not retail and absf(value-NEUTRAL)<.00009): return
	if rd==null: rd=RenderingServer.get_rendering_device()
	if rd==null: fail("Native gamma requires a RenderingDevice renderer"); return
	var buffers:=data.get_render_scene_buffers() as RenderSceneBuffersRD
	var tonal:=retail and not options.is_empty() and frame.size()==Post.FLOATS
	if buffers==null or not prepare(tonal): return
	if tonal and buffers.get_view_count()!=1:fail("Native postprocess scene inputs require one camera view");return
	var mask: int=options.get("mask",0);var changed:=false
	if tonal:
		var bytes:=tone_bytes if cpu_midpoint_enabled else frame.to_byte_array()
		if cpu_midpoint_enabled and bytes.size()!=16:fail("Native CPU midpoint packet is missing");return
		changed=bytes!=uploaded_frame
		if changed:
			rd.buffer_update(midpoint_output if cpu_midpoint_enabled else midpoint_input,0,bytes.size(),bytes)
			uploaded_frame=bytes;state_lock.lock();midpoint_uploads+=1;state_lock.unlock()
	var push:=PackedFloat32Array([value,1.0 if retail else 0.0,float(mask),0.0]).to_byte_array()
	var program: RID=tone_shader if tonal else shader;var selected_pipeline: RID=tone_pipeline if tonal else pipeline
	for view in buffers.get_view_count():
		var color:=buffers.get_color_layer(view,false)
		var format:=rd.texture_get_format(color)
		if format.format!=RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT or not format.usage_bits&RenderingDevice.TEXTURE_USAGE_STORAGE_BIT:
			fail("Native gamma requires the owned linear RGBA16F storage framebuffer"); return
		var key:=str(view)+":tone" if tonal else str(view)+":gamma"
		if not bindings.has(key) or bindings[key].color!=color or not rd.uniform_set_is_valid(bindings[key].rid):
			if bindings.has(key) and rd.uniform_set_is_valid(bindings[key].rid): rd.free_rid(bindings[key].rid)
			var uniform:=RDUniform.new(); uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE; uniform.binding=0; uniform.add_id(color)
			var uniforms: Array[RDUniform]=[uniform]
			if tonal:
				var tone:=RDUniform.new();tone.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;tone.binding=1;tone.add_id(midpoint_output);uniforms.append(tone)
			bindings[key]={"color":color,"rid":rd.uniform_set_create(uniforms,program,0)}
		var list:=rd.compute_list_begin()
		if tonal and not cpu_midpoint_enabled and (mask&4 or changed):
			rd.compute_list_bind_compute_pipeline(list,midpoint_pipeline);rd.compute_list_bind_uniform_set(list,midpoint_binding,0);rd.compute_list_set_push_constant(list,push,push.size());rd.compute_list_dispatch(list,1,1,1);rd.compute_list_add_barrier(list)
			state_lock.lock();midpoint_passes+=1;state_lock.unlock()
		rd.compute_list_bind_compute_pipeline(list,selected_pipeline); rd.compute_list_bind_uniform_set(list,bindings[key].rid,0)
		rd.compute_list_set_push_constant(list,push,push.size()); rd.compute_list_dispatch(list,ceili(format.width/8.0),ceili(format.height/8.0),1); rd.compute_list_end()
		state_lock.lock(); passes+=1; state_lock.unlock()
func snapshot() -> Dictionary:
	state_lock.lock()
	var result:={"gamma":gamma_value,"retail_surface_output":surface_output,"enabled":not closed and (surface_output or absf(gamma_value-NEUTRAL)>=.00009),"failure":failure,"passes":passes,"closed":closed,"postprocess":post_options.duplicate(),"postprocess_revision":post_revision,"postprocess_waiting":not post_options.is_empty() and post_frame.is_empty(),"postprocess_lights":int(post_frame[3]) if not post_frame.is_empty() else 0,"midpoint_passes":midpoint_passes,"midpoint_uploads":midpoint_uploads}
	if prewarm_enabled: result.prewarm={"gamma_requested":prewarm_gamma_requested,"tone_requested":prewarm_tone_requested,"gamma_completed":prewarm_gamma_completed,"tone_completed":prewarm_tone_completed,"gamma_ms":prewarm_gamma_ms,"tone_ms":prewarm_tone_ms}
	if cpu_midpoint_enabled:result.midpoint_cpu=true
	state_lock.unlock()
	return result
func _release(_held: RefCounted) -> void:
	if rd==null: return
	for entry in bindings.values():
		if rd.uniform_set_is_valid(entry.rid): rd.free_rid(entry.rid)
	bindings.clear()
	if pipeline.is_valid(): rd.free_rid(pipeline); pipeline=RID()
	if shader.is_valid(): rd.free_rid(shader); shader=RID()
	for resource in [midpoint_binding,tone_pipeline,midpoint_pipeline,tone_shader,midpoint_shader,midpoint_input,midpoint_output]:
		if resource.is_valid():rd.free_rid(resource)
	midpoint_binding=RID();tone_pipeline=RID();midpoint_pipeline=RID();tone_shader=RID();midpoint_shader=RID();midpoint_input=RID();midpoint_output=RID();uploaded_frame=PackedByteArray()
func close() -> void:
	state_lock.lock(); var was_closed:=closed; closed=true; state_lock.unlock()
	if was_closed: return
	enabled=false; RenderingServer.call_on_render_thread(Callable(self,"_release").bind(self))
