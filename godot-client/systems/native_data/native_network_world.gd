extends RefCounted
# Godot-owned received world state. Server object IDs stay in the client wire
# namespace. Every update packet is applied to a detached copy and committed
# only after its records are accepted.
const INVALID:=0x7f000000
const EXTERNAL:=0x80000000
const SkillAdmission=preload("res://systems/native_data/skill_admission.gd")
const DM_PERMISSION_SOURCE:="received_game_master_permission_31_22"
const CLIENT_PERMISSION_SOURCE:="native_connection_start_16"
var module: Dictionary={}
var area: Dictionary={}
var entry: Dictionary={}
var time: Dictionary={}
var area_id:=INVALID
var local_object_id:=INVALID
var game_master_permission: Variant=null
var registry: Dictionary={}
var players: Dictionary={}
var controls: Dictionary={}
var player_roster_known:=false
var inventories: Dictionary={}
var containers: Dictionary={}
var store: Variant=null
var barter: Variant=null
var inventory_windows: Dictionary={}
var rejected_inventory_window: Variant=null
var inventory_window_serial:=0
var inventory_receipt_serial:=0
var quickbar: Array=[]
var spell_targeting_overrides: Dictionary={}
var tlk_overrides: Dictionary={}
var tlk_override_version:=0
var script_targeting: Variant=null
var script_targeting_data: Variant=null
var script_target_version:=0
var journal: Dictionary={"entries":{},"worldEntries":{},"loaded":false}
var map_pins: Dictionary={}
var player_attitudes: Dictionary={}
var timing: Variant=null
var party: Array[Dictionary]=[]
var party_list_revision:=0
var party_invite_notice: Variant=null
var error: String=""
var next_object_lifetime:=0

func _init()->void:
	for _index in range(36):quickbar.append({"type":0,"intParam":0})
	reset_inventory_windows()

func empty_inventory_window(role: String)->Dictionary:
	return {"role":role,"ownerId":INVALID,"actorId":INVALID,"areaId":INVALID,"open":false,"serial":0,"receiptSerial":0,"rawOwnerId":INVALID,"receivedOpen":false,"source":"uninitialized"}

func reset_inventory_windows()->void:
	inventory_windows={"primary":empty_inventory_window("primary"),"alternate":empty_inventory_window("alternate")}
	rejected_inventory_window=null
	inventory_window_serial+=1

func inventory_window_snapshot()->Dictionary:
	return {"primary":inventory_windows.primary.duplicate(true),"alternate":inventory_windows.alternate.duplicate(true),"rejected":rejected_inventory_window.duplicate(true) if rejected_inventory_window is Dictionary else null}

func observe_inventory_window(message: Dictionary)->bool:
	if not message.get("open") is bool or not message.get("ownerId") is int or int(message.ownerId)<0 or int(message.ownerId)>0xffffffff:error="Invalid native inventory-window status";return false
	var raw:=int(message.ownerId)
	var role: String="primary" if raw==INVALID or raw==local_object_id else "alternate"
	var previous: Dictionary=inventory_windows[role]
	inventory_receipt_serial+=1
	var receipt:=inventory_receipt_serial
	if role=="alternate":
		var creature: Dictionary=registry.get(raw,{})
		if int(creature.get("objectType",0))!=5 or bool(creature.get("replicationRemoved",false)):
			rejected_inventory_window={"ownerId":raw,"open":message.open,"receiptSerial":receipt,"actorId":local_object_id,"areaId":area_id}
			return true
	rejected_inventory_window=null
	var duplicate: bool=bool(previous.open) and int(previous.ownerId)==raw if message.open else not bool(previous.open)
	var owner: int=(local_object_id if raw==INVALID else raw) if message.open else int(previous.ownerId)
	var serial:=int(previous.serial)
	if not duplicate:
		inventory_window_serial+=1
		serial=inventory_window_serial
	inventory_windows[role]={"role":role,"ownerId":owner,"actorId":local_object_id,"areaId":area_id,"open":message.open,"serial":serial,"receiptSerial":receipt,"rawOwnerId":raw,"receivedOpen":message.open,"source":"server13/1"}
	if role=="alternate" and message.open:bind_alternate_inventory(owner,int(previous.ownerId)!=owner and int(previous.ownerId)!=INVALID)
	return true

func bind_alternate_inventory(owner: int,replace: bool)->void:
	var creature: Dictionary=registry.get(owner,{})
	if int(creature.get("objectType",0))!=5 or bool(creature.get("replicationRemoved",false)):return
	for channel in ["r","i"]:
		var view: Dictionary=inventories.get(channel,{"entries":[],"ownerId":owner})
		if replace:
			for entry in view.get("entries",[]):
				var item: Dictionary=registry.get(int(entry.get("id",-1)),{})
				if item.get("inventoryLocation") is Dictionary and str(item.inventoryLocation.get("channel",""))==channel:item.inventoryLocationStatus="last-disclosed"
			view.entries=[];view.erase("stats")
		view.ownerId=owner
		for entry in view.get("entries",[]):
			var item: Dictionary=registry.get(int(entry.get("id",-1)),{})
			if int(item.get("objectType",0))==6 and item.get("inventoryLocation") is Dictionary and str(item.inventoryLocation.get("channel",""))==channel:item.inventoryLocation.ownerId=owner
		if view.get("stats") is Dictionary:
			var stats: Dictionary=creature.get("inventoryStats",{});stats.merge(view.stats,true);creature.inventoryStats=stats
		inventories[channel]=view

func require_alternate_window(owner: int,serial: int,receipt: int)->bool:
	var current: Dictionary=inventory_windows.alternate
	var creature: Dictionary=registry.get(owner,{})
	return bool(current.open) and int(current.actorId)==local_object_id and int(current.areaId)==area_id and int(current.ownerId)==owner and int(current.serial)==serial and int(current.receiptSerial)==receipt and int(creature.get("objectType",0))==5 and not bool(creature.get("replicationRemoved",false))

func close_alternate_window()->void:
	inventory_window_serial+=1
	inventory_windows.alternate.open=false
	inventory_windows.alternate.serial=inventory_window_serial
	inventory_windows.alternate.source="client-close"

func clear_repository_view(primary: bool)->void:
	var channel: String="R" if primary else "r"
	if inventories.get(channel) is Dictionary:inventories[channel].entries=[]

func clear_container_view(primary: bool=true)->void:
	var channel: String="C" if primary else "c"
	if inventories.get(channel) is Dictionary:inventories[channel].entries=[]

func apply_container_status(message: Dictionary)->bool:
	if not message.get("primary") is bool or not message.get("targetId") is int or int(message.targetId)<0 or int(message.targetId)>0xffffffff:error="Invalid native container status";return false
	var channel: String="C" if message.primary else "c"
	containers[channel]=int(message.targetId)
	inventories[channel]={"entries":[],"pageCount":1,"ownerId":int(message.targetId)}
	return true

func valid_id(id: int)->bool:
	return id>=EXTERNAL and id<=0xffffffff

func stage_object(target: Dictionary,id: int,object_type: int,properties: Dictionary)->bool:
	if not valid_id(id):error="Server object ID is outside the client namespace";return false
	var old: Dictionary=target.get(id,{})
	if not old.is_empty() and int(old.objectType)!=object_type:error="Server object ID changed type";return false
	var next: Dictionary=old.duplicate(true) if not old.is_empty() else {"id":id,"objectType":object_type,"areaId":area_id,"replicated":{}}
	# Godot owns this receive lifetime. It identifies a local object instance;
	# the wire carries an object ID but no independent lifetime number.
	if old.is_empty() or not next.has("nativeLifetime"):
		next_object_lifetime+=1
		next.nativeLifetime=next_object_lifetime
		next.clientKnownLifetime=next_object_lifetime
	next.merge(properties,true)
	target[id]=next
	return true

func apply_module(value: Dictionary)->bool:
	if value.is_empty() or not value.has("minutesPerHour"):error="Native module information is unavailable";return false
	module=value.duplicate(true)
	return true

func apply_time(changes: Dictionary)->void:
	time.merge(changes,true)

func begin_client_connection(connection_type: int)->bool:
	if connection_type!=16:return false
	game_master_permission={"permission":0,"field114":null,"parameter":null,"source":CLIENT_PERMISSION_SOURCE}
	return true

func apply_dm_permission(message: Dictionary)->bool:
	if str(message.get("kind",""))!="game-master-permission" or not message.get("permission") is int or int(message.permission) not in [0,1] or not message.get("field114") is int or int(message.field114) not in [0,1] or not message.get("parameter") is int or int(message.parameter)<-2147483648 or int(message.parameter)>2147483647:
		error="Invalid received native game-master permission";return false
	var target: Dictionary=registry.get(local_object_id,{})
	if int(message.permission)==0 and int(target.get("objectType",0))==5 and not bool(target.get("replicationRemoved",false)):
		var current: Variant=target.get("clientSkillAdmission")
		if current!=null and not SkillAdmission.valid(current):error="Invalid native skill-admission view";return false
		var view: Dictionary=current.duplicate(true) if current is Dictionary else {"version":1,"source":SkillAdmission.SOURCE,"mask":null,"knownMask":0,"playerUpdateSeen":false,"inventoryUpdateSeen":false}
		view.override=0;view.overrideSource=DM_PERMISSION_SOURCE
		target.clientSkillAdmission=view
		registry[local_object_id]=target
	game_master_permission={"permission":int(message.permission),"field114":int(message.field114),"parameter":int(message.parameter),"source":DM_PERMISSION_SOURCE}
	return true

func valid_current_area()->bool:
	var current: Dictionary=registry.get(area_id,{})
	return int(current.get("objectType",0))==4 and not bool(current.get("replicationRemoved",false)) and current.get("state") is Dictionary

func apply_hud(message: Dictionary)->bool:
	match str(message.get("kind","")):
		"gui-timing":
			var version:=int(timing.get("version",0)) if timing is Dictionary else 0
			timing=message.duplicate(true);timing.version=version+1
		"player-attitude":
			var id:=int(message.playerId)
			var attitude: Dictionary=player_attitudes.get(id,{"ownLikes":1,"incomingLikes":1}).duplicate(true)
			attitude.merge(message,true)
			attitude["ownLikes" if bool(message.get("own",message.get("clear",false))) else "incomingLikes"]=message.likes
			player_attitudes[id]=attitude
		"map-pin-created":map_pins[int(message.id)]=message.duplicate(true)
		"map-pin-enabled":
			if map_pins.has(int(message.id)):map_pins[int(message.id)].enabled=message.enabled
		"map-pin-added":
			var current: Dictionary=registry.get(area_id,{})
			if not valid_current_area():error="Native map pin has no current area";return false
			var pins: Array=[]
			for pin in area.get("playerMapPins",[]):
				if int(pin.get("index",-1))!=int(message.index):pins.append(pin)
			pins.append({"index":message.index,"text":message.text,"position":message.position.duplicate()})
			area.playerMapPins=pins.duplicate(true);current.state.playerMapPins=pins.duplicate(true)
		"journal":
			var operation:=int(message.operation)
			match operation:
				6:journal.entries[str(message.entry.tag)]=message.entry.duplicate(true)
				7:journal.entries.erase(str(message.tag))
				8:
					if journal.entries.has(str(message.tag)):journal.entries[str(message.tag)].picture=message.picture
				9:
					if bool(message.get("present",false)):
						if bool(message.get("full",false)):journal.entries.clear()
						for entry in message.get("entries",[]):
							var key:=str(entry.tag)
							if int(entry.mask)&0x4000:journal.entries.erase(key)
							else:
								var prior: Dictionary=journal.entries.get(key,{})
								prior.merge(entry,true);journal.entries[key]=prior
					journal.loaded=true
				12:journal.notification={"title":message.title,"quest":message.quest,"changed":message.changed}
				1,2:journal.worldEntries[int(message.worldEntry.id)]=message.worldEntry.duplicate(true)
				3:journal.worldEntries.erase(int(message.worldId))
				4:
					for id in journal.worldEntries.keys():
						if int(journal.worldEntries[id].get("strRef",-1))==int(message.worldStrRef):journal.worldEntries.erase(id)
				5:journal.worldEntries.clear()
				_:error="Unknown native journal operation";return false
		_:error="Unknown native HUD message";return false
	return true

func apply_area_visual(message: Dictionary)->bool:
	var current: Dictionary=registry.get(area_id,{})
	if not valid_current_area():error="Native area visual has no current area";return false
	match str(message.get("kind","")):
		"area-weather":
			var weather: Dictionary=message.get("weather",{})
			if int(weather.get("type",-1))<0 or int(weather.get("type",-1))>255 or int(weather.get("enabled",-1)) not in [0,1]:error="Invalid native area weather";return false
			area.weather=weather.duplicate(true);current.state.weather=weather.duplicate(true)
		"area-wind":
			var fields: Dictionary=message.get("fields",{})
			for key in ["e8","ec","f0","f4","f8","fc"]:
				if not fields.has(key) or not is_finite(float(fields[key])):error="Invalid native area wind";return false
			var next: Dictionary=area.get("fields",{}).duplicate(true);next.merge(fields,true);next.e4=3
			area.fields=next.duplicate(true);current.state.fields=next
		_:error="Unknown native area visual state";return false
	return true

func apply_store(message: Dictionary)->bool:
	match str(message.get("kind","")):
		"store-open":
			if store is Dictionary and bool(store.get("open",false)):return true
			var generation:=int(store.get("generation",0))+1 if store is Dictionary else 1
			store=message.duplicate(true);store.open=true;store.generation=generation;store.page=0
			inventories["M"]={"entries":[],"panel":int(message.panel),"pageCount":1}
		"store-close":
			if store is Dictionary:store.open=false
			inventories.erase("M")
		"store-transaction":
			if store is Dictionary:store.gold=int(message.gold);store.lastTransaction={"itemId":int(message.itemId)}
		_:error="Unknown native store message";return false
	return true

func retire_barter(completed: bool=false)->void:
	var previous: Dictionary=barter if barter is Dictionary else {}
	var retired: Dictionary=previous.duplicate(true)
	retired.open=false;retired.serial=int(previous.get("serial",0));retired.completed=completed;retired.revision=int(previous.get("revision",0))+1
	barter=retired
	for channel in ["A","B"]:
		for entry in inventories.get(channel,{}).get("entries",[]):
			var object: Dictionary=registry.get(int(entry.get("id",-1)),{})
			var location: Variant=object.get("inventoryLocation")
			if location is Dictionary and str(location.get("channel",""))==channel:object.inventoryLocation=null
		inventories.erase(channel)

func apply_barter(message: Dictionary)->bool:
	match str(message.get("kind","")):
		"barter-start":
			var own:=local_object_id
			if own!=int(message.get("firstId",-1)) and own!=int(message.get("secondId",-1)):return false
			var serial:=int(barter.get("serial",0))+1 if barter is Dictionary else 1
			retire_barter()
			var initiator:=own==int(message.firstId)
			barter={"open":true,"serial":serial,"revision":1,"actorId":own,"areaId":area_id,"firstId":int(message.firstId),"secondId":int(message.secondId),"partnerId":int(message.secondId) if initiator else int(message.firstId),"initiator":initiator,"ownLocked":false,"otherLocked":false,"ownAccepted":false,"otherAccepted":false}
			inventories["A"]={"entries":[]};inventories["B"]={"entries":[]}
		"barter-close":retire_barter(bool(message.get("completed",false)))
		"barter-lock","barter-accept":
			if not barter is Dictionary or not bool(barter.get("open",false)) or int(barter.get("actorId",-1))!=local_object_id or int(barter.get("areaId",-1))!=area_id:return false
			var side: String="own" if bool(message.get("initiator",false))==bool(barter.initiator) else "other"
			var suffix: String="Locked" if message.kind=="barter-lock" else "Accepted"
			barter[side+suffix]=bool(message.get("value",false));barter.revision=int(barter.get("revision",0))+1
		_:return false
	return true

func apply_party(message: Dictionary)->bool:
	if message.get("kind")=="party-invite-notice":
		var serial:=int(party_invite_notice.get("serial",0))+1 if party_invite_notice is Dictionary else 1
		party_invite_notice={"name":str(message.get("name","")),"serial":serial}
		return true
	if message.get("kind")!="party-list" or str(message.get("operation","")) not in ["all","add","remove"] or not message.get("ids") is Array:error="Invalid native party list";return false
	var operation:=str(message.operation)
	var next: Array[Dictionary]=[]
	for member in party:next.append(member.duplicate(true))
	if operation=="all":
		for member in next:member.stale=true
	for value in message.ids:
		if not value is int or value<0 or value>0xffffffff:error="Invalid native party member ID";return false
		var id:=int(value);var found: Dictionary={}
		for member in next:
			if int(member.id)==id:found=member;break
		if operation=="remove":
			if not found.is_empty():found.stale=true
			var kept: Array[Dictionary]=[]
			for member in next:
				if int(member.id)==0 or not bool(member.get("stale",false)):kept.append(member)
			next=kept
		elif not found.is_empty() and id!=INVALID:found.stale=false
		else:next.append({"id":id,"stale":false})
	if operation=="all":
		var kept: Array[Dictionary]=[]
		for member in next:
			if int(member.id)==0 or not bool(member.get("stale",false)):kept.append(member)
		next=kept
	party=next;party_list_revision+=1
	return true

func apply_examine(message: Dictionary)->bool:
	if str(message.get("kind",""))!="examine" or str(message.get("type",""))!="item" or bool(message.get("close",false)):return false
	var id:=int(message.get("targetId",-1))
	var object: Dictionary=registry.get(id,{})
	if int(object.get("objectType",0))!=6 or not object.get("item") is Dictionary:return false
	var changed: bool=object.item.get("identified")!=message.get("identified")
	object.item.identified=message.identified
	if message.has("canUse"):
		changed=changed or object.item.get("canUse")!=message.canUse
		object.item.canUse=message.canUse
	return changed

static func native_f32(value: float)->float:
	return PackedFloat32Array([value])[0]

func apply_sound_object(message: Dictionary)->bool:
	var operation:=int(message.get("operation",-1));var id:=int(message.get("objectId",-1))
	var current: Dictionary=registry.get(id,{})
	if operation==6:
		if not current.is_empty() or int(message.get("areaId",INVALID))!=area_id or not valid_id(id):return false
		var sound: Variant=message.get("sound")
		if not sound is Dictionary or int(sound.get("id",-1))!=id or not sound.get("position") is Array or sound.position.size()!=3:return false
		var state: Dictionary=sound.duplicate(true)
		registry[id]={"id":id,"objectType":16,"areaId":area_id,"state":state,"nativeSoundHeight":float(state.position[2])}
		var sounds: Array=area.get("sounds",[]).duplicate(true);sounds.append(state.duplicate(true));area.sounds=sounds
		if registry.get(area_id,{}).get("state") is Dictionary:registry[area_id].state.sounds=sounds.duplicate(true)
		return true
	if int(current.get("objectType",0))!=16:return false
	var state: Dictionary=current.get("state",{})
	match operation:
		2,3:
			var fields: Dictionary=state.get("fields",{});fields["308"]=1 if operation==2 else 0;state.fields=fields
		4:
			var fields: Dictionary=state.get("fields",{});fields["314"]=int(message.get("volume",0));state.fields=fields
		5:
			var position: Variant=message.get("position")
			if not position is Array or position.size()!=3:return false
			state.position=[native_f32(float(position[0])),native_f32(float(position[1])),native_f32(native_f32(float(position[2]))+native_f32(float(current.get("nativeSoundHeight",state.position[2]))))]
		7:registry.erase(id)
		_:return false
	var sounds: Array=[]
	for value in area.get("sounds",[]):
		if int(value.get("id",-1))==id:
			if operation!=7:sounds.append(state.duplicate(true))
		else:sounds.append(value)
	area.sounds=sounds.duplicate(true)
	if registry.get(area_id,{}).get("state") is Dictionary:registry[area_id].state.sounds=sounds.duplicate(true)
	return true

func apply_roster(message: Dictionary)->bool:
	var kind:=str(message.get("kind",""))
	if kind=="object-control":
		controls[int(message.playerId)]=int(message.objectId)
		if local_object_id!=int(message.objectId):script_targeting=null
		local_object_id=int(message.objectId)
		return true
	if kind=="player-list-delete":players.erase(int(message.playerId));controls.erase(int(message.playerId));return true
	if kind not in ["player-list-all","player-list-add"]:error="Unknown native player-roster message";return false
	if kind=="player-list-all":players.clear();controls.clear();player_roster_known=bool(message.get("server140",false))
	for row in message.get("players",[]):
		var id:=int(row.playerId)
		players[id]=row.duplicate(true)
		controls[id]=int(row.objectId)
	return true

func apply_area(message: Dictionary)->bool:
	var next_area: Dictionary=message.get("area",{})
	if next_area.is_empty() or not valid_id(int(next_area.get("id",0))):error="Native area ID is unavailable";return false
	var next_registry: Dictionary=registry.duplicate(true)
	var id:=int(next_area.id)
	# Original area teardown7e7770 retires the prior area's type16 sounds.
	# Preserve unrelated creatures/items and their canonical object IDs.
	for old_id in next_registry.keys():
		var old: Dictionary=next_registry[old_id]
		if int(old.get("objectType",0))==16 and int(old.get("areaId",INVALID))==area_id:next_registry.erase(old_id)
	if next_registry.has(area_id) and next_registry[area_id].get("state") is Dictionary:
		next_registry[area_id].state.sounds=[]
	if not stage_object(next_registry,id,4,{"state":next_area.duplicate(true)}):return false
	for pin in next_area.get("mapPins",[]):
		if not stage_object(next_registry,int(pin.id),12,{"areaId":id,"mapPin":pin.duplicate(true)}):return false
	for sound in next_area.get("sounds",[]):
		if not stage_object(next_registry,int(sound.id),16,{"areaId":id,"state":sound.duplicate(true),"nativeSoundHeight":sound.position[2]}):return false
	for light in next_area.get("placeableLights",[]):
		if not stage_object(next_registry,int(light.id),9,{"areaId":id,"lightState":light.duplicate(true)}):return false
	for placeable in next_area.get("staticPlaceables",[]):
		if not stage_object(next_registry,int(placeable.id),9,{"areaId":id,"staticState":placeable.duplicate(true)}):return false
	var controlled: Dictionary=next_registry.get(local_object_id,{})
	if int(controlled.get("objectType",0))==5:
		var replicated: Dictionary=controlled.get("replicated",{}).duplicate(true)
		replicated.position=message.position.duplicate()
		replicated.orientation=[cos(float(message.facing)),sin(float(message.facing)),0.0]
		if not stage_object(next_registry,local_object_id,5,{"areaId":id,"replicationRemoved":false,"replicated":replicated}):return false
	registry=next_registry;area=next_area.duplicate(true);area_id=id
	script_targeting=null
	map_pins.clear()
	for pin in next_area.get("mapPins",[]):map_pins[int(pin.id)]=pin.duplicate(true)
	retire_barter()
	for channel in ["C","c","M"]:inventories.erase(channel)
	containers.clear();store=null;reset_inventory_windows()
	entry={"loadingScreen":message.loadingScreen,"position":message.position.duplicate(),"facing":message.facing,"flag":message.flag}
	time=next_area.get("time",{}).duplicate(true)
	return true

func apply_inventory(target: Dictionary,views: Dictionary,record: Dictionary,controlled: int)->bool:
	var channel:=str(record.channel);var operation:=str(record.operation)
	var view: Dictionary=views.get(channel,{"entries":[]}).duplicate(true)
	if record.has("pageCount"):
		view.pageCount=record.pageCount
		if record.has("panel"):view.panel=record.panel
		views[channel]=view;return true
	if record.has("state"):
		var stats: Dictionary=view.get("stats",{});stats.merge(record.state,true);view.stats=stats;views[channel]=view
		return true
	var entries: Array=view.get("entries",[])
	if operation=="A":
		var id:=int(record.id)
		if not stage_object(target,id,6,{"areaId":INVALID,"replicationRemoved":false}):return false
		var item: Dictionary=target[id].get("item",{}).duplicate(true);item.merge(record.item,true);target[id].item=item
		var slot: Dictionary={"id":id}
		if record.has("slot"):slot.slot=record.slot
		else:slot.x=record.x;slot.y=record.y
		for index in range(entries.size()-1,-1,-1):
			if int(entries[index].id)==id or record.has("slot") and int(entries[index].get("slot",-1))==int(record.slot):entries.remove_at(index)
		entries.append(slot)
		var location_owner: Variant=controlled
		if channel in ["C","c"]:location_owner=int(containers.get(channel,controlled))
		elif channel in ["r","i"]:location_owner=int(view.get("ownerId",controlled))
		elif channel=="M":location_owner=null
		target[id].inventoryLocation={"channel":channel,"ownerId":location_owner,"slot":record.slot} if record.has("slot") else {"channel":channel,"ownerId":location_owner,"x":record.x,"y":record.y}
	elif operation=="D":
		for index in range(entries.size()-1,-1,-1):
			if record.has("slot") and int(entries[index].get("slot",-1))==int(record.slot) or record.has("id") and int(entries[index].id)==int(record.id):
				var removed_id:=int(entries[index].id)
				entries.remove_at(index)
				if target.has(removed_id):target[removed_id].inventoryLocation=null
	elif operation in ["U","M"]:
		if record.has("id") and target.has(int(record.id)) and record.has("stackSize"):
			var item: Dictionary=target[int(record.id)].get("item",{})
			item.stackSize=record.stackSize;item.field280=record.field280;item.cost=record.field280
		if record.has("id") and record.has("x"):
			for item in entries:
				if int(item.id)==int(record.id):item.x=record.x;item.y=record.y
	else:error="Unsupported native inventory operation";return false
	view.entries=entries;views[channel]=view
	return true

func apply_quickbar(message: Dictionary)->bool:
	var buttons: Array=quickbar.duplicate(true)
	var next: Dictionary=registry.duplicate(true)
	for row in message.get("entries",[]):
		var index:=int(row.get("index",-1))
		if index<0 or index>=36:error="Native quickbar index is invalid";return false
		var button: Dictionary=buttons[index]
		button.merge(row.button,true)
		if int(button.get("type",0))==0:button.intParam=0
		for value in row.get("items",[]):
			var id:=int(value.id)
			if not stage_object(next,id,6,{"areaId":INVALID,"replicationRemoved":false}):return false
			var item: Dictionary=next[id].get("item",{}).duplicate(true)
			item.merge(value.item,true);next[id].item=item
		buttons[index]=button
	quickbar=buttons;registry=next
	return true

func apply_item_caption(message: Dictionary)->bool:
	# network_world.js applies server 24/5 only to an item already known to
	# this connection. The wire packet creates no item and carries no lifetime.
	if str(message.get("kind",""))!="item-text-bubble-override":return false
	var id:=int(message.get("itemId",-1))
	var object: Dictionary=registry.get(id,{})
	if int(object.get("objectType",0))!=6 or not object.get("item") is Dictionary:return false
	var item: Dictionary=object.item.duplicate(true)
	item.field2b8=int(message.get("mode",0))
	item.field2c0=str(message.get("text",""))
	object.item=item
	registry[id]=object
	return true

func apply_targeting(message: Dictionary)->bool:
	match str(message.get("kind","")):
		"script-targeting":
			script_target_version+=1
			script_targeting=message.merged({"version":script_target_version,"areaId":area_id,"actorId":local_object_id},true) if int(message.get("objectMask",0))!=0 else null
		"script-targeting-data":script_targeting_data=message.duplicate(true)
		"spell-targeting-data":spell_targeting_overrides[int(message.spellId)]=message.duplicate(true)
		_:return false
	return true

func apply_tlk_overrides(message: Dictionary)->bool:
	if str(message.get("kind",""))!="tlk-overrides" or not message.get("entries") is Array:return false
	for row in message.entries:
		var ref:=int(row.strRef)
		var value:=str(row.text)
		if value.is_empty():tlk_overrides.erase(ref)
		else:tlk_overrides[ref]=value
	if not message.entries.is_empty():tlk_override_version+=1
	return true

func apply_updates(message: Dictionary)->bool:
	if not message.get("complete",false):error="Native object-update packet is incomplete";return false
	var next: Dictionary=registry.duplicate(true)
	var views: Dictionary=inventories.duplicate(true)
	var controlled:=local_object_id
	for record in message.get("records",[]):
		var action:=str(record.get("action",""))
		if action=="work-remaining" or action=="item-use-counts":continue
		if action=="inventory":
			if not apply_inventory(next,views,record,controlled):return false
			continue
		var id:=int(record.get("id",0));var object_type:=int(record.get("objectType",0))
		if action=="delete" and not next.has(id):continue
		if not stage_object(next,id,object_type,{}):return false
		var object: Dictionary=next[id]
		if action=="delete":object.replicationRemoved=true;object.deletionFlag=record.get("remove");continue
		var state: Dictionary=record.get("state",{}).duplicate(true)
		if action=="create":
			if bool(object.get("replicationRemoved",false)):
				next_object_lifetime+=1
				object.nativeLifetime=next_object_lifetime
				object.clientKnownLifetime=next_object_lifetime
			object.replicationRemoved=false
			if object_type==6 and state.has("item"):object.item=state.item;state.erase("item")
		if action=="appearance":
			var appearance: Dictionary=object.get("appearance",{}).duplicate(true)
			if state.has("equipment"):
				var equipped: Dictionary={}
				for previous in appearance.get("equipment",[]):equipped[int(previous.slot)]=previous
				for change in state.equipment:
					var slot:=int(change.slot)
					if change.action=="D":equipped.erase(slot)
					elif change.action=="A":
						if not stage_object(next,int(change.id),6,{"areaId":INVALID,"item":change.item.duplicate(true),"equipmentOwnerId":id}):return false
						equipped[slot]=change
					elif change.action=="U":
						if not next.has(int(change.id)):continue
						var item: Dictionary=next[int(change.id)].get("item",{}).duplicate(true)
						item.merge(change.item,true);next[int(change.id)].item=item
					else:error="Unknown native equipment appearance change";return false
				state.equipment=equipped.values()
			appearance.merge(state,true);object.appearance=appearance
		elif action=="player-state":
			var player_state: Dictionary=object.get("playerState",{});player_state.merge(state,true);object.playerState=player_state;controlled=id
		elif action=="inventory-stats":
			var stats: Dictionary=object.get("inventoryStats",{});stats.merge(state,true);object.inventoryStats=stats
		elif action in ["create","update"]:
			var replicated: Dictionary=object.get("replicated",{});replicated.merge(state,true);object.replicated=replicated
			if state.has("areaId"):object.areaId=state.areaId
		else:error="Unsupported native object-update action";return false
	registry=next;inventories=views
	if local_object_id!=controlled:retire_barter();script_targeting=null
	local_object_id=controlled
	return true

func summary()->Dictionary:
	var control_rows: Array[Dictionary]=[]
	for player_id in controls:control_rows.append({"playerId":player_id,"objectId":controls[player_id]})
	return {"areaId":area_id,"localObjectId":local_object_id,"entry":entry.duplicate(true),"time":time.duplicate(true),"objects":registry.size(),"controls":control_rows}

func presentation(prepare_area: bool=false)->Dictionary:
	# The original 4/3 area acknowledgement precedes controlled-creature
	# replication. The renderer may prepare terrain from the received area now;
	# ordinary world publication still requires the admitted creature.
	if area.is_empty() or module.is_empty() or not prepare_area and (local_object_id==INVALID or not registry.has(local_object_id)):return {"error":"Native world is not ready for presentation"}
	var inventory_rows: Array=[]
	for channel in inventories:inventory_rows.append([channel,inventories[channel].duplicate(true)])
	var player_rows: Array=[]
	for player_id in players:player_rows.append([player_id,players[player_id].duplicate(true)])
	var container_rows: Array=[]
	for channel in containers:container_rows.append([channel,containers[channel]])
	var journal_entries: Array=[];var world_entries: Array=[];var map_pin_rows: Array=[];var attitudes: Array=[]
	for key in journal.entries:journal_entries.append([key,journal.entries[key].duplicate(true)])
	for key in journal.worldEntries:world_entries.append([key,journal.worldEntries[key].duplicate(true)])
	for key in map_pins:map_pin_rows.append([key,map_pins[key].duplicate(true)])
	for key in player_attitudes:attitudes.append([key,player_attitudes[key].duplicate(true)])
	var journal_view: Dictionary={"entries":journal_entries,"worldEntries":world_entries,"loaded":journal.loaded}
	if journal.has("notification"):journal_view.notification=journal.notification.duplicate(true)
	return {"area":area.duplicate(true),"objects":registry.values().map(func(value):return value.duplicate(true)),"controlledId":local_object_id,"entry":entry.duplicate(true),"time":time.duplicate(true),"module":module.duplicate(true),"inventory":{"inventories":inventory_rows,"containers":container_rows,"windows":inventory_window_snapshot(),"store":store.duplicate(true) if store is Dictionary else null},"ui":{"players":player_rows,"playerRosterKnown":player_roster_known,"gameMasterPermission":game_master_permission.duplicate(true) if game_master_permission is Dictionary else null,"party":party.duplicate(true),"partyListRevision":party_list_revision,"partyInviteNotice":party_invite_notice.duplicate(true) if party_invite_notice is Dictionary else null,"barter":barter.duplicate(true) if barter is Dictionary else {},"quickbar":quickbar.duplicate(true),"journal":journal_view,"mapPins":map_pin_rows,"playerAttitudes":attitudes,"timing":timing.duplicate(true) if timing is Dictionary else null,"scriptTargeting":script_targeting.duplicate(true) if script_targeting is Dictionary else null,"scriptTargetingData":script_targeting_data.duplicate(true) if script_targeting_data is Dictionary else null,"spellTargetingOverrides":spell_targeting_overrides.duplicate(true),"tlkOverrides":tlk_overrides.duplicate(true),"tlkOverrideVersion":tlk_override_version}}
