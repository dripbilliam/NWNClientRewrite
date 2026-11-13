extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Original GUI MDL, UVs and replacement layers rendered in a private native
# viewport. Explicit prework also persists finished pixels and exact GUI bounds.
signal completed(key: String,texture: Texture2D,error: String)
const Plan=preload("res://systems/native_data/item_icon.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")
const Instance=preload("res://systems/native_render/model_instance.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const Region=preload("res://systems/native_data/gui_render_region.gd")
const GuiTextureInfo=preload("res://systems/native_data/gui_texture_info.gd")
const GuiSampler=preload("res://systems/native_render/gui_sampler.gd")
var assets
var catalog
var ui_assets
var pool:=Pool.new()
var requests: Dictionary={}
var pending: Dictionary={}
var deferred_models: Array=[]
var maximum_deferred_models:=4096
var textures: Dictionary={}
var queue: Array=[]
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var image_bounds: Dictionary={}
var active:=false
var pending_draw: Dictionary={}
var render_fence: CompositorEffect
var render_fence_compositor: Compositor
var render_epoch := 0
var closed:=false
var reuse_models_enabled:=not OS.get_cmdline_user_args().has("--icon-model-reuse=false")
var maximum_cached_models:=32
var cached_models: Dictionary={}
var cache_directory:=""
var prework_records: Dictionary={}
var stats:={"requested":0,"reused":0,"rendered":0,"errors":[],"native_only":true,"slow_cleanup":[],"model_reuses":0,"model_cache_full":0}
func _ready() -> void:set_process(false)
static func raster_extent(units: float,pixels_per_unit: float) -> int:
	var pixels:=units*pixels_per_unit; var nearest:=roundf(pixels)
	if absf(pixels-nearest)<0.001: pixels=nearest
	return maxi(1,ceili(pixels))
func configure(source,cache_path: String) -> void:
	cache_directory=cache_path; add_to_group("native_prework_icons")
	catalog=source; ui_assets=source.ui_asset_owner() if source!=null and source.has_method("ui_asset_owner") else null
	pool.unshaded=true; pool.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	viewport=SubViewport.new(); viewport.own_world_3d=true; viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; viewport.msaa_3d=Viewport.MSAA_4X; add_child(viewport)
	stage=Node3D.new(); viewport.add_child(stage); camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect=Camera3D.KEEP_HEIGHT; camera.near=0.1; camera.far=200; stage.add_child(camera); camera.current=true
	# Compositor callbacks are supported only by RD renderers. Keep the old
	# non-RD/headless path; this experiment changes only the native Vulkan path.
	if DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() in ["forward_plus", "mobile"]:
		render_fence = preload("res://systems/native_render/icon_draw_fence.gd").new(Callable(self, "icon_viewport_drawn"))
		render_fence_compositor = Compositor.new()
		render_fence_compositor.compositor_effects = [render_fence]
		camera.compositor = render_fence_compositor
	var world_environment:=WorldEnvironment.new(); var settings:=Environment.new(); settings.background_mode=Environment.BG_COLOR; settings.background_color=Color(0,0,0,0); settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR; world_environment.environment=settings; stage.add_child(world_environment)
func session_ui_owner():
	# The explicit disk-prework renderer erases each completed live image. It must
	# not turn a 3,819-image bake into an unbounded session GPU residency job.
	return ui_assets if ui_assets!=null and is_instance_valid(assets) and not assets.prework_write else null
func request(item: Dictionary,tables: Dictionary,gender: int=0) -> String:
	var decoder:=Plan.new(); var plan:=decoder.plan(item,tables,gender)
	if plan.is_empty(): stats.errors.append(decoder.failure); return ""
	var key:=Cache.digest(var_to_bytes(plan))
	if textures.has(key): stats.reused+=1; return key
	var owner=session_ui_owner()
	var shared: Dictionary=owner.lookup("item",key) if owner!=null else {}
	if not shared.is_empty(): textures[key]=shared.texture; image_bounds[key]=shared.bounds; stats.reused+=1; stats.shared_reused=int(stats.get("shared_reused",0))+1; return key
	if pending.has(key): return key
	var selected:=decoder.select(plan,catalog)
	if selected.is_empty(): stats.errors.append(decoder.failure); return ""
	var id: int=assets.request(str(selected.model),2002,"gui-icon-v1",{"icon_layers":selected.layers,"icon_descriptor":["item",key],"gui_texture_info":GuiTextureInfo.REVISION})
	if id<0: stats.errors.append(assets.failure); return ""
	requests[id]=key; pending[key]=true; stats.requested+=1; return key
static func model_key(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,texture_layer: String="",poses: Array=[],render_region: Rect2=Rect2()) -> String:
	return "gui:"+name.to_lower()+":"+clip+(":"+Cache.digest(var_to_bytes([overrides,turn,texture_layer])) if not overrides.is_empty() or turn!=0 or not texture_layer.is_empty() else "")+(":pose:"+Cache.digest(var_to_bytes(poses)) if not poses.is_empty() else "")+(":region:"+Cache.digest(var_to_bytes(render_region)) if render_region!=Rect2() else "")
func request_model(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,texture_layer: String="",poses: Array=[],render_region: Rect2=Rect2()) -> String:
	if closed: return ""
	if not Region.valid(render_region): stats.errors.append("Original GUI render region is invalid"); return ""
	var key:=model_key(name,clip,overrides,turn,texture_layer,poses,render_region)
	if textures.has(key) or pending.has(key): return key
	var owner=session_ui_owner()
	var shared: Dictionary=owner.lookup("model",key) if owner!=null else {}
	if not shared.is_empty(): textures[key]=shared.texture; image_bounds[key]=shared.bounds; stats.shared_reused=int(stats.get("shared_reused",0))+1; return key
	if not catalog.has_resource(name,2002): return ""
	if deferred_models.size()>=maximum_deferred_models: stats.errors.append("Original GUI model backlog is full"); return ""
	# A whole original icon-tab tree can exceed the worker queue in one frame.
	# Keep accepted GUI requests owned here until bounded worker capacity opens;
	# queue pressure must not turn valid controls into permanently missing art.
	deferred_models.append({"name":name,"overrides":overrides.duplicate(true),"key":key,"clip":clip,"turn":turn,"texture_layer":texture_layer,"poses":poses.duplicate(true),"render_region":render_region}); stats.model_backlog_peak=maxi(int(stats.get("model_backlog_peak",0)),deferred_models.size())
	pending[key]=true; stats.requested+=1; pump_models(); return key
func pump_models() -> void:
	while not closed and not deferred_models.is_empty() and assets.pending.size()+assets.running.size()<assets.maximum_pending:
		var job: Dictionary=deferred_models.pop_front()
		var id: int=assets.request(job.name,2002,"actor-model",{"relevant_tracks":true,"texture_overrides":job.overrides,"icon_descriptor":[job.key],"gui_texture_info":GuiTextureInfo.REVISION})
		if id<0:
			pending.erase(job.key); stats.errors.append(assets.failure); completed.emit(job.key,null,assets.failure)
		else:
			job.erase("name"); job.erase("overrides"); requests[id]=job
	_refresh_processing()
func _refresh_processing() -> void:
	set_process(not closed and (not deferred_models.is_empty() or not queue.is_empty()))
func prepared(id: int,result: Dictionary) -> void:
	if closed or not requests.has(id): return
	var request_value: Variant=requests[id]; requests.erase(id)
	var key:=str(request_value.key) if request_value is Dictionary else str(request_value)
	var clip:=str(request_value.clip) if request_value is Dictionary else ""
	if not str(result.error).is_empty(): pending.erase(key); stats.errors.append(result.error); completed.emit(key,null,str(result.error)); return
	if result.has("prework_icon"):
		prework_records[key]={"key":result.prework_icon_key,"inputs":result.prework_inputs}
		if restore_prework(key,result.prework_icon): return
	queue.append({"key":key,"bundle":result,"clip":clip,"turn":int(request_value.get("turn",0)) if request_value is Dictionary else 0,"texture_layer":str(request_value.get("texture_layer","")) if request_value is Dictionary else "","poses":request_value.get("poses",[]) if request_value is Dictionary else [],"render_region":request_value.get("render_region",Rect2()) if request_value is Dictionary else Rect2()})
	_refresh_processing()
func restore_prework(key: String,data: Dictionary) -> bool:
	var width:=int(data.get("width",0)); var height:=int(data.get("height",0)); var pixels: Variant=data.get("pixels")
	if width<=0 or height<=0 or width>4096 or height>4096 or not pixels is PackedByteArray or pixels.size()!=width*height*4 or not data.get("bounds") is Dictionary: return false
	var image:=Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,pixels)
	textures[key]=ImageTexture.create_from_image(image); image_bounds[key]=data.bounds
	var owner=session_ui_owner()
	if owner!=null: owner.retain("model" if key.begins_with("gui:") else "item",key,textures[key],image_bounds[key])
	pending.erase(key); stats.prework_hits=int(stats.get("prework_hits",0))+1
	completed.emit(key,textures[key],""); return true
func prework_packet(key: String) -> Dictionary:
	if not prework_records.has(key) or not textures.has(key): return {}
	var image: Image=textures[key].get_image()
	if image==null or image.is_empty(): return {}
	image.convert(Image.FORMAT_RGBA8)
	return {"key":prework_records[key].key,"inputs":prework_records[key].inputs,"data":{"width":image.get_width(),"height":image.get_height(),"pixels":image.get_data(),"bounds":image_bounds.get(key,{})}}
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_icons",began)
func _profile_process(_delta: float) -> void:
	pump_models()
	if not closed and not active and not queue.is_empty(): draw_icon(queue.pop_front())
	_refresh_processing()
func draw_icon(job: Dictionary) -> void:
	active=true
	# A single GUI state can animate mesh UVs as well as transform hooks.
	# The ordinary actor pose owner does not bake those mesh samples. Use the
	# same native composition path as sized GUI controls when they are present;
	# otherwise checked/unchecked barter buttons both use the default atlas row.
	if job.get("poses",[]).is_empty() and not str(job.get("clip","")).is_empty():
		for clip in job.bundle.value.get("rig_asset",{}).get("clips",[]):
			if str(clip.name)==str(job.clip) and not clip.get("meshTracks",[]).is_empty():
				job=job.duplicate(); job.poses=[{"clip":str(clip.name),"time":float(clip.length)}]; break
	if not job.get("poses",[]).is_empty():
		var posed:=preload("res://systems/native_data/gui_pose.gd").compose(job.bundle.value.get("rig_asset",{}),job.poses)
		if not str(posed.error).is_empty(): finish(job.key,null,null,str(posed.error)); return
		job.bundle=job.bundle.duplicate(); job.bundle.value=job.bundle.value.duplicate(); job.bundle.value.rig_asset=posed.asset; job.clip="native_gui_pose"
		# ResourcePool keys native geometry by bundle identity plus part index.
		# A different GUI size has different vertices, even with the same MDL.
		job.bundle.gui_pose_source_sha256=job.bundle.sha256; job.bundle.sha256=Cache.digest(var_to_bytes([job.bundle.sha256,job.poses]))
		job.bundle.value.nodes=job.bundle.value.nodes.duplicate()
		for index in posed.meshes:
			var node: Dictionary=job.bundle.value.nodes[int(index)].duplicate(); node.mesh=node.mesh.duplicate()
			var values: Dictionary=posed.meshes[index]
			if values.has("positions"): node.mesh.vertices=values.positions
			if values.has("uv"): node.mesh.uv=[values.uv]
			node.mesh.erase("native_upload"); job.bundle.value.nodes[int(index)]=node
	var reusable: bool=reuse_models_enabled and job.get("poses",[]).is_empty() and not str(job.get("clip","")).is_empty() and int(job.get("turn",0))==0 and not job.bundle.value.nodes.any(func(row):return row.has("reference") or row.has("emitter") or row.features.has("light"))
	var cache_key:=model_cache_key(job) if reusable else ""
	var reused:=cached_models.has(cache_key)
	var model: Variant=cached_models[cache_key] if reused else Actor.new() if not str(job.get("clip","")).is_empty() else Instance.new()
	if reused: model.show(); stats.model_reuses+=1
	else: stage.add_child(model)
	if model is Actor:
		if not reused and not model.install([{"bundle":job.bundle,"initial_clip":str(job.clip),"follow":false}],pool,0,{}): finish(job.key,model,null,model.failure); return
		model.rigs.set_process(false)
		var at:=0.0
		for clip in job.bundle.value.get("rig_asset",{}).get("clips",[]):
			if str(clip.name)==str(job.clip): at=float(clip.length)
		for entry in model.rigs.entities.values():
			for part in entry.models: model.rigs._play(part,str(job.clip),false,1.0,at,true)
		model.rigs._update(0.0)
	elif not model.install(job.bundle,pool): finish(job.key,model,null,model.failure); return
	if not reused and int(job.get("turn",0))!=0:
		for part in model.find_children("*","Node3D",true,false):
			if str(part.get_meta("native_part_name","")).to_lower()=="icon": part.rotate_y(int(job.turn)*PI/2)
	var bounds:=AABB(); var has_bounds:=false
	var layer_texture: Texture2D=null
	if not str(job.get("texture_layer","")).is_empty():
		var raster: Dictionary=job.bundle.get("textures",{}).get(job.texture_layer,{})
		if not raster.is_empty(): layer_texture=pool.texture(raster)
	for mesh in model.meshes:
		var original: StandardMaterial3D=mesh.get_meta("native_gui_source_material",mesh.material_override)
		if not str(job.get("texture_layer","")).is_empty() and (layer_texture==null or original.albedo_texture!=layer_texture): mesh.hide(); continue
		var box: AABB=mesh.global_transform*mesh.get_aabb(); bounds=bounds.merge(box) if has_bounds else box; has_bounds=true
		if not reused:
			var material: StandardMaterial3D=original.duplicate()
			# Original checkbox clips turn the mark's face away when unchecked.
			# Preserve the source winding contract instead of showing both sides.
			material.cull_mode=original.cull_mode; material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
			material.albedo_color=Color(1,1,1,material.albedo_color.a) if material.albedo_texture!=null else material.albedo_color
			var index:=int(mesh.get_meta("native_source_part_index",mesh.get_parent().get_meta("native_part_index",-1))); var info:=GuiTextureInfo.defaults()
			if index>=0 and index<job.bundle.value.nodes.size():
				var names: Array=job.bundle.value.nodes[index].mesh.get("textures",[])
				if not names.is_empty(): info=job.bundle.get("textures",{}).get(str(names[0]).to_lower(),{}).get("gui_sampler",info)
			mesh.set_meta("native_gui_source_material",original)
			mesh.material_override=GuiSampler.material(material,info)
	# Full original GUI panels use pixel-sized coordinates; item icons use
	# small model units. Fit either into a bounded viewport with identical UVs
	# and aspect instead of rejecting a valid loading/menu panel at 80000px.
	var source_bounds:=bounds; var render_region: Rect2=job.get("render_region",Rect2())
	bounds=Region.bounds(bounds,render_region)
	var pixel_scale:=minf(100.0,2048.0/maxf(0.001,maxf(bounds.size.x,bounds.size.z)))
	var width:=raster_extent(bounds.size.x,pixel_scale); var height:=raster_extent(bounds.size.z,pixel_scale)
	if not has_bounds or width>4096 or height>4096 or bounds.size.z<=0: finish(job.key,model,null,"Original GUI icon bounds exceed supported limits"); return
	# Retain only a bounded working set of small GUI actors. Native Parts and
	# resources stay on the main thread; no worker ever destroys GPU/scene data.
	# Once full, preserve the old transient path rather than evict during entry.
	if reusable and not reused:
		if cached_models.size()<maximum_cached_models and model.find_children("*","Node",true,false).size()<=512:
			cached_models[cache_key]=model; model.set_meta("native_icon_cache_key",cache_key)
		else: stats.model_cache_full+=1
	# The viewport encloses fractional pixel bounds. Preserve one pixel scale on
	# both axes and publish that complete raster footprint, including padding.
	# Using content bounds here squeezes a19.5px model inside its20px raster.
	var center:=bounds.get_center(); var half_width:=float(width)/(2.0*pixel_scale); var half_height:=float(height)/(2.0*pixel_scale)
	image_bounds[str(job.key)]={"min":[center.x-half_width,-center.z-half_height],"max":[center.x+half_width,-center.z+half_height],"geometry_min":[bounds.position.x,-bounds.end.z],"geometry_max":[bounds.end.x,-bounds.position.z],"pixels_per_unit":pixel_scale}
	if render_region!=Rect2(): image_bounds[str(job.key)].merge({"render_region":render_region,"source_geometry_min":[source_bounds.position.x,-source_bounds.end.z],"source_geometry_max":[source_bounds.end.x,-source_bounds.position.z]})
	viewport.size=Vector2i(width,height); camera.size=float(height)/pixel_scale
	camera.position=Vector3(center.x,100,center.z); camera.look_at(Vector3(center.x,0,center.z),Vector3(0,0,-1))
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	pending_draw={"job":job,"model":model,"wait_began":Timing.begin()}
	if render_fence != null:
		render_epoch += 1
		pending_draw.render_epoch = render_epoch
		pending_draw.completed_epoch = 0
		RenderingServer.call_on_render_thread(Callable(render_fence, "arm").bind(render_epoch, render_fence))
	else:
		RenderingServer.frame_post_draw.connect(frame_rendered,CONNECT_ONE_SHOT)
func icon_viewport_drawn(epoch: int) -> void:
	# Main-thread deferred receiver. Old/retired/replaced camera completions
	# cannot consume another request, including after owner closure.
	if closed or pending_draw.is_empty() or int(pending_draw.get("render_epoch", -1)) != epoch:
		return
	pending_draw.completed_epoch = epoch
	frame_rendered()
func frame_rendered() -> void:
	if closed or pending_draw.is_empty(): return
	if render_fence != null and int(pending_draw.get("completed_epoch", 0)) != int(pending_draw.get("render_epoch", -1)):
		return
	var draw: Dictionary=pending_draw; pending_draw={}
	var job: Dictionary=draw.job; var model=draw.model
	Timing.finish("icon_render_wait_ms",int(draw.wait_began))
	var postdraw_began:=Timing.begin()
	var readback_began:=Timing.begin()
	var image:=viewport.get_texture().get_image()
	Timing.finish("icon_gpu_readback_ms",readback_began)
	if image==null or image.is_empty():
		finish(job.key,model,null,"Native icon viewport did not produce pixels")
		Timing.finish("icon_postdraw_cpu_ms",postdraw_began); return
	var texture_began:=Timing.begin()
	var texture:=ImageTexture.create_from_image(image)
	Timing.finish("icon_texture_upload_ms",texture_began)
	if not str(job.bundle.get("prework_icon_key","")).is_empty() and job.bundle.has("prework_inputs"):
		prework_records[str(job.key)]={"key":job.bundle.prework_icon_key,"inputs":job.bundle.prework_inputs}
	finish(job.key,model,texture,"")
	Timing.finish("icon_postdraw_cpu_ms",postdraw_began)
func finish(key: String,model,texture: Texture2D,error: String) -> void:
	var cleanup_began:=Timing.begin()
	if is_instance_valid(model):
		if error.is_empty() and model.has_meta("native_icon_cache_key"): model.hide()
		else:
			if model.has_meta("native_icon_cache_key"): cached_models.erase(str(model.get_meta("native_icon_cache_key")))
			model.free()
	Timing.finish("icon_model_cleanup_ms",cleanup_began)
	if cleanup_began>0:
		var cleanup_ms:=(Time.get_ticks_usec()-cleanup_began)/1000.0
		if cleanup_ms>5.0:
			stats.slow_cleanup.append({"key":key,"ms":cleanup_ms})
			if stats.slow_cleanup.size()>16: stats.slow_cleanup.pop_front()
	pending.erase(key); active=false
	if texture!=null:
		textures[key]=texture; stats.rendered+=1
		var owner=session_ui_owner()
		if owner!=null: owner.retain("model" if key.begins_with("gui:") else "item",key,texture,image_bounds.get(key,{}))
	else:
		stats.errors.append(error)
		var owner=session_ui_owner()
		if owner!=null: owner.note_failure("model" if key.begins_with("gui:") else "item",key,error)
	var notify_began:=Timing.begin()
	completed.emit(key,texture,error)
	Timing.finish("icon_notify_ms",notify_began)
func model_cache_key(job: Dictionary) -> String:
	var samplers: Dictionary={}
	for name in job.bundle.get("textures",{}): samplers[name]=job.bundle.textures[name].get("gui_sampler",{})
	return Cache.digest(var_to_bytes([Template.identity(job.bundle,pool),int(job.get("turn",0)),str(job.get("texture_layer","")),samplers]))
func snapshot() -> Dictionary:
	var state:=stats.duplicate(true); state.merge({"pending":pending.size(),"deferred_models":deferred_models.size(),"textures":textures.size(),"active":active,"model_reuse_enabled":reuse_models_enabled,"cached_models":cached_models.size(),"maximum_cached_models":maximum_cached_models}); return state
func close() -> void:
	if closed: return
	closed=true;set_process(false)
	if is_instance_valid(camera): camera.compositor = null
	render_fence = null
	render_fence_compositor = null
	if RenderingServer.frame_post_draw.is_connected(frame_rendered): RenderingServer.frame_post_draw.disconnect(frame_rendered)
	for model in cached_models.values():
		if is_instance_valid(model): model.free()
	cached_models.clear()
	if not pending_draw.is_empty() and is_instance_valid(pending_draw.model): pending_draw.model.free()
	pending_draw.clear(); active=false
	if is_instance_valid(assets): assets.close()
	queue.clear(); deferred_models.clear(); requests.clear(); pending.clear(); textures.clear(); prework_records.clear(); pool.clear(); catalog=null; ui_assets=null
func _exit_tree() -> void: close()
