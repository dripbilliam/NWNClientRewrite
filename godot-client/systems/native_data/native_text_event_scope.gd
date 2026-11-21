extends RefCounted
# Received text provenance only. The World remains the sole canonical object,
# disclosure, roster, clock and actor-name owner.
const MAX_SAFE:=9007199254740991
const MAX_ID:=4294967295
const HIGH=[0x20ac,0x81,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x8d,0x17d,0x8f,0x90,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x9d,0x17e,0x178]
var serial:=0

static func integer(value: Variant,low: int,high: int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high

static func byte_projection(value: Variant)->Variant:
	if not value is String:return null
	var bytes: Array=[]
	for at in value.length():
		var point: int=value.unicode_at(at)
		var slot: int=HIGH.find(point)
		if slot>=0:bytes.append(slot+128)
		elif point<128 or point>=160 and point<=255:bytes.append(point)
		else:return null
	return {"bytes":bytes}

static func name_bytes(value: Variant)->Variant:
	if value is String:return byte_projection(value)
	if not value is Dictionary:return null
	if value.get("text") is String:return byte_projection(value.text)
	if value.has("firstName") or value.has("lastName"):
		var result: Dictionary={}
		for key in ["firstName","lastName"]:
			if value.has(key):result[key]=name_bytes(value[key])
		return result
	return value.duplicate(true)

static func source_id(message: Dictionary)->Dictionary:
	if message.get("kind")=="server-speech":return {"supported":true,"id":message.get("objectId")}
	if message.get("kind")=="combat-feedback" and message.get("type") in [93,94]:
		var data: Variant=message.get("data")
		var objects: Variant=data.get("objects") if data is Dictionary else null
		return {"supported":true,"id":objects.get("0") if objects is Dictionary else null}
	return {"supported":false}

static func source_reference(world: RefCounted,selected_id: Variant,area_id: Variant)->Variant:
	if not integer(selected_id,0,MAX_ID):return null
	var row: Variant=world.registry.get(int(selected_id))
	if not row is Dictionary or row.get("id")!=selected_id:return null
	var object_type: Variant=row.get("objectType")
	var object_area: Variant=row.get("areaId")
	if object_type!=null and not integer(object_type,1,MAX_ID):return null
	if object_area!=null and not integer(object_area,0,MAX_ID):return null
	if object_area!=null and area_id!=null and object_area!=area_id or row.get("replicationRemoved")==true:return null
	var lifetime: Variant=row.get("nativeLifetime")
	if not integer(lifetime,1,MAX_SAFE):return null
	var handle: Variant=world.disclosure_handles.get(int(selected_id))
	var known: Variant=world.disclosures.token(handle,row)
	if not integer(known,1,MAX_SAFE):return null
	return {"id":int(selected_id),"objectType":object_type,"areaId":object_area,"nativeLifetime":int(lifetime),"knownLifetime":int(known)}

static func actor_name(world: RefCounted,source: Variant)->Variant:
	if not source is Dictionary or source.get("objectType")!=5:return null
	var id: int=int(source.id)
	var row: Variant=world.registry.get(id)
	if not row is Dictionary or row.get("id")!=id or row.get("objectType")!=5:return null
	var saved: Variant=world.actor_name_states.get(id)
	var state: Variant=saved.get("value") if saved is Dictionary and saved.get("handle")==world.clock_handles.get(id) else null
	return {"version":1,"historyComplete":world.actor_name_history_complete,"state":state.duplicate(true) if state is Dictionary else null}

static func token_context(world: RefCounted,source: Variant)->Variant:
	if not source is Dictionary:return null
	var object: Variant=world.registry.get(int(source.id))
	if not object is Dictionary:return null
	var row: Dictionary={"id":source.id,"objectType":source.objectType,"areaId":source.areaId,"nativeLifetime":source.nativeLifetime,"clientKnownLifetime":source.knownLifetime}
	for section in ["replicated","appearance"]:
		var raw: Variant=object.get(section)
		if not raw is Dictionary:continue
		var selected: Dictionary={}
		if raw.has("name"):selected.name=name_bytes(raw.name)
		if section=="replicated" and raw.get("stats") is Dictionary:
			var stats: Dictionary={}
			for key in ["race","racialType","fieldD20","fieldD28","fieldE58","fieldDE4","fieldDE6"]:
				if not raw.stats.has(key):continue
				var value: Variant=raw.stats[key]
				if value==null or value is String or value is int or value is float or value is bool:
					stats[key]=byte_projection(value) if key in ["fieldD28","fieldE58"] else value
			if raw.stats.get("classes") is Array:
				stats.classes=[]
				if not raw.stats.classes.is_empty():
					var first: Variant=raw.stats.classes[0]
					var entry: Dictionary={}
					if first is Dictionary:
						for key in ["id","level"]:
							if first.has(key):entry[key]=first[key]
					stats.classes.append(entry)
			selected.stats=stats
		row[section]=selected
	return row

func capture(world: RefCounted,message: Dictionary,generation: int,connection: int)->Dictionary:
	var selected: Dictionary=source_id(message)
	if not selected.supported:return {"supported":false}
	var area_id: Variant=world.area_id
	if not integer(connection,0,MAX_SAFE) or not integer(generation,0,MAX_SAFE) or area_id!=null and not integer(area_id,0,MAX_ID) or serial>=MAX_SAFE:
		return {"error":"Invalid native text event scope"}
	serial+=1
	var source: Variant=source_reference(world,selected.id,area_id)
	var event: Dictionary={"version":1,"serial":serial,"connection":connection,"generation":generation,"areaId":area_id,"source":source,"nativeByteProjection":"windows-1252","nativeWorld":{}}
	var time: Variant=world.time
	if time is Dictionary:
		for pair in [["native160","year"],["native164","month"],["native16c","hour"],["native17c","dawn"],["native17d","dusk"]]:
			var value: Variant=time.get(pair[1])
			if integer(value,0,MAX_ID if pair[1]=="year" else 255):event.nativeWorld[pair[0]]=int(value)
	event.nativePlayers={}
	event.nativePlayersComplete=world.player_roster_known==true
	for player_id in world.players:
		if not integer(player_id,0,MAX_ID):continue
		var player: Variant=world.players[player_id]
		var name: Variant=byte_projection(player.get("name") if player is Dictionary else null)
		var entry: Dictionary={"known":true,"present":true}
		if name!=null:entry.name=name
		event.nativePlayers[player_id]=entry
	if message.get("kind")=="server-speech":
		var speaker_name: Variant=actor_name(world,source)
		if speaker_name!=null:event.actorName=speaker_name
		if message.get("channel") in [11,12]:
			event.context=source_reference(world,message.get("contextId"),area_id)
			event.contextData=token_context(world,event.context)
			var context_name: Variant=actor_name(world,event.context)
			if context_name!=null:event.contextActorName=context_name
	return {"ready":true,"value":event}
