extends Control
# Shared original-resource modal preparation and held-input lifetime. Subclasses
# own their actions, not asset decoding, source button styling or scope guards.
signal prepared
signal art_cancel_requested(value_scope: Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const NativeArt=preload("res://systems/native_ui_art.gd")
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
var art_gate_enabled:=false
var art_pending:=false
var art_error:=""
var last_art_cohort: Dictionary={}
var art_overlay: ColorRect
var art_message: Label
var modal_owner_order
var modal_owner_kind:=""
var modal_owner_lifetime:=0
var modal_owner_ticket: Dictionary={}
var modal_input=preload("res://systems/native_data/modal_lease.gd").new()
func configure(painter,text,catalog,cache_path: String) -> void:
	frame=painter;text_owner=text;mouse_filter=Control.MOUSE_FILTER_STOP;hide()
	assets=Assets.new();add_child(assets);assets.maximum_workers=2;assets.configure(catalog);assets.cache_directory=cache_path;assets.completed.connect(received)
	if art_gate_enabled:
		art_overlay=ColorRect.new();add_child(art_overlay);art_overlay.color=Color(0.015,0.018,0.025,0.97);art_overlay.z_index=100;art_overlay.mouse_filter=Control.MOUSE_FILTER_STOP;art_overlay.hide()
		art_message=Label.new();art_overlay.add_child(art_message);art_message.position=Vector2(24,24);art_message.size=Vector2(580,110);art_message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var cancel:=Button.new();art_overlay.add_child(cancel);cancel.text="Cancel";cancel.position=Vector2(24,150);cancel.size=Vector2(120,36)
		cancel.pressed.connect(func():var prior:=scope.duplicate();dismiss();art_cancel_requested.emit(prior))
func start() -> void:
	if closed or started:return
	started=true
	var id: int=assets.request(resource,2047,"gff")
	if id<0:failure="Original modal layout: "+str(assets.failure);return
	jobs[id]="@layout"
	for name in extra_models:request_model(str(name))
func request_model(name: String) -> void:
	name=name.to_lower()
	if name.is_empty() or requested.has(name):return
	requested[name]=true
	var id: int=assets.request(name,2002,"actor-model")
	if id<0:failure="Original modal model "+name+": "+str(assets.failure);return
	jobs[id]=name
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
	if wanted:
		if art_gate_enabled:request_art_admission()
		else:show();register_modal_owner()
func art_icon_targets() -> Array:return []
func art_scrollbars() -> Array:return []
func art_excluded_subtrees() -> Array:return []
func art_owned(node: Node) -> bool:
	var ancestor: Node=node.get_parent()
	while ancestor!=null and ancestor!=self:
		if ancestor.has_method("request_art_admission"):return false
		ancestor=ancestor.get_parent()
	for excluded in art_excluded_subtrees():
		if is_instance_valid(excluded) and (node==excluded or excluded.is_ancestor_of(node)):return false
	return true
func art_snapshot() -> Dictionary:
	var result:={"ready":false,"pending":[],"failures":[],"images_expected":0,"images_ready":0,"fonts_expected":0,"fonts_ready":0}
	if not failure.is_empty():result.failures.append(failure)
	if not layout_ready:
		if result.failures.is_empty():result.pending.append("Original modal layout")
		return result
	for picture in find_children("*","TextureRect",true,false):
		if not art_owned(picture):continue
		var key:=str(picture.get_meta("native_gui_art_key",""))
		if key.is_empty():continue
		result.images_expected+=1
		if picture.texture!=null and frame.art.textures.get(key)==picture.texture:result.images_ready+=1
		elif frame.art.failed.has(key):result.failures.append("Creation artwork "+key+": "+str(frame.art.failed[key]))
		else:result.pending.append("image:"+key)
	for button in find_children("*","Button",true,false):
		if not art_owned(button):continue
		var data: Dictionary=frame.button_geometry.get(button.get_instance_id(),{})
		if data.is_empty():continue
		for pair in data.styles.values():
			var key: String=frame.art.models.model_key(str(data.resource),str(pair[1]),data.overrides)
			result.images_expected+=1
			if pair[0].texture!=null and frame.art.textures.get(key)==pair[0].texture:result.images_ready+=1
			elif frame.art.failed.has(key):result.failures.append("Creation button "+key+": "+str(frame.art.failed[key]))
			else:result.pending.append("image:"+key)
	for control in find_children("*","Control",true,false):
		if not art_owned(control):continue
		var font: String=str(control.get_meta("native_font_resource",""))
		if font.is_empty():continue
		result.fonts_expected+=1
		if str(control.get_meta("native_font_applied",""))==font:result.fonts_ready+=1
		elif frame.fonts.failed.has(font):result.failures.append("Creation font "+font+": "+str(frame.fonts.failed[font]))
		else:result.pending.append("font:"+font)
	for bar in art_scrollbars():
		if not is_instance_valid(bar):result.pending.append("Creation scrollbar");continue
		if not str(bar.failure).is_empty():result.failures.append("Creation scrollbar: "+str(bar.failure))
		elif not bar.art_ready or bar.snapshot().thumb_pending or bar.snapshot().layout_pending:result.pending.append("Creation scrollbar")
	for entry in art_icon_targets():
		var resource: String=str(entry.get("resource","")).to_lower();var target: TextureRect=entry.get("target");var art=entry.get("art")
		if resource.is_empty():continue
		result.images_expected+=1
		if not is_instance_valid(art) or not is_instance_valid(target):result.failures.append("Creation icon "+resource+": original art owner or target is unavailable");continue
		var expected: Texture2D=art.textures.get(resource)
		if art is NativeArt:
			var owner=art.catalog.ui_asset_owner()
			var resident: Dictionary=owner.lookup("raster",resource) if owner!=null else {}
			expected=resident.get("texture") if not resident.is_empty() and expected==resident.texture else null
		if art.failed.has(resource):result.failures.append("Creation icon "+resource+": "+str(art.failed[resource]))
		elif expected!=null and target.texture==expected:result.images_ready+=1
		else:result.pending.append("icon:"+resource)
	result.ready=result.failures.is_empty() and result.pending.is_empty()
	return result
func request_art_admission() -> void:
	if not art_gate_enabled or closed or not wanted:return
	revision+=1;held.clear();hide();art_pending=true;art_error=""
	if is_instance_valid(art_overlay):art_overlay.hide()
	check_art_admission()
	if art_pending and not get_tree().process_frame.is_connected(check_art_admission):get_tree().process_frame.connect(check_art_admission)
func check_art_admission() -> void:
	if closed or not wanted or not art_pending:return
	var cohort: Dictionary=art_snapshot();last_art_cohort=cohort
	if cohort.ready:
		art_pending=false;art_error="";art_overlay.hide();show();register_modal_owner()
	elif not cohort.failures.is_empty():
		art_pending=false;art_error=str(cohort.failures[0]);art_message.text="Original creation art unavailable: "+art_error
		if size.x<=0 or size.y<=0:size=Vector2(640,240)
		art_overlay.size=size;art_overlay.show();show();register_modal_owner()
	if not art_pending and get_tree().process_frame.is_connected(check_art_admission):get_tree().process_frame.disconnect(check_art_admission)
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
	if art_gate_enabled:request_art_admission()
	elif layout_ready:show();register_modal_owner()
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
func dismiss() -> void:
	if art_gate_enabled and get_tree()!=null and get_tree().process_frame.is_connected(check_art_admission):get_tree().process_frame.disconnect(check_art_admission)
	art_pending=false;art_error="";last_art_cohort={}
	if is_instance_valid(art_overlay):art_overlay.hide()
	retire_modal_owner();wanted=false;retire_input();hide()
func close() -> void:
	if closed:return
	dismiss();closed=true
	if is_instance_valid(assets):assets.close()
	if is_instance_valid(frame):
		for button in buttons.values():
			if is_instance_valid(button):frame.button_geometry.erase(button.get_instance_id())
	jobs.clear();models.clear();frame=null;text_owner=null;modal_input.close();modal_owner_order=null;modal_owner_kind=""
func _exit_tree() -> void:close()
