extends Control
const RangePlan=preload("res://systems/native_data/gui_scroll_range.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
var frame
var range_control: Range
var texture: TextureRect
var host: Control
var horizontal:=false
var length:=0.0
var rest_thumb:=Vector2.ZERO
var key:=""
var requested:=""
var pixels:=0.0
var dragging:=false
var grab:=0.0
var closed:=false
func configure(painter,source: Dictionary,range_owner: Range,is_horizontal: bool) -> void:
	frame=painter; range_control=range_owner; horizontal=is_horizontal; rest_thumb=Geometry.model(source).hooks.thumb
	mouse_filter=Control.MOUSE_FILTER_STOP; focus_mode=Control.FOCUS_NONE
	host=Control.new(); add_child(host); host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture=TextureRect.new(); host.add_child(texture); texture.mouse_filter=Control.MOUSE_FILTER_IGNORE; texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	range_control.changed.connect(refresh); range_control.value_changed.connect(value_changed); frame.art.loaded.connect(loaded)
	visibility_changed.connect(func():if not is_visible_in_tree(): dragging=false)
func arrange(attachment: Vector2,extent: float) -> void:
	length=extent
	position=attachment-Vector2(0,3) if horizontal else attachment; size=Vector2(length,3) if horizontal else Vector2(3,length)
	host.position=Vector2(0,3) if horizontal else Vector2.ZERO; host.rotation=-PI/2 if horizontal else 0.0
	refresh()
func maximum() -> float: return maxf(0,range_control.max_value-range_control.page)
func refresh() -> void:
	if closed or not is_instance_valid(range_control) or length<=0: return
	visible=maximum()>0
	if not visible: dragging=false; return
	var plan:=RangePlan.thumb(ceili(maximum())+1,roundi(range_control.page),length); pixels=float(plan.pixels)
	var poses: Array=[{"clip":"size","time":(maxf(3.01,length)-3.0)/30.0},{"clip":"thumbsize","time":float(plan.time)}]
	var signature:=JSON.stringify([length,pixels])
	if signature!=requested:
		requested=signature; key=frame.art.request_model("ctl_map_panbar","",{},0,"",poses)
		if frame.art.textures.has(key): loaded(key,frame.art.textures[key],frame.art.bounds.get(key,{}))
	value_changed(range_control.value)
func loaded(id: String,image: Texture2D,bounds: Dictionary) -> void:
	if closed or id!=key or bounds.is_empty(): return
	texture.texture=image; texture.size=Vector2(float(bounds.max[0])-float(bounds.min[0]),float(bounds.max[1])-float(bounds.min[1]))*100.0
	texture.set_meta("source_origin",Vector2(float(bounds.min[0]),-float(bounds.max[1]))*100.0); value_changed(range_control.value)
func value_changed(value: float) -> void:
	if closed or not texture.has_meta("source_origin"): return
	var amount:=roundf(maxf(0,length-pixels)*clampf(value/maximum(),0,1)) if maximum()>0 else 0.0
	texture.position=texture.get_meta("source_origin")-rest_thumb+Vector2(0,amount)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		var coordinate: float=event.position.x if horizontal else event.position.y
		if event.pressed:
			var start:=roundf(maxf(0,length-pixels)*range_control.value/maximum()) if maximum()>0 else 0.0
			dragging=true; grab=coordinate-start if coordinate>=start and coordinate<=start+pixels else pixels/2; move_thumb(coordinate)
		else: dragging=false
		accept_event()
	elif event is InputEventMouseMotion and dragging: move_thumb(event.position.x if horizontal else event.position.y); accept_event()
func move_thumb(coordinate: float) -> void:
	var travel:=maxf(0,length-pixels)
	if travel>0: range_control.value=roundf(clampf((coordinate-grab)/travel,0,1)*maximum())
func close() -> void:
	if closed: return
	closed=true; dragging=false
	if is_instance_valid(range_control):
		if range_control.changed.is_connected(refresh): range_control.changed.disconnect(refresh)
		if range_control.value_changed.is_connected(value_changed): range_control.value_changed.disconnect(value_changed)
	if is_instance_valid(frame) and frame.art.loaded.is_connected(loaded): frame.art.loaded.disconnect(loaded)
