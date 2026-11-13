extends Node
# Per-world native standard-material profile and SET-selected 2D environment.
# Original Scene::Render chooses SET EnvMap, then chrome1 on lookup failure.
# Payload decoding uses existing native workers; late/retired worlds cannot
# replace a newer world's global sampler. Cube/mapped profiles remain open.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const RETAIL_SHADERS:={"inc_common":"20ecd0437d31e26ee797c83422c83870d62c7f910ca3bffc2473553401575337","inc_config":"8ae83f7fa429b2d646e7fe421edd25bdfb8c13724a56d5bdb2346b27ae258a8d","inc_material":"e6b53caa87429237c32b37606b956f3b6fc20eeff69ddedd35a3128c0a3992ac","inc_lighting":"8548ea59d662829521e0618edb1511fc2a88a3ecf7108ead86829b8f3d200bf8"}
const RETAIL_PROGRAMS:={"inc_envmap":"c63fad7bb9734cd566ff0923e30ebefbd36608dc39aef0610e1e21d0449da107","inc_standard":"ba71b3946a52552078db408e4949075f548f4cfc40ea29a89aba138d85545148","fslit":"c7ff8b64841c40a809ef69a28339a2c4b48c7a5ec5e68f32073f411fe6c0cfa6"}
static var active_id:=0
var catalog
var pool
var assets
var closed:=false
var enabled:=false
var hashes: Dictionary={}
var jobs: Dictionary={}
var selected:=""
var requested:=""
var map_ready:=false
var failure:=""
var publications:=0
var profile_us:=0
func configure(source,shared_pool) -> void:
	catalog=source; pool=shared_pool; pool.native_standard=false
	if not pool.native_lighting: return
	var began:=Time.get_ticks_usec()
	var expected: Dictionary=RETAIL_SHADERS.merged(RETAIL_PROGRAMS)
	for name in expected:
		var bytes: PackedByteArray=catalog.get_resource(name,2069)
		if bytes.is_empty(): failure="Native standard shader profile unavailable: "+name; break
		hashes[name]=Cache.digest(bytes)
		if hashes[name]!=expected[name]: failure="Active native shader profile requires mapping: "+name; break
	profile_us=Time.get_ticks_usec()-began
	if not failure.is_empty(): return
	enabled=true; pool.native_standard=true; active_id=get_instance_id(); Palette.environment(null)
	assets=Assets.new(); add_child(assets); assets.maximum_workers=1; assets.configure(catalog); assets.completed.connect(completed)
	request_map("chrome1")
static func selected_name(definition: Dictionary) -> String:
	var general: Dictionary=definition.get("tileset",{}).get("sections",{}).get("GENERAL",{})
	for key in general:
		if str(key).to_lower()=="envmap":
			var name:=str(general[key]).strip_edges().to_lower()
			return "chrome1" if name in ["","null","****"] else name
	return "chrome1"
func receive_definition(definition: Dictionary) -> void:
	if enabled and not closed: request_map(selected_name(definition))
func request_map(name: String) -> void:
	if closed or not enabled or requested==name: return
	requested=name
	var location: Dictionary=catalog.raster_location(name)
	if location.is_empty():
		if name!="chrome1": request_map("chrome1")
		else: failure="Native fallback environment bitmap unavailable"
		return
	var job: int=assets.request(name,int(location.type),"raster")
	if job<0: failure=assets.failure; return
	jobs[job]=name
func completed(id: int,result: Dictionary) -> void:
	if not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if closed or active_id!=get_instance_id() or name!=requested: return
	if not str(result.get("error","")).is_empty():
		failure="Native environment decode: "+str(result.error); return
	var texture=pool.texture(result)
	if texture==null: failure=pool.failure; return
	Palette.environment(texture); selected=name; map_ready=true; publications+=1; failure=""
func snapshot() -> Dictionary:
	return {"enabled":enabled,"ready":map_ready,"requested":requested,"selected":selected,"closed":closed,"failure":failure,"pending":jobs.size(),"publications":publications,"profile_us":profile_us,"shader_sha256":hashes.duplicate(),"policy":"Original retail fragment-lit ordinary materials and SET-selected 2D environment; mapped/cube and quality-0 vertex paths pending"}
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(assets): assets.close()
	jobs.clear()
	if active_id==get_instance_id(): active_id=0; Palette.environment(null)
func _exit_tree() -> void: close()
