extends RefCounted
# Original enhanced postprocessing inputs. One midpoint invocation per frame;
# never repeat its admitted-light loop for every screen pixel. Research carrier
# only, with explicit original shader-profile validation and no network work.
const Policy=preload("res://systems/native_render/native_light_policy.gd")
const SurfaceState=preload("res://systems/native_render/native_surface_state.gd")
const MAX_LIGHTS:=128
const FLOATS:=(9+MAX_LIGHTS*2)*4
const SHADERS={
	"inc_common":"20ecd0437d31e26ee797c83422c83870d62c7f910ca3bffc2473553401575337",
	"inc_config":"8ae83f7fa429b2d646e7fe421edd25bdfb8c13724a56d5bdb2346b27ae258a8d",
	"inc_postpr":"4a4ff91e2ff73c3f05df1bcf0868df305ae3e5f63846cea624275c91d3236b5b",
	"inc_postpr_dyn_c":"2be52629215d6233d7024b74853cf3fe90cccafb2a52c5b979c60dde11378a85",
	"inc_postpr_vibr":"6c3f5c7b25095abc5966033b187cfcc4d717501204188cb4eea7d1a1a8586024",
	"inc_postpr_gam":"3e614e5c58f61547d04b6dc4baf5b55d13ddb58b9b6a7f46ad501b25f62c2d48",
	"inc_tonemap":"d59921acbe17cf2e990b70acf2a69cf2f4624e93e3cc8d0f0ba58ef7bc683133"}
static func profile(catalog) -> String:
	if catalog==null:return "Native postprocess catalog is absent"
	for name in SHADERS:
		var data: PackedByteArray=catalog.get_resource(name,2069);var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(data)
		if hash.finish().hex_encode()!=SHADERS[name]:return "Unsupported native postprocess shader profile: "+name
	return ""
static func row(data: PackedFloat32Array,index: int,value: Vector4) -> void:
	for n in 4:data[index*4+n]=value[n]
static func empty_frame() -> PackedFloat32Array:
	var data:=PackedFloat32Array();data.resize(FLOATS)
	for n in 4:row(data,5+n,Projection.IDENTITY[n])
	return data
static func capture(world: Node3D,area: Node,camera: Camera3D) -> Dictionary:
	if not is_instance_valid(world) or not is_instance_valid(area) or not is_instance_valid(camera) or not SurfaceState.owns(world):return {"error":"Native postprocess world/camera owner is inactive"}
	var reference: WeakRef=world.get_meta("native_focus_light_owner",null);var focus=reference.get_ref() if reference!=null else null
	if not is_instance_valid(focus) or focus.closed or focus.history==null or not focus.history_result.has("area_fades"):return {"error":"Native postprocess requires actual native admission/fade history"}
	if area.camera!=camera or area.lighting_world==null or area.lighting_world.get_ref()!=world or not SurfaceState.authoritative(world):return {"error":"Native postprocess area/camera generation differs"}
	var data:=empty_frame();var view:=camera.get_camera_transform().affine_inverse();var projection:=camera.get_camera_projection()
	var fades: Array=focus.history_result.area_fades
	for index in 2:
		var name: String=["ambient","diffuse"][index];var raw: Array=focus.area.get(name,{}).get("color",[0,0,0]);var fade: float=fades[index][0]
		var linear:=Policy.linear_rgb(raw.map(func(v):return Policy.f(v*fade)));row(data,index,Vector4(linear.x,linear.y,linear.z,0))
	var direction: Vector3=view.basis*area.sunlight.global_basis.z if is_instance_valid(area.sunlight) and area.sunlight.light_energy!=0 else Vector3.ZERO
	row(data,2,Vector4(direction.x,direction.y,direction.z,0))
	var fog: Array=SurfaceState.packet(world);row(data,3,Vector4(fog[0],fog[1],fog[2],fog[4]));data[16]=fog[5]
	for n in 4:row(data,5+n,projection[n])
	var count:=0
	for call in focus.history_result.calls:
		if call.kind!="draw":continue
		var id:=int(call.id)
		if not focus.members.has(id):continue
		var light=focus.members[id].light.get_ref()
		# Expired sources can retire after history selection but before this late
		# snapshot. They no longer render; never retain their old packet colors.
		if not is_instance_valid(light) or not light.is_inside_tree() or not light.is_visible_in_tree() or not light.native_admitted:continue
		if light.native_state.is_empty():return {"error":"Native postprocess lamp has no current enhanced state"}
		if count>=MAX_LIGHTS:return {"error":"Native postprocess exceeded original finite light limit"}
		var state: Dictionary=light.native_state;var color: Vector3=state.color;var point: Vector3=view*light.global_position
		var range_squared:=Policy.f(state.range*state.range)
		row(data,9+count*2,Vector4(point.x,point.y,point.z,1))
		row(data,10+count*2,Vector4(color.x,color.y,color.z,-range_squared if state.ambient else range_squared));count+=1
	data[3]=count
	return {"value":data,"lights":count}
const PIXEL_CODE="""
layout(set=0,binding=1,std430) readonly buffer NativeTone { vec4 tone; };
float nwn_luma(vec3 c){return dot(c,vec3(.299,.587,.114));}
vec3 nwn_contrast(vec3 c){
 float brightness=dot(c,vec3(.3333333));
 float modifier=(nwn_luma(c)-tone.x)*tone.y*max(0.0,1.0-brightness*brightness);
 return c*(1.0+modifier/max(brightness,.2));
}
vec3 nwn_vibrance(vec3 c){
 float luma=nwn_luma(c);
 if(luma>0.0){
  float high=max(c.r,max(c.g,c.b));float low=min(c.r,min(c.g,c.b));
  float saturation=(high-low)/high;
  c=clamp(vec3(high)+(c-vec3(high))*(1.0+(1.0-saturation)*(1.0-saturation)*tone.z),0.0,1.0);
  c*=luma/nwn_luma(c);
 }
 return c;
}
"""
const MIDPOINT_SOURCE="""#version 450
layout(local_size_x=1,local_size_y=1,local_size_z=1)in;
layout(set=0,binding=0,std430)readonly buffer Inputs{vec4 data[];};
layout(set=0,binding=1,std430)writeonly buffer Outputs{vec4 tone;};
layout(push_constant,std430)uniform Params{vec4 values;}params;
void main(){
 float midpoint=0.0;
 if((int(params.values.z)&4)!=0){
  vec3 direction=data[2].xyz;
  vec3 color=.5*data[0].rgb+.5*data[1].rgb*(.5+(direction.z<0.0?1.0-dot(direction.xy,direction.xy):0.0));
  mat4 projection=mat4(data[5],data[6],data[7],data[8]);
  for(int n=0;n<int(data[0].w);n++){
   vec4 point=data[9+n*2];vec4 light=data[10+n*2];vec4 clip=projection*point;
   clip.xy/=clip.w;float factor=.15;
   if(light.a>0.0)factor/=.25*(1.0+.5*clip.x*clip.x+.5*clip.y*clip.y);
   factor*=factor;float falloff=inversesqrt(abs(light.a));
   factor/=falloff*point.z*point.z*(point.z<0.0?1.0:100.0)+1.0;
   color+=factor*light.rgb;
  }
  color=data[4].y*sign(color)*pow(abs(color),vec3(.45454545));
  color=mix(color,data[3].rgb,1.0/(1.0+.05*max(2.0*data[3].w+data[4].x,0.0)));
  midpoint=clamp(dot(color,vec3(.299,.587,.114)),0.0,1.0);
 }
 tone=vec4(midpoint,data[4].z,data[4].w,params.values.z);
}
"""
