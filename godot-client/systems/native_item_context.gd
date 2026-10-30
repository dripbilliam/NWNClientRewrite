extends Node
# Native item-wheel presentation. Every selection revalidates its original
# repository or trade lifetime before dispatch; received items are never edited.
signal opened
signal ability_selected(binding: Dictionary)
const Radial=preload("res://systems/server_radial.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Policy=preload("res://systems/native_data/item_radial.gd")
var inventory
var wheel
var policy:=Policy.new()
var rules:=Rules.new()
var spell_entries: Callable
var selection: Dictionary={}
var trade
var lifetime: Array=[]
var history: Array=[]
var entries: Dictionary={}
var serial:=0
var trade_lock: Array=[]
var closed:=false
func configure(owner) -> void:
	inventory=owner; rules.text=owner.text_owner; policy.rules=rules
	wheel=Radial.new(); add_child(wheel); wheel.shortcut_kind="item-radial-entry"; wheel.configure_art(inventory.frame_skin.art); wheel.request.connect(input)
func cancel() -> void:
	if is_instance_valid(wheel): wheel.reset()
	selection.clear(); lifetime.clear(); history.clear(); entries.clear(); trade=null; trade_lock.clear()
func item() -> Dictionary: return inventory.objects.get(int(selection.get("entryId",-1)),{}).get("item",{})
func current_row() -> Dictionary:
	if closed or selection.is_empty() or lifetime!=[inventory.generation,inventory.area_id,inventory.controlled_id]: return {}
	if is_instance_valid(trade):
		var id:=int(selection.entryId); var value: Dictionary=trade.all_rows.get(id,{})
		if not trade.active() or int(trade.state.serial)!=int(selection.serial) or value.get("signature")!=selection.get("signature"): return {}
		return value
	if inventory.store.get("generation",-1)!=selection.get("storeGeneration",-1): return {}
	return inventory.valid_item(selection)
func open_inventory(id: int,point: Vector2,powers_only: bool=false) -> void:
	cancel()
	selection={"entryId":id,"viewId":inventory.view_serial,"storeGeneration":inventory.store.get("generation",-1)}; lifetime=[inventory.generation,inventory.area_id,inventory.controlled_id]
	if current_row().is_empty(): cancel(); return
	inventory.ui.select_item(id); opened.emit(); wheel.open_at(point,id,Vector3.ZERO,false)
	history=[{"kind":"powers" if powers_only else "root"}]; refresh()
func open_trade(owner,id: int,point: Vector2) -> void:
	cancel()
	if not owner.active() or not owner.all_rows.has(id): return
	trade=owner; selection={"entryId":id,"serial":int(owner.state.serial),"signature":owner.all_rows[id].signature}; lifetime=[inventory.generation,inventory.area_id,inventory.controlled_id]
	opened.emit(); wheel.open_at(point,id,Vector3.ZERO,false); history=[{"kind":"root"}]; refresh()
func context(row: Dictionary) -> Dictionary:
	var source: Dictionary=inventory.objects.get(int(row.itemId),{}); var location: Dictionary=source.get("inventoryLocation",{}); var base:=rules.row("baseitems",int(item().get("baseItem",-1)))
	var actor: Dictionary=inventory.objects.get(inventory.controlled_id,{})
	var learning:=false
	for cls in actor.get("replicated",{}).get("stats",{}).get("classes",[]):
		if Rules.number(Rules.cell(rules.row("classes",int(cls.id)),"LearnScroll"),0)!=0: learning=true
	var container_id:=int(inventory.containers.get("C",2130706432)); var container: Dictionary=inventory.objects.get(container_id,{})
	var container_owned: bool=int(container.get("inventoryLocation",{}).get("ownerId",-1))==inventory.controlled_id
	var first_ring:=128 if int(row.get("slotMask",0))&128 else 256; var filled:=false
	for equipped in inventory.inventories.get("I",{}).get("entries",[]):
		if int(equipped.get("slot",0))==first_ring: filled=true
	return {"channel":row.channel,"owned":int(location.get("ownerId",-1))==inventory.controlled_id,"slots":int(row.get("slotMask",Rules.number(Rules.cell(base,"EquipableSlots"),0))),"stack":int(row.get("stack",1)),"store":inventory.store.get("open",false),"container":Rules.number(Rules.cell(base,"Container"),0)!=0,"container_open":container_id==int(row.itemId),"container_owned":container_owned,"learning":learning,"ring_filled":filled,"pending":row.get("pending",false)}
func refresh() -> void:
	var row:=current_row()
	if row.is_empty() or history.is_empty(): cancel(); return
	var page: Dictionary=history[-1]; var values: Array=[]; var source:=item(); var ctx:=context(row)
	match str(page.kind):
		"root":
			if is_instance_valid(trade):
				values=[policy.row(0,"IR_EXAMINE",549,"examine")]
				if trade.own_rows.has(int(row.itemId)):
					var value:=policy.row(2,"IR_PICKUP",555,"barter-remove"); value.label="Remove offer"; value.disabled=not trade.can_remove(trade.payload(int(row.itemId))); values.append(value)
				trade_lock=[trade.state.get("ownLocked"),trade.pending.keys()]
			else: values=policy.root(source,ctx)
		"powers": values=policy.powers(source,false,bool(ctx.learning))
		"more": values=policy.page(source,int(page.start))
		"variants": values=policy.variants(source,int(page.index))
		"spells": values=spell_entries.call() if spell_entries.is_valid() else []
		"children": values=page.values
	if values.size()>8:
		var rest:=values.slice(7); values=values.slice(0,7)
		var more:=policy.row(7,"IR_USE",554,"children"); more.children=rest; values.append(more)
	entries.clear(); serial+=1
	for value in values:
		if value.has("children"): value.action="children"
		if value.action=="use": value.binding={"type":1,"itemId":int(row.itemId),"intParam":int(value.payload),"spellId":int(value.get("spellId",-1))}; value.canDrag=true
		value.submenu=value.action in ["more","variants","spells","children"]
		entries[int(value.slot)]=value
	wheel.receive({"kind":"action-menu","requestId":wheel.request_id,"menuId":serial,"depth":history.size()-1,"title":str(row.name),"entries":values})
	wheel.set_center("ir_use")
	var texture: Texture2D=inventory.ui.textures.get(int(row.entryId))
	if is_instance_valid(trade) and trade.view.item_buttons.has(int(row.itemId)): texture=trade.view.item_buttons[int(row.itemId)].image.texture
	if texture!=null:
		inventory.frame_skin.art.bind(wheel.center_image,""); wheel.center_image.texture=texture; wheel.center_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	for slot in entries: inventory.frame_skin.art.bind(wheel.icons[int(slot)],str(entries[slot].icon))
func can_shortcut(data: Dictionary) -> bool:
	return data.get("kind","")=="item-radial-entry" and not current_row().is_empty() and wheel.can_shortcut(data) and entries.has(int(data.get("slot",-1))) and entries[int(data.slot)].has("binding")
func binding(data: Dictionary) -> Dictionary:
	return entries[int(data.slot)].binding.duplicate(true) if can_shortcut(data) else {}
func input(message: Dictionary) -> void:
	if closed: return
	if message.kind=="radial-cancel": cancel(); return
	if int(message.get("requestId",-1))!=wheel.request_id or int(message.get("menuId",-1))!=wheel.menu_id: return
	if current_row().is_empty(): cancel(); return
	if message.kind=="radial-back":
		if history.size()>1: history.pop_back(); refresh()
		else: cancel()
		return
	if message.kind!="radial-select" or not entries.has(int(message.get("slot",-1))): return
	var value: Dictionary=entries[int(message.slot)]
	if value.get("disabled",false): refresh(); return
	match str(value.action):
		"more": history.append({"kind":"more","start":int(value.payload)}); refresh(); return
		"variants": history.append({"kind":"variants","index":int(value.index)}); refresh(); return
		"spells": history.append({"kind":"spells"}); refresh(); return
		"children": history.append({"kind":"children","values":value.children}); refresh(); return
		"power":
			# Spell-on-item submenu from the native desktop, with its active rules.
			ability_selected.emit(value.binding.merged({"itemTarget":int(selection.entryId)})); cancel(); return
		"use": ability_selected.emit(value.binding.duplicate(true)); cancel(); return
		"barter-remove":
			if is_instance_valid(trade): trade.remove_item(int(selection.entryId))
		"examine":
			if is_instance_valid(trade): trade.examine(int(selection.entryId))
			else: inventory.input_request({"kind":"inventory-action","viewId":selection.viewId,"entryId":selection.entryId,"operation":"examine"})
		"buy","sell": inventory.store_command({"viewId":selection.viewId,"entryId":selection.entryId,"operation":value.action})
		"split": inventory.stack_dialog.open_item(selection)
		_:
			var request:={"kind":"inventory-action","viewId":selection.get("viewId",-1),"entryId":selection.entryId,"operation":value.action}
			if value.action=="equip": request.slot=int(value.payload)
			inventory.input_request(request)
	cancel()
func _process(_delta: float) -> void:
	if closed or not is_instance_valid(wheel) or not wheel.active: return
	if current_row().is_empty(): cancel(); return
	if is_instance_valid(trade) and trade_lock!=[trade.state.get("ownLocked"),trade.pending.keys()]: refresh()
func blocks_pointer(point: Vector2) -> bool: return is_instance_valid(wheel) and wheel.blocks_pointer(point)
func snapshot() -> Dictionary: return {"native_only":true,"active":is_instance_valid(wheel) and wheel.active,"depth":history.size(),"entries":entries.size(),"warnings":policy.warnings.duplicate(),"full_item_parity":false}
func close() -> void:
	if closed: return
	closed=true; cancel(); inventory=null
