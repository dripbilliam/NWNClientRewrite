extends Node
# Native renderer-only warmup. Authored white images are never attached to world
# objects. Use the production pool's exact material recipe, retain its bounded
# shader owners, and never read mod/server data or create a gameplay object.
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Timing=preload("res://systems/native_render/frame_profile.gd")
var pool:=Pool.new()
var recipes: Array=[]
var materials: Array=[]
var enabled:=false
var closed:=false
var stats:={"enabled":false,"done":false,"closed":false,"prepared":0,"expected":20,"retained_materials":0,"retained_textures":0,"material_ms":0.0,"shader_request_ms":0.0,"maximum_step_ms":0.0,"failures":[]}
func raster(opaque: bool) -> Dictionary:
	var bytes:=PackedByteArray([255,255,255,255,0,0,0,0]) if opaque else PackedByteArray()
	if not opaque: bytes.resize(64); bytes.fill(255)
	var format:="dxt1_rgb" if opaque else "rgba8"
	return {"sha256":Cache.digest(("authored-material-prewarm:"+format).to_utf8_buffer()+bytes),"value":{"width":4,"height":4,"format":format,"mips":[{"width":4,"height":4,"data":bytes}]}}
func start(value: bool=true) -> void:
	if closed or enabled: return
	enabled=value
	stats.enabled=enabled
	if not enabled: stats.done=true; set_process(false); return
	var rgba:=raster(false); var opaque:=raster(true)
	for unshaded in [false,true]:
		for emission in [false,true]:
			for textured in [false,true]:
				for alpha in ([0,1,2] if textured else [0,1]):
					recipes.append({"unshaded":unshaded,"part":{"alpha":0.75 if alpha==1 else 1.0,"selfillum":[1.0,1.0,1.0] if emission else [0.0,0.0,0.0],"mesh":{"diffuse":[1.0,1.0,1.0],"transparency_hint":alpha==1}},"raster":(opaque if alpha==0 else rgba) if textured else {}})
	set_process(true)
func step() -> void:
	if not enabled or closed or recipes.is_empty(): set_process(false); return
	var began:=Time.get_ticks_usec(); var row: Dictionary=recipes.pop_front(); pool.unshaded=bool(row.unshaded)
	var material=pool.material(row.part,row.raster); var at:=Time.get_ticks_usec()
	stats.material_ms+=(at-began)/1000.0
	if material==null: stats.failures.append(pool.failure); set_process(false); return
	var rid: RID=material.get_rid()
	stats.shader_request_ms+=(Time.get_ticks_usec()-at)/1000.0
	if not rid.is_valid(): stats.failures.append("Material shader warmup returned an invalid native RID"); set_process(false); return
	materials.append(material); stats.prepared+=1
	stats.retained_materials=materials.size(); stats.retained_textures=pool.textures.size()
	stats.maximum_step_ms=maxf(float(stats.maximum_step_ms),(Time.get_ticks_usec()-began)/1000.0)
	if recipes.is_empty(): stats.done=true; set_process(false)
func _process(_delta: float) -> void:
	var began:=Timing.begin(); step(); Timing.finish("material_shader_warmup_ms",began); Timing.finish("callback_material_prewarm",began)
func snapshot() -> Dictionary:
	return {"enabled":enabled,"done":not enabled or recipes.is_empty(),"prepared":stats.prepared,"expected":stats.expected,"pending":recipes.size(),"material_ms":stats.material_ms,"shader_request_ms":stats.shader_request_ms,"maximum_step_ms":stats.maximum_step_ms,"failures":stats.failures.duplicate(),"retained_materials":materials.size(),"retained_textures":pool.textures.size(),"closed":closed,"scope":"Bounded native material/shader owners only; authored white warmup resources never replace or render world assets"}
func close() -> void:
	if closed: return
	closed=true; set_process(false); recipes.clear(); materials.clear(); pool.clear()
	stats.closed=true; stats.retained_materials=0; stats.retained_textures=0
func _exit_tree() -> void: close()
