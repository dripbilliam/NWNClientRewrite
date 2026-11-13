extends Node
const Timing=preload("res://systems/native_data/tooltip_timing.gd")
const Preferences=preload("res://systems/native_data/tooltip_preferences.gd")
const Managed=preload("res://systems/native_tooltip_control.gd")
const META="native_tooltip_router"
var policy:=Timing.new()
var controllers: Dictionary={}
var current: Dictionary={}
var displayed: Dictionary={}
var moved:=false
var pointer:=Vector2i(-1,-1)
var last_tick:=0
var started:=0
var captured_delay:=Preferences.DEFAULT_USEC
var closed:=false
static func acquire(viewport: Viewport):
	if viewport.has_meta(META):
		var existing: Object=viewport.get_meta(META).get_ref()
		if is_instance_valid(existing) and not existing.is_queued_for_deletion(): return existing
	var router=load("res://systems/native_tooltip_router.gd").new(); viewport.add_child(router); viewport.set_meta(META,weakref(router)); return router
func _ready() -> void:
	last_tick=Time.get_ticks_usec(); started=last_tick; pointer=Vector2i(get_viewport().get_mouse_position()); policy.configure(Preferences.delay_usec)
func register_controller(controller) -> void: controllers[controller.get_instance_id()]=weakref(controller)
func register_control(controller,control: Control) -> bool:
	if not is_instance_valid(control): return false
	if control.has_meta("native_tooltip_controller"):
		var previous: Object=control.get_meta("native_tooltip_controller").get_ref()
		if previous==controller and controller.controls.has(control.get_instance_id()): return true
		if is_instance_valid(previous): unregister_control(previous,control)
	if control.get_script()==null: control.set_script(Managed)
	elif control.get_script()!=Managed and not control.has_method("native_tooltip_content"): return false
	control.set_meta("native_tooltip_managed",true); control.set_meta("native_tooltip_controller",weakref(controller))
	var identifier:=control.get_instance_id(); var reference: WeakRef=weakref(controller)
	controller.controls[identifier]=weakref(control)
	control.tree_exiting.connect(func():
		var owner: Object=reference.get_ref()
		if is_instance_valid(owner): owner.call_deferred("prune_control",identifier))
	return true
func unregister_control(controller,control: Control) -> void:
	if not is_instance_valid(control) or not control.has_meta("native_tooltip_controller") or control.get_meta("native_tooltip_controller").get_ref()!=controller: return
	if current.get("control")==control:
		apply_events(policy.remove(owner_id(current)),{}); current={}
	if displayed.get("control")==control:
		apply_events(policy.remove(owner_id(displayed)),{}); hide_displayed()
	if controller.target!=null and controller.target.get_ref()==control: controller.clear_observation()
	controller.controls.erase(control.get_instance_id()); control.remove_meta("native_tooltip_controller"); control.remove_meta("native_tooltip_managed")
func resolve() -> Dictionary:
	var control: Control=get_viewport().gui_get_hovered_control()
	while is_instance_valid(control):
		if control.has_meta("native_tooltip_controller"):
			var controller: Object=control.get_meta("native_tooltip_controller").get_ref()
			if is_instance_valid(controller) and not controller.closed:
				var info: Dictionary=controller.content(control)
				if not info.is_empty(): return info
		control=control.get_parent() as Control
	return {}
func owner_id(info: Dictionary) -> int: return int(info.get("owner",0))
func apply_events(event: Dictionary,info: Dictionary) -> void:
	if int(event.finish)!=0: hide_displayed()
	if event.reset: started=Time.get_ticks_usec(); captured_delay=policy.delay
	if int(event.trigger)!=0 and not info.is_empty():
		displayed=info; info.controller.show_content(info,Vector2(policy.point))
func hide_displayed() -> void:
	if not displayed.is_empty() and is_instance_valid(displayed.get("controller")): displayed.controller.hide_bubble()
	displayed={}
func cancel_controller(controller) -> void:
	if current.get("controller")==controller:
		apply_events(policy.remove(owner_id(current)),{}); current={}
	if displayed.get("controller")==controller: hide_displayed()
	controller.clear_observation()
func remove_controller(controller) -> void:
	cancel_controller(controller); controllers.erase(controller.get_instance_id())
	for reference in controller.controls.values():
		var control: Object=reference.get_ref()
		if is_instance_valid(control) and control.has_meta("native_tooltip_controller") and control.get_meta("native_tooltip_controller").get_ref()==controller:
			control.remove_meta("native_tooltip_controller"); control.remove_meta("native_tooltip_managed")
	controller.controls.clear()
	if controllers.is_empty():
		closed=true; hide_displayed()
		if get_viewport().has_meta(META) and get_viewport().get_meta(META).get_ref()==self: get_viewport().remove_meta(META)
		queue_free()
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# CGuiMan saves the integer coordinates supplied by HandleMouseMove.
		# Sampling a later transformed cursor can drift a pixel at scaled edges.
		pointer=Vector2i(event.position); moved=true
func note_entry() -> void: moved=true
func _process(_delta: float) -> void:
	if closed: return
	var now:=Time.get_ticks_usec(); var delta:=now-last_tick; last_tick=now
	if policy.saved!=Preferences.delay_usec: policy.configure(Preferences.delay_usec)
	var next:=resolve(); var id:=owner_id(next)
	# Repository882000 removes the current tooltip when the hovered item or
	# its dirty presentation changes, while retaining the repository hit owner.
	if not current.is_empty() and owner_id(current)==id and current.get("identity")!=next.get("identity"):
		apply_events(policy.remove(id),{})
	if moved or owner_id(current)!=id:
		apply_events(policy.motion(id,pointer),next); moved=false
	current=next
	if get_viewport().gui_is_dragging():
		apply_events(policy.remove(id),{}); hide_displayed(); return
	apply_events(policy.advance(delta,id,true,int(next.get("flags",0))),next)
	for reference in controllers.values():
		var controller: Object=reference.get_ref()
		if not is_instance_valid(controller): continue
		if next.get("controller")==controller:
			controller.observe(next,float(maxi(0,now-started))/1000000.0,captured_delay)
		else: controller.clear_observation()
func instant_mode(enabled: bool) -> void:
	var info:=resolve(); apply_events(policy.instant(enabled,not displayed.is_empty(),owner_id(info),true,int(info.get("flags",0))),info)
func trigger_tooltip() -> void:
	var info:=resolve(); apply_events(policy.trigger(not displayed.is_empty(),owner_id(info),true,int(info.get("flags",0))),info)
