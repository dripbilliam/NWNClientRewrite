extends RefCounted
# Godot-owned received world state. Server object IDs stay in the client wire
# namespace. Every update packet is applied to a detached copy and committed
# only after its records are accepted.
const FrameProfile=preload("res://systems/native_render/frame_profile.gd")
const INVALID:=0x7f000000
const EXTERNAL:=0x80000000
const SkillAdmission=preload("res://systems/native_data/skill_admission.gd")
const ActionQueueState=preload("res://systems/native_data/native_action_queue_state.gd")
const NetworkAutomap=preload("res://systems/native_data/native_network_automap.gd")
const NetworkSpellGain=preload("res://systems/native_data/native_network_spell_gain.gd")
const ItemUses=preload("res://systems/native_data/native_item_uses.gd")
const QuickbarButton=preload("res://systems/native_data/native_quickbar_button.gd")
const EquipmentCache=preload("res://systems/native_data/native_network_equipment_cache.gd")
const AttackAnimationRecords=preload("res://systems/native_data/native_attack_animation_records.gd")
const CastAnimationRecords=preload("res://systems/native_data/native_cast_animation_records.gd")
const NetworkAssociates=preload("res://systems/native_data/native_network_associates.gd")
const CustomTokenTable=preload("res://systems/native_data/native_custom_token_table.gd")
const ClockLifecycle=preload("res://systems/native_data/native_client_clock_lifecycle.gd")
const NetworkDoor=preload("res://systems/native_data/native_network_door.gd")
const PlayerRoster=preload("res://systems/native_data/native_player_roster.gd")
const GameObjectArray=preload("res://systems/native_data/native_game_object_array.gd")
const NativeMath=preload("res://systems/native_data/native_math.gd")
const ActorNameReceipt=preload("res://systems/native_data/native_actor_name_receipt.gd")
const DisclosureLifetimes=preload("res://systems/native_data/network_entity_lifetimes.gd")
const RawWorldDeltas=preload("res://systems/native_data/raw_world_deltas.gd")
const DM_PERMISSION_SOURCE:="received_game_master_permission_31_22"
const CLIENT_PERMISSION_SOURCE:="native_connection_start_16"
const MOVEMENT_TRIGGERS=["position","orientation","facingTarget","animation","path","walkRate","runRate"]
const MOVEMENT_FIELDS=["position","orientation","facingTarget","animation","path","walkRate","runRate","field8F4","field8EC","actionFlag"]
var module: Dictionary={}
var area: Dictionary={}
var entry: Dictionary={}
var time: Dictionary={}
var area_id:=INVALID
var local_object_id:=INVALID
var game_master_permission: Variant=null
var registry: Dictionary={}
var parallel_import_clone_requested:=not OS.get_cmdline_user_args().has("--network-import-clone=serial")
var parallel_import_clone_uses:=0
var parallel_import_clone_task_count:=0
var parallel_import_clone_fallbacks:=0
var players: Dictionary={}
var actor_name_history_complete:=true
var actor_name_sequence:=0
var actor_name_states: Dictionary={}
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
var custom_tokens=CustomTokenTable.new()
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
var sound_diagnostic: Dictionary={}
var world_diagnostics: Array[Dictionary]=[]
var presentation_changes: Array[Dictionary]=[]
var next_object_lifetime:=0
var clock_lifecycle: RefCounted
var clock_handles: Dictionary={}
var clock_observer_failures:=0
var clock_last_boundaries: Array=[]
var disclosures: RefCounted
var disclosure_handles: Dictionary={}

func _init()->void:
	clock_lifecycle=ClockLifecycle.new({"owner":self,"connection":null,"recordHistoryComplete":true,"externalRegistryHistoryComplete":true})
	disclosures=DisclosureLifetimes.new()
	disclosures.reset()
	quickbar=QuickbarButton.initialize_buttons()
	reset_inventory_windows()

func sync_disclosure_handles()->void:
	for id in disclosure_handles.keys():
		if not registry.has(id):disclosure_handles.erase(id)
	for id in registry:
		if not disclosure_handles.has(id):disclosure_handles[id]=DisclosureLifetimes.make_handle(int(id))
		# The raw registry slot survives delete -> create updates. Preserve its
		# presentation identity even when nativeLifetime advances for rendering.
		var row: Variant=registry[id]
		var registration: int=disclosure_handles[id].get_instance_id()
		if row is Dictionary and (not row.has("nativeProjectileRegistration") or int(row.nativeProjectileRegistration)!=registration):row.nativeProjectileRegistration=registration

func reject_clock_observer(context: Dictionary)->void:
	clock_observer_failures=min(clock_observer_failures+1,9007199254740991)
	clock_lifecycle.abort(context.transaction,"world-clock-observer-rejected")
	context.tracked=false
	context.prepared=false

func observe_clock_record(context: Dictionary,record: Dictionary,index: int,staged: Variant=null,already_staged: bool=false,next: Dictionary={})->void:
	if not bool(context.get("tracked",false)):return
	var boundary: Dictionary={}
	if int(record.get("objectType",0))==5:
		var id:=int(record.get("id",-1))
		var canonical: Variant=clock_handles.get(id) if registry.has(id) else null
		var private_owner: Variant=clock_lifecycle.state_for(self,canonical) if canonical!=null else null
		var external_owner: String="live" if private_owner is Dictionary and bool(private_owner.get("physicalCurrent",false)) and str(private_owner.get("presence",""))=="live" else "absent" if canonical==null and not already_staged else "unknown"
		var observed_area: Variant=null
		if record.get("state") is Dictionary:observed_area=record.state.get("areaId")
		if observed_area==null and staged!=null:observed_area=next.get(id,{}).get("areaId")
		if observed_area==null:observed_area=area_id
		boundary={"canonicalBefore":canonical,"stagedProxy":staged,"externalOwner":external_owner,"areaId":observed_area}
	var result: Dictionary=clock_lifecycle.observe(context.transaction,record,index,boundary)
	if result.get("ok",true)==false:reject_clock_observer(context)

func clock_owner_transport(object_id: int)->Variant:
	var canonical: Variant=clock_handles.get(object_id) if registry.has(object_id) else null
	if canonical==null:return null
	var owner: Variant=clock_lifecycle.state_for(self,canonical)
	if not owner is Dictionary:return null
	return {"version":1,"source":"native-client-clock-owner-v1","epoch":owner.epoch,"connection":owner.connection,"physicalCurrent":owner.physicalCurrent,"physicalToken":owner.physicalToken if owner.physicalCurrent else null}

func stage_actor_name_record(context: Dictionary,record: Dictionary,had_proxy: bool)->bool:
	if not bool(context.get("tracked",false)):return true
	if int(record.get("objectType",0))!=5 or str(record.get("action","")) not in ["create","delete","appearance"]:return true
	if str(record.action)=="appearance" and (not record.get("state") is Dictionary or not record.state.has("name")):return true
	var id:=int(record.get("id",-1))
	var current: Variant=null
	if context.staged.has(id):current=context.staged[id]
	elif actor_name_states.has(id) and actor_name_states[id].get("handle")==clock_handles.get(id):current=actor_name_states[id].get("value")
	var history_complete: bool=bool(context.historyComplete)
	var typed_owner: String="present" if current is Dictionary and str(current.get("presence",""))=="present" else "absent" if not had_proxy and history_complete else "unknown"
	if int(context.sequence)>=9007199254740991:error="Native actor-name sequence exhausted";return false
	context.sequence=int(context.sequence)+1
	var environment: Dictionary={"overrides":tlk_overrides,"customTokens":{"records":custom_tokens.snapshot()}}
	var staged: Dictionary=ActorNameReceipt.stage(current,record,{"sequence":context.sequence,"typedOwner":typed_owner,"historyComplete":history_complete},environment)
	if not bool(staged.get("ok",false)):error=str(staged.get("error","Invalid native actor-name state"));return false
	context.staged[id]=staged.get("value")
	return true

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

func stage_object(target: Dictionary,id: int,object_type: int,properties: Dictionary,touched: Variant=null)->bool:
	if not valid_id(id):error="Server object ID is outside the client namespace";return false
	if not object_type in [3,4,5,6,7,8,9,10,11,12,13,14,15,16]:error="Invalid replicated object identity";return false
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
	if touched is Dictionary:touched[id]=true
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
		var admission: Dictionary=SkillAdmission.merge(target.get("clientSkillAdmission"),message,"permission")
		if not admission.ok:error=str(admission.error);return false
		target.clientSkillAdmission=admission.value
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
	error=""
	var current: Dictionary=registry.get(area_id,{})
	if not valid_current_area():return false
	match str(message.get("kind","")):
		"area-weather":
			var weather: Dictionary=message.get("weather",{})
			if not weather.get("type") is int or int(weather.type)<0 or int(weather.type)>255 or not weather.get("enabled") is int or int(weather.enabled) not in [0,1]:error="Invalid native area weather state";return false
			area.weather=weather.duplicate(true);current.state.weather=weather.duplicate(true)
		"area-wind":
			var fields: Dictionary=message.get("fields",{})
			for key in ["e8","ec","f0","f4","f8","fc"]:
				if not (fields.get(key) is float or fields.get(key) is int) or not is_finite(float(fields[key])):error="Invalid native area wind fields";return false
			var next: Dictionary=current.state.get("fields",{}).duplicate(true);next.merge(fields,true);next.e4=3
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
	if message.get("kind")!="party-list" or str(message.get("operation","")) not in ["all","add","remove"] or not message.get("ids") is Array:error="Invalid replicated party list";return false
	var operation:=str(message.operation)
	var next: Array[Dictionary]=[]
	for member in party:next.append(member.duplicate(true))
	if operation=="all":
		for member in next:member.stale=true
	for value in message.ids:
		if not value is int or value<0 or value>0xffffffff:error="Invalid replicated party list";return false
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
	if str(message.get("kind",""))!="examine":return false
	if str(message.get("type",""))!="item" or bool(message.get("close",false)):return true
	var id:=int(message.get("targetId",-1))
	var object: Dictionary=registry.get(id,{})
	if int(object.get("objectType",0))!=6 or not object.get("item") is Dictionary:return true
	object.item.identified=message.identified
	if message.has("canUse"):
		object.item.canUse=message.canUse
	return true

static func native_f32(value: float)->float:
	return PackedFloat32Array([value])[0]

func reject_sound(code: String,reason: String,details: Dictionary={})->bool:
	sound_diagnostic={"code":code,"reason":reason}
	sound_diagnostic.merge(details,true)
	return false

func apply_sound_object(message: Dictionary)->bool:
	sound_diagnostic.clear()
	error=""
	var operation:=int(message.get("operation",-1));var id:=int(message.get("objectId",-1))
	var current: Dictionary=registry.get(id,{})
	if operation==6:
		if not current.is_empty():return reject_sound("network.sound-create-duplicate","Native sound create references an existing object",{"objectId":id})
		if int(message.get("areaId",INVALID))!=area_id:return reject_sound("network.sound-create-wrong-area","Native sound create references another area",{"objectId":id,"areaId":message.get("areaId")})
		var sound: Variant=message.get("sound")
		if not valid_id(id) or not sound is Dictionary or int(sound.get("id",-1))!=id:return reject_sound("network.sound-create-invalid-id","Native sound create has inconsistent canonical IDs",{"objectId":id,"packedId":sound.get("id") if sound is Dictionary else null})
		if not sound.get("position") is Array or sound.position.size()!=3:return false
		var state: Dictionary=sound.duplicate(true)
		var record: Dictionary={"id":id,"objectType":16,"areaId":area_id,"state":state,"nativeSoundHeight":float(state.position[2])}
		var validation:=GameObjectArray.new({"clientMode":true})
		if int(validation.add_external_object(id,record).status)!=0:error="Native sound object ID cannot be registered";return false
		registry[id]=record
		sync_disclosure_handles()
		var sounds: Array=area.get("sounds",[]).duplicate(true);sounds.append(state.duplicate(true));area.sounds=sounds
		if registry.get(area_id,{}).get("state") is Dictionary:registry[area_id].state.sounds=sounds.duplicate(true)
		return true
	if int(current.get("objectType",0))!=16:
		if operation==7:return reject_sound("network.sound-destroy-missing","Native sound destroy has no matching sound object",{"objectId":id})
		return false
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
		7:
			registry.erase(id)
			disclosure_handles.erase(id)
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
		# Party/14 updates only the roster. GameObjectUpdate/5 selects the
		# controlled creature for this client connection.
		if int(message.get("major",-1))==5 and int(message.get("minor",-1))==2:
			if local_object_id!=int(message.objectId):script_targeting=null
			local_object_id=int(message.objectId)
		return true
	if kind=="player-list-delete":players.erase(int(message.playerId));controls.erase(int(message.playerId));player_attitudes.erase(int(message.playerId));return true
	if kind not in ["player-list-all","player-list-add"]:error="Unknown native player-roster message";return false
	var staged: Dictionary=PlayerRoster.stage(message)
	if staged.has("error"):error=str(staged.error);return false
	if kind=="player-list-all":players.clear();controls.clear();player_roster_known=bool(staged.complete)
	for row in staged.rows:
		var id:=int(row.playerId)
		players[id]=row.duplicate(true)
		controls[id]=int(row.objectId)
	return true

func apply_area(message: Dictionary)->bool:
	var next_area: Dictionary=message.get("area",{})
	if next_area.is_empty() or not valid_id(int(next_area.get("id",0))):error="Native area ID is unavailable";return false
	var next_registry: Dictionary=registry.duplicate(true)
	var area_records: Dictionary={}
	var removed_sounds: Array=[]
	var id:=int(next_area.id)
	# Original area teardown7e7770 retires the prior area's type16 sounds.
	# Preserve unrelated creatures/items and their canonical object IDs.
	for old_id in next_registry.keys():
		var old: Dictionary=next_registry[old_id]
		if int(old.get("objectType",0))==16 and int(old.get("areaId",INVALID))==area_id:
			next_registry.erase(old_id)
			removed_sounds.append(old_id)
	if next_registry.has(area_id) and next_registry[area_id].get("state") is Dictionary:
		next_registry[area_id].state.sounds=[]
	if not stage_object(next_registry,id,4,{"state":next_area.duplicate(true)},area_records):return false
	for pin in next_area.get("mapPins",[]):
		if not stage_object(next_registry,int(pin.id),12,{"areaId":id,"mapPin":pin.duplicate(true)},area_records):return false
	for sound in next_area.get("sounds",[]):
		if not stage_object(next_registry,int(sound.id),16,{"areaId":id,"state":sound.duplicate(true),"nativeSoundHeight":sound.position[2]},area_records):return false
	for light in next_area.get("placeableLights",[]):
		if not stage_object(next_registry,int(light.id),9,{"areaId":id,"lightState":light.duplicate(true)},area_records):return false
	for placeable in next_area.get("staticPlaceables",[]):
		if not stage_object(next_registry,int(placeable.id),9,{"areaId":id,"staticState":placeable.duplicate(true)},area_records):return false
	var controlled: Dictionary=next_registry.get(local_object_id,{})
	if int(controlled.get("objectType",0))==5:
		var replicated: Dictionary=controlled.get("replicated",{}).duplicate(true)
		replicated.position=message.position.duplicate()
		var cosine: float=NativeMath.native_cosf(float(message.facing))
		var cosine_error: String=NativeMath.last_error
		var sine: float=NativeMath.native_sinf(float(message.facing))
		var sine_error: String=NativeMath.last_error
		if not cosine_error.is_empty() or not sine_error.is_empty() or not is_finite(cosine) or not is_finite(sine):error=cosine_error if not cosine_error.is_empty() else sine_error if not sine_error.is_empty() else "Native area entry orientation is invalid";return false
		replicated.orientation=[cosine,sine,0.0]
		if not stage_object(next_registry,local_object_id,5,{"areaId":id,"replicationRemoved":false,"replicated":replicated},area_records):return false
	var validation:=GameObjectArray.new({"clientMode":true})
	for record_id in area_records:
		if int(validation.add_object_at_pos(record_id,next_registry[record_id]).status)!=0:error="Server area object ID cannot be registered";return false
	registry=next_registry;area=next_area.duplicate(true);area_id=id
	for old_sound_id in removed_sounds:disclosure_handles.erase(old_sound_id)
	sync_disclosure_handles()
	script_targeting=null
	map_pins.clear()
	for pin in next_area.get("mapPins",[]):map_pins[int(pin.id)]=pin.duplicate(true)
	retire_barter()
	for channel in ["C","c","M"]:inventories.erase(channel)
	containers.clear();store=null;reset_inventory_windows()
	entry={"loadingScreen":message.loadingScreen,"position":message.position.duplicate(),"facing":message.facing,"flag":message.flag}
	time=next_area.get("time",{}).duplicate(true)
	return true

func apply_inventory(target: Dictionary,views: Dictionary,record: Dictionary,controlled: int,events: Array[Dictionary],clock_context: Dictionary,touched: Dictionary)->bool:
	var channel:=str(record.channel);var operation:=str(record.operation)
	var existing:=views.has(channel)
	var view: Dictionary=views.get(channel,{"entries":[]}).duplicate(true)
	var owner: Variant=null
	if channel in ["C","c"]:owner=containers.get(channel)
	elif channel in ["R","I"]:owner=controlled
	elif channel in ["r","i"]:
		if bool(inventory_windows.alternate.get("open",false)):owner=inventory_windows.alternate.get("ownerId")
	elif barter is Dictionary and bool(barter.get("open",false)):
		if channel=="B":owner=controlled
		elif channel=="A":owner=barter.get("partnerId")
	if not existing and owner==null and channel!="M":
		events.append({"action":"inventory-owner-unavailable","channel":channel})
		world_diagnostics.append({"code":"network.inventory-owner-unavailable","reason":"Native inventory GUI owner binding is unavailable","channel":channel})
	if record.has("pageCount"):
		view.pageCount=record.pageCount
		if record.has("panel"):view.panel=record.panel
		views[channel]=view;return true
	if record.has("state"):
		var stats: Dictionary=view.get("stats",{});stats.merge(record.state,true);view.stats=stats;views[channel]=view
		if owner!=null:
			if not stage_object(target,int(owner),5,{},touched):return false
			if not clock_context.staged.has(int(owner)):clock_context.staged[int(owner)]=ClockLifecycle.make_proxy(int(owner))
			var actor_stats: Dictionary=target[int(owner)].get("inventoryStats",{})
			actor_stats.merge(record.state,true)
			target[int(owner)].inventoryStats=actor_stats
		return true
	var entries: Array=view.get("entries",[])
	var entry_key: String="slot" if channel.to_upper()=="I" else "id"
	if operation=="A":
		var id:=int(record.id)
		if not stage_object(target,id,6,{"areaId":INVALID,"replicationRemoved":false,"inventoryLocationStatus":"current"},touched):return false
		target[id].item=ItemUses.merge_network_item(target[id].get("item"),record.item)
		if channel=="I" and record.has("slot"):
			target[id].inventoryEquipmentSlot=record.slot
			if owner!=null and target.has(int(owner)) and int(target[int(owner)].get("objectType",0))==5:
				EquipmentCache.set_client_equipment_slot(target[int(owner)],record.slot,target[id],func(item_id):return target.get(item_id))
		if channel not in ["I","i"]:target[id].equipmentOwnerId=null
		var slot: Dictionary={"id":id}
		if record.has("slot"):slot.slot=record.slot
		else:slot.x=record.x;slot.y=record.y
		views[channel]=view
		var group: Array=["R","I","C","M","A","B"] if channel==channel.to_upper() else ["r","i","c"]
		if channel not in group:group=[channel]
		for related in group:
			if not views.has(related):continue
			var related_view: Dictionary=views[related].duplicate(true)
			var kept: Array=[]
			for prior in related_view.get("entries",[]):
				if int(prior.get("id",-1))==id:continue
				if related==channel and prior.get(entry_key)!=null and prior.get(entry_key)==record.get(entry_key):
					var displaced_id:=int(prior.get("id",-1))
					if target.has(displaced_id) and target[displaced_id].get("inventoryLocation") is Dictionary and str(target[displaced_id].inventoryLocation.get("channel",""))==channel:target[displaced_id].inventoryLocation=null
					continue
				kept.append(prior)
			related_view.entries=kept
			views[related]=related_view
		view=views.get(channel,view)
		entries=view.get("entries",[])
		entries.append(slot)
		target[id].inventoryLocation={"channel":channel,"ownerId":owner,"slot":record.slot} if record.has("slot") else {"channel":channel,"ownerId":owner,"x":record.x,"y":record.y}
	elif operation=="D":
		for index in entries.size():
			if entries[index].get(entry_key)==record.get(entry_key):
				var removed_id:=int(entries[index].id)
				entries.remove_at(index)
				if not stage_object(target,removed_id,6,{},touched):return false
				if target.has(removed_id) and target[removed_id].get("inventoryLocation") is Dictionary and str(target[removed_id].inventoryLocation.get("channel",""))==channel:target[removed_id].inventoryLocation=null
				break
	elif operation in ["U","M"]:
		var item_id:=int(record.get("id",-1))
		if not stage_object(target,item_id,6,{},touched):return false
		if record.has("stackSize"):
			var item: Dictionary=target[item_id].get("item",{})
			item.stackSize=record.stackSize;item.field280=record.field280;item.cost=record.field280
		if record.has("x"):
			for item in entries:
				if int(item.id)==int(record.id):
					item.x=record.x;item.y=record.y
					if target.has(int(record.id)):
						target[int(record.id)].inventoryLocation={"channel":channel,"ownerId":owner,"x":record.x,"y":record.y}
						target[int(record.id)].inventoryLocationStatus="current"
					break
	else:error="Unsupported native inventory operation";return false
	view.entries=entries;views[channel]=view
	return true

func apply_quickbar(message: Dictionary)->bool:
	var buttons: Array=quickbar.duplicate(true)
	var next: Dictionary=registry.duplicate(true)
	var item_records: Dictionary={}
	for row in message.get("entries",[]):
		var index:=int(row.get("index",-1))
		if index<0 or index>=36:error="Native quickbar index is invalid";return false
		var button: Dictionary=buttons[index]
		button.merge(row.button,true)
		if int(button.get("type",0))==0:button.intParam=0
		for value in row.get("items",[]):
			var id:=int(value.id)
			if not stage_object(next,id,6,{"areaId":INVALID,"replicationRemoved":false},item_records):return false
			next[id].item=ItemUses.merge_network_item(next[id].get("item"),value.item)
		buttons[index]=button
	var validation:=GameObjectArray.new({"clientMode":true})
	for item_id in item_records:
		if int(validation.add_object_at_pos(item_id,next[item_id]).status)!=0:error="Quickbar item ID cannot be registered";return false
	quickbar=buttons;registry=next
	sync_disclosure_handles()
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

func apply_custom_token(message: Dictionary)->bool:
	if str(message.get("kind",""))!="custom-token" or not message.get("textBytes") is PackedByteArray:return false
	custom_tokens.apply(int(message.get("id",-1)),message.textBytes)
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

func player_spell_class(books: Dictionary,position: Variant)->Dictionary:
	if not position is int or position<0 or position>=8:return {"error":"Invalid native player spell-class position"}
	if not books.has(position):books[position]={"known":[],"memorized":{},"slots":{},"usesLeft":{}}
	return {"book":books[position]}

func apply_player_state(current: Dictionary,changes: Dictionary)->Dictionary:
	var result: Dictionary=current.duplicate(true)
	var c: Dictionary=changes.duplicate(true)
	var books: Dictionary=result.get("spellbooks",{})
	var has_books:=false
	for change in c.get("memorizedSlotCounts",[]):
		var found: Dictionary=player_spell_class(books,change.position)
		if found.has("error"):return found
		has_books=true
		var book: Dictionary=found.book
		var slots_by_level: Dictionary=book.get("slots",{})
		var memorized: Dictionary=book.get("memorized",{})
		for level_count in change.levels:
			var level:=int(level_count.level);var count:=int(level_count.count)
			if count<0:return {"error":"Invalid native memorized slot count"}
			slots_by_level[level]=count
			var slots: Array=memorized.get(level,[])
			slots.resize(count)
			memorized[level]=slots
		book.slots=slots_by_level;book.memorized=memorized;books[change.position]=book
	for change in c.get("knownSpellChanges",[]):
		var found: Dictionary=player_spell_class(books,change.position)
		if found.has("error"):return found
		has_books=true
		var book: Dictionary=found.book
		var known: Array=book.get("known",[])
		for id in change.removed:
			var index:=known.find(id)
			if index>=0:known.remove_at(index)
		known.append_array(change.added)
		book.known=known;books[change.position]=book
	for change in c.get("memorizedSpellChanges",[]):
		var found: Dictionary=player_spell_class(books,change.position)
		if found.has("error"):return found
		has_books=true
		var book: Dictionary=found.book
		var memorized: Dictionary=book.get("memorized",{})
		var slots_by_level: Dictionary=book.get("slots",{})
		for slot in change.removed:
			var level:=int(slot.level);var index:=int(slot.index)
			if level>=10:return {"error":"Invalid native prepared-spell level"}
			var slots: Array=memorized.get(level,[])
			if index>=0 and index<slots.size():slots[index]=null
			memorized[level]=slots
		for slot in change.added:
			var level:=int(slot.level);var index:=int(slot.index)
			if level>=10:return {"error":"Invalid native prepared-spell level"}
			if not slots_by_level.has(level) or index<0 or index>=int(slots_by_level[level]):return {"error":"Prepared-spell index exceeds server slot count"}
			var slots: Array=memorized.get(level,[])
			if slots.size()<=index:slots.resize(index+1)
			slots[index]=slot
			memorized[level]=slots
		book.memorized=memorized;books[change.position]=book
	for change in c.get("spontaneousUses",[]):
		var found: Dictionary=player_spell_class(books,change.position)
		if found.has("error"):return found
		has_books=true
		var book: Dictionary=found.book
		var uses: Dictionary=book.get("usesLeft",{})
		for level_count in change.levels:uses[int(level_count.level)]=level_count.count
		book.usesLeft=uses;books[change.position]=book
	if has_books:result.spellbooks=books
	if c.has("featChanges"):
		var feats: Array=result.get("feats",[])
		var bonus: Array=result.get("bonusFeats",[])
		for change in c.featChanges:
			var normal:=str(change.action) in ["A","D"]
			var chosen: Array=feats if normal else bonus
			if str(change.action) in ["A","B"]:chosen.append(change.feat)
			else:
				var index:=chosen.find(change.feat)
				if index>=0:chosen.remove_at(index)
			if normal:feats=chosen
			else:bonus=chosen
		result.feats=feats;result.bonusFeats=bonus
	if c.has("featUses"):
		var uses: Dictionary=result.get("featUses",{})
		for change in c.featUses:uses[change.feat]=change.uses
		result.featUses=uses
	if c.has("effectIcons"):
		var icons: Dictionary=result.get("effectIcons",{})
		var serials: Dictionary=result.get("effectIconSerials",{})
		var next_serial:=int(result.get("effectIconNextSerial",0))
		for icon in c.effectIcons.removed:
			icons.erase(icon);serials.erase(icon)
		for icon in c.effectIcons.added:
			icons[icon.icon]=icon.state
			serials[icon.icon]=next_serial
			next_serial+=1
		result.effectIcons=icons;result.effectIconSerials=serials;result.effectIconNextSerial=next_serial
	if c.has("specialAbilityChanges"):
		var abilities: Array=result.get("specialAbilities",[])
		for change in c.specialAbilityChanges:
			if str(change.action)=="S":
				var size:=int(change.size)
				if size<0:return {"error":"Invalid native special-ability size"}
				abilities.resize(size)
			else:
				var index:=int(change.index)
				if index<0 or index>=abilities.size():return {"error":"Special-ability index exceeds server size"}
				abilities[index]=change
		result.specialAbilities=abilities
	if c.has("visibilityChanges"):
		var visibility: Dictionary=result.get("visibility",{})
		for id in c.visibilityChanges.removed:visibility.erase(id)
		for change in c.visibilityChanges.updated:visibility[change.id]=change.flags
		result.visibility=visibility
	if c.has("actionQueueChanges"):
		var queue: Dictionary=ActionQueueState.merge_network_action_queue(result.get("actionQueue",[]),c.actionQueueChanges,int(result.get("actionQueueNextSerial",0)))
		if queue.has("error"):return queue
		result.actionQueue=queue.entries;result.actionQueueNextSerial=queue.nextSerial
		c.erase("actionQueueChanges")
	for key in ["memorizedSlotCounts","knownSpellChanges","memorizedSpellChanges","spontaneousUses","featChanges","featUses","effectIcons","specialAbilityChanges","visibilityChanges"]:c.erase(key)
	result.merge(c,true)
	return {"state":result}

class ImportCloneBatch:
	extends RefCounted
	var identifiers: Array = []
	var source_rows: Array[Dictionary] = []
	var copied_rows: Array[Dictionary] = []

	func run() -> void:
		copied_rows.resize(source_rows.size())
		for index in source_rows.size():
			copied_rows[index] = source_rows[index].duplicate(true)

func clone_import_registry() -> Dictionary:
	var next := registry.duplicate()
	if not parallel_import_clone_requested or registry.size()<1024 or OS.get_thread_caller_id()!=OS.get_main_thread_id() or OS.get_processor_count()<2:
		for object_id in registry:
			var row: Dictionary=registry[object_id]
			var kind:=int(row.objectType)
			next[object_id]=row.duplicate(kind!=9 and kind!=10)
		return next
	# This callback owns the registry until every task is joined. Jobs read
	# immutable rows during the copy and never see the destination dictionary,
	# clocks, entities, callbacks, disclosure state, or the scene tree.
	var batches: Array[ImportCloneBatch] = []
	var batch_count:=mini(4,OS.get_processor_count())
	for index in batch_count:
		batches.append(ImportCloneBatch.new())
	var deep_rows:=0
	for object_id in registry:
		var row: Dictionary=registry[object_id]
		var kind:=int(row.objectType)
		if kind==9 or kind==10:
			next[object_id]=row.duplicate(false)
		else:
			var batch:=batches[deep_rows%batch_count]
			batch.identifiers.append(object_id)
			batch.source_rows.append(row)
			deep_rows+=1
	if deep_rows<64:
		parallel_import_clone_fallbacks+=1
		for batch in batches:
			for index in batch.identifiers.size():
				next[batch.identifiers[index]]=batch.source_rows[index].duplicate(true)
		return next
	var tasks:=PackedInt64Array()
	for index in range(1,batch_count):
		var batch:=batches[index]
		var task:=WorkerThreadPool.add_task(batch.run,true,"Received world row copy")
		if task<0:
			batch.run()
		else:
			tasks.append(task)
	batches[0].run()
	var wait_began:=FrameProfile.begin()
	var completed:=true
	for task in tasks:
		if WorkerThreadPool.wait_for_task_completion(task)!=OK:completed=false
	FrameProfile.finish("network_import_clone_wait_ms",wait_began)
	var workers_used:=not tasks.is_empty() and completed
	parallel_import_clone_uses+=int(workers_used)
	if workers_used:
		FrameProfile.count("count_network_import_worker_packets",1)
		FrameProfile.count("count_network_import_worker_deep_rows",deep_rows)
		FrameProfile.count("count_network_import_worker_tasks",tasks.size())
	parallel_import_clone_task_count+=tasks.size()
	for batch in batches:
		if completed and batch.copied_rows.size()==batch.source_rows.size():
			for index in batch.identifiers.size():next[batch.identifiers[index]]=batch.copied_rows[index]
		else:
			parallel_import_clone_fallbacks+=1
			for index in batch.identifiers.size():next[batch.identifiers[index]]=batch.source_rows[index].duplicate(true)
	return next

func apply_updates(message: Dictionary)->bool:
	var phase_began:=FrameProfile.begin()
	for id in registry:
		if int(registry[id].get("objectType",0))==5 and not clock_handles.has(id):clock_handles[id]=ClockLifecycle.make_proxy(int(id))
	var transaction:=RefCounted.new()
	var clock_context: Dictionary={"transaction":transaction,"tracked":false,"prepared":false,"staged":{}}
	var actor_context: Dictionary={"tracked":message.get("complete") is bool,"historyComplete":actor_name_history_complete and message.get("complete")==true,"sequence":actor_name_sequence,"staged":{}}
	var begun: Dictionary=clock_lifecycle.begin(transaction,{"complete":bool(message.get("complete",false)),"recordCount":message.get("records",[]).size()})
	if begun.get("version")==1:clock_context.tracked=true
	else:reject_clock_observer(clock_context)
	FrameProfile.finish("network_import_clock_setup_ms",phase_began)
	var applied:=apply_updates_inner(message,clock_context,actor_context)
	if not applied:
		if bool(clock_context.tracked) or bool(clock_context.prepared):reject_clock_observer(clock_context)
		actor_name_history_complete=false
	return applied

func apply_updates_inner(message: Dictionary,clock_context: Dictionary,actor_context: Dictionary)->bool:
	world_diagnostics.clear()
	var phase_began:=FrameProfile.begin()
	# Each receive replaces the canonical root. Door and placeable nested
	# values keep the old shallow-copy rules and detach on writes.
	var next:=clone_import_registry()
	var views: Dictionary=inventories.duplicate(true)
	FrameProfile.finish("network_import_detach_ms",phase_began)
	phase_began=FrameProfile.begin()
	var touched: Dictionary={}
	var controlled:=local_object_id
	var events: Array[Dictionary]=[]
	var attack_records:=AttackAnimationRecords.new()
	var clock_index:=0
	for record in message.get("records",[]):
		var action:=str(record.get("action",""))
		var id:=int(record.get("id",0));var object_type:=int(record.get("objectType",0))
		var deferred_clock:=object_type==5 and action not in ["work-remaining","item-use-counts","inventory"]
		var current_clock_index:=clock_index
		clock_index+=1
		if not deferred_clock:observe_clock_record(clock_context,record,current_clock_index)
		if action=="work-remaining":events.append(record.duplicate(true));continue
		if action=="item-use-counts":
			for entry in record.get("entries",[]):
				var item_id:=int(entry.id)
				var current: Dictionary=next.get(item_id,{})
				if current.is_empty():current=registry.get(item_id,{})
				if int(current.get("objectType",0))!=6 or bool(current.get("replicationRemoved",false)):continue
				if not stage_object(next,item_id,6,{},touched):return false
				var item: Variant=next[item_id].get("item")
				if item is Dictionary:
					var kind: String=ItemUses.apply_client_item_uses(item,entry)
					next[item_id].item=item
					var event: Dictionary=entry.duplicate(true)
					event.action="item-use-count";event.kind=kind
					events.append(event)
			continue
		if action=="inventory":
			if not apply_inventory(next,views,record,controlled,events,clock_context,touched):return false
			continue
		if action=="delete" and not next.has(id):
			if deferred_clock:observe_clock_record(clock_context,record,current_clock_index,null,false,next)
			events.append(record.duplicate(true));continue
		var had_proxy: bool=clock_context.staged.has(id) or registry.has(id)
		if not stage_object(next,id,object_type,{},touched):return false
		if object_type==5:
			if not clock_context.staged.has(id):clock_context.staged[id]=ClockLifecycle.make_proxy(id)
			if deferred_clock:observe_clock_record(clock_context,record,current_clock_index,clock_context.staged[id],had_proxy,next)
		if not stage_actor_name_record(actor_context,record,had_proxy):return false
		var object: Dictionary=next[id]
		if action=="delete":
			object.clientSkillAdmission=null;object.replicationRemoved=true;object.deletionFlag=record.get("remove")
			events.append(record.duplicate(true))
			continue
		var state: Dictionary=record.get("state",{}).duplicate(true)
		if action=="create":
			if bool(object.get("replicationRemoved",false)):
				object.clientSkillAdmission=null
				next_object_lifetime+=1
				object.nativeLifetime=next_object_lifetime
				object.clientKnownLifetime=next_object_lifetime
			object.replicationRemoved=false
			if object_type==6:
				object.areaId=area_id
				object.inventoryLocation=null
				object.inventoryLocationStatus="current"
				object.equipmentOwnerId=null
				for channel in views:
					var view: Dictionary=views[channel]
					var retained: Array=[]
					for entry in view.get("entries",[]):
						if int(entry.get("id",-1))!=id:retained.append(entry)
					view.entries=retained
					views[channel]=view
				if state.has("item"):object.item=ItemUses.merge_network_item(object.get("item"),state.item);state.erase("item")
		if action=="appearance":
			var appearance: Dictionary=object.get("appearance",{}).duplicate(true)
			if state.has("bodyParts"):
				var parts: Dictionary={}
				for part in appearance.get("bodyParts",[]):parts[int(part.index)]=part.value
				for part in state.bodyParts:parts[int(part.index)]=part.value
				var indexes: Array=parts.keys()
				indexes.sort()
				var merged_parts: Array=[]
				for index in indexes:merged_parts.append({"index":index,"value":parts[index]})
				state.bodyParts=merged_parts
			if state.has("equipment"):
				var equipped: Dictionary={}
				for previous in appearance.get("equipment",[]):equipped[int(previous.slot)]=previous
				for change in state.equipment:
					var slot:=int(change.slot)
					if change.action=="D":
						equipped.erase(slot)
						EquipmentCache.set_client_equipment_slot(object,slot,null,func(item_id):return next.get(item_id))
					elif change.action=="A":
						var prior_item: Variant=next.get(int(change.id),registry.get(int(change.id),{})).get("item")
						var merged_item: Dictionary=ItemUses.merge_network_item(prior_item,change.item)
						if not stage_object(next,int(change.id),6,{"areaId":INVALID,"item":merged_item,"equipmentOwnerId":id},touched):return false
						EquipmentCache.set_client_equipment_slot(object,slot,next[int(change.id)],func(item_id):return next.get(item_id))
						change.item=merged_item
						equipped[slot]=change
					elif change.action=="U":
						if not next.has(int(change.id)):continue
						if not stage_object(next,int(change.id),6,{},touched):return false
						var item: Dictionary=ItemUses.merge_network_item(next[int(change.id)].get("item"),change.item)
						next[int(change.id)].item=item
						for equipped_slot in equipped:
							if int(equipped[equipped_slot].get("id",-1))==int(change.id):equipped[equipped_slot].item=item.duplicate(true)
					else:error="Unknown native equipment appearance change";return false
				state.equipment=equipped.values()
			appearance.merge(state,true);object.appearance=appearance
		elif action=="player-state":
			if state.has("skillFlags"):
				var player_admission: Dictionary=SkillAdmission.merge(object.get("clientSkillAdmission"),state,"player")
				if not player_admission.ok:error=str(player_admission.error);return false
				object.clientSkillAdmission=player_admission.value
			var player_result: Dictionary=apply_player_state(object.get("playerState",{}),state)
			if player_result.has("error"):error=str(player_result.error);return false
			if state.has("automap"):
				var area_state: Variant=next.get(area_id,{}).get("state")
				if not area_state is Dictionary:error="Native automap area is unavailable";return false
				var exploration: Dictionary=player_result.state.get("mapExploration",{})
				var prior: Variant=exploration.get(str(area_id),[])
				var map_result: Dictionary=NetworkAutomap.apply_network_automap(prior,state.automap,int(area_state.get("width",0)),int(area_state.get("height",0)))
				if map_result.has("error"):error=str(map_result.error);return false
				exploration[str(area_id)]=map_result.value
				player_result.state.mapExploration=exploration
			if state.has("abilities"):object.clientAbilityCache=NetworkSpellGain.merge_network_ability_cache(object.get("clientAbilityCache"),state,"player")
			object.playerState=player_result.state;controlled=id
		elif action=="inventory-stats":
			var stats: Dictionary=object.get("inventoryStats",{}).duplicate(true)
			if state.has("skills"):
				var inventory_admission: Dictionary=SkillAdmission.merge(object.get("clientSkillAdmission"),state,"inventory")
				if not inventory_admission.ok:error=str(inventory_admission.error);return false
				object.clientSkillAdmission=inventory_admission.value
			if state.has("fields70") or state.has("fields76") or state.has("fields7d"):object.clientAbilityCache=NetworkSpellGain.merge_network_ability_cache(object.get("clientAbilityCache"),state,"stats")
			if state.has("skills"):
				var skills: Dictionary={}
				for prior in stats.get("skills",[]):skills[int(prior.index)]=prior
				for received in state.skills:
					var index:=int(received.index)
					var merged: Dictionary=received.duplicate(true)
					if not bool(merged.get("flag",false)):merged.flag=skills.get(index,{}).get("flag",0)
					skills[index]=merged
				state.skills=skills.values()
			if state.has("featsRemoved") or state.has("featsAdded"):
				var feats: Dictionary={}
				for prior in stats.get("feats",[]):feats[int(prior.id)]=prior
				for removed in state.get("featsRemoved",[]):feats.erase(int(removed))
				for added in state.get("featsAdded",[]):feats[int(added.id)]=added
				state.feats=feats.values()
				state.erase("featsRemoved");state.erase("featsAdded")
			stats.merge(state,true);object.inventoryStats=stats
		elif action in ["create","update"]:
			if state.has("visualEffects"):
				events.append({"action":"visual-effects","id":id,"changes":state.visualEffects.duplicate(true)})
				state.erase("visualEffects")
			if object_type==5:
				if state.has("animation") and state.has("animationTime"):state.animationSpeed=state.animationTime
				if state.has("animation") and int(state.animation)==9 and action!="create":
					var projected: Array=attack_records.records(id,state.get("attacks"))
					if not attack_records.failure.is_empty():error=attack_records.failure;return false
					events.append({"action":"attack-animation","id":id,"animation":9,"speed":state.get("animationTime"),"records":projected})
					state.erase("attacks")
				elif state.has("animation") and CastAnimationRecords.release_base(int(state.animation))!=null and state.get("cast") is Dictionary:
					events.append({"action":"cast-animation","id":id,"animation":state.animation,"record":CastAnimationRecords.record(state.cast)})
				var changed:=false
				for key in MOVEMENT_TRIGGERS:
					if state.has(key):changed=true;break
				if changed:
					var motion: Dictionary={}
					for key in MOVEMENT_FIELDS:
						if state.has(key):motion[key]=state[key].duplicate(true) if state[key] is Array or state[key] is Dictionary else state[key]
					events.append({"action":"movement","id":id,"created":action=="create","changes":motion})
			var replicated: Dictionary=object.get("replicated",{});replicated.merge(state,true);object.replicated=replicated
			if object_type==6 and state.get("light") is Dictionary and state.light.has("field270"):
				var item: Dictionary=object.get("item",{})
				item.field2b8=state.light.field270
				item.field2c0=state.light.get("field278")
				object.item=item
			if object_type==5:
				NetworkAssociates.apply_network_associate_state(object,state,func(owner_id):
					var owner: Variant=next.get(owner_id)
					return owner if owner is Dictionary and int(owner.get("objectType",0))==5 and not bool(owner.get("replicationRemoved",false)) else null
				)
			if object_type==10 and state.has("animation"):
				var open_state: Variant=NetworkDoor.apply_open_state(replicated.get("doorOpenState"),int(state.animation),action=="create")
				if open_state!=null:replicated.doorOpenState=open_state
			if state.has("areaId"):object.areaId=state.areaId
		else:error="Unsupported native object-update action";return false
	FrameProfile.finish("network_import_reduce_ms",phase_began)
	phase_began=FrameProfile.begin()
	var validation:=GameObjectArray.new({"clientMode":true})
	for object_id in touched:
		if int(validation.add_object_at_pos(object_id,next[object_id]).status)!=0:error="Replicated object ID cannot be registered";return false
	if bool(clock_context.tracked):
		var boundaries: Array=clock_lifecycle.commit(clock_context.transaction,func(object_id):
			return clock_handles.get(object_id,clock_context.staged.get(object_id))
		)
		if not clock_lifecycle.error.is_empty():reject_clock_observer(clock_context)
		else:
			clock_context.prepared=true
			clock_context.boundaries=boundaries
	FrameProfile.finish("network_import_validate_ms",phase_began)
	phase_began=FrameProfile.begin()
	registry=next;inventories=views;presentation_changes=events
	sync_disclosure_handles()
	FrameProfile.finish("network_import_registration_ms",phase_began)
	phase_began=FrameProfile.begin()
	# Existing creature handles are registered before begin. Any new creature
	# row was staged by a creature record or the inventory owner update.
	for object_id in clock_context.staged:
		if not clock_handles.has(object_id):clock_handles[object_id]=clock_context.staged[object_id]
	for named_id in actor_context.staged:
		var canonical: Variant=clock_handles.get(named_id)
		var named: Variant=actor_context.staged[named_id]
		if canonical==null:continue
		if named is Dictionary:actor_name_states[named_id]={"handle":canonical,"value":named.duplicate(true)}
		else:actor_name_states.erase(named_id)
	if bool(clock_context.prepared):
		var published: Variant=clock_lifecycle.publish(clock_context.transaction)
		if published==null:reject_clock_observer(clock_context)
		else:clock_last_boundaries=published
	actor_name_sequence=int(actor_context.sequence)
	actor_name_history_complete=bool(actor_context.historyComplete)
	if local_object_id!=controlled:retire_barter();script_targeting=null
	local_object_id=controlled
	disclosures.observe_accepted(message.get("records",[]),func(object_id):return disclosure_handles.get(object_id))
	FrameProfile.finish("network_import_publish_ms",phase_began)
	return true

func summary()->Dictionary:
	var control_rows: Array[Dictionary]=[]
	for player_id in controls:control_rows.append({"playerId":player_id,"objectId":controls[player_id]})
	return {"areaId":area_id,"localObjectId":local_object_id,"entry":entry.duplicate(true) if not entry.is_empty() else null,"time":time.duplicate(true),"objects":registry.size(),"controls":control_rows}

func presentation(prepare_area: bool=false)->Dictionary:
	return _project_presentation(prepare_area,null)

func _project_presentation(prepare_area: bool,static_rows: RawWorldDeltas.StaticRows)->Dictionary:
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
	sync_disclosure_handles()
	var object_rows: Array=[]
	for object_id in registry:
		var source: Dictionary=registry[object_id]
		var clock_owner: Variant=clock_owner_transport(int(object_id))
		var proof_static:=static_rows!=null and int(source.objectType) in [9,10]
		# Static nested state is replaced on staged writes. The private
		# planner detaches upserts before the presentation reaches consumers.
		var borrow_nested:=proof_static and static_rows.borrows_static_nested and clock_owner==null and source.get("replicated") is Dictionary
		var wire: Dictionary=source.duplicate(not borrow_nested)
		wire.nativeClockOwner=clock_owner
		wire.clientKnownLifetime=disclosures.token(disclosure_handles[object_id],wire)
		if proof_static:static_rows.capture(source,wire)
		object_rows.append(wire)
	if static_rows!=null:static_rows.objects=object_rows
	return {"area":area.duplicate(true),"objects":object_rows,"controlledId":local_object_id,"entry":entry.duplicate(true),"time":time.duplicate(true),"module":module.duplicate(true),"inventory":{"inventories":inventory_rows,"containers":container_rows,"windows":inventory_window_snapshot(),"store":store.duplicate(true) if store is Dictionary else null},"ui":{"players":player_rows,"playerRosterKnown":player_roster_known,"gameMasterPermission":game_master_permission.duplicate(true) if game_master_permission is Dictionary else null,"party":party.duplicate(true),"partyListRevision":party_list_revision,"partyInviteNotice":party_invite_notice.duplicate(true) if party_invite_notice is Dictionary else null,"barter":barter.duplicate(true) if barter is Dictionary else {},"quickbar":quickbar.duplicate(true),"journal":journal_view,"mapPins":map_pin_rows,"playerAttitudes":attitudes,"timing":timing.duplicate(true) if timing is Dictionary else null,"scriptTargeting":script_targeting.duplicate(true) if script_targeting is Dictionary else null,"scriptTargetingData":script_targeting_data.duplicate(true) if script_targeting_data is Dictionary else null,"spellTargetingOverrides":spell_targeting_overrides.duplicate(true),"tlkOverrides":tlk_overrides.duplicate(true),"tlkOverrideVersion":tlk_override_version}}
