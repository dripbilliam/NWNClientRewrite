extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Native presentation of raw server inventory state. Sending an item request
# never moves an item locally; snapshots/result packets remain authoritative.
signal request(message: Dictionary)
signal ability_requested(item_id: int)
const Inventory=preload("res://systems/server_inventory.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const IconPlan=preload("res://systems/native_data/item_icon.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Tooltip=preload("res://systems/native_data/item_tooltip.gd")
const INVALID:=2130706432
const EQUIPMENT=[
	[16,0,0,80,240,"Right hand"],[2,80,0,100,160,"Chest"],[32,180,0,80,160,"Left hand"],[1,260,0,80,80,"Head"],[512,260,80,80,80,"Neck"],[64,340,0,80,160,"Cloak"],
	[8,180,160,80,80,"Arms"],[128,260,160,40,40,"Right ring"],[256,260,200,40,40,"Left ring"],[1024,300,160,40,80,"Belt"],[4,340,160,80,80,"Boots"],
	[2048,80,160,100.0/3,80,"Arrows"],[4096,80+100.0/3,160,100.0/3,80,"Bullets"],[8192,80+200.0/3,160,100.0/3,80,"Bolts"]]
var ui
var icons
var equipment_skin
var frame_skin
var store_skin
var examine_owner
var gold
var stack_dialog
var item_context
var item_tooltips
var text_owner
var objects: Dictionary={}
var inventories: Dictionary={}
var containers: Dictionary={}
var store: Dictionary={}
var generation:=-1
var area_id:=-1
var controlled_id:=-1
var display_owner_id:=-1
var window_role:="primary"
var window_serial:=0
var window_receipt:=0
var page:=0
var container_page:=0
var container_serial:=0
var view_serial:=0
var request_serial:=0
var views: Dictionary={}
var pending: Dictionary={}
var signature:=""
var icon_bindings: Dictionary={}
var closed:=false
var notice_text:=""
var detailed_timings:=false
var timing_rows: Array=[]
var data_received_us:=0
var data_received_wall_ms:=0.0
var stats:={"views":0,"commands":0,"icons_bound":0,"rejected_results":0,"stale_input":0,"errors":[],"native_only":true}
func configure(parent: Control,catalog,cache_path: String,text,layout_storage: String="user://native-menu-layout.cfg",role: String="primary") -> void:
	window_role=role; text_owner=text; ui=Inventory.new(); parent.add_child(ui); ui.item_commands_enabled=role=="primary";ui.setup(layout_storage,"inventory" if role=="primary" else "associate-inventory"); ui.request.connect(input_request)
	equipment_skin=preload("res://systems/native_inventory_equipment.gd").new(); add_child(equipment_skin); ui.native_equipment=equipment_skin; equipment_skin.configure(ui,catalog,cache_path)
	frame_skin=preload("res://systems/native_inventory_frame.gd").new(); add_child(frame_skin); ui.native_frame=frame_skin; frame_skin.configure(ui,catalog,cache_path,text,equipment_skin)
	item_tooltips=frame_skin.tooltips; item_tooltips.prepare(); ui.item_tooltips=item_tooltips
	store_skin=preload("res://systems/native_store_frame.gd").new(); add_child(store_skin); store_skin.configure(self,catalog,cache_path)
	gold=preload("res://systems/native_gold_transfer.gd").new(); gold.configure(self,parent,catalog,cache_path); ui.gold_owner=gold
	if role=="alternate":ui.gold_owner=null
	stack_dialog=preload("res://systems/native_item_stack.gd").new(); stack_dialog.configure(self,parent,catalog,cache_path)
	item_context=preload("res://systems/native_item_context.gd").new(); add_child(item_context); item_context.configure(self)
	ui.menu_requested.connect(func(id,point): item_menu(id,point))
	icons=Icons.new(); add_child(icons); icons.configure(catalog,cache_path); icons.completed.connect(icon_ready)
func displayed_owner() -> int:return controlled_id if display_owner_id<0 else display_owner_id
func set_displayed_owner(id: int,serial: int,receipt: int) -> void:
	window_serial=serial;window_receipt=receipt
	if display_owner_id==id:return
	var was_wanted: bool=ui.wanted
	display_owner_id=id;signature="";views.clear();pending.clear();icon_bindings.clear();page=0;container_page=0
	item_context.cancel();stack_dialog.cancel();gold.cancel();ui.reset()
	if was_wanted:ui.present_received(true)
func set_world(epoch: int,area: int,controlled: int,source: Array,raw: Dictionary) -> void:
	if generation!=epoch or controlled_id!=controlled:
		gold.cancel()
		ui.reset(); item_context.cancel(); stack_dialog.cancel(); signature=""; views.clear(); pending.clear(); icon_bindings.clear(); page=0; container_page=0; notice_text=""
	generation=epoch; area_id=area; controlled_id=controlled; objects={}
	for object in source: objects[int(object.id)]=object
	update_inventory(raw)
func update_world(epoch: int,area: int,controlled: int,source: Array,removed: Array,raw: Dictionary) -> void:
	if generation!=epoch or area_id!=area: return
	if controlled_id!=controlled:
		ui.reset(); item_context.cancel(); stack_dialog.cancel(); signature=""; views.clear(); pending.clear(); icon_bindings.clear(); page=0; container_page=0; notice_text=""
	controlled_id=controlled
	for id in removed: objects.erase(int(id))
	for object in source: objects[int(object.id)]=object
	update_inventory(raw)
func update_inventory(raw: Dictionary) -> void:
	if detailed_timings:data_received_us=Time.get_ticks_usec();data_received_wall_ms=Time.get_unix_time_from_system()*1000.0
	var old_container:=int(containers.get("C",INVALID)); inventories={}; containers={}; store=raw.get("store",{}) if raw.get("store") is Dictionary else {}
	for row in raw.get("inventories",[]):
		var channel:=str(row[0])
		if window_role=="primary" and channel in ["I","R","C","M"]:inventories[channel]=row[1]
		elif window_role=="alternate" and channel in ["i","r","c"]:inventories[channel.to_upper()]=row[1]
	for row in raw.get("containers",[]):
		if str(row[0])==("C" if window_role=="primary" else "c"):containers["C"]=int(row[1])
	if window_role=="alternate":store={}
	if store.get("open",false) and int(store.get("generation",-1))>ui.blocked_store_generation and not ui.wanted: ui.open()
	if int(containers.get("C",INVALID))!=old_container:
		container_serial+=1; container_page=0
		if window_role=="primary" and int(containers.get("C",INVALID))!=INVALID and not ui.wanted: ui.open()
func rules_ready() -> bool:
	return text_owner!=null and text_owner.tables.has("baseitems") and text_owner.tables.has("encumbrance")
func store_price(item: Dictionary,buy: bool) -> int:
	if not store.get("open",false) or not item.has("cost"): return -1
	var cost:=int(item.cost)&4294967295
	var rate:=int(store.get("sellRate",0)) if buy else int(store.get("blackMarketRate",0) if item.get("field458",false) else store.get("buyRate",0))
	var value:=maxi(1,int(float(cost)*rate/100.0)) if cost!=0 else 0
	if not buy and int(store.get("maxBuyPrice",-1))!=-1: value=mini(value,int(store.maxBuyPrice))
	return value
func store_view() -> Dictionary:
	if not store.get("open",false): return {}
	var result:=store.duplicate(true); result.pageCount=int(inventories.get("M",{}).get("pageCount",1)); result.page=int(store.get("page",0)); result.labels=[]
	for index in 5: result.labels.append(text_owner.raw({"strRef":0xf85c+index}))
	return result
func store_command(message: Dictionary) -> void:
	if int(message.get("viewId",-1))!=view_serial or not store.get("open",false): return
	var operation:=str(message.operation); var value:={"kind":"native-store","operation":operation,"storeGeneration":int(store.generation)}
	if operation in ["buy","sell","identify"]:
		var row:=valid_item(message)
		if row.is_empty() or row.pending or pending.has(int(row.itemId)) or int(row.get("price",-1))<0: return
		value.itemId=int(row.itemId)
		pending[value.itemId]={"at":Time.get_ticks_msec(),"operation":"store-"+operation}; signature=""
	elif operation=="page": value.page=int(message.page)
	elif operation=="panel": value.panel=int(message.panel)
	elif operation!="close": return
	send_command(value)
func summary(actor: Dictionary) -> Dictionary:
	var combat: Dictionary=actor.get("playerState",{}).get("combat",{}); var state: Dictionary=actor.get("inventoryStats",{})
	var weight: Variant=state.get("field28c",combat.get("field978")); var abilities: Array=actor.get("playerState",{}).get("abilities",{}).get("current",[])
	var strength: Variant=state.get("field70",state.get("fields70",[null])[0] if not state.get("fields70",[]).is_empty() else (abilities[0] if not abilities.is_empty() else null))
	var capacity: Variant=IconPlan.row(text_owner.tables,"encumbrance",int(strength) if strength!=null else -1).get("Normal")
	return {"gold":combat.get("field898"),"weight":floorf(Vector3(float(weight)/10,0,0).x+0.5) if weight!=null else null,"capacity":int(Vector3(float(capacity)/10,0,0).x+0.5) if capacity!=null and str(capacity).is_valid_float() else null}
func layout() -> Array:
	var result: Array=[]
	for row in EQUIPMENT: result.append({"slot":row[0],"x":row[1],"y":row[2],"w":row[3],"h":row[4],"label":row[5]})
	for index in 4: result.append({"slot":1<<(14+index),"x":index*105,"y":240,"w":105,"h":80,"label":"Creature equipment"})
	return result
func _process(_delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(_delta)
	Timing.finish("callback_inventory",began)
func _profile_process(_delta: float) -> void:
	if closed or not ui.wanted or not rules_ready() or not objects.has(controlled_id): return
	for id in pending.keys():
		if pending[id].operation=="split":
			var item: Dictionary=objects.get(id,{}).get("item",{})
			if objects.get(id,{}).get("replicationRemoved",false) or int(item.get("stackSize",item.get("field454",0)))!=int(pending[id].previous_stack): pending.erase(id); signature=""; continue
		if pending[id].operation=="equip-pickup":
			var location: Dictionary=objects.get(id,{}).get("inventoryLocation",{})
			if location.get("channel","")=="R" and int(location.get("ownerId",-1))==controlled_id:
				pending[id].operation="equip"; pending[id].at=Time.get_ticks_msec(); send_command({"kind":"item-action","itemId":id,"operation":"equip","slot":int(pending[id].slot)})
		if Time.get_ticks_msec()-int(pending[id].at)>6000: pending.erase(id); signature=""; notice_text="The server has not confirmed that item action."
	refresh()
func refresh() -> void:
	if closed or not ui.wanted or not rules_ready() or not objects.has(displayed_owner()): return
	var refresh_started:=Time.get_ticks_usec() if detailed_timings else 0
	var actor: Dictionary=objects[displayed_owner()]; var rows: Array=[]; var sources: Array=[]
	for channel in ["I","R","C","M"]:
		for location in inventories.get(channel,{}).get("entries",[]):
			var id:=int(location.id); var object: Dictionary=objects.get(id,{})
			if object.get("replicationRemoved",false) or not object.get("item") is Dictionary: continue
			var item: Dictionary=object.item; var base:=IconPlan.row(text_owner.tables,"baseitems",int(item.get("baseItem",-1)))
			if base.is_empty(): continue
			sources.append([channel,location,item,object.get("inventoryLocation")])
			rows.append({"entryId":id,"itemId":id,"channel":channel,"slot":int(location.get("slot",0)),"x":int(location.get("x",0)),"y":int(location.get("y",0)),"width":IconPlan.number(base.get("InvSlotWidth"))&255,"height":IconPlan.number(base.get("InvSlotHeight"))&255,"slotMask":IconPlan.number(base.get("EquipableSlots"))&4294967295,"stack":item.get("stackSize",item.get("field454",1)),"name":text_owner.resolve(item.get("name",{}),controlled_id),"tooltip":Tooltip.project(item,text_owner,controlled_id),"pending":pending.has(id),"price":store_price(item,channel=="M"),"canIdentify":not item.get("identified",true)})
	var next:=Cache.digest(var_to_bytes([generation,controlled_id,displayed_owner(),page,container_page,container_serial,sources,actor.get("inventoryStats",{}),actor.get("playerState",{}).get("combat",{}),actor.get("playerState",{}).get("abilities",{}),pending.keys(),store]))
	if next==signature: return
	signature=next; view_serial+=1; views.clear()
	for row in rows: views[int(row.entryId)]={"object":objects[int(row.itemId)].duplicate(true),"row":row.duplicate(true)}
	var container_id:=int(containers.get("C",INVALID)); var container: Dictionary=objects.get(container_id,{})
	ui.receive({"kind":"inventory-view","viewId":view_serial,"title":text_owner.name(actor.get("replicated",{}).get("name",actor.get("appearance",{}).get("name")),displayed_owner()),"page":page,"items":rows,"store":store_view(),"layout":layout(),"summary":summary(actor),"armorClass":actor.get("playerState",{}).get("combat",{}).get("armorClass",actor.get("inventoryStats",{}).get("field8c")),"container":{"ownerId":container_id,"serial":container_serial,"title":text_owner.resolve(container.get("item",{}).get("name",container.get("replicated",{}).get("name",{})),controlled_id),"page":container_page,"pageCount":inventories.get("C",{}).get("pageCount",1)}})
	if detailed_timings and timing_rows.size()<128:
		var committed:=Time.get_ticks_usec()
		timing_rows.append({"phase":"native-row-controls-committed","mono_us":committed,"wall_ms":Time.get_unix_time_from_system()*1000.0,"data_received_us":data_received_us,"data_received_wall_ms":data_received_wall_ms,"data_to_controls_us":committed-data_received_us if data_received_us>0 else null,"refresh_us":committed-refresh_started,"role":window_role,"owner":displayed_owner(),"page":page,"view":view_serial,"wanted":ui.wanted,"visible":ui.is_visible_in_tree(),"frame_ready":frame_skin.layout_ready,"rows":rows.map(func(row):return {"id":row.itemId,"channel":row.channel,"slot":row.slot,"y":row.y}),"pixels_measured":false})
	stats.views+=1; icon_bindings.clear()
	if not notice_text.is_empty(): ui.notice.text=notice_text
	for row in rows:
		if row.channel=="R" and floori(float(row.y)/6)!=page or row.channel=="C" and floori(float(row.y)/5)!=container_page: continue
		var key: String=icons.request(objects[int(row.itemId)].item,text_owner.tables,int(actor.get("appearance",{}).get("gender",0)))
		if key.is_empty(): continue
		if not icon_bindings.has(key): icon_bindings[key]=[]
		icon_bindings[key].append({"view":view_serial,"entry":int(row.entryId)})
		if icons.textures.has(key): ui.install_native_icon(view_serial,int(row.entryId),icons.textures[key]); stats.icons_bound+=1
func icon_ready(key: String,texture: Texture2D,error: String) -> void:
	if closed: return
	if not error.is_empty(): notice_text="Item icon unavailable: "+error; ui.notice.text=notice_text; return
	for row in icon_bindings.get(key,[]):
		if ui.install_native_icon(int(row.view),int(row.entry),texture): stats.icons_bound+=1
func send_command(value: Dictionary) -> void:
	if window_role=="alternate":
		if value.get("kind","") not in ["inventory-open","inventory-close","inventory-page"]:stats["unported_alternate_commands"]=int(stats.get("unported_alternate_commands",0))+1;return
		value.merge({"inventoryRole":"alternate","ownerId":displayed_owner(),"windowSerial":window_serial,"inventoryReceipt":window_receipt},true)
	request_serial+=1; value.requestId=request_serial; stats.commands+=1; request.emit(value)
func valid_item(message: Dictionary) -> Dictionary:
	var id:=int(message.get("entryId",-1))
	if not ui.wanted or int(message.get("viewId",-1))!=view_serial or not views.has(id) or not objects.has(id): stats.stale_input+=1; return {}
	var previous: Dictionary=views[id].object; var current: Dictionary=objects[id]
	if current.get("replicationRemoved",false) or previous.get("item")!=current.get("item") or previous.get("inventoryLocation")!=current.get("inventoryLocation"): stats.stale_input+=1; return {}
	return views[id].row
func input_request(message: Dictionary) -> void:
	if closed or controlled_id<0: return
	if window_role=="alternate" and str(message.kind) not in ["inventory-open","inventory-close","inventory-page"]:
		stats["unported_alternate_commands"]=int(stats.get("unported_alternate_commands",0))+1;return
	match str(message.kind):
		"inventory-open": signature=""; send_command({"kind":"inventory-open","page":page})
		"inventory-close":
			gold.cancel()
			if store.get("open",false): send_command({"kind":"native-store","operation":"close","storeGeneration":int(store.generation)})
			item_context.cancel(); stack_dialog.cancel(); views.clear(); pending.clear(); icon_bindings.clear(); send_command({"kind":"inventory-close"})
		"inventory-page":
			if int(message.viewId)!=view_serial or int(message.page)<0 or int(message.page)>5: stats.stale_input+=1; return
			page=int(message.page); signature=""; send_command({"kind":"inventory-page","page":page})
		"inventory-container":
			if int(message.viewId)!=view_serial or str(message.operation) not in ["close","previous","next"]: stats.stale_input+=1; return
			var count:=maxi(1,int(inventories.get("C",{}).get("pageCount",1))); container_page=(container_page+(1 if message.operation=="next" else count-1))%count; signature=""
			send_command({"kind":"inventory-container","operation":message.operation,"targetId":int(containers.get("C",INVALID))})
		"inventory-action","inventory-activate": item_action(message)
		"inventory-store": store_command(message)
func item_action(message: Dictionary) -> void:
	var row:=valid_item(message)
	if row.is_empty(): ui.notice.text="That inventory selection is stale."; return
	var id:=int(row.itemId); var operation:=str(message.get("operation","activate"))
	notice_text=""
	if operation=="power": ability_requested.emit(id); return
	if operation=="examine": send_command({"kind":"examine","targetId":id}); return
	if pending.has(id): return
	if operation=="open": send_command({"kind":"item-use","itemId":id}); return
	if operation in ["split","learn"]:
		var parent_owned: bool=int(objects.get(int(containers.get("C",INVALID)),{}).get("inventoryLocation",{}).get("ownerId",-1))==controlled_id
		if row.channel not in ["R","I"] and not (operation=="split" and row.channel=="C" and parent_owned) or operation=="split" and (int(message.get("amount",0))<=0 or int(message.amount)>mini(65535,int(row.stack))): return
		pending[id]={"at":Time.get_ticks_msec(),"operation":operation,"previous_stack":int(row.stack)}; signature=""
		var request:={"kind":"item-action","itemId":id,"operation":operation}
		if operation=="split": request.amount=int(message.amount)
		send_command(request); return
	if operation=="pickup" and row.channel=="C": operation="move"; message.destination="backpack"
	if operation=="activate":
		var base:=IconPlan.row(text_owner.tables,"baseitems",int(objects[id].item.baseItem))
		if row.channel=="C": operation="move"; message.destination="backpack"
		elif IconPlan.number(base.get("Container"))!=0: send_command({"kind":"item-use","itemId":id}); return
		elif int(row.slotMask)!=0: operation="toggle"
		else: ability_requested.emit(id); return
	if operation not in ["equip","unequip","toggle","move","drop"]: return
	var value:={"kind":"item-action","itemId":id,"operation":operation}
	if operation=="equip":
		var slot:=int(message.get("slot",0))
		if slot<=0 or slot&(slot-1) or (int(row.slotMask)&slot)==0: ui.notice.text="That slot does not accept this item."; return
		value.slot=slot
		if row.channel=="C":
			pending[id]={"at":Time.get_ticks_msec(),"operation":"equip-pickup","slot":slot}; signature=""; send_command({"kind":"item-action","itemId":id,"operation":"pickup"}); return
	if message.has("destination"):
		if str(message.destination) not in ["container","backpack"]: return
		value.destinationId=int(containers.get("C",INVALID)) if message.destination=="container" else controlled_id
		if value.destinationId==INVALID: return
	for field in ["x","y"]:
		if message.has(field): value[field]=int(message[field])
	pending[id]={"at":Time.get_ticks_msec(),"operation":operation}; signature=""; send_command(value)
func item_menu(id: int,point: Vector2) -> void:
	item_context.open_inventory(id,point)
func blocks_pointer(point: Vector2) -> bool:
	return gold.blocks_pointer(point) or stack_dialog.blocks_pointer(point) or item_context.blocks_pointer(point) or ui.blocks_pointer(point)
func receive(message: Dictionary) -> void:
	if message.kind=="inventory-ack" and message.get("operation","")=="learn":
		if not bool(message.get("alternate",false)):
			if pending.get(int(message.itemId),{}).get("operation","")=="learn": pending.erase(int(message.itemId)); signature=""
			stats.learn_acks=int(stats.get("learn_acks",0))+1
		return
	if message.kind=="examine" and message.get("type","")=="item":
		var id:=int(message.get("targetId",-1))
		if pending.get(id,{}).get("operation","")=="store-identify": pending.erase(id); signature=""
	if message.kind=="store-transaction": pending.erase(int(message.itemId)); signature=""; return
	if message.kind=="store-close" or message.kind=="native-action-result" and message.get("action","")=="native-store" and not message.get("accepted",false):
		for id in pending.keys():
			if str(pending[id].operation).begins_with("store-"): pending.erase(id)
		signature=""; return
	if message.kind=="inventory-result" and not bool(message.get("alternate",false)):
		if pending.get(int(message.itemId),{}).get("operation","")=="equip-pickup" and bool(message.success): return
		pending.erase(int(message.itemId)); signature=""
		if not bool(message.success): stats.rejected_results+=1; notice_text="The server rejected that item action."; ui.notice.text=notice_text
	elif message.kind=="inventory-command-result" and not bool(message.accepted):
		pending.clear(); signature=""; notice_text=str(message.get("reason","Inventory request was rejected.")); ui.notice.text=notice_text; stats.rejected_results+=1
func snapshot() -> Dictionary:
	stats.item_context=item_context.snapshot(); stats.stack_dialog=stack_dialog.snapshot()
	if detailed_timings:stats.timings=timing_rows.duplicate(true)
	var state:=stats.duplicate(true); state.merge({"wanted":ui.wanted,"view":view_serial,"items":views.size(),"pending":pending.size(),"icons":icons.snapshot(),"equipment_skin":equipment_skin.snapshot(),"frame_skin":frame_skin.snapshot(),"store_skin":store_skin.snapshot(),"gold":gold.snapshot(),"scope":"Native inventory/equipment/container presentation and server-owned item requests. Store presentation and item powers route through the native gameplay desktop; full UI migration remains incomplete."}); return state
func close() -> void:
	if closed: return
	closed=true; item_tooltips.close(); item_context.close(); stack_dialog.close(); store_skin.close(); gold.close(); icons.close(); frame_skin.close(); equipment_skin.close(); ui.reset(); objects.clear(); inventories.clear(); containers.clear(); views.clear(); pending.clear(); icon_bindings.clear()
func _exit_tree() -> void: close()
