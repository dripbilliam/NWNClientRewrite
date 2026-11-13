extends RefCounted
# View construction only: definitions describe controls, controllers own actions.
# Authored original GUI geometry still goes through the same source painter.
const KINDS=["column","row","tabs","label","rich","button","check","choice","progress","scroll","control","edit","number"]
const PROPERTIES=["name","text","custom_minimum_size","size_flags_horizontal","size_flags_vertical","autowrap_mode","horizontal_scroll_mode","vertical_scroll_mode","show_percentage","disabled","focus_mode","mouse_filter","tooltip_text","min_value","max_value","step","value"]
static func validate(specs: Array,ids: Dictionary={}) -> String:
	for spec in specs:
		if not spec is Dictionary or str(spec.get("kind","")) not in KINDS: return "Unknown menu control kind"
		var id:=str(spec.get("id",""))
		if not id.is_empty():
			if ids.has(id): return "Duplicate menu control: "+id
			ids[id]=true
		for key in spec.get("properties",{}):
			if key not in PROPERTIES: return "Unsupported menu property: "+str(key)
		var error:=validate(spec.get("children",[]),ids)
		if not error.is_empty(): return error
	return ""
static func build(parent: Control,specs: Array) -> Dictionary:
	# Validate the whole tree before adding anything to a live menu.
	var error:=validate(specs,{})
	if not error.is_empty(): return {"error":error,"nodes":{}}
	var nodes: Dictionary={}; append(parent,specs,nodes)
	return {"error":"","nodes":nodes}
static func append(parent: Control,specs: Array,nodes: Dictionary) -> void:
	for spec in specs:
		var node:=create(str(spec.kind),parent,spec.get("properties",{}))
		var id:=str(spec.get("id",""))
		if not id.is_empty(): nodes[id]=node
		if node is OptionButton:
			for item in spec.get("items",[]):
				if item is Array: node.add_item(str(item[0]),int(item[1]))
				else: node.add_item(str(item))
		append(node,spec.get("children",[]),nodes)
static func create(kind: String,parent: Control,properties: Dictionary={}) -> Control:
	var node: Control
	match kind:
		"column": node=VBoxContainer.new()
		"row": node=HBoxContainer.new()
		"tabs": node=TabContainer.new()
		"label": node=Label.new(); node.mouse_filter=Control.MOUSE_FILTER_IGNORE
		"rich": node=RichTextLabel.new()
		"button": node=Button.new()
		"check": node=CheckBox.new()
		"choice": node=OptionButton.new()
		"progress": node=ProgressBar.new()
		"scroll": node=ScrollContainer.new()
		"edit": node=LineEdit.new()
		"number": node=SpinBox.new()
		_: node=Control.new()
	if node is BaseButton: node.focus_mode=Control.FOCUS_NONE
	for key in properties: node.set(key,properties[key])
	parent.add_child(node); return node
static func source_button(painter,parent: Control,entry: Dictionary,models: Dictionary,checkbox: bool=false) -> Button:
	var node: Button=create("button",parent)
	painter.button(node,entry,parent,models,false,checkbox); node.toggle_mode=checkbox
	return node
static func source_label(painter,parent: Control,entry: Dictionary,value: String="") -> Label:
	var node: Label=create("label",parent); painter.label(node,entry,parent); node.text=value; return node
static func source_edit(painter,parent: Control,entry: Dictionary) -> LineEdit:
	if entry.model.drawn: painter.image(entry.resource,entry.rect,parent)
	var node: LineEdit=create("edit",parent); node.custom_minimum_size=Vector2.ZERO; node.max_length=0
	for state in ["normal","focus","read_only"]: node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	painter.font_style(node,entry.caption); node.position=entry.text_rect.position; node.size=entry.text_rect.size
	return node
static func source_ready(root: Control,painter) -> bool:
	if not is_instance_valid(painter) or painter.closed: return false
	for node in root.find_children("*","Control",true,false):
		if node is TextureRect and node.get_meta("native_gui_static_image",false) and node.texture==null: return false
		if node.has_meta("native_font_resource") and not node.has_meta("native_font_applied"): return false
		if node is Button and painter.button_geometry.has(node.get_instance_id()):
			for pair in painter.button_geometry[node.get_instance_id()].styles.values():
				if pair[0].texture==null: return false
	return true
static func apply_window(window: PanelContainer,value: Theme,close: Button=null) -> void:
	window.theme=value; window.remove_theme_stylebox_override("panel"); window.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	if is_instance_valid(close):
		close.focus_mode=Control.FOCUS_NONE
		if value.has_icon("client_close","Button"):
			close.text=""; close.theme_type_variation="ClientCloseButton"; close.size_flags_vertical=Control.SIZE_SHRINK_CENTER; close.custom_minimum_size=value.get_icon("client_close","Button").get_size()
		else: close.text="×"
