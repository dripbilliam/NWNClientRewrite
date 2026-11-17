extends RefCounted
# Shared target-preview state for every owned world-material program, including
# static draw mergers. The UI publishes only on targeting changes; TIME animates
# the outline on the GPU without a per-frame material or mesh walk.
static var registered:=false
static var current: Dictionary={"enabled":false}
static var publications:=0

static func ensure()->void:
	if registered:return
	RenderingServer.global_shader_parameter_add("nwn_target_type",RenderingServer.GLOBAL_VAR_TYPE_INT,0)
	RenderingServer.global_shader_parameter_add("nwn_target_shape",RenderingServer.GLOBAL_VAR_TYPE_INT,0)
	RenderingServer.global_shader_parameter_add("nwn_target_flags",RenderingServer.GLOBAL_VAR_TYPE_INT,0)
	RenderingServer.global_shader_parameter_add("nwn_target_size",RenderingServer.GLOBAL_VAR_TYPE_VEC2,Vector2.ZERO)
	RenderingServer.global_shader_parameter_add("nwn_target_range",RenderingServer.GLOBAL_VAR_TYPE_FLOAT,0.0)
	RenderingServer.global_shader_parameter_add("nwn_target_point",RenderingServer.GLOBAL_VAR_TYPE_VEC3,Vector3.ZERO)
	RenderingServer.global_shader_parameter_add("nwn_target_player",RenderingServer.GLOBAL_VAR_TYPE_VEC3,Vector3.ZERO)
	RenderingServer.global_shader_parameter_add("nwn_target_color",RenderingServer.GLOBAL_VAR_TYPE_VEC3,Vector3.ONE)
	registered=true

static func _point(value: Variant)->Variant:
	if not value is Array or value.size()!=3:return null
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)):return null
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

static func publish(snapshot: Dictionary)->bool:
	if not bool(snapshot.get("enabled",false)):reset();return false
	var preview: Variant=snapshot.get("preview")
	var point: Variant=_point(snapshot.get("point"))
	var player: Variant=_point(snapshot.get("player"))
	var kind: Variant=snapshot.get("type")
	if not preview is Dictionary or point==null or player==null or not kind is int or kind<=0:reset();return false
	for key in ["shape","sizeX","sizeY","flags","range","spellId","featId"]:
		if not preview.has(key) or not (preview[key] is int or preview[key] is float) or not is_finite(float(preview[key])):reset();return false
	var flags:=int(preview.flags)
	var shape:=0 if flags&32 and kind!=2 else int(preview.shape)
	var color:=Vector3(1,0,0) if flags&1 and flags&2 else Vector3(0,0,1) if flags&1 else Vector3(0,1,0) if flags&4 else Vector3.ONE
	var next: Dictionary={"enabled":true,"type":kind,"shape":shape,"flags":flags,"size":Vector2(float(preview.sizeX),float(preview.sizeY)),"range":float(preview.range),"point":point,"player":player,"color":color,"spellId":int(preview.spellId),"featId":int(preview.featId),"generation":int(snapshot.get("generation",-1)),"areaId":int(snapshot.get("areaId",-1)),"actorId":int(snapshot.get("actorId",-1)),"targetVersion":int(snapshot.get("targetVersion",-1))}
	if current==next:return true
	ensure();current=next;publications+=1
	RenderingServer.global_shader_parameter_set("nwn_target_shape",shape)
	RenderingServer.global_shader_parameter_set("nwn_target_flags",flags)
	RenderingServer.global_shader_parameter_set("nwn_target_size",next.size)
	RenderingServer.global_shader_parameter_set("nwn_target_range",next.range)
	RenderingServer.global_shader_parameter_set("nwn_target_point",point)
	RenderingServer.global_shader_parameter_set("nwn_target_player",player)
	RenderingServer.global_shader_parameter_set("nwn_target_color",color)
	# Enable last so a frame cannot observe new type with stale geometry.
	RenderingServer.global_shader_parameter_set("nwn_target_type",kind)
	return true

static func reset()->void:
	if not current.get("enabled",false):return
	ensure();current={"enabled":false};publications+=1
	RenderingServer.global_shader_parameter_set("nwn_target_type",0)

static func snapshot()->Dictionary:
	return {"state":current.duplicate(true),"publications":publications,"registered":registered}

static func code()->String:
	return """
global uniform int nwn_target_type;
global uniform int nwn_target_shape;
global uniform int nwn_target_flags;
global uniform vec2 nwn_target_size;
global uniform float nwn_target_range;
global uniform vec3 nwn_target_point;
global uniform vec3 nwn_target_player;
global uniform vec3 nwn_target_color;

float nwn_target_box(vec3 p,vec3 half_size){
 vec3 outside=abs(p)-half_size;
 return length(max(outside,vec3(0.0)))+min(max(outside.x,max(outside.y,outside.z)),0.0);
}
float nwn_target_cone(vec3 p,float length_value){
 vec2 base=length_value*vec2(0.50000019433/0.86602529158,-1.0);
 vec2 q=vec2(length(p.xz),p.y);
 vec2 a=q-base*clamp(dot(q,base)/dot(base,base),0.0,1.0);
 vec2 b=q-base*vec2(clamp(q.x/base.x,0.0,1.0),1.0);
 float side=max(sign(base.y)*(q.x*base.y-q.y*base.x),sign(base.y)*(q.y-base.y));
 return sqrt(min(dot(a,a),dot(b,b)))*sign(side);
}
vec3 nwn_target_yaw(vec3 p,float angle){
 float c=cos(angle),s=sin(angle);
 return vec3(c*p.x-s*p.y,s*p.x+c*p.y,p.z);
}
float nwn_target_pulse(){return 0.7+0.4*sin(TIME*4.0);}
vec3 nwn_target_overlay(vec3 godot_world){
 if(nwn_target_type==0)return vec3(0.0);
 if(nwn_target_shape==0 && nwn_target_range<=0.0)return vec3(0.0);
 // Godot world x,y,z -> original world x,y,z.
 vec3 world=vec3(godot_world.x,-godot_world.z,godot_world.y);
 vec3 player_to_point=nwn_target_player-nwn_target_point;
 float distance_to_point=length(player_to_point);
 vec3 toward_player=distance_to_point>0.0?player_to_point/distance_to_point:vec3(0.0,1.0,0.0);
 float yaw=atan(toward_player.y,toward_player.x)-1.57079632679;
 vec3 origin=(nwn_target_flags&16)!=0?nwn_target_player:nwn_target_point;
 if((nwn_target_flags&16)!=0){
  float shift=nwn_target_shape==2?nwn_target_size.x*0.5:0.0;
  shift+=max(distance_to_point-nwn_target_range,0.0);
  origin-=toward_player*shift;
 }
 vec3 relative=world-origin;
 vec3 rotated=nwn_target_yaw(relative,yaw);
 if(distance_to_point>0.0){
  float pitch=asin(clamp(-toward_player.z,-1.0,1.0));
  rotated=vec3(rotated.x,cos(pitch)*rotated.y+sin(pitch)*rotated.z,-sin(pitch)*rotated.y+cos(pitch)*rotated.z);
 }
 float width=0.05;
 float strength=0.0;
 if(nwn_target_shape==1){
  float radius=length(rotated);
  if(radius<=nwn_target_size.x)strength=radius>nwn_target_size.x-width?nwn_target_pulse():0.1;
 }else if(nwn_target_shape==2){
  float edge=nwn_target_box(rotated,vec3(nwn_target_size.y*0.5,nwn_target_size.x*0.5,max(1.0,abs(player_to_point.z))));
  if(edge<=0.0)strength=edge>-width?nwn_target_pulse():0.1;
 }else if(nwn_target_shape==3){
  float edge=nwn_target_cone(rotated,nwn_target_size.x);
  if(edge<=0.0)strength=edge>-width?nwn_target_pulse():0.1;
 }else if(nwn_target_shape==4){
  float radius=length(rotated);
  if(radius>=nwn_target_size.x && radius<=nwn_target_size.y){
   float midpoint=(nwn_target_size.x+nwn_target_size.y)*0.5;
   float edge=radius>midpoint?nwn_target_size.y-radius:radius-nwn_target_size.x;
   strength=edge<=width?nwn_target_pulse():0.1;
  }
 }
 if(nwn_target_range>0.0 && distance_to_point>nwn_target_range){
  float half_over=(distance_to_point-nwn_target_range)*0.5;
  vec3 to_player=world-nwn_target_player;
  vec3 line=nwn_target_yaw(to_player+toward_player*half_over,yaw);
  float edge=nwn_target_box(line,vec3(width*0.5,half_over,max(1.0,abs(player_to_point.z))));
  if(edge<=0.0 && mod(length(to_player),1.0)<0.5)strength=max(strength,nwn_target_pulse());
 }
 return nwn_target_color*clamp(strength,0.0,1.0);
}
"""
