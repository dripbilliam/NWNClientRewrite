extends CanvasLayer
# Original quickslot Examine and two-step text macro dialogs. Shared source
# controls own artwork/input; this owner validates the originating slot scope.
var desktop
var surface: Control
var edit
var information
var scope: Dictionary={}
var macro: Dictionary={}
var stage:=""
var text_revision:=-1
var closed:=false
func configure(owner,catalog,cache_path: String) -> void:
	desktop=owner;layer=101;surface=Control.new();add_child(surface);surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var painter=owner.owner_ui.inventory.frame_skin
	edit=preload("res://systems/native_generic_edit.gd").new();surface.add_child(edit);edit.configure(painter,owner.owner_ui.text,catalog,cache_path);edit.prepared.connect(dialog_prepared.bind(edit));edit.finished.connect(edited)
	information=preload("res://systems/native_feat_popup.gd").new();information.configure_mode(true);surface.add_child(information);information.configure(painter,owner.owner_ui.text,catalog,cache_path);information.prepared.connect(dialog_prepared.bind(information));information.finished.connect(func(_accepted,_id,_ticket):clear())
	get_viewport().size_changed.connect(place)
func dialog_prepared(panel) -> void:
	place()
	if not closed and panel.wanted:panel.open()
func place() -> void:
	var extent:=get_viewport().get_visible_rect().size
	for panel in [edit,information]:
		if not is_instance_valid(panel) or not panel.layout_ready:continue
		var factor:=minf(1.0,minf(extent.x/panel.size.x,extent.y/panel.size.y));panel.scale=Vector2.ONE*factor;panel.position=(extent-panel.size*factor)*0.5
func clear() -> void:
	if is_instance_valid(edit):edit.dismiss()
	if is_instance_valid(information):information.dismiss()
	scope.clear();macro.clear();stage="";text_revision=-1
func examine(value: Dictionary,model: Dictionary) -> void:
	clear()
	if closed or model.is_empty() or not desktop.shortcut_scope_valid(value):return
	scope=value.duplicate(true);stage="information";text_revision=int(desktop.owner_ui.text.revision)
	if int(value.binding.get("type",0))==10:model=model.merged({"icon":str(desktop.shortcut_row(value.binding).icon)},true)
	information.set_context(model,desktop.owner_ui.text,desktop.art,identity());information.start();information.open();place()
func edit_macro(value: Dictionary,part: String="new") -> void:
	clear()
	if closed or not desktop.shortcut_scope_valid(value):return
	scope=value.duplicate(true);macro=value.binding.duplicate(true) if int(value.binding.get("type",0))==18 else {"type":18,"commandLine":"","commandLabel":""}
	stage="new-label" if part=="new" else "line" if part=="line" else "label";show_edit()
func identity() -> Array:return [scope.get("generation"),scope.get("area"),scope.get("actor"),scope.get("index"),stage]
func show_edit() -> void:
	var line:=stage=="line"
	edit.set_context(str(macro.get("commandLine" if line else "commandLabel","")),6628 if line else 6679,-1,identity());edit.start();edit.open();place()
func edited(accepted: bool,value: String,ticket: Array) -> void:
	if closed or scope.is_empty() or ticket!=identity() or not desktop.shortcut_scope_valid(scope):clear();return
	if not accepted:clear();return
	macro["commandLine" if stage=="line" else "commandLabel"]=value
	if stage=="new-label":stage="line";show_edit();return
	var index:=int(scope.index);var binding:=macro.duplicate(true);clear();desktop.assign(index,binding)
func _process(_delta: float) -> void:
	if not scope.is_empty() and not desktop.shortcut_scope_valid(scope):clear()
	if stage=="information" and not scope.is_empty() and text_revision!=int(desktop.owner_ui.text.revision):
		var value:=scope.duplicate(true);examine(value,desktop.shortcut_rules.information(value.binding))
func blocks_pointer(point: Vector2) -> bool:
	for panel in [edit,information]:
		if is_instance_valid(panel) and panel.wanted and panel.is_visible_in_tree() and panel.get_global_rect().has_point(point):return true
	return false
func close() -> void:
	if closed:return
	clear();closed=true
	for panel in [edit,information]:
		if is_instance_valid(panel):panel.close()
	desktop=null
func _exit_tree() -> void:close()
