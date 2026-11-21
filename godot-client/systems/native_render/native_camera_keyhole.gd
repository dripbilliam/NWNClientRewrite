extends RefCounted
const ShdSource=preload("res://systems/native_render/native_shd_source.gd")
# Direct spatial-shader translation of the installed inc_keyhole SHD, with its
# NoiseSimplex3D dependency from inc_common. Coordinates entering the shader
# are converted from Godot xyz back to the original NWN x,-z,y convention.
static var registered:=false
static var current: Dictionary={"enabled":false}
static var source_profile: Dictionary={"loaded":false,"resources":[],"sha256":"","error":"Native keyhole shader has not been loaded"}
static var source_variants: Dictionary={}
static var translated_code: String=""
const SHADER_UNIFORMS="""
global uniform vec2 nwn_keyhole_screen;
global uniform float nwn_keyhole_pitch;
global uniform float nwn_keyhole_distance;
global uniform vec3 nwn_keyhole_player;
instance uniform int nwn_keyhole_can=0;
varying float nwn_keyhole_view_z;
varying float nwn_keyhole_offset;
const float nwn_keyhole_diameter_min=0.4;
const float nwn_keyhole_diameter_max=0.9;
const float nwn_keyhole_min_z_offset=1.0;
"""
const STAGE_DEFINES:="#define SHADER_TYPE 1\n#define KEYHOLING 1\n#define KEYHOLING_ENABLED 1\n#define NO_DISCARD 0\n#define LIGHTING 0\n#define FOG 0\n#define MAX_NUM_LIGHTS 0\n#define MAX_NUM_BONES 0\n#define FRAGMENT_LIGHTING 0\n#define GAMMA_CORRECTION 0\n#define SHADER_DEBUG_MODE 0\n#define SHADER_QUALITY_MODE 1\n#define POSTPROCESSING_TYPES_ENABLED 0\n"
const REQUIRED=["ApplyKeyhole","SetupKeyholeFactors","vPosView","fFragCamOffset","m_view_inv","screenParams","pixelParams","keyholeCanDissolve","cameraPitch","playerCameraDist","playerPosition","keyholeDiameterMin","keyholeDiameterMax","keyholeMinZOffset"]

static func _stage_source(source: String,symbols: Dictionary,stage: int) -> String:
	# Preserve the old loader's desktop precision normalization and declaration
	# namespace. These GLSL strings are not executable Godot spatial shaders.
	var text: String=STAGE_DEFINES.replace("SHADER_TYPE 1","SHADER_TYPE "+str(stage))+source
	var precision:=RegEx.new()
	precision.compile("\\b([ib]?vec[234]|float|int)\\s+(highp|mediump|lowp)\\b")
	var normalized:=""
	var at:=0
	for row in precision.search_all(text):
		normalized+=text.substr(at,row.get_start()-at)+row.get_string(2)+" "+row.get_string(1)
		at=row.get_end()
	normalized+=text.substr(at)
	var names:=RegEx.new()
	names.compile("\\b[A-Za-z_]\\w*\\b")
	var renamed:=""
	at=0
	for row in names.search_all(normalized):
		var name: String=row.get_string()
		renamed+=normalized.substr(at,row.get_start()-at)+("nwnKeyhole_"+name if symbols.has(name) else name)
		at=row.get_end()
	return renamed+normalized.substr(at)

static func load_profile(catalog) -> bool:
	source_variants={}
	translated_code=""
	var result: Dictionary=ShdSource.load(catalog,"inc_keyhole",[])
	if result.has("error"):
		source_profile={"loaded":false,"resources":[],"sha256":"","error":str(result.error)}
		return false
	var symbols: Dictionary=ShdSource.declared_symbols(STAGE_DEFINES+str(result.source))
	for name in REQUIRED:
		if symbols.has(name):continue
		source_profile={"loaded":false,"resources":result.resources,"sha256":result.sha256,"error":"Native keyhole shader declaration "+str(name)+" is unavailable"}
		return false
	symbols.erase("discard")
	source_variants={"vertex":_stage_source(str(result.source),symbols,1),"fragment":_stage_source(str(result.source),symbols,2),"symbols":symbols.keys()}
	var adapted: Dictionary=_adapt_installed_source(str(result.source))
	if adapted.has("error"):
		source_profile={"loaded":false,"resources":result.resources,"sha256":result.sha256,"error":str(adapted.error)}
		return false
	translated_code=str(adapted.code)
	source_profile={"loaded":true,"resources":result.resources,"sha256":result.sha256,"cacheKey":ShdSource.fnv_cache_key(str(result.source)),"error":"","translation":"Installed inc_keyhole vertex/fragment functions adapted into the Godot spatial material"}
	return true

static func loaded() -> bool:return bool(source_profile.get("loaded",false))
static func source_identity() -> String:return "inc_keyhole:2069:"+str(source_profile.get("cacheKey","unloaded"))
static func profile_snapshot() -> Dictionary:return source_profile.duplicate(true)

static func ensure() -> void:
	if registered:return
	RenderingServer.global_shader_parameter_add("nwn_keyhole_screen",RenderingServer.GLOBAL_VAR_TYPE_VEC2,Vector2.ONE)
	RenderingServer.global_shader_parameter_add("nwn_keyhole_pitch",RenderingServer.GLOBAL_VAR_TYPE_FLOAT,50.0)
	RenderingServer.global_shader_parameter_add("nwn_keyhole_distance",RenderingServer.GLOBAL_VAR_TYPE_FLOAT,20.0)
	RenderingServer.global_shader_parameter_add("nwn_keyhole_player",RenderingServer.GLOBAL_VAR_TYPE_VEC3,Vector3.ZERO)
	registered=true

static func publish(screen: Vector2,pitch: float,distance: float,player: Vector3) -> void:
	ensure()
	var next: Dictionary={"enabled":true,"screen":screen,"pitch":pitch,"distance":distance,"player":player}
	if current==next:return
	current=next
	RenderingServer.global_shader_parameter_set("nwn_keyhole_screen",screen)
	RenderingServer.global_shader_parameter_set("nwn_keyhole_pitch",pitch)
	RenderingServer.global_shader_parameter_set("nwn_keyhole_distance",distance)
	RenderingServer.global_shader_parameter_set("nwn_keyhole_player",player)

static func reset() -> void: current={"enabled":false}
static func snapshot() -> Dictionary:return current.duplicate(true)

# This is a bounded adapter for the installed inc_keyhole stage pair and its
# sqr/permute/NoiseSimplex3D dependencies, not a general GLSL compiler.
static func _function_source(source: String,name: String) -> String:
	var pattern:=RegEx.new()
	if pattern.compile("(?m)\\b(?:float|vec4|void)\\s+"+name+"\\s*\\([^)]*\\)\\s*\\{")!=OK:return ""
	var row:=pattern.search(source)
	if row==null:return ""
	var opening:=source.find("{",row.get_start())
	var depth:=0
	for index in range(opening,source.length()):
		var point:=source.unicode_at(index)
		if point==123:depth+=1
		elif point==125:
			depth-=1
			if depth==0:return source.substr(row.get_start(),index-row.get_start()+1)
	return ""

static func _float_constant(source: String,name: String) -> String:
	var pattern:=RegEx.new()
	if pattern.compile("(?m)^\\s*const\\s+float\\s+"+name+"\\s*=\\s*([0-9]+(?:\\.[0-9]+)?)\\s*;")!=OK:return ""
	var row:=pattern.search(source)
	return row.get_string(1) if row!=null else ""

static func _rewrite_tokens(source: String,replacements: Dictionary) -> String:
	var token:=RegEx.new()
	if token.compile("\\b[A-Za-z_]\\w*\\b")!=OK:return ""
	var out:="";var at:=0
	for row in token.search_all(source):
		out+=source.substr(at,row.get_start()-at)
		var name:=row.get_string()
		out+=str(replacements.get(name,name))
		at=row.get_end()
	return out+source.substr(at)

static func _adapt_installed_source(source: String) -> Dictionary:
	var names: Array[String]=["sqr","permute","NoiseSimplex3D","SetupKeyholeFactors","ApplyKeyhole"]
	var replacements: Dictionary={
		"sqr":"nwn_keyhole_source_sqr",
		"permute":"nwn_keyhole_source_permute",
		"NoiseSimplex3D":"nwn_keyhole_source_noise",
		"SetupKeyholeFactors":"nwn_keyhole_setup",
		"ApplyKeyhole":"nwn_keyhole_source_apply",
		"keyholeCanDissolve":"nwn_keyhole_can",
		"fFragCamOffset":"nwn_keyhole_offset",
		"cameraPitch":"nwn_keyhole_pitch",
		"playerCameraDist":"nwn_keyhole_distance",
		"playerPosition":"nwn_keyhole_player",
		"keyholeDiameterMin":"nwn_keyhole_diameter_min",
		"keyholeDiameterMax":"nwn_keyhole_diameter_max",
		"keyholeMinZOffset":"nwn_keyhole_min_z_offset",
		"invScreenWidth":"(1.0/nwn_keyhole_screen.x)",
		"invScreenHeight":"(1.0/nwn_keyhole_screen.y)",
		"fAspectRatio":"(nwn_keyhole_screen.x/nwn_keyhole_screen.y)"
	}
	for name in ["fKeyholeBlackness","fKeyholeNoiseModifier","fKeyholePunchthroughPoint","fKeyholeSizeBase"]:
		var value:=_float_constant(source,name)
		if value.is_empty():return {"error":"Native keyhole shader constant unavailable: "+name}
		replacements[name]=value
	var comments:=RegEx.new();var precision:=RegEx.new();var bare_float:=RegEx.new()
	if comments.compile("(?m)//[^\\r\\n]*")!=OK or precision.compile("\\b(?:highp|mediump|lowp)\\s+")!=OK or bare_float.compile("\\b([0-9]+)\\.(?![0-9])")!=OK:
		return {"error":"Native keyhole shader syntax matcher failed"}
	var declared: Dictionary=ShdSource.declared_symbols(STAGE_DEFINES+source)
	var identifiers:=RegEx.new()
	if identifiers.compile("\\b[A-Za-z_]\\w*\\b")!=OK:return {"error":"Native keyhole shader identifier matcher failed"}
	var local_constants: Dictionary={"C":true,"D":true,"n_":true,"discard":true}
	var functions:=PackedStringArray()
	for name in names:
		var body:=_function_source(source,name)
		if body.is_empty():return {"error":"Native keyhole shader function unavailable: "+name}
		body=comments.sub(body,"",true)
		if name=="SetupKeyholeFactors":
			# Godot only permits varying assignment in vertex(), not in a helper.
			# Keep the installed branch math local and return its source offset.
			var setup_signature:=RegEx.new()
			if setup_signature.compile("\\bvoid\\s+SetupKeyholeFactors\\s*\\(\\s*\\)\\s*\\{")!=OK or setup_signature.search(body)==null or body.contains("return"):
				return {"error":"Native keyhole vertex setup signature is unsupported"}
			body=setup_signature.sub(body,"float SetupKeyholeFactors(){float nwn_keyhole_offset_local=0.0;",false)
			body=body.replace("fFragCamOffset","nwn_keyhole_offset_local")
			var closing:=body.rfind("}")
			if closing<0:return {"error":"Native keyhole vertex setup body is incomplete"}
			body=body.substr(0,closing)+"return nwn_keyhole_offset_local;"+body.substr(closing)
		if name=="ApplyKeyhole":
			if not body.contains("inout vec4 ColorIO"):return {"error":"Native keyhole output signature is unsupported"}
			body=body.replace("inout vec4 ColorIO","inout vec4 ColorIO, vec2 nwn_keyhole_frag_coord, vec3 nwn_keyhole_world")
			if not body.contains("(m_view_inv * vec4(vPosView, 1.0)).xyz"):return {"error":"Native keyhole world-position expression is unsupported"}
			body=body.replace("(m_view_inv * vec4(vPosView, 1.0)).xyz","nwn_keyhole_world")
			body=body.replace("gl_FragCoord.x","nwn_keyhole_frag_coord.x").replace("gl_FragCoord.y","nwn_keyhole_frag_coord.y")
			body=body.replace("#if NO_DISCARD != 1","").replace("#endif","")
		body=body.replace("vPosView.z","nwn_keyhole_view_z")
		body=precision.sub(body,"",true)
		body=bare_float.sub(body,"$1.0",true)
		for identifier in identifiers.search_all(body):
			var symbol:=identifier.get_string()
			if declared.has(symbol) and not replacements.has(symbol) and not local_constants.has(symbol):
				return {"error":"Native keyhole shader symbol is unsupported: "+symbol}
		body=_rewrite_tokens(body,replacements)
		if body.is_empty() or body.contains("#") or body.contains("vPosView") or body.contains("m_view_inv") or body.contains("gl_FragCoord"):
			return {"error":"Native keyhole shader contains unsupported stage syntax: "+name}
		functions.append(body)
	return {"code":SHADER_UNIFORMS+"\n".join(functions)+"""
void nwn_keyhole_apply(inout vec3 color,inout vec3 emissive,vec2 frag_coord,vec3 godot_world){
 vec3 native_world=vec3(godot_world.x,-godot_world.z,godot_world.y);
 vec4 tint=vec4(1.0);
 nwn_keyhole_source_apply(tint,frag_coord,native_world);
 color*=tint.rgb;
 emissive*=tint.rgb;
}
"""}

static func code() -> String:
	if loaded() and not translated_code.is_empty():return translated_code
	return SHADER_UNIFORMS+"""
float nwn_keyhole_setup(){return 0.0;}
void nwn_keyhole_apply(inout vec3 color,inout vec3 emissive,vec2 frag_coord,vec3 godot_world){}
"""
