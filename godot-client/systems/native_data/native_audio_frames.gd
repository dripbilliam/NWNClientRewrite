extends RefCounted
# Fresh decoded script sound transport. Audio class, cue, resource and playback
# remain owned by ScriptSoundWorld on the Godot scene side.
var script_serial:=0
var voice_serial:=0

func script_sound(world: RefCounted,message: Dictionary,generation: int,connection: int)->Dictionary:
	if message.get("kind")!="script-sound":return {}
	var object: Variant=world.registry.get(message.get("objectId"))
	if not object is Dictionary or bool(object.get("replicationRemoved",false)):return {}
	if object.get("areaId")!=world.area_id and not (object.get("objectType")==4 and object.get("id")==world.area_id) and object.get("objectType")!=3:return {}
	var source: Dictionary={"id":object.get("id"),"objectType":object.get("objectType"),"lifetime":object.get("nativeLifetime")}
	for field in ["replicated","staticState","lightState","state","mapPin"]:
		var section: Variant=object.get(field)
		if section is Dictionary and section.has("position"):
			var position: Variant=section.position
			source[field]={"position":position.duplicate(true) if position is Dictionary or position is Array else position}
	var event: Dictionary={"source":source}
	if message.has("soundBytes"):
		event.soundBytes=Array(message.soundBytes)
	else:event.sound=message.get("sound")
	script_serial+=1
	return {"kind":"raw-script-sounds","connection":connection,"generation":generation,"areaId":world.area_id,"serial":script_serial,"events":[event]}

func voice(world: RefCounted,message: Dictionary,generation: int,connection: int)->Dictionary:
	if message.get("kind")!="voice-play":return {}
	var object: Variant=world.registry.get(message.get("objectId"))
	if not object is Dictionary or object.get("objectType")!=5 or bool(object.get("replicationRemoved",false)) or object.get("areaId")!=world.area_id:return {}
	var appearance: Variant=object.get("appearance")
	var soundset: int=int(appearance.get("field8A0",65535))&65535 if appearance is Dictionary else 65535
	voice_serial+=1
	return {"kind":"raw-voice-events","connection":connection,"generation":generation,"areaId":world.area_id,"serial":voice_serial,"events":[{"objectId":message.objectId,"voiceCode":int(message.get("voiceCode",0))&255,"lifetime":object.get("nativeLifetime"),"soundsetId":soundset}]}
