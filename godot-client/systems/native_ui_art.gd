extends Node
# Native archive reads and GUI-model rendering. No browser or prepared images.
signal loaded(key: String,texture: Texture2D,bounds: Dictionary)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const SharedRasters=preload("res://systems/native_data/shared_ui_rasters.gd")
var assets
var models
var pool:=Pool.new()
var catalog
var ui_assets
var jobs: Dictionary={}
var bitmap_jobs: Dictionary={}
var waiting: Dictionary={}
var textures: Dictionary={}
var failed: Dictionary={}
var bounds: Dictionary={}
var binding_serial:=0
var bindings: Dictionary={}
var binding_resources: Dictionary={}
# Admission pressure is not a missing/corrupt bitmap. Keep one descriptor per
# current resource, bounded by its live weak bindings, until a completion frees
# real worker capacity. Superseded cells do not retain a retry/history queue.
var deferred: Dictionary={}
var stale_bindings:=0
var closed:=false
func configure(source,cache_path: String) -> void:
	closed=false
	catalog=source; ui_assets=source.ui_asset_owner() if source!=null and source.has_method("ui_asset_owner") else null
	assets=Assets.new(); add_child(assets); assets.configure(source); assets.maximum_workers=2; assets.cache_directory=cache_path; assets.completed.connect(prepared)
	models=Icons.new(); add_child(models); models.configure(source,cache_path); models.completed.connect(model_ready)
func unbind(target: Object,property: String="texture") -> void:
	if is_instance_valid(target): retire_binding(str(target.get_instance_id())+":"+property)
func retire_binding(binding_key: String) -> void:
	var key: String=str(binding_resources.get(binding_key,"")); var serial: int=int(bindings.get(binding_key,-1))
	bindings.erase(binding_key); binding_resources.erase(binding_key)
	if key.is_empty() or not waiting.has(key): return
	var retained: Array=[]
	for listener in waiting[key]:
		if str(listener.binding_key)==binding_key and int(listener.serial)==serial: stale_bindings+=1
		else: retained.append(listener)
	if retained.is_empty(): waiting.erase(key); deferred.erase(key)
	else: waiting[key]=retained
func bind(target: Object,resource: String,property: String="texture",model: bool=false,clip: String="up",portrait: bool=false,overrides: Dictionary={},render_region: Rect2=Rect2()) -> void:
	if closed or not is_instance_valid(target): return
	binding_serial+=1
	var binding_key:=str(target.get_instance_id())+":"+property
	retire_binding(binding_key)
	bindings[binding_key]=binding_serial
	if resource.is_empty() or resource=="****": bindings.erase(binding_key); return
	var key:=Icons.model_key(resource,clip,overrides,0,"",[],render_region) if model else resource.to_lower()
	var shared: Dictionary=ui_assets.lookup("model" if model else "raster",key) if ui_assets!=null else {}
	if not shared.is_empty(): textures[key]=shared.texture; bounds[key]=shared.bounds
	if not model and not textures.has(key):
		var process_texture: Texture2D=SharedRasters.lookup(catalog,resource)
		if process_texture!=null:
			textures[key]=process_texture
			if ui_assets!=null: ui_assets.retain("raster",key,process_texture)
	if textures.has(key): apply_image(target,property,textures[key],not model,portrait); bindings.erase(binding_key); return
	if failed.has(key): bindings.erase(binding_key); return
	binding_resources[binding_key]=key
	var listener:={"target":weakref(target),"property":property,"flip":not model,"portrait":portrait,"binding_key":binding_key,"serial":binding_serial}
	if waiting.has(key): waiting[key].append(listener); return
	waiting[key]=[listener]
	if model:
		var requested: String=models.request_model(resource,clip,overrides,0,"",[],render_region)
		if requested.is_empty(): fail_image(key)
		elif models.textures.has(requested): deliver(key,models.textures[requested])
	else:
		var location: Dictionary=catalog.raster_location(resource)
		if location.is_empty(): fail_image(key,"Original UI raster is missing"); return
		submit_bitmap(key,{"resource":resource,"type":int(location.type)})
func submit_bitmap(key: String,descriptor: Dictionary) -> bool:
	# A queued/running read survives listener retirement; a rapid revisit joins
	# that admitted job instead of spending another worker slot on the same bytes.
	if bitmap_jobs.has(key): deferred.erase(key); return true
	var id: int=assets.request(str(descriptor.resource),int(descriptor.type),"raster")
	if id>=0: jobs[id]=key; bitmap_jobs[key]=id; deferred.erase(key); return true
	if str(assets.failure)=="Native asset queue is full": deferred[key]=descriptor; return false
	fail_image(key); return true
func current_listeners(key: String) -> bool:
	var retained: Array=[]
	for listener in waiting.get(key,[]):
		if is_instance_valid(listener.target.get_ref()) and bindings.get(listener.binding_key,-1)==listener.serial: retained.append(listener)
		else:
			stale_bindings+=1
			if bindings.get(listener.binding_key,-1)==listener.serial: bindings.erase(listener.binding_key); binding_resources.erase(listener.binding_key)
	if retained.is_empty(): waiting.erase(key); deferred.erase(key); return false
	waiting[key]=retained; return true
func drain_deferred() -> void:
	if closed: return
	for key in deferred.keys():
		if not current_listeners(str(key)): continue
		if not submit_bitmap(str(key),deferred[key]): break
func bind_portrait(target: Object,resource: String) -> void:
	if resource.is_empty(): bind(target,""); return
	bind(target,portrait_resource(resource),"texture",false,"up",true)
func portrait_resource(resource: String) -> String:
	var suffixes:=["","t","s","m","l","h"]; var size:=suffixes.find(resource.right(1).to_lower())
	if size<=0: return resource
	return preload("res://systems/native_data/portrait_resources.gd").sized(resource.left(-1),size,catalog.has_resource)
static func portrait_texture(texture: Texture2D) -> AtlasTexture:
	# Original rasters retain bottom-left row order for 3D UVs. The GUI's
	# portrait rectangle uses only width*100/64 rows, excluding pad rows.
	var atlas:=AtlasTexture.new(); atlas.atlas=texture
	var height:=mini(texture.get_height(),roundi(texture.get_width()*100.0/64.0))
	atlas.region=Rect2(0,texture.get_height()-height,texture.get_width(),height)
	return atlas
static func apply_image(target: Object,property: String,texture: Texture2D,flip: bool,portrait: bool) -> void:
	target.set(property,portrait_texture(texture) if portrait else texture)
	if target is TextureRect: target.flip_v=flip
func prepared(id: int,result: Dictionary) -> void:
	if not jobs.has(id): return
	var key:=str(jobs[id]); jobs.erase(id)
	if bitmap_jobs.get(key,-1)==id: bitmap_jobs.erase(key)
	if not str(result.error).is_empty(): fail_image(key,str(result.error)); drain_deferred(); return
	var texture=pool.texture(result)
	if texture==null: fail_image(key); drain_deferred(); return
	deliver(key,texture); drain_deferred()
func request_model(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,texture_layer: String="",poses: Array=[],render_region: Rect2=Rect2()) -> String:
	var expected: String=Icons.model_key(name,clip,overrides,turn,texture_layer,poses,render_region)
	var shared: Dictionary=ui_assets.lookup("model",expected) if ui_assets!=null else {}
	if not shared.is_empty(): textures[expected]=shared.texture; bounds[expected]=shared.bounds; return expected
	var key: String=models.request_model(name,clip,overrides,turn,texture_layer,poses,render_region)
	if models.textures.has(key): textures[key]=models.textures[key]; bounds[key]=models.image_bounds.get(key,{})
	return key
func model_ready(key: String,texture: Texture2D,error: String) -> void:
	if not error.is_empty() or texture==null: fail_image(key,error); return
	bounds[key]=models.image_bounds.get(key,{})
	deliver(key,texture)
func deliver(key: String,texture: Texture2D) -> void:
	textures[key]=texture
	if not key.begins_with("gui:"): SharedRasters.retain(catalog,key,texture)
	if ui_assets!=null: ui_assets.retain("model" if key.begins_with("gui:") else "raster",key,texture,bounds.get(key,{}))
	loaded.emit(key,texture,bounds.get(key,{}))
	for listener in waiting.get(key,[]):
		var target: Object=listener.target.get_ref()
		if is_instance_valid(target) and bindings.get(listener.binding_key,-1)==listener.serial:
			apply_image(target,str(listener.property),texture,bool(listener.flip),bool(listener.portrait)); bindings.erase(listener.binding_key); binding_resources.erase(listener.binding_key)
		else:
			stale_bindings+=1
			if bindings.get(listener.binding_key,-1)==listener.serial: bindings.erase(listener.binding_key); binding_resources.erase(listener.binding_key)
	waiting.erase(key); deferred.erase(key)
func fail_image(key: String,reason: String="Original UI image could not be prepared") -> void:
	failed[key]=true
	if ui_assets!=null: ui_assets.note_failure("model" if key.begins_with("gui:") else "raster",key,reason)
	for listener in waiting.get(key,[]):
		if bindings.get(listener.binding_key,-1)==listener.serial: bindings.erase(listener.binding_key); binding_resources.erase(listener.binding_key)
	waiting.erase(key); deferred.erase(key)
func close() -> void:
	closed=true
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(models): models.close()
	jobs.clear(); bitmap_jobs.clear(); waiting.clear(); textures.clear(); bindings.clear(); binding_resources.clear(); deferred.clear(); pool.clear(); catalog=null; ui_assets=null
func _exit_tree() -> void: close()
