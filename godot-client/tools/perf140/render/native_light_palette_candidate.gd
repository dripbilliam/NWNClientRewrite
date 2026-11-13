extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Metadata only: Godot still selects/culls lights and renders their shadows.
# The native model shaders reserve their unused light-specular scalar as a
# palette index. 32..2047 remain exact in Godot's half-precision light input;
# 0..2 are ordinary Godot lights and must never alias a native entry.
# Ordinary materials/lights and GUI previews never receive encoded indices.
const CAPACITY:=2016
static var image: Image
static var texture: ImageTexture
static var environment_texture: Texture2D
static var empty_environment: Texture2D
static var free_slots: Array[int]=[]
static var active: Dictionary={}
static var retained_shapes:=PackedColorArray()
static var retained_policies:=PackedColorArray()
static var dirty:=false
static var revision:=0
static var flushes:=0
static var overflows:=0
static func ensure() -> void:
	if image!=null: return
	image=Image.create(2,CAPACITY,false,Image.FORMAT_RGBAF); image.fill(Color(0,0,0,0))
	retained_shapes.resize(CAPACITY); retained_shapes.fill(Color(0,0,0,0))
	retained_policies.resize(CAPACITY); retained_policies.fill(Color(0,0,0,0))
	texture=ImageTexture.create_from_image(image)
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
static func update(slot: int,position: Vector3,state: Dictionary) -> void:
	if not active.has(slot): return
	var shape:=Color(position.x,position.y,position.z,maxf(state.range,0.0001))
	var policy:=Color(state.inverse,state.factor,1.0 if state.ambient else 0.0,1.0)
	if retained_shapes[slot]==shape and retained_policies[slot]==policy:return
	if retained_shapes[slot]!=shape:
		image.set_pixel(0,slot,shape);retained_shapes[slot]=shape
	if retained_policies[slot]!=policy:
		image.set_pixel(1,slot,policy);retained_policies[slot]=policy
	dirty=true; revision+=1
static func release(slot: int) -> void:
	if not active.has(slot): return
	active.erase(slot); free_slots.append(slot); image.set_pixel(1,slot,Color(0,0,0,0)); retained_policies[slot]=Color(0,0,0,0); dirty=true; revision+=1
static func ambient(value: Vector3) -> void:
	ensure(); RenderingServer.global_shader_parameter_set("nwn_native_ambient",value)
static func environment(value: Texture2D) -> void:
	ensure(); environment_texture=value if value!=null else empty_environment
	RenderingServer.global_shader_parameter_set("nwn_native_environment",environment_texture)
static func flush() -> void:
	if dirty: texture.update(image); dirty=false; flushes+=1
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
