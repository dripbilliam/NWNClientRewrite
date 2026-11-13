extends Control
# Shared original-resource modal preparation and held-input lifetime. Subclasses
# own their actions, not asset decoding, source button styling or scope guards.
signal prepared
const Assets=preload("res://systems/native_data/asset_service.gd")
var frame
var text_owner
var assets
var resource:=""
var extra_models: Array=[]
var models: Dictionary={}
var jobs: Dictionary={}
var requested: Dictionary={}
var source: Dictionary={}
var plan: Dictionary={}
var buttons: Dictionary={}
var scope: Array=[]
var held: Dictionary={}
var revision:=0
var started:=false
var layout_ready:=false
var wanted:=false
var closed:=false
var failure:=""
var modal_owner_order
var modal_owner_kind:=""
var modal_owner_lifetime:=0
var modal_owner_ticket: Dictionary={}
var modal_input=preload("res://systems/native_data/modal_lease.gd").new()
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter;text_owner=text;mouse_filter=Control.MOUSE_FILTER_STOP;hide()
	assets=Assets.new();add_child(assets);assets.maximum_workers=2;assets.configure(catalog);assets.cache_directory=cache_path;assets.completed.connect(received)
func start() -> void:
	if closed or started:return
	started=true;jobs[assets.request(resource,2047,"gff")]="@layout"
	for name in extra_models:request_model(str(name))
func request_model(name: String) -> void:
	name=name.to_lower()
	if name.is_empty() or requested.has(name):return
	requested[name]=true;jobs[assets.request(name,2002,"actor-model")]=name
func collect(node: Dictionary) -> void:
	request_model(str(node.get("Obj_ResRef","")))
	for child in node.get("Obj_ChildList",[]):collect(child)
func received(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id):return
	var name: String=jobs[id];jobs.erase(id)
	if not str(result.get("error","")).is_empty():failure=name+": "+str(result.error);return
	if name=="@layout":source=result.value.root;collect(source)
	else:models[name]=result.value
	if not jobs.is_empty() or source.is_empty() or not failure.is_empty():return
	plan=parse_layout()
	if not str(plan.get("error","")).is_empty():failure=str(plan.error);return
	size=plan.size;custom_minimum_size=size;assemble()
	if not failure.is_empty():return
	layout_ready=true;refresh();prepared.emit()
	if wanted:show();register_modal_owner()
func parse_layout() -> Dictionary:return {"error":"Original modal has no layout adapter"}
func assemble() -> void:pass
func refresh() -> void:pass
func caption(entry: Dictionary) -> String:
	var value: Dictionary=entry.get("caption",{});var ref:=int(value.get("Obj_StrRef",4294967295))
	return text_owner.raw({"strRef":ref}) if ref!=4294967295 else str(value.get("AurString_Text",""))
func make_button(tag: String,entry: Dictionary,parent: Control=null,radio: bool=false) -> Button:
	var button: Button=frame.create_button(entry,self if parent==null else parent,models,radio);buttons[tag]=button;frame.button_caption(button,caption(entry))
	button.button_down.connect(capture.bind(tag));button.pressed.connect(invoke.bind(tag));return button
func available() -> bool:return not closed and wanted and is_visible_in_tree() and (not is_instance_valid(modal_owner_order) or modal_owner_order.admits(modal_owner_ticket))
func capture(tag: String) -> void:
	if available():held[tag]={"revision":revision,"scope":scope.duplicate()}
func valid_press(tag: String) -> bool:
	var value: Dictionary=held.get(tag,{});held.erase(tag)
	return available() and not value.is_empty() and int(value.revision)==revision and value.scope==scope
func invoke(_tag: String) -> void:pass
func open() -> void:
	if closed:return
	wanted=true
	if layout_ready:show();register_modal_owner()
func set_modal_owner(order,verified_kind: String="") -> void:
	# Optional explicit original-owner classification. Inheriting this native
	# source control does not prove membership in the original modal array.
	if modal_owner_order==order and modal_owner_kind==verified_kind:return
	retire_modal_owner();modal_owner_order=order;modal_owner_kind=verified_kind
	modal_input.configure(self,order);modal_input.bind_input(self)
	if not modal_input.admission_changed.is_connected(modal_admission_changed):modal_input.admission_changed.connect(modal_admission_changed)
	if wanted and layout_ready and is_visible_in_tree():register_modal_owner()
func register_modal_owner() -> void:
	if closed or not wanted or not layout_ready or not is_visible_in_tree() or not is_instance_valid(modal_owner_order) or modal_owner_kind not in ["other","unknown"]:return
	if modal_owner_ticket.is_empty():
		if modal_owner_lifetime>=9007199254740991:return
		modal_owner_lifetime+=1
	var ticket: Dictionary=modal_owner_order.activate(self,modal_owner_kind,modal_owner_lifetime,scope)
	modal_owner_ticket=ticket if ticket.has("registry") else {}
	modal_input.active=true;modal_input.ticket=modal_owner_ticket;modal_input.update_input()
func modal_admission_changed(admitted: bool) -> void:
	if not admitted:retire_input()
func retire_modal_owner() -> void:
	if is_instance_valid(modal_owner_order) and not modal_owner_ticket.is_empty():modal_owner_order.retire(modal_owner_ticket)
	modal_owner_ticket.clear()
	modal_input.active=false;modal_input.ticket={};modal_input.update_input()
func retire_input() -> void:
	revision+=1;held.clear()
	for button in buttons.values():
		if not is_instance_valid(button):continue
		var disabled: bool=button.disabled;button.disabled=true;button.disabled=disabled
func dismiss() -> void:retire_modal_owner();wanted=false;retire_input();hide()
func close() -> void:
	if closed:return
	dismiss();closed=true
	if is_instance_valid(assets):assets.close()
	if is_instance_valid(frame):
		for button in buttons.values():
			if is_instance_valid(button):frame.button_geometry.erase(button.get_instance_id())
	jobs.clear();models.clear();frame=null;text_owner=null;modal_input.close();modal_owner_order=null;modal_owner_kind=""
func _exit_tree() -> void:close()
