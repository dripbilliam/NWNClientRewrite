extends Control
# Original INV_STACKSPLIT amount controls -> private CGuiPlayerGoldSource drag.
# No balance/ownership prediction. Every drop is revalidated against live state.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Layout=preload("res://systems/native_data/inventory_frame_layout.gd")
const Amount=preload("res://systems/native_data/amount_dialog.gd")
const INVALID:=2130706432
var owner_inventory
var frame
var assets
var jobs: Dictionary={}
var gui: Dictionary={}
var models: Dictionary={}
var entries: Dictionary={}
var modal: Control
var number: LineEdit
var title_label: Label
var buttons: Dictionary={}
var world_pick: Callable
var world_blocked: Callable
var barter_context: Callable
var from_barter:=false
var context: Array=[]
var maximum:=0
var serial:=0
var payload: Dictionary={}
var layout_ready:=false
var closed:=false
var failure:=""
var repeat_step:=0
var repeat_elapsed:=0
var repeat_initial:=true
var repeat_button: Button
var stats:={"opened":0,"drags":0,"sent":0,"stale":0,"canceled":0}
func dialog_title() -> String: return owner_inventory.text_owner.raw({"strRef":63448})
func configure(inventory,parent: Control,catalog,cache_path: String) -> void:
	owner_inventory=inventory; frame=inventory.frame_skin
	parent.add_child(self); parent.move_child(self,0); set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP; hide(); set_process(false)
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	jobs[assets.request("inv_stacksplit",2047,"gff")]="gui"
func collect(root: Dictionary) -> void:
	for child in root.get("Obj_ChildList",[]):
		if child.has("Obj_ResRef"): models[str(child.Obj_ResRef).to_lower()]={}
		collect(child)
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var key:=str(jobs[id]); jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=str(result.error); return
	if key=="gui":
		if str(result.value.get("type",""))!="GUI ": failure="Invalid original amount dialog"; return
		gui=result.value.root; models[str(gui.Obj_ResRef).to_lower()]={}; collect(gui)
		for name in models: jobs[assets.request(name,2002,"mdl-original")]=name
	else: models[key]=result.value
	if jobs.is_empty() and failure.is_empty(): build()
func flatten(root: Dictionary,offset: Vector2) -> bool:
	var plan:=Layout.elements(root,models,offset)
	if not str(plan.error).is_empty(): failure=str(plan.error); return false
	for child in root.get("Obj_ChildList",[]):
		var tag:=str(child.get("Obj_Tag","")).to_lower()
		if entries.has(tag): failure="Ambiguous original amount control"; return false
		entries[tag]=plan.entries[tag]
		if not child.get("Obj_ChildList",[]).is_empty() and not flatten(child,entries[tag].offset): return false
	return true
func build() -> void:
	var panel:=Layout.Model.model(models[str(gui.Obj_ResRef).to_lower()])
	if not str(panel.error).is_empty() or not panel.drawn: failure="Original amount panel geometry unavailable"; return
	if not flatten(gui,-panel.bounds.position): return
	for tag in ["title","numedit","okbutton","cancelbutton","allbutton","upbutton","downbutton"]:
		if not entries.has(tag): failure="Original amount control missing: "+tag; return
	modal=Control.new(); modal.mouse_filter=Control.MOUSE_FILTER_STOP; get_parent().add_child(modal); modal.size=panel.bounds.size
	frame.image(str(gui.Obj_ResRef),Rect2(Vector2.ZERO,panel.bounds.size),modal)
	for tag in ["ctl_btn_inv_st","numedit"]:
		if entries.has(tag): frame.image(entries[tag].resource,entries[tag].rect,modal)
	title_label=frame.create_label(entries.title,modal); title_label.text=dialog_title()
	# CGuiLabel's default flags do not apply Obj_Label_Width. Its StringGob
	# aligns the unbounded string around the caption's anchor; using the GUI
	# width as a clipped Godot label shifted and cut off the amount title.
	title_label.clip_text=false; title_label.minimum_size_changed.connect(position_title); position_title()
	number=LineEdit.new(); modal.add_child(number); frame.relocate(number,modal,entries.numedit.rect); number.alignment=HORIZONTAL_ALIGNMENT_CENTER; number.max_length=0
	for state in ["normal","focus","read_only"]: number.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	frame.font_style(number,entries.numedit.caption)
	for tag in ["okbutton","cancelbutton","allbutton","upbutton","downbutton"]:
		var button: Button=frame.create_button(entries[tag],modal,models); buttons[tag]=button
		if entries[tag].get("caption",{}).has("Obj_StrRef"):
			frame.button_caption(button,owner_inventory.text_owner.raw({"strRef":int(entries[tag].caption.Obj_StrRef)}))
	buttons.okbutton.pressed.connect(confirm); buttons.cancelbutton.pressed.connect(cancel)
	buttons.allbutton.pressed.connect(func(): number.text=str(maximum))
	for tag in ["upbutton","downbutton"]:
		var step:=1 if tag=="upbutton" else -1
		buttons[tag].button_down.connect(func(): change(step); repeat_step=step; repeat_elapsed=0; repeat_initial=true; repeat_button=buttons[tag])
		buttons[tag].button_up.connect(func(): repeat_step=0; repeat_button=null)
	number.text_submitted.connect(func(_text):confirm()); modal.hide(); layout_ready=true; frame.refresh()
func position_title() -> void:
	if not is_instance_valid(title_label): return
	var extent:=title_label.get_minimum_size(); var entry: Dictionary=entries.title
	title_label.size=extent
	title_label.position=entry.rect.position-Vector2(extent.x*float(entry.get("caption",{}).get("AurString_AlignH",0)),0)
func current_context() -> Array:
	var barter: Dictionary=barter_context.call() if barter_context.is_valid() else {}
	return [owner_inventory.generation,owner_inventory.area_id,owner_inventory.controlled_id,int(barter.get("serial",-1))]
func balance() -> int:
	var value: Variant=owner_inventory.summary(owner_inventory.objects.get(owner_inventory.controlled_id,{})).gold
	return int(value) if value!=null else -1
func open(barter_source: bool=false) -> void:
	var barter: Dictionary=barter_context.call() if barter_context.is_valid() else {}
	if closed or not layout_ready or balance()<=0 or (barter_source and (not barter.get("open",false) or barter.get("locked",false))) or not barter_source and not owner_inventory.ui.wanted: return
	cancel(); from_barter=barter_source; context=current_context(); maximum=balance(); number.text="1"; modal.position=(get_viewport_rect().size-modal.size)*0.5; modal.show(); modal.move_to_front(); number.grab_focus(); number.select_all(); set_process(true); stats.opened+=1
func change(step: int) -> void: number.text=str(Amount.changed(number.text,maximum,step))
func confirm() -> void:
	if closed or not is_instance_valid(modal) or not modal.visible: return
	var amount:=Amount.confirmed(number.text,maximum)
	if context!=current_context() or amount>balance(): stats.stale+=1; cancel(); return
	modal.hide(); repeat_step=0; repeat_button=null; repeat_elapsed=0; repeat_initial=true; number.release_focus()
	if amount<=0: set_process(false); return
	serial+=1; payload={"kind":"native-inventory-gold","serial":serial,"context":context.duplicate(),"amount":amount}
	var preview:=Control.new(); var image:=TextureRect.new(); image.mouse_filter=Control.MOUSE_FILTER_IGNORE; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.size=Vector2(32,32); preview.add_child(image); frame.art.bind(image,"ir_buy")
	var caption:=Label.new(); caption.text=str(amount); caption.position=Vector2(0,30); preview.add_child(caption)
	show(); force_drag(payload.duplicate(true),preview); stats.drags+=1
func valid(data: Variant) -> bool:
	return not closed and data is Dictionary and not payload.is_empty() and data==payload and context==current_context() and int(data.amount)>0 and int(data.amount)<=balance()
func destination(id: int) -> bool:
	var object: Dictionary=owner_inventory.objects.get(id,{})
	if object.is_empty() or object.get("replicationRemoved",false): return false
	var kind:=int(object.get("objectType",0)); var location: Dictionary=object.get("inventoryLocation",{}); var channel:=str(location.get("channel","")); var container:=int(owner_inventory.containers.get("C",INVALID))
	var owned: bool=kind==6 and (container!=INVALID and id==container or channel in ["R","I"] and int(location.get("ownerId",-1))==owner_inventory.controlled_id or channel=="C" and container!=INVALID and int(location.get("ownerId",-1))==container)
	if not owned and int(object.get("areaId",-1))!=owner_inventory.area_id: return false
	if kind in [5,9]: return true
	return kind==6 and int(owner_inventory.IconPlan.number(owner_inventory.IconPlan.row(owner_inventory.text_owner.tables,"baseitems",int(object.get("item",{}).get("baseItem",-1))).get("Container")))!=0
func can_target(data: Variant,id: int) -> bool: return valid(data) and destination(id)
func drop_target(data: Dictionary,id: int) -> void:
	if not can_target(data,id): stats.stale+=1; return
	# Original ordinary inventory gold drop140855e80 passes placement=0.
	# The coordinate-bearing placement variant belongs to player barter.
	send({"targetId":id,"placement":false})
func drop_barter(data: Dictionary,id: int,x: int,y: int,serial: int) -> void:
	var barter: Dictionary=barter_context.call() if barter_context.is_valid() else {}
	if not valid(data) or not barter.get("open",false) or barter.get("locked",false) or int(barter.get("serial",-1))!=serial or int(barter.get("targetId",-1))!=id: stats.stale+=1; return
	send({"targetId":id,"placement":true,"x":x,"y":y,"barterSerial":serial})
func world_destination(point: Vector2) -> Dictionary:
	if not world_pick.is_valid() or world_blocked.is_valid() and world_blocked.call(point): return {}
	var hit: Dictionary=world_pick.call(point)
	if hit.is_empty(): return {}
	var id:=int(hit.get("id",-1))
	if id>=0: return {"targetId":id} if destination(id) else {}
	var position: Variant=hit.get("position")
	if not position is Vector3 or not position.is_finite(): return {}
	return {"targetId":INVALID,"position":[position.x,-position.z,position.y]}
func _can_drop_data(point: Vector2,data: Variant) -> bool: return valid(data) and not world_destination(get_global_transform()*point).is_empty()
func _drop_data(point: Vector2,data: Variant) -> void:
	if not valid(data): stats.stale+=1; return
	var target:=world_destination(get_global_transform()*point)
	if not target.is_empty(): send(target)
func send(target: Dictionary) -> void:
	var value:={"kind":"inventory-gold","actorId":owner_inventory.controlled_id,"amount":int(payload.amount)}; value.merge(target)
	payload.clear(); hide(); set_process(false); owner_inventory.send_command(value); stats.sent+=1
func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_END and not payload.is_empty(): payload.clear(); hide(); set_process(false); stats.canceled+=1
func cancel() -> void:
	repeat_step=0; repeat_elapsed=0; repeat_initial=true; repeat_button=null
	if is_instance_valid(number): number.release_focus()
	if is_instance_valid(modal): modal.hide()
	if not payload.is_empty(): get_viewport().gui_cancel_drag(); payload.clear()
	hide(); set_process(false)
func _input(event: InputEvent) -> void:
	if closed: return
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and (not payload.is_empty() or is_instance_valid(modal) and modal.visible): cancel(); get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and is_instance_valid(modal) and modal.visible and number.has_focus() and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not Amount.accepts_character(event.unicode): get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if closed: return
	if not context.is_empty() and context!=current_context(): cancel(); context.clear()
	if not owner_inventory.ui.wanted and not from_barter: cancel()
	if repeat_step!=0:
		var held: bool=is_instance_valid(repeat_button) and repeat_button.get_draw_mode() in [BaseButton.DRAW_PRESSED,BaseButton.DRAW_HOVER_PRESSED]
		var next:=Amount.tick(repeat_elapsed,repeat_initial,roundi(delta*1000000.0),held)
		repeat_elapsed=int(next.elapsed); repeat_initial=next.initial
		if next.fired: change(repeat_step)
func blocks_pointer(point: Vector2) -> bool: return is_instance_valid(modal) and modal.visible and modal.get_global_rect().has_point(point)
func snapshot() -> Dictionary: return {"ready":layout_ready,"failure":failure,"dragging":not payload.is_empty(),"amount_dialog":is_instance_valid(modal) and modal.visible,"stats":stats.duplicate()}
func close() -> void:
	if closed: return
	cancel(); closed=true; assets.close(); jobs.clear(); models.clear()
	if is_instance_valid(modal): modal.queue_free()
	queue_free()
