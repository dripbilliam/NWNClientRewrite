extends Control
# Private CG_APPEARANCE edit transaction. The owner supplies active-catalog
# choices and commits only finished(true,...); previews are detached values.
signal prepared
signal finished(accepted:bool,value:Dictionary,scope:Array)
signal preview_changed(value:Dictionary,scope:Array)
signal preview_attached(slot:Control,scope:Array)
const Assets=preload("res://systems/native_data/asset_service.gd")
const Layout=preload("res://systems/native_data/creation_appearance_layout.gd")
const State=preload("res://systems/native_data/creation_appearance_state.gd")
var state:=State.new()
var frame
var text_owner
var assets
var models:Dictionary={}
var source:Dictionary={}
var plan:Dictionary={}
var jobs:Dictionary={}
var requested:Dictionary={}
var buttons:Dictionary={}
var scope:Array=[]
var held:Dictionary={}
var revision:=0
var started:=false
var layout_ready:=false
var wanted:=false
var closed:=false
var failure:=""
var preview_slot:Control
var palette:Control
var palette_kind:=""
var palette_press:Dictionary={}
var swatch_unavailable:Dictionary={}
var preview_scope:Array=[]
var modal_lease=preload("res://systems/native_data/modal_lease.gd").new()
var modal_kind:=""
func set_modal_owner(order,verified_kind:String="")->void:
	if modal_lease.order==order and modal_kind==verified_kind:return
	modal_lease.retire();modal_kind=verified_kind;modal_lease.configure(self,order);modal_lease.bind_input(self)
	if not modal_lease.admission_changed.is_connected(modal_admission_changed):modal_lease.admission_changed.connect(modal_admission_changed)
	register_modal_owner()
func register_modal_owner()->void:
	if not closed and wanted and layout_ready and is_visible_in_tree() and modal_kind in ["other","unknown"]:modal_lease.activate(scope,modal_kind)
func modal_admission_changed(admitted:bool)->void:
	if not admitted:retire_input()
func available()->bool:return not closed and wanted and is_visible_in_tree() and modal_lease.admits()
func configure(painter,text,catalog,cache_path:String)->void:
	frame=painter;text_owner=text;mouse_filter=Control.MOUSE_FILTER_STOP;hide()
	assets=Assets.new();add_child(assets);assets.configure(catalog);assets.cache_directory=cache_path;assets.maximum_workers=2;assets.completed.connect(received)
func start()->void:
	if closed or started:return
	started=true;jobs[assets.request("cg_appearance",2047,"gff")]="@layout"
	for resource in Layout.EXTRA:request_model(resource)
func request_model(resource:String)->void:
	resource=resource.to_lower()
	if resource.is_empty() or requested.has(resource):return
	requested[resource]=true;jobs[assets.request(resource,2002,"mdl-original")]=resource
func request_children(node:Dictionary)->void:
	request_model(str(node.get("Obj_ResRef","")))
	for child in node.get("Obj_ChildList",[]):request_children(child)
func received(id:int,result:Dictionary)->void:
	if closed or not jobs.has(id):return
	var resource:String=jobs[id];jobs.erase(id)
	if not str(result.get("error","")).is_empty():failure=resource+": "+str(result.error);return
	if resource=="@layout":source=result.value.root;request_children(source)
	else:models[resource]=result.value
	if not jobs.is_empty() or source.is_empty() or not failure.is_empty():return
	plan=Layout.parse(source,models)
	if not str(plan.error).is_empty():failure=str(plan.error);return
	build()
func caption(entry:Dictionary)->String:
	var value:Dictionary=entry.get("caption",{});var ref:=int(value.get("Obj_StrRef",4294967295))
	return text_owner.raw({"strRef":ref}) if ref!=4294967295 else str(value.get("AurString_Text",""))
func build()->void:
	if closed or layout_ready:return
	size=plan.size;custom_minimum_size=size;frame.image(plan.resource,plan.main,self)
	# Source row planes must be present, and below all foreground captions.
	for tag in Layout.ROWS:frame.image(plan.entries[tag].resource,plan.entries[tag].rect,self)
	var viewer:Dictionary=plan.entries.modelviewer;frame.image(viewer.resource,viewer.rect,self)
	frame.create_label(plan.entries.title,self,caption(plan.entries.title))
	for tag in Layout.ROWS:frame.create_label(plan.entries[tag],self,caption(plan.entries[tag]))
	preview_slot=Control.new();add_child(preview_slot);preview_slot.position=plan.preview.position;preview_slot.size=plan.preview.size;preview_slot.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview_slot.clip_contents=true
	for tag in Layout.BUTTONS.keys()+plan.controls.keys():
		var entry:Dictionary=plan.entries[tag] if Layout.BUTTONS.has(tag) else plan.controls[tag]
		var button:Button=frame.create_button(entry,self,models);buttons[tag]=button
		if Layout.BUTTONS.has(tag):frame.button_caption(button,caption(entry))
		button.button_down.connect(capture.bind(tag));button.pressed.connect(invoke.bind(tag))
	layout_ready=true;refresh();prepared.emit()
	if wanted:show();register_modal_owner();attach_preview()
func set_context(context:Dictionary,value_scope:Array)->void:
	if closed:return
	var changed:bool=scope!=value_scope
	if changed:modal_lease.retire()
	retire_input();scope=value_scope.duplicate();state.reset(context);preview_scope.clear();refresh()
	if wanted and layout_ready:attach_preview()
	if changed:register_modal_owner()
func attach_preview()->void:
	if not layout_ready or not wanted or preview_scope==scope:return
	preview_scope=scope.duplicate();preview_attached.emit(preview_slot,scope.duplicate());preview_changed.emit(state.snapshot(),scope.duplicate())
func refresh()->void:
	if not layout_ready:return
	for tag in plan.controls:
		var kind:String=tag.split("_")[0];var can:bool=state.editable(kind)
		if kind=="body":can=can and State.whole(state.value.get("phenotype"),255) and (state.source.get("enabledPhenotypes") is int or state.source.get("enabledPhenotypes") is float)
		elif kind=="head":can=can and State.whole(state.value.get("head"),65535) and state.source.get("headIndexComplete")==true and state.source.get("heads") is Dictionary
		elif kind=="tattoo" and tag.contains("_"):can=can and State.whole(state.value.get("tattooPattern"),15) and state.value.get("bodyParts") is Array
		elif kind=="clothes":can=can and state.source.get("clothing") is Array and not state.source.clothing.is_empty() and State.whole(state.value.get("clothingIndex"),state.source.clothing.size()-1)
		elif tag in ["skin","hair","tattoo1","tattoo2"]:can=can and State.whole(state.source.get("paletteSizes",{}).get(tag),65535) and int(state.source.paletteSizes[tag])>0
		buttons[tag].disabled=not can
	refresh_swatches()
func refresh_swatches()->void:
	#8eb480/94: ReplaceTexturePLT on gui_replace01 only. The high BYTE
	# selects the native palette; it is not an ordinary world PLT row index.
	swatch_unavailable.clear()
	for kind in ["skin","hair","tattoo1","tattoo2"]:
		if not State.whole(state.value.get(kind),255):continue
		var button:Button=buttons[kind];var geometry:Dictionary=frame.button_geometry.get(button.get_instance_id(),{})
		if geometry.is_empty():continue
		var selector:int=int(state.value[kind])|((0 if kind=="skin" else 1 if kind=="hair" else 6)<<8)
		var descriptor:Dictionary={"resource":"gui_cg_color_tmp","palette":[selector]}
		if state.source.has("paletteRows") or state.source.has("paletteSourceHashes"):
			var rows:Variant=state.source.get("paletteRows");var sources:Variant=state.source.get("paletteSourceHashes")
			var row:Variant=rows.get(selector) if rows is Dictionary else null;var source:Variant=sources.get(selector) if sources is Dictionary else null
			if not row is PackedByteArray or row.size()!=1024 or not source is String or source.length()!=64 or not source.is_valid_hex_number(false):
				swatch_unavailable[kind]="The active selected palette row/source is unavailable."
				for pair in geometry.styles.values():frame.art.unbind(pair[0]);pair[0].texture=null
				geometry.overrides={};button.queue_redraw();continue
			descriptor.palette_row=row;descriptor.palette_source=source
		var overrides:Dictionary={"gui_replace01":descriptor}
		if geometry.overrides==overrides:continue
		geometry.overrides=overrides
		for pair in geometry.styles.values():frame.art.bind(pair[0],str(geometry.resource),"texture",true,str(pair[1]),false,overrides)
		frame.update_button(button.get_instance_id());button.queue_redraw()
func capture(tag:String)->void:
	if not available():return
	held[tag]={"revision":revision,"scope":scope.duplicate()}
func invoke(tag:String)->void:
	var press:Dictionary=held.get(tag,{});held.erase(tag)
	if not available() or press.is_empty() or int(press.revision)!=revision or press.scope!=scope:return
	if tag in Layout.BUTTONS:
		var result_scope:=scope.duplicate();var value:=state.snapshot();dismiss();finished.emit(tag=="okbutton",value,result_scope);return
	if tag in ["skin","hair","tattoo1","tattoo2"]:open_palette(tag);return
	close_palette()
	var pair:=tag.split("_")
	if pair.size()!=2:return
	if state.step(pair[0],-1 if pair[1]=="left" else 1):refresh();preview_changed.emit(state.snapshot(),scope.duplicate())
func open_palette(kind:String)->void:
	close_palette()
	if not available() or not buttons.has(kind) or buttons[kind].disabled:return
	palette_kind=kind;palette_press={"scope":scope.duplicate(),"revision":revision};var board:Dictionary=plan.boards["tatt" if kind.begins_with("tattoo") else kind]
	palette=Control.new();add_child(palette);palette.position=plan.controls[kind].offset+board.model.bounds.position;palette.size=board.model.bounds.size;palette.mouse_filter=Control.MOUSE_FILTER_STOP
	frame.image(board.resource,Rect2(Vector2.ZERO,palette.size),palette)
func _input(event:InputEvent)->void:
	if not available():return
	# CCharacterAppearancePanel vtable+140 ->8e3300: original modal Cancel2.
	# The attached color board is not another modal, so Escape cancels the pane.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		capture("cancelbutton");invoke("cancelbutton");get_viewport().set_input_as_handled();return
	if not is_instance_valid(palette) or not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT:return
	# Original CGuiCGColSelect captures the mouse when attached and releases it
	# on the next left-up, including a drag or release outside the board.
	if not event.pressed:
		var point:Vector2=palette.get_global_transform_with_canvas().affine_inverse()*event.position
		palette_release(point)
	get_viewport().set_input_as_handled()
func palette_release(point:Vector2)->void:
	if not available() or not is_instance_valid(palette):return
	var press:Dictionary=palette_press.duplicate();var kind:=palette_kind
	var index:Variant=State.palette_index(Vector2(point.x*.01,(palette.size.y-point.y)*.01))
	close_palette()
	if press.is_empty() or press.scope!=scope or int(press.revision)!=revision or index==null:return
	if state.color(kind,int(index)):refresh();preview_changed.emit(state.snapshot(),scope.duplicate())
func close_palette()->void:
	if is_instance_valid(palette):palette.hide();palette.queue_free()
	palette=null;palette_kind="";palette_press.clear()
func open()->void:
	if closed:return
	wanted=true
	if layout_ready:show();register_modal_owner();attach_preview()
func retire_input()->void:
	revision+=1;held.clear();close_palette()
	for button in buttons.values():
		var disabled:bool=button.disabled;button.disabled=true;button.disabled=disabled
func dismiss()->void:modal_lease.retire();wanted=false;retire_input();hide();preview_scope.clear()
func snapshot()->Dictionary:return {"ready":layout_ready,"failure":failure,"scope":scope.duplicate(),"value":state.snapshot(),"palette":palette_kind,"swatchesUnavailable":swatch_unavailable.duplicate(),"full_creation_parity":false}
func close()->void:
	if closed:return
	dismiss();closed=true
	if is_instance_valid(assets):assets.close()
	if is_instance_valid(frame):
		for button in buttons.values():frame.button_geometry.erase(button.get_instance_id())
	jobs.clear();models.clear();text_owner=null;frame=null;modal_lease.close();modal_kind=""
func _exit_tree()->void:close()
