extends Control
# One live 3D GUI scene for an item-bearing panel. Each binding owns a distinct
# model instance; immutable meshes and textures come from the caller's pool.
const ModelInstance=preload("res://systems/native_render/model_instance.gd")
const GuiSampler=preload("res://systems/native_render/gui_sampler.gd")
const GuiTextureInfo=preload("res://systems/native_data/gui_texture_info.gd")
const DrawFence=preload("res://systems/native_render/icon_draw_fence.gd")
const UNITS_PER_PIXEL:=0.01
signal presented(revision: int)

var failure:=""
var pool
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var presentation: TextureRect
var slots: Dictionary={}
var render_fence: CompositorEffect
var render_compositor: Compositor
var revision:=0
var presented_revision:=0
var waiting_frame_post_draw:=false
var batch_depth:=0
var batch_dirty:=false

func configure(shared_pool) -> bool:
	if viewport!=null or shared_pool==null:
		failure="Item icon panel host is already configured or has no resource pool"
		return false
	pool=shared_pool
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	viewport=SubViewport.new()
	viewport.name="ItemIconPanelViewport"
	viewport.own_world_3d=true
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.msaa_3d=Viewport.MSAA_4X
	add_child(viewport)
	stage=Node3D.new()
	stage.name="ItemIconPanelScene"
	viewport.add_child(stage)
	camera=Camera3D.new()
	camera.name="ItemIconPanelCamera"
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.near=0.1
	camera.far=200.0
	stage.add_child(camera)
	camera.current=true
	if DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method() in ["forward_plus","mobile"]:
		render_fence=DrawFence.new(Callable(self,"_viewport_drawn"))
		render_compositor=Compositor.new()
		render_compositor.compositor_effects=[render_fence]
		camera.compositor=render_compositor
	var world_environment:=WorldEnvironment.new()
	var environment:=Environment.new()
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color(0,0,0,0)
	environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	world_environment.environment=environment
	stage.add_child(world_environment)
	presentation=TextureRect.new()
	presentation.name="ItemIconPanelImage"
	presentation.mouse_filter=Control.MOUSE_FILTER_IGNORE
	presentation.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	presentation.stretch_mode=TextureRect.STRETCH_SCALE
	# The converter keeps source GUI model winding; mirror only the final panel
	# image so top-left UI anchors increase downward without viewing backfaces.
	presentation.flip_v=true
	presentation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(presentation)
	presentation.texture=viewport.get_texture()
	presentation.visible=false
	resized.connect(_sync_viewport)
	visibility_changed.connect(_visibility_changed)
	_sync_viewport()
	return true

func _sync_viewport() -> void:
	if viewport==null:return
	var pixels:=Vector2i(maxi(2,roundi(size.x)),maxi(2,roundi(size.y)))
	viewport.size=pixels
	camera.size=float(pixels.y)*UNITS_PER_PIXEL
	var center:=Vector3(float(pixels.x)*UNITS_PER_PIXEL*0.5,0.0,-float(pixels.y)*UNITS_PER_PIXEL*0.5)
	camera.position=center+Vector3(0,100,0)
	camera.look_at(center,Vector3(0,0,-1))
	if not slots.is_empty():_mark_dirty()

func resize_panel(panel_size: Vector2) -> void:
	if size!=panel_size:size=panel_size

func _identity(key: String,bundle: Dictionary) -> int:
	return hash([key,bundle.get("sha256",""),bundle.get("dependencies",[])])

func bind_slot(binding_id: String,key: String,bundle: Dictionary,anchor: Vector2,alpha: float=1.0) -> bool:
	failure=""
	if viewport==null or binding_id.is_empty() or key.is_empty() or not is_finite(anchor.x) or not is_finite(anchor.y) or not is_finite(alpha):
		failure="Invalid item icon panel binding"
		return false
	if not str(bundle.get("error","")).is_empty():failure=str(bundle.error);return false
	if not bundle.get("value") is Dictionary or not bundle.value.get("nodes") is Array:
		failure="Item icon model bundle is incomplete"
		return false
	var identity:=_identity(key,bundle)
	if slots.has(binding_id):
		var previous: Dictionary=slots[binding_id]
		if int(previous.identity)==identity and is_instance_valid(previous.model):
			if _update_slot(previous,anchor,alpha):_mark_dirty()
			return true
		unbind_slot(binding_id)
	var model=ModelInstance.new()
	model.name="ItemIcon_"+str(hash(binding_id))
	stage.add_child(model)
	if not model.install(bundle,pool):
		failure=model.failure
		model.free()
		return false
	for mesh in model.meshes:
		# Keep source vertices, UVs, part transforms and mesh order untouched.
		# This mirrors the existing GUI model material/sampler contract.
		var source: Material=mesh.material_override
		if source is StandardMaterial3D:
			var material: StandardMaterial3D=source.duplicate()
			material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
			var index:=int(mesh.get_meta("native_mesh_source",{}).get("part_index",mesh.get_parent().get_meta("native_part_index",-1)))
			var info:=GuiTextureInfo.defaults()
			if index>=0 and index<bundle.value.nodes.size():
				var names: Array=bundle.value.nodes[index].mesh.get("textures",[])
				if not names.is_empty():info=bundle.get("textures",{}).get(str(names[0]).to_lower(),{}).get("gui_sampler",info)
			mesh.material_override=GuiSampler.material(material,info)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var slot:={"key":key,"identity":identity,"model":model}
	slots[binding_id]=slot
	_update_slot(slot,anchor,alpha)
	_mark_dirty()
	return true

func _mark_dirty() -> void:
	if viewport==null or slots.is_empty():return
	if batch_depth>0:
		batch_dirty=true
		presentation.visible=false
		return
	revision+=1
	presentation.visible=false
	_request_draw()

func begin_batch() -> void:
	batch_depth+=1

func end_batch() -> void:
	if batch_depth<=0:return
	batch_depth-=1
	if batch_depth>0 or not batch_dirty:return
	batch_dirty=false
	if slots.is_empty():
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		presentation.visible=false
		return
	revision+=1
	_request_draw()

func _request_draw() -> void:
	if viewport==null or slots.is_empty():return
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	if render_fence!=null:
		RenderingServer.call_on_render_thread(Callable(render_fence,"arm").bind(revision,render_fence))
	elif not waiting_frame_post_draw:
		waiting_frame_post_draw=true
		RenderingServer.frame_post_draw.connect(_fallback_frame_drawn,CONNECT_ONE_SHOT)

func _visibility_changed() -> void:
	if batch_depth==0 and is_visible_in_tree() and not presentation_ready():_request_draw()

func _viewport_drawn(epoch: int) -> void:
	if slots.is_empty():return
	if epoch!=revision:
		_request_draw()
		return
	presented_revision=epoch
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	presentation.visible=true
	presented.emit(epoch)

func _fallback_frame_drawn() -> void:
	waiting_frame_post_draw=false
	if slots.is_empty():return
	presented_revision=revision
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	presentation.visible=true
	presented.emit(revision)

func presentation_ready() -> bool:return not batch_dirty and (slots.is_empty() or presented_revision==revision)
func binding_ready(binding_id: String) -> bool:return slots.has(binding_id) and presentation_ready()

func _update_slot(slot: Dictionary,anchor: Vector2,alpha: float) -> bool:
	var model: Node3D=slot.model
	var target:=Vector3(anchor.x*UNITS_PER_PIXEL,0.0,-anchor.y*UNITS_PER_PIXEL)
	var transparency:=1.0-clampf(alpha,0.0,1.0)
	var changed:=not model.position.is_equal_approx(target)
	if changed:model.position=target
	for mesh in model.meshes:
		if not is_equal_approx(mesh.transparency,transparency):
			mesh.transparency=transparency
			changed=true
	return changed

func reposition_slot(binding_id: String,anchor: Vector2,alpha: float=1.0) -> bool:
	if not slots.has(binding_id) or not is_finite(anchor.x) or not is_finite(anchor.y) or not is_finite(alpha):return false
	if _update_slot(slots[binding_id],anchor,alpha):_mark_dirty()
	return true

func unbind_slot(binding_id: String) -> void:
	if not slots.has(binding_id):return
	var model=slots[binding_id].model
	slots.erase(binding_id)
	if is_instance_valid(model):model.free()
	if slots.is_empty() and viewport!=null:
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		presentation.visible=false
	else:_mark_dirty()

func clear() -> void:
	begin_batch()
	for binding_id in slots.keys():unbind_slot(str(binding_id))
	end_batch()

func _exit_tree() -> void:clear()
