extends Node
# Native48/1 is a display timer only. The server owns completion and gameplay.
const LABEL_REFS={1:0x10566,2:0x10567,3:0x10569,4:0x1056b,5:0x1056c,6:0x1056d,7:0x1056e,8:0x10570}
const INVALID:=0x7f000000
var text_owner
var parent: Control
var host: PanelContainer
var label: Label
var bar: ProgressBar
var last_external_version:=-1
var pending: Dictionary={}
var started_us:=0
var failure:=""

func configure(container: Control,text) -> void:
	parent=container;text_owner=text
	host=PanelContainer.new();host.name="NativeTimingView";host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	host.custom_minimum_size=Vector2(240,0)
	var panel:=StyleBoxFlat.new();panel.bg_color=Color("061710ed");panel.border_color=Color("a69b74")
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		panel.set_border_width(side,1);panel.set_content_margin(side,10)
	host.add_theme_stylebox_override("panel",panel)
	var column:=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_theme_constant_override("separation",5);host.add_child(column)
	label=Label.new();label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color",Color("eee9d9"));label.add_theme_font_size_override("font_size",14);column.add_child(label)
	bar=ProgressBar.new();bar.show_percentage=false;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(bar)
	parent.add_child(host);host.hide();parent.resized.connect(place);call_deferred("place")

func place() -> void:
	if not is_instance_valid(parent) or not is_instance_valid(host):return
	host.position=Vector2((parent.size.x-host.size.x)*0.5,parent.size.y-95-host.size.y)

func reset_display() -> void:
	pending.clear();started_us=0;failure=""
	if is_instance_valid(host):host.hide()

func reset() -> void:
	last_external_version=-1
	reset_display()

func observe(value: Variant) -> void:
	if not value is Dictionary:
		reset()
		return
	var version:=int(value.get("version",0))
	if version==last_external_version:return
	last_external_version=version
	reset_display()
	if not bool(value.get("active",false)):return
	pending=value.duplicate(true)
	resolve_label()

func resolve_label() -> void:
	if pending.is_empty() or not is_instance_valid(host):return
	var kind:=int(pending.get("type",0))
	var caption:="Action in progress"
	if LABEL_REFS.has(kind):
		var resolved: Dictionary=text_owner.network_resolve({"strRef":int(LABEL_REFS[kind])},INVALID)
		if not bool(resolved.get("ready",false)):
			if bool(resolved.get("pending",false)):return
			failure=str(resolved.get("error",resolved.get("reason","Timing label is unavailable")))
			pending.clear()
			return
		caption=str(resolved.get("body",""))
	label.text=caption
	bar.max_value=maxf(1.0,float(pending.get("duration",0)))
	bar.value=0
	started_us=Time.get_ticks_usec()
	pending.clear()
	host.show();place()

func _process(_delta: float) -> void:
	if not pending.is_empty():resolve_label()
	if started_us==0 or not is_instance_valid(host) or not host.visible:return
	bar.value=minf(bar.max_value,float(Time.get_ticks_usec()-started_us)/1000.0)

func close() -> void:
	reset()
	if is_instance_valid(parent) and parent.resized.is_connected(place):parent.resized.disconnect(place)
	text_owner=null;parent=null
