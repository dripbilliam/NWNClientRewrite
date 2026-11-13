extends Button
const BitmapPlane=preload("res://systems/native_gui_bitmap_plane.gd")
var art
var plan: Dictionary={}
var planes: Dictionary={}
var closed:=false
var portrait:=""
var tooltip_provider: Callable
func _get_tooltip(_at_position: Vector2) -> String:
	return str(tooltip_provider.call()) if not closed and tooltip_provider.is_valid() else ""
func configure(definition: Dictionary,owner,resource: String) -> void:
	plan=definition; art=owner; portrait=resource; size=plan.bounds.size; focus_mode=Control.FOCUS_NONE; add_theme_font_size_override("font_size",1)
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for part in plan.states.up:
		var name: String=part.resource; var image:=BitmapPlane.new(); add_child(image); planes[str(part.id)]=image
		art.bind(image,art.portrait_resource(resource) if name=="gui_replace01" and not resource.is_empty() else "" if name=="gui_replace01" else name)
	set_clip("up"); mouse_entered.connect(func():set_clip("hilite")); mouse_exited.connect(func():set_clip("up"))
func set_clip(state: String) -> void:
	if closed: return
	for part in plan.states[state]: planes[str(part.id)].configure(part)
func close() -> void:
	if closed: return
	closed=true; hide(); mouse_filter=Control.MOUSE_FILTER_IGNORE
	for image in planes.values():
		if is_instance_valid(art): art.unbind(image)
		image.texture=null
	art=null; plan={}; tooltip_provider=Callable()
func _exit_tree() -> void: close()
