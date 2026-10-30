extends Node
# Native archive reads and GUI-model rendering. No browser or prepared images.
signal loaded(key: String,texture: Texture2D,bounds: Dictionary)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Icons=preload("res://systems/native_item_icons.gd")
var assets
var models
var pool:=Pool.new()
var catalog
var jobs: Dictionary={}
var waiting: Dictionary={}
var textures: Dictionary={}
var failed: Dictionary={}
var bounds: Dictionary={}
var binding_serial:=0
var bindings: Dictionary={}
var stale_bindings:=0
func configure(source,cache_path: String) -> void:
	catalog=source; assets=Assets.new(); add_child(assets); assets.configure(source); assets.maximum_workers=2; assets.cache_directory=cache_path; assets.completed.connect(prepared)
	models=Icons.new(); add_child(models); models.configure(source,cache_path); models.completed.connect(model_ready)
func unbind(target: Object,property: String="texture") -> void:
	bindings.erase(str(target.get_instance_id())+":"+property)
func bind(target: Object,resource: String,property: String="texture",model: bool=false,clip: String="up",portrait: bool=false,overrides: Dictionary={},render_region: Rect2=Rect2()) -> void:
	binding_serial+=1
	var binding_key:=str(target.get_instance_id())+":"+property
	bindings[binding_key]=binding_serial
	if resource.is_empty() or resource=="****": bindings.erase(binding_key); return
	var key:=Icons.model_key(resource,clip,overrides,0,"",[],render_region) if model else resource.to_lower()
	if textures.has(key): apply_image(target,property,textures[key],not model,portrait); bindings.erase(binding_key); return
	if failed.has(key): bindings.erase(binding_key); return
	var listener:={"target":weakref(target),"property":property,"flip":not model,"portrait":portrait,"binding_key":binding_key,"serial":binding_serial}
	if waiting.has(key): waiting[key].append(listener); return
	waiting[key]=[listener]
	if model:
		var requested: String=models.request_model(resource,clip,overrides,0,"",[],render_region)
		if requested.is_empty(): fail_image(key)
		elif models.textures.has(requested): deliver(key,models.textures[requested])
	else:
		var location: Dictionary=catalog.raster_location(resource)
		if location.is_empty(): fail_image(key); return
		var id: int=assets.request(resource,int(location.type),"raster")
		if id<0: fail_image(key)
		else: jobs[id]=key
func bind_portrait(target: Object,resource: String) -> void:
	if resource.is_empty(): bind(target,""); return
	bind(target,portrait_resource(resource),"texture",false,"up",true)
func portrait_resource(resource: String) -> String:
	var suffixes:=["","t","s","m","l","h"]; var size:=suffixes.find(resource.right(1))
	if size<=0: return resource
	for offset in [0,1,-1,2,-2,3,-3,4,-4]:
		var index:=size+int(offset)
		if index<1 or index>5: continue
		var name:=resource.left(-1)+str(suffixes[index])
		if not catalog.raster_location(name).is_empty(): return name
	return resource
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
	if not str(result.error).is_empty(): fail_image(key); return
	var texture=pool.texture(result)
	if texture==null: fail_image(key); return
	deliver(key,texture)
func request_model(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,texture_layer: String="",poses: Array=[],render_region: Rect2=Rect2()) -> String:
	var key: String=models.request_model(name,clip,overrides,turn,texture_layer,poses,render_region)
	if models.textures.has(key): textures[key]=models.textures[key]; bounds[key]=models.image_bounds.get(key,{})
	return key
func model_ready(key: String,texture: Texture2D,error: String) -> void:
	if not error.is_empty() or texture==null: fail_image(key); return
	bounds[key]=models.image_bounds.get(key,{})
	deliver(key,texture)
func deliver(key: String,texture: Texture2D) -> void:
	textures[key]=texture; loaded.emit(key,texture,bounds.get(key,{}))
	for listener in waiting.get(key,[]):
		var target: Object=listener.target.get_ref()
		if is_instance_valid(target) and bindings.get(listener.binding_key,-1)==listener.serial:
			apply_image(target,str(listener.property),texture,bool(listener.flip),bool(listener.portrait)); bindings.erase(listener.binding_key)
		else:
			stale_bindings+=1
			if bindings.get(listener.binding_key,-1)==listener.serial: bindings.erase(listener.binding_key)
	waiting.erase(key)
func fail_image(key: String) -> void:
	failed[key]=true
	for listener in waiting.get(key,[]):
		if bindings.get(listener.binding_key,-1)==listener.serial: bindings.erase(listener.binding_key)
	waiting.erase(key)
func close() -> void:
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(models): models.close()
	jobs.clear(); waiting.clear(); textures.clear(); bindings.clear(); pool.clear(); catalog=null
func _exit_tree() -> void: close()
