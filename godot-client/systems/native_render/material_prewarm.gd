extends Node
# Native renderer-only warmup. Authored white images are never attached to world
# objects. Use the production pool's exact material recipe, retain its bounded
# shader owners, and never read mod/server data or create a gameplay object.
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
const NativeMaterial=preload("res://systems/native_render/native_model_material.gd")
var pool:=Pool.new()
var recipes: Array=[]
var materials: Array=[]
var policy: Dictionary={}
var native_family_keys: Dictionary={}
var enabled:=false
var closed:=false
var stats:={"enabled":false,"done":false,"closed":false,"prepared":0,"expected":20,"retained_materials":0,"retained_textures":0,"material_ms":0.0,"shader_request_ms":0.0,"maximum_step_ms":0.0,"failures":[],"policy":{},"policy_failure":"","policy_resets":0,"native_families_prepared":0,"native_family_keys":[]}
static func policy_from_pool(source) -> Dictionary:
	# Copy only final scalar policy, never retain a live render pool or world.
	return {"native_lighting":bool(source.native_lighting),"native_standard":bool(source.native_standard),"native_surface_output":bool(source.native_surface_output),"texture_filter":int(source.texture_filter)}
func configure_policy(value: Dictionary) -> bool:
	if closed or OS.get_thread_caller_id()!=OS.get_main_thread_id():return false
	for name in ["native_lighting","native_standard","native_surface_output"]:
		if not value.get(name) is bool:stats.policy_failure="Warmup policy requires boolean "+name;return false
	if not value.get("texture_filter") is int or int(value.texture_filter) not in [BaseMaterial3D.TEXTURE_FILTER_NEAREST,BaseMaterial3D.TEXTURE_FILTER_LINEAR,BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC,BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC]:
		stats.policy_failure="Unsupported warmup texture filter";return false
	var next: Dictionary={}
	for name in ["native_lighting","native_standard","native_surface_output","texture_filter"]:next[name]=value[name]
	stats.policy_failure=""
	if next==policy:return true
	policy=next;policy.make_read_only();stats.policy=next.duplicate()
	if enabled:
		_reset_owned();stats.policy_resets+=1;_enqueue();set_process(true)
	return true
func _reset_owned(reset_progress: bool=true) -> void:
	set_process(false);recipes.clear();materials.clear();native_family_keys.clear();pool.clear()
	stats.retained_materials=0;stats.retained_textures=0
	if reset_progress:stats.prepared=0;stats.native_families_prepared=0;stats.native_family_keys=[];stats.done=false
func raster(opaque: bool) -> Dictionary:
	var bytes:=PackedByteArray([255,255,255,255,0,0,0,0]) if opaque else PackedByteArray()
	if not opaque: bytes.resize(64); bytes.fill(255)
	var format:="dxt1_rgb" if opaque else "rgba8"
	return {"sha256":Cache.digest(("authored-material-prewarm:"+format).to_utf8_buffer()+bytes),"value":{"width":4,"height":4,"format":format,"mips":[{"width":4,"height":4,"data":bytes}]}}
func start(value: bool=true) -> void:
	if closed or enabled: return
	if value and policy.is_empty():configure_policy(policy_from_pool(pool))
	enabled=value
	stats.enabled=enabled
	if not enabled: stats.done=true; set_process(false); return
	_enqueue();set_process(true)
func _enqueue() -> void:
	var rgba:=raster(false); var opaque:=raster(true)
	for unshaded in [false,true]:
		for emission in [false,true]:
			for textured in [false,true]:
				for alpha in ([0,1,2] if textured else [0,1]):
					recipes.append({"native":false,"unshaded":unshaded,"part":{"alpha":0.75 if alpha==1 else 1.0,"selfillum":[1.0,1.0,1.0] if emission else [0.0,0.0,0.0],"mesh":{"diffuse":[1.0,1.0,1.0],"transparency_hint":alpha==1}},"raster":(opaque if alpha==0 else rgba) if textured else {}})
	# Production native material quality is fixed at2 in ResourcePool. These
	# three recipes request the exact final opaque/blended/scissor shader keys;
	# colors/emission/textures are uniforms and need no extra native families.
	if bool(policy.native_lighting):
		for alpha in [0,1,2]:
			var key:=NativeMaterial.variant_key(alpha==1,alpha==2,int(policy.texture_filter),bool(policy.native_standard),2,bool(policy.native_surface_output),false)
			# A verified policy change warms its native families immediately,
			# before the preserved legacy requests rather than twenty frames later.
			recipes.insert(alpha,{"native":true,"family_key":key,"unshaded":false,"part":{"alpha":0.75 if alpha==1 else 1.0,"selfillum":[0.0,0.0,0.0],"mesh":{"diffuse":[1.0,1.0,1.0],"transparency_hint":alpha==1}},"raster":opaque if alpha==0 else rgba})
	stats.expected=recipes.size()
func step() -> void:
	if not enabled or closed or recipes.is_empty(): set_process(false); return
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():stats.failures.append("Material warmup requires main thread");set_process(false);return
	var began:=Time.get_ticks_usec(); var row: Dictionary=recipes.pop_front()
	if bool(row.native) and native_family_keys.has(row.family_key):
		if recipes.is_empty():stats.done=true;set_process(false)
		return
	pool.unshaded=bool(row.unshaded);pool.texture_filter=int(policy.texture_filter)
	pool.native_lighting=bool(row.native);pool.native_standard=bool(policy.native_standard) if row.native else false;pool.native_surface_output=bool(policy.native_surface_output) if row.native else false
	var material=pool.material(row.part,row.raster); var at:=Time.get_ticks_usec()
	stats.material_ms+=(at-began)/1000.0
	if material==null: stats.failures.append(pool.failure); set_process(false); return
	if bool(row.native):
		if not material is NativeMaterial or material.shader_variant_key()!=str(row.family_key):stats.failures.append("Warmup final native shader policy mismatch");set_process(false);return
	var rid: RID=material.get_rid()
	stats.shader_request_ms+=(Time.get_ticks_usec()-at)/1000.0
	if not rid.is_valid(): stats.failures.append("Material shader warmup returned an invalid native RID"); set_process(false); return
	materials.append(material); stats.prepared+=1
	if bool(row.native):native_family_keys[row.family_key]=true;stats.native_families_prepared=native_family_keys.size();stats.native_family_keys=native_family_keys.keys()
	stats.retained_materials=materials.size(); stats.retained_textures=pool.textures.size()
	stats.maximum_step_ms=maxf(float(stats.maximum_step_ms),(Time.get_ticks_usec()-began)/1000.0)
	if recipes.is_empty(): stats.done=true; set_process(false)
func _process(_delta: float) -> void:
	var began:=Timing.begin(); step(); Timing.finish("material_shader_warmup_ms",began); Timing.finish("callback_material_prewarm",began)
func snapshot() -> Dictionary:
	return {"enabled":enabled,"done":not enabled or recipes.is_empty(),"prepared":stats.prepared,"expected":stats.expected,"pending":recipes.size(),"material_ms":stats.material_ms,"shader_request_ms":stats.shader_request_ms,"maximum_step_ms":stats.maximum_step_ms,"failures":stats.failures.duplicate(),"retained_materials":materials.size(),"retained_textures":pool.textures.size(),"closed":closed,"policy":policy.duplicate(),"policy_failure":stats.policy_failure,"policy_resets":stats.policy_resets,"native_families_prepared":stats.native_families_prepared,"native_family_keys":stats.native_family_keys.duplicate(),"scope":"At most20 legacy materials plus3 unique final native shader families for the copied verified production policy; authored white resources never replace or render world assets. Main-thread requests can exceed one frame; no GPU completion guarantee."}
func close() -> void:
	if closed: return
	# Keep completed/requested diagnostic counts after releasing every owner.
	closed=true;_reset_owned(false)
	stats.closed=true;stats.done=true; stats.retained_materials=0; stats.retained_textures=0
func _exit_tree() -> void: close()
