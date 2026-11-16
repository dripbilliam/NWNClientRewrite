extends RefCounted
# Presentation handoff for decoded server 22/0 and 26/1. The existing Godot
# creature_voice_world owns SSF asset loading and the actual audio source.
const Ssf=preload("res://systems/native_data/sound_set.gd")
var area_id: int=-1
var area_generation: int=-1
var epoch:=0
var sequence:=0
var actor_versions: Dictionary={}
var admitted: Dictionary={}

func begin_area(id: int,generation: int)->void:
	area_id=id;area_generation=generation;epoch+=1;sequence=0
	actor_versions.clear();admitted.clear()

func receive(message: Dictionary,actor: Dictionary)->Dictionary:
	if area_id<0 or area_generation<0:return {"accepted":false,"reason":"No current area."}
	var quick: bool=message.get("kind")=="quick-chat" and message.get("major")==22 and message.get("minor")==0
	var voice: bool=message.get("kind")=="voice-play" and message.get("major")==26 and message.get("minor")==1
	if not quick and not voice or not message.get("objectId") is int:return {"accepted":false,"reason":"Not a decoded creature voice packet."}
	var id: int=message.objectId
	var code: Variant=message.get("quickChat") if quick else message.get("voiceCode")
	if id<0 or id>4294967295 or not code is int or int(code)<0 or int(code)>(65535 if quick else 255):return {"accepted":false,"reason":"Invalid creature voice identity or code."}
	if not _actor_matches(id,actor) or _soundset(actor)==65535:return {"accepted":false,"reason":"Creature voice actor is stale or has no soundset."}
	sequence+=1
	var ticket: Dictionary={"epoch":epoch,"areaId":area_id,"generation":area_generation,"objectId":id,"lifetime":int(actor.nativeLifetime),"soundsetId":_soundset(actor),"actorVersion":int(actor_versions.get(id,0)),"sequence":sequence,"code":int(code),"quickChat":quick}
	return {"accepted":true,"ticket":ticket}

func prepare(ticket: Dictionary,actor: Dictionary,soundset: Dictionary)->Dictionary:
	if not current(ticket,actor):return {"ready":false,"reason":"Creature voice request is stale."}
	if not soundset.get("count") is int or not soundset.get("entries") is Array or int(soundset.count)<0 or int(soundset.count)>1000000 or soundset.entries.size()!=int(soundset.count):return {"ready":false,"reason":"Decoded SSF entries are unavailable."}
	var entry: Variant=Ssf.entry(soundset,int(ticket.code))
	if not entry is Dictionary:return {"ready":true,"caption":{},"audio":{}}
	var caption: Dictionary={}
	var str_ref: int=int(entry.get("strRef",4294967295))
	if bool(ticket.quickChat) and str_ref>=0 and str_ref<4294967295:
		caption={"actorId":int(ticket.objectId),"strRef":str_ref,"voiceCode":int(ticket.code)}
	var resource:=str(entry.get("resRef",""))
	var audio: Dictionary={"resRef":resource,"sequence":int(ticket.sequence)} if not resource.is_empty() else {}
	return {"ready":true,"caption":caption,"audio":audio}

func admit_audio(ticket: Dictionary,actor: Dictionary,audio: Dictionary,wave_exists: bool,controlled: bool,player: bool,size_category: int)->Dictionary:
	if not current(ticket,actor) or not wave_exists or audio.is_empty() or str(audio.get("resRef","")).is_empty() or int(audio.get("sequence",-1))!=int(ticket.get("sequence",-2)):
		return {"ready":false,"reason":"Voice resource or actor is unavailable."}
	var id: int=ticket.objectId
	if int(ticket.sequence)<int(admitted.get(id,-1)):return {"ready":false,"reason":"A newer creature voice was admitted."}
	admitted[id]=int(ticket.sequence)
	var quick: bool=ticket.quickChat
	var priority:=6 if controlled else 7 if quick or player else 15 if size_category<4 else 14
	return {"ready":true,"play":{"actorId":id,"lifetime":int(ticket.lifetime),"soundsetId":int(ticket.soundsetId),"code":int(ticket.code),"resRef":str(audio.resRef),"quickChat":quick,"positional":1,"priority":priority,"height":0.0 if quick else 1.5,"replace":true}}

func current(ticket: Dictionary,actor: Dictionary)->bool:
	return int(ticket.get("epoch",-1))==epoch and int(ticket.get("areaId",-1))==area_id and int(ticket.get("generation",-1))==area_generation and _actor_matches(int(ticket.get("objectId",-1)),actor) and int(ticket.get("lifetime",-1))==int(actor.nativeLifetime) and int(ticket.get("soundsetId",-1))==_soundset(actor) and int(ticket.get("actorVersion",-1))==int(actor_versions.get(int(ticket.objectId),0))

func forget_actor(id: int)->void:
	actor_versions[id]=int(actor_versions.get(id,0))+1
	admitted.erase(id)

func reset()->void:
	area_id=-1;area_generation=-1;epoch+=1;sequence=0
	actor_versions.clear();admitted.clear()

func snapshot()->Dictionary:
	return {"areaId":area_id,"generation":area_generation,"epoch":epoch,"sequence":sequence,"admitted":admitted.duplicate()}

func _actor_matches(id: int,actor: Dictionary)->bool:
	return id>=0 and actor.get("id") is int and int(actor.id)==id and int(actor.get("objectType",0))==5 and not bool(actor.get("replicationRemoved",false)) and int(actor.get("areaId",-1))==area_id and actor.get("nativeLifetime") is int

static func _soundset(actor: Dictionary)->int:
	var appearance: Variant=actor.get("appearance",{})
	return int(appearance.get("field8A0",65535))&65535 if appearance is Dictionary else 65535
