extends Node
const Assets=preload("res://systems/native_data/asset_service.gd")
const Layout=preload("res://systems/native_data/barter_layout.gd")
const View=preload("res://systems/native_barter_view.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const INVALID:=2130706432
var owner_ui
var view
var assets
var jobs: Dictionary={}
var models: Dictionary={}
var gui: Dictionary={}
var definition: Dictionary={}
var objects: Dictionary={}
var state: Dictionary={"open":false}
var own_rows: Dictionary={}
var all_rows: Dictionary={}
var pending: Dictionary={}
var receipts: Dictionary={}
var icon_bindings: Dictionary={}
var epoch:=-1
var area:=-1
var actor:=-1
var signature:=""
var window_serial:=-1
var closed:=false
var layout_ready:=false
var failure:=""
var stats:={"views":0,"commands":0,"stale_input":0,"rejected":0,"native_only":true}
func configure(ui,catalog,cache_path: String,storage: String) -> void:
	owner_ui=ui; view=View.new(); ui.controls.add_child(view); view.setup(self,storage)
	ui.inventory.ui.barter_owner=self; ui.inventory.gold.barter_context=context
	ui.inventory.icons.completed.connect(icon_ready)
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(catalog); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	jobs[assets.request("ingame_barter",2047,"gff")]="gui"
func collect(root: Dictionary) -> void:
	for child in root.get("Obj_ChildList",[]):
		if child.has("Obj_ResRef"): models[str(child.Obj_ResRef).to_lower()]={}
		collect(child)
func prepared(id: int,result: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var key:=str(jobs[id]); jobs.erase(id)
	if not str(result.get("error","")).is_empty(): failure=str(result.error); return
	if key=="gui":
		if str(result.value.get("type",""))!="GUI ": failure="Invalid original barter GUI"; return
		gui=result.value.root; models[str(gui.Obj_ResRef).to_lower()]={}; collect(gui)
		for resource in models: jobs[assets.request(resource,2002,"mdl-original")]=resource
	else: models[key]=result.value
	if not jobs.is_empty() or not failure.is_empty(): return
	definition=Layout.parse(gui,models)
	if not str(definition.error).is_empty(): failure=str(definition.error); return
	view.build(definition,models); layout_ready=true; signature=""; refresh()
func active() -> bool:
	return not closed and bool(state.get("open",false)) and int(state.get("actorId",-1))==actor and int(state.get("areaId",-1))==area
func context() -> Dictionary:
	return {"open":true,"serial":int(state.serial),"targetId":int(state.partnerId),"locked":bool(state.ownLocked)} if active() else {}
func set_world(generation: int,area_id: int,actor_id: int,source: Dictionary,header: Dictionary) -> void:
	if closed: return
	var changed: bool=epoch!=generation or actor!=actor_id or area!=area_id
	if changed:
		state={"open":false}; pending.clear(); receipts.clear(); window_serial=-1; signature=""; view.examine_mode=false
	epoch=generation; area=area_id; actor=actor_id; objects=source
	if int(header.get("serial",0))==int(state.get("serial",0)) and int(header.get("revision",0))<int(state.get("revision",0)): return
	var was_active:=active(); var old_serial:=int(state.get("serial",-1)); state=header.duplicate(true)
	if int(state.get("serial",-1))!=old_serial: pending.clear(); receipts.clear(); signature=""; view.examine_mode=false
	if not active():
		pending.clear(); receipts.clear(); own_rows.clear(); all_rows.clear(); view.wanted=false; view.hide()
		if was_active and not changed and int(state.get("serial",-1))==old_serial: emit_command("window",{"value":false})
		window_serial=-1; return
	for key in receipts.keys():
		if int(state.get("revision",0))>=int(receipts[key]): pending.erase(key); receipts.erase(key)
	for key in pending.keys():
		if not str(key).begins_with("item:"): continue
		var item_id:=int(str(key).substr(5)); var current: Dictionary=objects.get(item_id,{})
		if Cache.digest(var_to_bytes([current.get("item"),current.get("inventoryLocation")]))!=str(pending[key].signature): pending.erase(key)
	refresh()
func refresh() -> void:
	if closed or not layout_ready or not active() or not owner_ui.tables_ready: return
	var rows: Array=[]; var sources: Array=[]; var own: Dictionary={}; var all: Dictionary={}
	var inventory=owner_ui.inventory
	for channel in ["B","A"]:
		for entry in inventory.inventories.get(channel,{}).get("entries",[]):
			var id:=int(entry.id); var object: Dictionary=objects.get(id,{})
			if object.get("replicationRemoved",false) or not object.get("item") is Dictionary: continue
			var item: Dictionary=object.item; var base: Dictionary=inventory.IconPlan.row(owner_ui.text.tables,"baseitems",int(item.get("baseItem",-1)))
			var row:={"entryId":id,"itemId":id,"channel":channel,"x":int(entry.x),"y":int(entry.y),"width":maxi(1,int(inventory.IconPlan.number(base.get("InvSlotWidth")))) ,"height":maxi(1,int(inventory.IconPlan.number(base.get("InvSlotHeight")))),"stack":int(item.get("stackSize",item.get("field454",1))),"name":owner_ui.text.resolve(item.get("name",{}),actor),"pending":pending.has("item:"+str(id))}
			var fingerprint:=Cache.digest(var_to_bytes([item,object.get("inventoryLocation")]))
			row.tooltip=preload("res://systems/native_data/item_tooltip.gd").project(item,owner_ui.text,actor)
			row.signature=fingerprint; rows.append(row); sources.append([channel,entry,item,object.get("inventoryLocation")]); all[id]=row
			if channel=="B": own[id]=row
	var identities: Dictionary={}; var identity_signature: Array=[]
	for id in [actor,int(state.partnerId)]:
		identities[id]=owner_ui.desktop.rules.presentation_object(objects,id,owner_ui.desktop.state.get("players",[]))
		var replicated: Dictionary=identities[id].replicated
		identity_signature.append([replicated.get("name"),replicated.get("portraitRef"),replicated.get("portrait")])
	var next:=Cache.digest(var_to_bytes([epoch,actor,area,state,sources,pending,identity_signature]))
	if signature==next: return
	signature=next; own_rows=own; all_rows=all; view.render(state,rows,pending); stats.views+=1
	view.heading.text=owner_ui.text.resolve({"strRef":0x1ab4},int(state.partnerId),{"nativeB8":1,"context":identities[int(state.partnerId)]})
	for pair in [["playerportrait",actor],["barratorportrait",int(state.partnerId)]]:
		var resource: String=view.frame.art.portrait_resource(owner_ui.desktop.rules.portrait(identities[int(pair[1])],3))
		view.frame.art.bind(view.portraits[pair[0]],str(definition.entries[pair[0]].resource),"texture",true,"",false,{"gui_replace01":resource} if not resource.is_empty() else {})
	icon_bindings.clear()
	for row in rows:
		var key: String=inventory.icons.request(objects[int(row.itemId)].item,owner_ui.text.tables,int(objects.get(actor,{}).get("appearance",{}).get("gender",0)))
		if key.is_empty(): continue
		if not icon_bindings.has(key): icon_bindings[key]=[]
		icon_bindings[key].append(int(row.itemId))
		if inventory.icons.textures.has(key): view.item_buttons[int(row.itemId)].set_icon(inventory.icons.textures[key])
	if window_serial!=int(state.serial):
		window_serial=int(state.serial); view.move_to_front(); emit_command("window",{"value":true})
func icon_ready(key: String,texture: Texture2D,error: String) -> void:
	if closed or not active() or not icon_bindings.has(key): return
	if not error.is_empty(): view.notice.text=error; return
	for id in icon_bindings[key]:
		if view.item_buttons.has(id): view.item_buttons[id].set_icon(texture)
func emit_command(operation: String,extra: Dictionary={}) -> void:
	var value:={"kind":"native-barter","operation":operation,"serial":int(state.get("serial",-1)),"targetId":int(state.get("partnerId",INVALID))}; value.merge(extra,true)
	stats.commands+=1; owner_ui.desktop.command(value)
func command(operation: String,extra: Dictionary={}) -> void:
	if not active() or pending.has("close"): stats.stale_input+=1; return
	if operation=="accept" and (not bool(state.ownLocked) or not bool(state.otherLocked) or pending.has("lock") or pending.has("accept")): stats.stale_input+=1; refresh(); return
	if operation=="lock" and pending.has("lock"): stats.stale_input+=1; refresh(); return
	if operation not in ["accept","lock","close"]: return
	pending[operation]={}; signature=""; emit_command(operation,extra); refresh()
func payload(id: int) -> Dictionary:
	if not active() or bool(state.ownLocked) or not own_rows.has(id) or pending.has("item:"+str(id)): return {}
	return {"kind":"native-barter-item","generation":epoch,"actorId":actor,"serial":int(state.serial),"itemId":id,"signature":own_rows[id].signature}
func can_remove(data: Variant) -> bool:
	return data is Dictionary and active() and not bool(state.ownLocked) and not pending.has("close") and not pending.has("lock") and data.get("kind","")=="native-barter-item" and int(data.get("generation",-1))==epoch and int(data.get("actorId",-1))==actor and int(data.get("serial",-1))==int(state.serial) and own_rows.has(int(data.get("itemId",-1))) and str(data.get("signature",""))==str(own_rows[int(data.itemId)].signature) and not pending.has("item:"+str(int(data.itemId)))
func can_drop(data: Variant,cell: Vector2i) -> bool:
	if not active() or bool(state.ownLocked) or pending.has("close") or pending.has("lock") or not data is Dictionary or cell.x<0 or cell.x>=3 or cell.y<0 or cell.y>=10: return false
	if data.get("kind","")=="native-inventory-gold": return owner_ui.inventory.gold.valid(data)
	var row: Dictionary={}
	if data.get("kind","")=="native-inventory-item":
		row=owner_ui.inventory.valid_item(data)
		if row.get("channel","")!="R": return false
	elif can_remove(data): row=own_rows[int(data.itemId)]
	return not row.is_empty() and cell.x+int(row.width)<=3 and cell.y+int(row.height)<=10
func drop(data: Dictionary,cell: Vector2i) -> void:
	if not can_drop(data,cell): stats.stale_input+=1; return
	if data.get("kind","")=="native-inventory-gold": owner_ui.inventory.gold.drop_barter(data,int(state.partnerId),cell.x,cell.y,int(state.serial)); return
	var id:=int(data.itemId) if data.get("kind","")=="native-barter-item" else int(owner_ui.inventory.views[int(data.entryId)].row.itemId)
	item_command("move" if data.get("kind","")=="native-barter-item" else "add",id,cell.x,cell.y)
func item_command(operation: String,id: int,x: int=255,y: int=255) -> void:
	var object: Dictionary=objects.get(id,{})
	if object.is_empty() or pending.has("item:"+str(id)): return
	pending["item:"+str(id)]={"signature":Cache.digest(var_to_bytes([object.get("item"),object.get("inventoryLocation")]))}; signature=""; emit_command(operation,{"itemId":id,"x":x,"y":y}); refresh()
func remove_to(data: Dictionary,x: int,y: int) -> void:
	if not can_remove(data): stats.stale_input+=1; return
	item_command("remove",int(data.itemId),x,y)
func remove_item(id: int) -> void:
	var data:=payload(id)
	if not data.is_empty(): remove_to(data,255,255)
func examine(id: int) -> void:
	if active() and all_rows.has(id): owner_ui.desktop.command({"kind":"examine","targetId":id})
func item_menu(id: int,point: Vector2) -> void:
	if active() and all_rows.has(id): owner_ui.desktop.barter_item_menu(id,point,own_rows.has(id) and not bool(state.ownLocked))
func receive(message: Dictionary) -> void:
	if closed: return
	if message.kind=="native-action-result" and message.get("action","")=="native-barter" and not message.get("accepted",false):
		pending.clear(); receipts.clear(); view.notice.text=str(message.get("text","Barter request was rejected.")); stats.rejected+=1; signature=""; refresh()
	elif message.kind=="barter-reject" and int(message.get("nativeBarterSerial",-1))==int(state.get("serial",-2)):
		if int(message.operation) in [5,6,13]: pending.erase("item:"+str(int(message.targetId)))
		if int(message.operation) in [7,9]: pending.erase("lock" if int(message.operation)==7 else "accept")
		signature=""; refresh()
	elif message.kind in ["barter-lock","barter-accept"] and active() and int(message.get("nativeBarterSerial",-1))==int(state.serial) and bool(message.initiator)==bool(state.initiator):
		var key: String="lock" if message.kind=="barter-lock" else "accept"; receipts[key]=int(message.get("nativeBarterRevision",0))
		if int(state.get("revision",0))>=int(receipts[key]): pending.erase(key); receipts.erase(key)
		signature=""; refresh()
func blocks_pointer(point: Vector2) -> bool: return view.visible and view.get_global_rect().has_point(point)
func snapshot() -> Dictionary: return {"ready":layout_ready,"failure":failure,"active":active(),"own_items":own_rows.size(),"items":all_rows.size(),"pending":pending.size(),"stats":stats.duplicate(),"full_barter_acceptance":false}
func close() -> void:
	if closed: return
	closed=true; assets.close()
	if owner_ui.inventory.icons.completed.is_connected(icon_ready): owner_ui.inventory.icons.completed.disconnect(icon_ready)
	owner_ui.inventory.ui.barter_owner=null; owner_ui.inventory.gold.barter_context=Callable(); view.queue_free(); jobs.clear(); models.clear(); objects={}; pending.clear(); all_rows.clear(); own_rows.clear()
func _exit_tree() -> void: close()
