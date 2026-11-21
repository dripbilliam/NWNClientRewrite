extends RefCounted
const ShdSource=preload("res://systems/native_render/native_shd_source.gd")
# Shared target-preview state for every owned world-material program, including
# static draw mergers. The UI publishes only on targeting changes; TIME animates
# the outline on the GPU without a per-frame material or mesh walk.
static var registered:=false
static var current: Dictionary={"enabled":false}
static var publications:=0
static var source_profile: Dictionary={"loaded":false,"resources":[],"sha256":"","error":"Native target shader has not been loaded"}
static var translated_code: String=""
const SHADER_UNIFORMS="""
global uniform int nwn_target_type;
global uniform int nwn_target_shape;
global uniform int nwn_target_flags;
global uniform vec2 nwn_target_size;
global uniform float nwn_target_range;
global uniform vec3 nwn_target_point;
global uniform vec3 nwn_target_player;
global uniform vec3 nwn_target_color;
global uniform int nwn_target_time_ms;
"""

static func load_profile(catalog) -> bool:
	reset()
	translated_code=""
	var result: Dictionary=ShdSource.load(catalog,"inc_target",[])
	if result.has("error"):
		source_profile={"loaded":false,"resources":[],"sha256":"","error":str(result.error)}
		return false
	var source: String="#define POSITION_WORLD 1\n#define PI 3.14159265358979323846\n#define COLOR_WHITE vec4(1.0)\nvarying vec3 vPosWorld;\n"+str(result.source)
	var symbols: Dictionary=ShdSource.declared_symbols(source)
	if not symbols.has("ApplyTargetGroundHighlighting") or not symbols.has("targetShape"):
		source_profile={"loaded":false,"resources":result.resources,"sha256":result.sha256,"error":"Native target shader declarations are unavailable"}
		return false
	var adapted: Dictionary=_adapt_installed_source(source)
	if adapted.has("error"):
		source_profile={"loaded":false,"resources":result.resources,"sha256":result.sha256,"error":str(adapted.error)}
		return false
	translated_code=str(adapted.code)
	source_profile={"loaded":true,"resources":result.resources,"sha256":result.sha256,"cacheKey":ShdSource.fnv_cache_key(source),"error":"","translation":"Installed inc_target POSITION_WORLD functions adapted into the Godot spatial material"}
	return true

static func loaded() -> bool:return bool(source_profile.get("loaded",false))
static func source_identity() -> String:return "inc_target:2069:"+str(source_profile.get("cacheKey","unloaded"))

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
	RenderingServer.global_shader_parameter_add("nwn_target_time_ms",RenderingServer.GLOBAL_VAR_TYPE_INT,0)
	registered=true

static func tick(time_ms: int)->void:
	if not bool(current.get("enabled",false)):return
	ensure()
	RenderingServer.global_shader_parameter_set("nwn_target_time_ms",time_ms%86400000)

static func _point(value: Variant)->Variant:
	if not value is Array or value.size()!=3:return null
	for component in value:
		if not (component is int or component is float) or not is_finite(float(component)):return null
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

static func _number(value: Variant, fallback: float=0.0) -> float:
	# TargetPreviewShader.update applies Number(value)||0 to dimensions/range.
	if value==null:return fallback
	if value is String and not value.is_valid_float():return fallback
	var result:=float(value)
	return result if is_finite(result) else fallback

static func publish(snapshot: Dictionary)->bool:
	if not bool(snapshot.get("enabled",false)):reset();return false
	if not loaded():reset();return false
	var preview: Variant=snapshot.get("preview")
	var point: Variant=_point(snapshot.get("point"))
	var player: Variant=_point(snapshot.get("player"))
	var kind: Variant=snapshot.get("type")
	if not preview is Dictionary or point==null or player==null or not kind is int or kind<=0:reset();return false
	var flags:=int(_number(preview.get("flags")))
	var shape:=0 if flags&32 and kind!=2 else int(_number(preview.get("shape")))
	var color:=Vector3(1,0,0) if flags&1 and flags&2 else Vector3(0,0,1) if flags&1 else Vector3(0,1,0) if flags&4 else Vector3.ONE
	var next: Dictionary={"enabled":true,"type":kind,"shape":shape,"flags":flags,"size":Vector2(_number(preview.get("sizeX")),_number(preview.get("sizeY"))),"range":_number(preview.get("range")),"point":point,"player":player,"color":color,"spellId":int(_number(preview.get("spellId"),-1.0)),"featId":int(_number(preview.get("featId"),-1.0)),"generation":int(snapshot.get("generation",-1)),"areaId":int(snapshot.get("areaId",-1)),"actorId":int(snapshot.get("actorId",-1)),"targetVersion":int(snapshot.get("targetVersion",-1))}
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
	return {"state":current.duplicate(true),"publications":publications,"registered":registered,"source":source_profile.duplicate(true)}

# Only the installed target functions and POSITION_WORLD stage are translated.
# Unsupported dependencies fail loading; they never execute stale fixed math.
static func _function_source(source: String,name: String) -> String:
	var pattern:=RegEx.new()
	if pattern.compile("(?m)\\b(?:float|mat4|void)\\s+"+name+"\\s*\\([^)]*\\)\\s*\\{")!=OK:return ""
	var match_row:=pattern.search(source)
	if match_row==null:return ""
	var start:=match_row.get_start()
	var opening:=source.find("{",start)
	var depth:=0
	for index in range(opening,source.length()):
		var point:=source.unicode_at(index)
		if point==123:depth+=1
		elif point==125:
			depth-=1
			if depth==0:return source.substr(start,index-start+1)
	return ""

static func _integer_define(source: String,name: String) -> String:
	var pattern:=RegEx.new()
	if pattern.compile("(?m)^\\s*#define\\s+"+name+"\\s+([0-9]+)\\b")!=OK:return ""
	var match_row:=pattern.search(source)
	return match_row.get_string(1) if match_row!=null else ""

static func _world_stage(source: String) -> String:
	const DIRECTIVE="#if POSITION_WORLD == 1"
	var start:=source.find(DIRECTIVE)
	if start<0:return ""
	var alternate:=source.find("#else",start+DIRECTIVE.length())
	var finish:=source.find("#endif",alternate+5) if alternate>=0 else -1
	if finish<0:return ""
	return source.substr(0,start)+source.substr(start+DIRECTIVE.length(),alternate-start-DIRECTIVE.length())+source.substr(finish+6)

static func _rewrite_tokens(source: String,replacements: Dictionary) -> String:
	var token:=RegEx.new()
	if token.compile("\\b[A-Za-z_]\\w*\\b")!=OK:return ""
	var out:="";var at:=0
	for match_row in token.search_all(source):
		out+=source.substr(at,match_row.get_start()-at)
		var name:=match_row.get_string()
		out+=str(replacements.get(name,name))
		at=match_row.get_end()
	return out+source.substr(at)

static func _rotation_columns(source: String) -> String:
	var constructor:=RegEx.create_from_string("\\breturn\\s+mat4\\s*\\(([^()]*)\\)\\s*;")
	var row:=constructor.search(source)
	if row==null:return ""
	var coefficients:=row.get_string(1).split(",")
	if coefficients.size()!=16:return ""
	for index in coefficients.size():
		coefficients[index]=coefficients[index].strip_edges()
		if coefficients[index].is_empty():return ""
	# GLSL supplied each column as four consecutive scalars. Godot requires
	# an explicit vec4 for each column in that same order.
	var columns:=PackedStringArray()
	for start in range(0,16,4):
		columns.append("vec4("+", ".join(coefficients.slice(start,start+4))+")")
	return source.substr(0,row.get_start())+"return mat4(\n\t"+",\n\t".join(columns)+");"+source.substr(row.get_end())

static func _adapt_installed_source(source: String) -> Dictionary:
	var names: Array[String]=["distanceToCone","distanceToRect","rotate","GetThrobStrength","ApplyTargetGroundHighlighting"]
	var replacements: Dictionary={
		"targetShape":"nwn_target_shape",
		"targetShapeSizeX":"nwn_target_size.x",
		"targetShapeSizeY":"nwn_target_size.y",
		"targetShapeSpellRange":"nwn_target_range",
		"targetObjectType":"nwn_target_type",
		"targetWorldCoords":"nwn_target_point",
		"playerPosition":"nwn_target_player",
		"worldtimerTimeOfDay":"nwn_target_time_ms",
		"targetShapeOriginOnSelf":"((nwn_target_flags & 16) != 0 ? 1 : 0)",
		"vPosWorld":"nwn_target_world"
	}
	for name in names:replacements[name]="nwn_target_source_"+name
	for name in ["TARGET_SHAPE_NONE","TARGET_SHAPE_SPHERE","TARGET_SHAPE_RECT","TARGET_SHAPE_CONE","TARGET_SHAPE_HSPHERE","TARGET_OBJECT_TYPE_NONE"]:
		var value:=_integer_define(source,name)
		if value.is_empty():return {"error":"Native target shader constant unavailable: "+name}
		replacements[name]=value
	var suffix:=RegEx.new()
	if suffix.compile("\\b([0-9]+\\.[0-9]+)f\\b")!=OK:return {"error":"Native target shader float-suffix matcher failed"}
	var comments:=RegEx.new()
	if comments.compile("(?m)//[^\\r\\n]*")!=OK:return {"error":"Native target shader comment matcher failed"}
	var declared: Dictionary=ShdSource.declared_symbols(source)
	var identifiers:=RegEx.new()
	if identifiers.compile("\\b[A-Za-z_]\\w*\\b")!=OK:return {"error":"Native target shader identifier matcher failed"}
	var local_constants: Dictionary={"outlineWidth":true,"sin30Degrees":true,"cos30Degrees":true,"PI":true}
	var functions:=PackedStringArray()
	for name in names:
		var body:=_function_source(source,name)
		if body.is_empty():return {"error":"Native target shader function unavailable: "+name}
		body=comments.sub(body,"",true)
		if name=="ApplyTargetGroundHighlighting":
			if not body.contains("inout vec4 FragmentColor"):return {"error":"Native target shader output signature is unsupported"}
			body=body.replace("inout vec4 FragmentColor","inout vec4 FragmentColor, vec3 nwn_target_world")
			body=_world_stage(body)
			if body.is_empty():return {"error":"Native target shader world-position stage is unsupported"}
		body=body.replace("COLOR_WHITE.rgb","vec3(1.0)")
		body=body.replace("targetShapeColour.rgb","nwn_target_color")
		body=body.replace("targetShapeColour.a","1.0")
		body=suffix.sub(body,"$1",true)
		if name=="rotate":
			body=_rotation_columns(body)
			if body.is_empty():return {"error":"Native target shader rotation coefficients are unsupported"}
		for identifier in identifiers.search_all(body):
			var symbol:=identifier.get_string()
			if declared.has(symbol) and not replacements.has(symbol) and not local_constants.has(symbol):
				return {"error":"Native target shader symbol is unsupported: "+symbol}
		body=_rewrite_tokens(body,replacements)
		if body.is_empty() or body.contains("#") or body.contains("targetShapeColour") or body.contains("vPosView") or body.contains("m_view_inv") or body.contains("gl_"):
			return {"error":"Native target shader contains unsupported stage syntax: "+name}
		functions.append(body)
	return {"code":SHADER_UNIFORMS+"\n".join(functions)+"""
vec3 nwn_target_overlay(vec3 godot_world){
 vec3 nwn_target_world=vec3(godot_world.x,-godot_world.z,godot_world.y);
 vec4 nwn_target_fragment=vec4(0.0);
 nwn_target_source_ApplyTargetGroundHighlighting(nwn_target_fragment,nwn_target_world);
 return nwn_target_fragment.rgb;
}
"""}

static func code()->String:
	if loaded() and not translated_code.is_empty():return translated_code
	# Materials can be built before the installed catalog opens. A disabled
	# preview has no visual output; loading a source changes the shader key.
	return SHADER_UNIFORMS+"vec3 nwn_target_overlay(vec3 unused_world){return vec3(0.0);}\n"
