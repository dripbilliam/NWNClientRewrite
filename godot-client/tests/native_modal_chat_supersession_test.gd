extends SceneTree
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
class QueuedArtAssets extends Node:
	signal completed(id: int,result: Dictionary)
	var serial:=0
	func request(_name: String,_type: int,_decoder: String) -> int: serial+=1; return serial
class ControlledArt extends Node:
	signal loaded(key: String,texture: Texture2D,bounds: Dictionary)
	const models=preload("res://systems/native_item_icons.gd")
	var assets
	var bounds: Dictionary={}
	var textures: Dictionary={}
	var failed: Dictionary={}
	var bindings: Dictionary={}
	func _init() -> void: assets=QueuedArtAssets.new(); add_child(assets)
	func bind(target: Object,resource: String,property: String="texture",_model: bool=false,_clip: String="up",_portrait: bool=false,_overrides: Dictionary={},_region: Rect2=Rect2()) -> void: bindings[str(target.get_instance_id())+":"+property]=resource
	func unbind(target: Object,property: String="texture") -> void: bindings.erase(str(target.get_instance_id())+":"+property)
	func request_model(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,layer: String="",poses: Array=[],region: Rect2=Rect2()) -> String:
		return models.model_key(name,clip,overrides,turn,layer,poses,region)
	func close() -> void: bindings.clear()
class ControlledFonts extends Node:
	signal loaded(name: String)
	var bindings: Dictionary={}
	var metrics: Dictionary={}
	func bind(control: Control,name: String) -> void: bindings[control.get_instance_id()]=name
	func unbind(control: Control) -> void: bindings.erase(control.get_instance_id())
	func close() -> void: bindings.clear()
var checks:=0
var failures: Array=[]
var completions:=0
var assembled_on_completion:=false
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
	return value
func wheel_open(wheel) -> void: wheel.open_at(Vector2(400,300),42,Vector3.ZERO,false)
func make_ui(surface: SubViewport,catalog,install: String,path: String):
	var ui:=Gameplay.new()
	# Actual production configure and real chat asset workers; unrelated owners
	# stay idle so this case never waits for GPU fonts/raster publication.
	ui.process_mode=Node.PROCESS_MODE_DISABLED; surface.add_child(ui)
	ui.configure(catalog,install,path+".cache",path+".layout.cfg")
	return ui
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new()
	if not check(catalog.mount_install(args.install),"Actual installed resource catalog mounts read-only"): quit(1); return
	var surface:=SubViewport.new(); surface.size=Vector2i(1024,768); surface.disable_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface)
	var ui=make_ui(surface,catalog,args.install,args.report)
	check(is_instance_valid(ui.desktop.radial) and is_instance_valid(ui.inventory.item_context.wheel) and ui.chat_skin.context==null,"Actual Gameplay.configure returns before the asynchronous chat wheel exists")
	check(ui.desktop.radial.modal_owner_order==ui.modal_order and ui.inventory.item_context.wheel.modal_owner_order==ui.modal_order and not ui.modal_radials_bound,"Existing real wheels bind immediately without falsely declaring all three bound")
	wheel_open(ui.desktop.radial)
	var before: Dictionary=ui.modal_order.snapshot(); var world_ticket: Dictionary=ui.desktop.radial.modal_owner_ticket.duplicate(true)
	ui.bind_modal_radials(); ui.bind_modal_radials()
	check(ui.modal_order.snapshot().records==before.records and ui.desktop.radial.modal_owner_ticket==world_ticket and not ui.modal_radials_bound,"Repeated binding while chat is absent neither throws nor reorders an active wheel")
	var painter:=Painter.new(); painter.art=ControlledArt.new(); painter.fonts=ControlledFonts.new(); painter.add_child(painter.art); painter.add_child(painter.fonts); surface.add_child(painter)
	var chat=ui.chat_skin
	chat.frame.fonts.loaded.disconnect(chat.font_loaded); chat.frame=painter; painter.fonts.loaded.connect(chat.font_loaded)
	chat.context_prepared.connect(func():
		completions+=1
		assembled_on_completion=is_instance_valid(chat.stage) and chat.panes.size()==2 and is_instance_valid(chat.notice) and ui.modal_radials_bound)
	# Start actual requests before allowing completion processing; no preassembled
	# chat context or manually decoded model is injected into this boundary.
	chat._process(0)
	check(chat.requested and not chat.jobs.is_empty() and chat.context==null and not ui.modal_radials_bound,"Real original-model requests remain pending without an early third lease")
	chat.process_mode=Node.PROCESS_MODE_ALWAYS
	var deadline:=Time.get_ticks_msec()+5000
	while not chat.layout_ready and chat.failure.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	var prepared:=check(chat.layout_ready and chat.failure.is_empty() and chat.jobs.is_empty() and completions==1,"Real chat asset workers finish exactly one asynchronous assembly within the owned bound")
	if prepared:
		check(assembled_on_completion and ui.modal_radials_bound and chat.context.modal_owner_order==ui.modal_order,"Completion binds the actual third wheel only after all chat controls exist")
		check(ui.modal_order.snapshot().records==before.records and ui.desktop.radial.modal_owner_ticket==world_ticket,"Late chat binding preserves an already active desktop lease and its order")
		wheel_open(chat.context); var chat_ticket: Dictionary=chat.context.modal_owner_ticket.duplicate(true)
		check(not ui.desktop.radial.active and chat.context.active,"Late real chat open supersedes the exact previous desktop wheel")
		wheel_open(ui.desktop.radial); var active_order: Array=ui.modal_order.snapshot().records
		chat.context_prepared.emit(); ui.bind_modal_radials()
		check(ui.modal_order.snapshot().records==active_order and chat.context.modal_owner_ticket.is_empty() and not chat.context.active and completions==2,"Duplicate completion preserves the one live promoted wheel after exact supersession")
		check(not ui.modal_order.deactivate_for_panel(16).deactivationRequested and ui.desktop.radial.active,"Production membership remains unavailable and does not enable server-driven close")
	ui.close(); check(not ui.modal_radials_bound and ui.modal_order.snapshot().records.is_empty(),"Closing the configured UI retires all real leases and the bound flag")
	chat.context_prepared.emit(); check(not ui.modal_radials_bound and ui.modal_order.snapshot().closed,"A late completion callback cannot bind a closed Gameplay owner")
	ui.free(); painter.free()
	var retiring=make_ui(surface,catalog,args.install,str(args.report)+".retiring")
	var pending=retiring.chat_skin; pending._process(0)
	var pending_id: int=pending.jobs.keys()[0]
	retiring.close()
	pending.prepared(pending_id,{"error":"","value":{}}); pending.context_prepared.emit()
	check(pending.closed and pending.jobs.is_empty() and pending.context==null and not retiring.modal_radials_bound and retiring.modal_order.snapshot().records.is_empty(),"Actual close-before-worker-completion retires pending chat jobs and rejects stale preparation/binding")
	retiring.free(); surface.queue_free(); catalog=null
	for index in 4: await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"servers":0,"scope":"Current supersession variant of actual NativeGameplayUi.configure and NativeChatHud production worker completion over installed original chat models; controlled borrowed art/font publication and idle unrelated owners. Late/idempotent/retired modal binding only; production modal coverage remains unavailable, no pixels or server access-close acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("MODAL_LATE_CHAT_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
