extends Node
# Shared source bubble for a painter's original controls. One viewport router
# owns the timing/hit policy across painters; no per-item workers or rendering.
const Plate=preload("res://systems/native_nameplate.gd")
const Source=preload("res://systems/native_nameplate_resources.gd")
const Data=preload("res://systems/native_data/item_tooltip.gd")
const Preferences=preload("res://systems/native_data/tooltip_preferences.gd")
const Router=preload("res://systems/native_tooltip_router.gd")
const Rich=preload("res://systems/native_data/rich_text.gd")
var source
var plate
var layer
var router
var frame
var catalog
var cache_path:=""
var controls: Dictionary={}
var display_control: WeakRef
var anchor_point:=Vector2.ZERO
var display_below:=false
var target: WeakRef
var elapsed:=0.0
var wait_usec:=Preferences.DEFAULT_USEC
var last_signature:=0
var closed:=false
func configure(_parent: Control,resources,path: String,painter) -> void:
	catalog=resources; cache_path=path; frame=painter
	router=Router.acquire(get_viewport()); router.register_controller(self); set_process(false)
func prepare() -> void:
	if closed or is_instance_valid(plate): return
	source=Source.new(); add_child(source); source.configure(catalog,cache_path)
	layer=CanvasLayer.new(); layer.layer=99; add_child(layer)
	plate=Plate.new(); layer.add_child(plate); plate.configure(frame.art,frame.fonts,source); plate.resized.connect(reposition)
func register_control(control: Control) -> void:
	if not closed and is_instance_valid(router): router.register_control(self,control)
func unregister_control(control: Control) -> void:
	if not closed and is_instance_valid(router): router.unregister_control(self,control)
func prune_control(identifier: int) -> void:
	# Reparenting also exits the tree. Keep live controls registered so closing
	# the scope can restore their engine behavior; remove freed weak entries.
	if controls.has(identifier) and not is_instance_valid(controls[identifier].get_ref()): controls.erase(identifier)
func content(control: Control) -> Dictionary:
	if closed or not control.is_visible_in_tree(): return {}
	var value: Dictionary={}
	if control.has_method("native_tooltip_content"): value=control.native_tooltip_content()
	else:
		if control.tooltip_text.is_empty(): return {}
		var rich:=Rich.parse(control.tooltip_text); value={"rich":rich,"owner":control.get_instance_id(),"identity":[control.get_instance_id(),hash(rich)],"below":false}
	if value.is_empty(): return {}
	value.controller=self; value.control=control; return value
func enter(button: Control) -> void:
	if closed: return
	if is_instance_valid(router): register_control(button); router.note_entry(); return
	# Standalone input/lifetime checks may configure the passive view directly.
	target=weakref(button); elapsed=0.0; wait_usec=Preferences.delay_usec; last_signature=0
	if is_instance_valid(plate): plate.hide()
func leave(button: Control) -> void:
	if not is_instance_valid(router) and target!=null and target.get_ref()==button: cancel()
func cancel() -> void:
	if is_instance_valid(router): router.cancel_controller(self)
	clear_observation(); hide_bubble()
func clear_observation() -> void: target=null; elapsed=0.0
func observe(info: Dictionary,seconds: float,delay: int) -> void:
	target=weakref(info.control); elapsed=seconds; wait_usec=delay
func show_content(info: Dictionary,point: Vector2) -> void:
	prepare(); var rich: Dictionary=info.rich
	display_control=weakref(info.control); anchor_point=point; display_below=bool(info.get("below",false)); last_signature=hash(rich)
	plate.set_content({"available":not str(rich.text).is_empty(),"creature":false,"name":rich,"caption":rich,"caption_color":Color.WHITE,"color":Color.WHITE,"portrait":""})
	if str(rich.text).is_empty(): plate.hide(); return
	reposition(); plate.show()
func hide_bubble() -> void:
	display_control=null
	if is_instance_valid(plate): plate.hide(); plate.caption.clear()
func reposition() -> void:
	if closed or display_control==null or not is_instance_valid(plate): return
	var control: Object=display_control.get_ref()
	if not is_instance_valid(control): hide_bubble(); return
	var scale_value:=maxf(0.01,absf(control.get_global_transform_with_canvas().get_scale().x)); plate.scale=Vector2.ONE*scale_value
	plate.position=Data.position_at(anchor_point,control.get_viewport_rect().size,plate.size,display_below,scale_value)
func close() -> void:
	if closed: return
	closed=true
	if is_instance_valid(router): router.remove_controller(self)
	router=null; clear_observation(); hide_bubble()
	if is_instance_valid(plate): plate.close()
	if is_instance_valid(source): source.close()
	catalog=null; frame=null
func _exit_tree() -> void: close()
