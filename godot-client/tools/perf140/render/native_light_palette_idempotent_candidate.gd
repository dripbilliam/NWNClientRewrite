extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# PRIVATE SOURCE-ONLY candidate. Parent is the immutable-upload palette in
# root/builtin-light-fenced-v2; shader, texture identity and slot owners remain.
const CAPACITY:=2016
static var image: Image
static var texture: ImageTexture
static var environment_texture: Texture2D
static var empty_environment: Texture2D
static var free_slots: Array[int]=[]
static var active: Dictionary={}
static var dirty:=false
# Keep the existing logical publication counter. Only pixel_revision controls
# whether a changed callback wrote new pixels during the current upload.
static var revision:=0
static var pixel_revision:=0
static var flushes:=0
static var overflows:=0
# Scalar observations only. No polling/RPC: diagnostics() is an explicit cold
# read. These increments still have a cost on the candidate's hot update path.
static var logical_updates:=0
static var logical_releases:=0
static var changed_updates:=0
static var skipped_updates:=0
static var state_fallbacks:=0
static var comparison_calls:=0
static var comparison_word_checks:=0
static var comparison_layout_fallbacks:=0
static func ensure() -> void:
	if image!=null: return
	image=Image.create(2,CAPACITY,false,Image.FORMAT_RGBAF); image.fill(Color(0,0,0,0))
	texture=ImageTexture.create_from_image(upload_snapshot())
	RenderingServer.global_shader_parameter_add("nwn_native_lights",RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D,texture)
	RenderingServer.global_shader_parameter_add("nwn_native_ambient",RenderingServer.GLOBAL_VAR_TYPE_VEC3,Vector3.ZERO)
	var empty:=Image.create(1,1,false,Image.FORMAT_RGBA8); empty.fill(Color.BLACK); empty_environment=ImageTexture.create_from_image(empty); environment_texture=empty_environment
	RenderingServer.global_shader_parameter_add("nwn_native_environment",RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D,environment_texture)
	for index in range(CAPACITY-1,-1,-1): free_slots.append(index)
static func acquire(owner: Node) -> int:
	ensure()
	if free_slots.is_empty():
		overflows+=1
		if overflows==1: push_warning("Native enhanced light palette capacity exceeded; retaining Godot fallback light")
		return -1
	var slot: int=free_slots.pop_back(); active[slot]=weakref(owner); return slot
static func comparable_state(state: Dictionary) -> bool:
	# Unsupported/malformed inputs keep the old statement/evaluation order.
	if not state.has("range") or not state.has("inverse") or not state.has("factor") or not state.has("ambient"): return false
	var range_type:=typeof(state.range); var inverse_type:=typeof(state.inverse); var factor_type:=typeof(state.factor)
	return (range_type==TYPE_FLOAT or range_type==TYPE_INT) and (inverse_type==TYPE_FLOAT or inverse_type==TYPE_INT) and (factor_type==TYPE_FLOAT or factor_type==TYPE_INT)
static func same_pixels(slot: int,shape: Color,policy: Color) -> bool:
	comparison_calls+=1
	if image==null or slot<0 or slot>=CAPACITY:
		comparison_layout_fallbacks+=1
		return false
	if image.get_format()!=Image.FORMAT_RGBAF or image.get_width()!=2 or image.get_height()!=CAPACITY or image.has_mipmaps():
		comparison_layout_fallbacks+=1
		return false
	# Color is four native float words; PackedColorArray.to_byte_array copies
	# those words. Do not use Color equality (signed zero/NaN are different).
	var expected:=PackedColorArray([shape,policy]).to_byte_array()
	if expected.size()!=32:
		comparison_layout_fallbacks+=1
		return false
	var current:=image.get_data()
	if current.size()!=CAPACITY*32:
		comparison_layout_fallbacks+=1
		return false
	var offset:=slot*32
	for index in range(0,32,8):
		comparison_word_checks+=1
		if current.decode_u64(offset+index)!=expected.decode_u64(index): return false
	return true
	# Both packed arrays are helper-local. The complete Image COW reference is
	# gone BEFORE update calls set_pixel; no row Image or persistent byte cache.
static func update(slot: int,position: Vector3,state: Dictionary) -> void:
	if not active.has(slot): return
	if not comparable_state(state):
		state_fallbacks+=1
		write_original(slot,position,state)
		return
	var shape:=Color(position.x,position.y,position.z,maxf(state.range,0.0001))
	var policy:=Color(state.inverse,state.factor,1.0 if state.ambient else 0.0,1.0)
	if same_pixels(slot,shape,policy):
		revision+=1; logical_updates+=1; skipped_updates+=1
		return
	image.set_pixel(0,slot,shape)
	image.set_pixel(1,slot,policy)
	dirty=true; revision+=1; pixel_revision+=1; logical_updates+=1; changed_updates+=1
static func write_original(slot: int,position: Vector3,state: Dictionary) -> void:
	# Fallback deliberately preserves the original two expressions and order.
	image.set_pixel(0,slot,Color(position.x,position.y,position.z,maxf(state.range,0.0001)))
	image.set_pixel(1,slot,Color(state.inverse,state.factor,1.0 if state.ambient else 0.0,1.0))
	dirty=true; revision+=1; pixel_revision+=1; logical_updates+=1; changed_updates+=1
static func release(slot: int) -> void:
	if not active.has(slot): return
	active.erase(slot); free_slots.append(slot); image.set_pixel(1,slot,Color(0,0,0,0)); dirty=true; revision+=1; pixel_revision+=1; logical_releases+=1
static func ambient(value: Vector3) -> void:
	ensure(); RenderingServer.global_shader_parameter_set("nwn_native_ambient",value)
static func environment(value: Texture2D) -> void:
	ensure(); environment_texture=value if value!=null else empty_environment
	RenderingServer.global_shader_parameter_set("nwn_native_environment",environment_texture)
static func upload_snapshot() -> Image:
	# Keep corrected immutable queued upload ownership for create AND update.
	return Image.create_from_data(image.get_width(),image.get_height(),image.has_mipmaps(),image.get_format(),image.get_data())
static func flush() -> void:
	if not dirty: return
	var uploaded_pixel_revision:=pixel_revision
	texture.update(upload_snapshot())
	# Logical same-pixel publication does not require another upload; a true
	# changed-callback pixel write/release still remains pending.
	dirty=pixel_revision!=uploaded_pixel_revision; flushes+=1
static func diagnostics() -> Dictionary:
	# All values are scalar or freshly constructed dictionaries. Do not ensure,
	# flush, scan owners, or return Image/Texture/Node/WeakRef references here.
	return {"version":1,"mode":"actual-image-byte-comparison","initialized":image!=null,"logical_updates":logical_updates,"logical_releases":logical_releases,"changed_updates":changed_updates,"skipped_updates":skipped_updates,"fallback_updates":state_fallbacks+comparison_layout_fallbacks,"comparisons":{"calls":comparison_calls,"word_checks":comparison_word_checks,"state_fallbacks":state_fallbacks,"layout_fallbacks":comparison_layout_fallbacks},"revision":revision,"pixel_revision":pixel_revision,"flushes":flushes,"overflows":overflows,"active_slots":active.size(),"free_slots":free_slots.size(),"dirty":dirty}
func _init() -> void: process_priority=1000
func _process(_delta: float) -> void:
	var began:=Timing.begin(); flush(); Timing.count("count_native_lamps",active.size()); Timing.finish("callback_native_lighting",began)
static func shader_code() -> String:
	return """
global uniform sampler2D nwn_native_lights;
global uniform vec3 nwn_native_ambient;
global uniform sampler2D nwn_native_environment;
varying vec3 nwn_world_vertex;
vec2 nwn_local_light(float attenuation,float index_value,bool directional){
 if(directional)return vec2(attenuation,0.0);
 int index=int(round(index_value))-32;
 if(index<0||index>=2016)return vec2(attenuation,0.0);
 vec4 shape=texelFetch(nwn_native_lights,ivec2(0,index),0);
 vec4 policy=texelFetch(nwn_native_lights,ivec2(1,index),0);
 if(policy.a<0.5)return vec2(attenuation,0.0);
 vec3 delta=nwn_world_vertex-shape.xyz;
 float q=dot(delta,delta)/(shape.w*shape.w);
 if(q>=1.0)return vec2(0.0,policy.z);
 // Godot's range envelope, with distance decay=0. Divide out only this
 // envelope, retaining its shadow factor. Never infer distance from shadows.
 float envelope=max(1.0-q*q,0.0); envelope*=envelope;
 float shadow_factor=clamp(attenuation/max(envelope,0.00000001),0.0,1.0);
 return vec2(shadow_factor*(1.0-q)/(policy.x+policy.y*q),policy.z);
}
"""
