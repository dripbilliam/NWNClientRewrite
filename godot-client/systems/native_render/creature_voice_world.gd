extends RefCounted
# Native actor-owned source+e8: original SSF, voice gate and source replacement.
# Only decoded protocol identities and combat bark codes enter this owner.
const Voice=preload("res://systems/native_data/creature_voice.gd")
const Ssf=preload("res://systems/native_data/sound_set.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Fields=preload("res://systems/native_data/combat_actor.gd")
const Sound=preload("res://systems/world_sound_state.gd")
const NetworkVoice=preload("res://systems/native_data/native_creature_voice_owner.gd")
var manager
var combat
var assets
var table: Dictionary={}
var table_failed:=false
var table_error: String=""
var table_type_ready:=false
var jobs: Dictionary={}
var sets: Dictionary={}
var waves: Dictionary={}
var requested: Dictionary={}
var records: Dictionary={}
var actor_references: Dictionary={}
var players: Dictionary={}
var queue: Array=[]
var history: Array=[]
var serial:=0
var wire_serial:=-1
var closed:=false
var retiring:=false
var stats:={"requested":0,"started":0,"replaced":0,"destroyed":0,"suppressed":0,"stale":0,"failed":0,"overflow":0,"set_imports":0}
var network_voice=NetworkVoice.new()
func configure(owner) -> void:
	manager=owner; combat=manager.world.get("combat")
	manager.world_audio.voice_object_lookup=Callable(self,"current_actor")
	network_voice.begin_area(int(manager.world.area_id),int(manager.world.generation))
	if is_instance_valid(combat): combat.engine.presentation_event.connect(combat_event)
	assets=Assets.new(); manager.add_child(assets); assets.configure(manager.world.catalog); assets.cache_directory=manager.world.cache_path; assets.maximum_workers=1; assets.completed.connect(prepared)
	request_tables()
func request_tables() -> void:
	if closed or retiring or jobs.values().has("@table") or jobs.values().has("@table-type"):return
	table_failed=false;table_type_ready=false;table_error="";table={}
	var job: int=assets.request("soundset",2017,"2da")
	if job>=0: jobs[job]="@table"
	else: table_failed=true;table_error=assets.failure; diagnose(assets.failure,0)
	job=assets.request("soundsettype",2017,"2da")
	if job>=0:jobs[job]="@table-type"
	else:table_failed=true;table_error=assets.failure;diagnose(assets.failure,0)
func diagnose(reason: String,id: int) -> void:
	stats.failed+=1; manager.diagnose("voice.native-resource-unavailable",reason,id)
func event(kind: String,detail: Dictionary) -> void:
	if history.size()>=64: history.pop_front()
	var row:={"kind":kind}; row.merge(detail); history.append(row)
func prepared(job: int,result: Dictionary) -> void:
	if closed or retiring or not jobs.has(job): return
	var name: String=jobs[job]; jobs.erase(job)
	if name=="@table":
		if not str(result.error).is_empty():table_failed=true;table_error=str(result.error);diagnose(table_error,0)
		else: table=result.value
		return
	if name=="@table-type":
		table_type_ready=str(result.error).is_empty()
		if not table_type_ready:table_failed=true;table_error=str(result.error);diagnose(table_error,0)
		return
	if name.begins_with("@wave:"):
		waves[name.substr(6)]={"state":"failed" if not str(result.error).is_empty() else "ready","error":str(result.error)}
		return
	sets[name]={"data":result.get("value",{}),"error":str(result.error),"bytes":result.get("bytes",PackedByteArray()).size(),"last":serial}; stats.set_imports+=1
	if not str(result.error).is_empty(): diagnose(name+": "+str(result.error),0)
func set_players(rows: Array) -> void:
	players.clear()
	for row in rows:
		var value: Variant=row[1] if row is Array and row.size()==2 else row
		if value is Dictionary and value.has("objectId"): players[int(value.objectId)]=true
func combat_event(value: Dictionary) -> void:
	if not closed and not retiring and value.kind=="bark": request(int(value.id),int(value.code),1)
func current_actor(id: int) -> Variant:
	var actor: Variant=manager.world.raw_object_lookup.call(id) if is_instance_valid(manager.world) and manager.world.raw_object_lookup.is_valid() else manager.object(id)
	if not actor is Dictionary or int(actor.get("objectType",0))!=5 or bool(actor.get("replicationRemoved",false)) or int(actor.get("areaId",-1))!=int(manager.world.area_id):return null
	if actor_references.has(id) and not is_same(actor_references[id],actor):forget(id)
	actor_references[id]=actor
	return actor
func wave_probe(ref: String) -> Dictionary:
	if waves.has(ref):return waves[ref]
	var job: int=assets.request(ref,4,"bytes")
	if job>=0:jobs[job]="@wave:"+ref;waves[ref]={"state":"pending","error":""}
	else:waves[ref]={"state":"failed","error":assets.failure}
	return waves[ref]
func receive_raw(message: Dictionary) -> void:
	if closed or retiring or int(message.get("serial",-1))<=wire_serial: return
	wire_serial=int(message.serial)
	for value in message.get("events",[]): request(int(value.objectId),int(value.voiceCode)&255,1,int(value.lifetime),int(value.soundsetId))
func receive_network(message: Dictionary,caption_sink: Callable=Callable(),transport_connection: int=-1) -> Dictionary:
	if closed or retiring:return {"accepted":false,"reason":"Creature voice owner is retiring."}
	if table_failed:request_tables()
	if message.get("kind")=="quick-chat" and (not caption_sink.is_valid() or transport_connection<0):return {"accepted":false,"reason":"Quick-chat caption scope is unavailable."}
	if queue.size()>=256:stats.overflow+=1;return {"accepted":false,"reason":"Creature voice queue is full."}
	var id: int=int(message.get("objectId",-1));var object: Variant=current_actor(id)
	if not object is Dictionary:stats.stale+=1;return {"accepted":false,"reason":"Creature voice actor is unavailable."}
	var actor: Dictionary=object.duplicate(true)
	actor.areaId=int(manager.world.area_id)
	var admitted: Dictionary=network_voice.receive(message,actor)
	if not admitted.get("accepted",false):stats.stale+=1;return admitted
	var ticket: Dictionary=admitted.ticket
	serial+=1
	queue.append({"id":id,"code":int(ticket.code),"positional":1,"lifetime":int(ticket.lifetime),"soundset":int(ticket.soundsetId),"sequence":serial,"networkTicket":ticket,"captionSink":caption_sink,"captionConnection":transport_connection,"captionSent":false})
	stats.requested+=1
	return {"accepted":true,"sequence":int(ticket.sequence)}
func request(id: int,code: int,positional: int=1,lifetime: int=0,soundset: int=-1) -> void:
	if closed or retiring: return
	if table_failed:request_tables()
	var object: Variant=current_actor(id)
	if object==null and lifetime<=0: stats.stale+=1; return
	if object!=null and int(object.get("objectType",0))!=5: stats.suppressed+=1; return
	if queue.size()>=256: stats.overflow+=1; return
	serial+=1
	queue.append({"id":id,"code":code&65535,"positional":positional,"lifetime":lifetime if lifetime>0 else int(object.get("nativeLifetime",0)),"soundset":soundset if soundset>=0 else int(object.get("appearance",{}).get("field8A0",65535))&65535,"sequence":serial})
	stats.requested+=1
func valid(r: Dictionary) -> bool:
	var object: Variant=current_actor(int(r.id))
	return object!=null and int(object.get("objectType",0))==5 and int(object.get("nativeLifetime",0))==int(r.lifetime)
func position_for(object: Dictionary) -> Variant:
	var host=manager.host(int(object.id))
	if is_instance_valid(host):
		var p: Vector3=host.global_position
		return [p.x,-p.z,p.y]
	return object.get("replicated",{}).get("position")
func create_source(resource: String,actor_id: int) -> Variant:
	var id: int=manager.world_audio.create_sound(resource,0,actor_id,"voice")
	return id if id>=0 else null
func advance() -> void:
	if closed or retiring: return
	for id in records.keys():
		if not valid(records[id]): forget(int(id)); stats.stale+=1
		elif records[id].sound!=null:
			# Original8114d0 updates the still-owned +e8 source at height1.5,
			# including finished/nonpositional sources. Follow the current actor
			# pose rather than leaving voices at their initial request location.
			var point: Variant=position_for(current_actor(int(id)))
			if point is Array and point.size()==3: manager.world_audio.move(int(records[id].sound),point,1.5)
	var waiting: Array=[]
	var failed_sets: Dictionary={}
	var failed_waves: Dictionary={}
	for q in queue:
		var object: Variant=current_actor(int(q.id))
		if q.has("networkTicket"):
			if not object is Dictionary:stats.stale+=1;continue
			var actor: Dictionary=object.duplicate(true);actor.areaId=int(manager.world.area_id)
			if not network_voice.current(q.networkTicket,actor):stats.stale+=1;continue
		if object==null or int(object.get("nativeLifetime",0))<int(q.lifetime): waiting.append(q); continue
		if int(object.get("nativeLifetime",0))!=int(q.lifetime) or int(object.get("objectType",0))!=5 or (int(object.get("appearance",{}).get("field8A0",65535))&65535)!=int(q.soundset): stats.stale+=1; continue
		if int(q.soundset)==65535:stats.suppressed+=1;continue
		if table_failed:
			manager.diagnose("network.voice-resource-failed",table_error,int(q.id),{"voiceCode":int(q.code)})
			stats.suppressed+=1
			continue
		if table.is_empty() or not table_type_ready or not manager.tables.has("appearance"): waiting.append(q); continue
		var rows: Array=table.get("orderedRows",[])
		if int(q.soundset)>=(rows.size()&65535): manager.diagnose("network.voice-soundset-invalid","Native soundset index exceeds the active table",int(q.id)); stats.suppressed+=1; continue
		var name:=Sound.resource_ref(str(rows[int(q.soundset)].get("RESREF",""))).to_lower()
		if name in ["","****"]: stats.suppressed+=1; continue
		if not sets.has(name):
			if not requested.has(name):
				var job: int=assets.request(name,2060,"ssf-native-v1")
				if job>=0: jobs[job]=name; requested[name]=true
				else:sets[name]={"data":{},"error":assets.failure,"bytes":0,"last":int(q.sequence)}
			if not sets.has(name):waiting.append(q);continue
		if not str(sets[name].error).is_empty():
			failed_sets[name]=true
			manager.diagnose("network.voice-resource-failed",str(sets[name].error),int(q.id),{"voiceCode":int(q.code)})
			stats.suppressed+=1
			continue
		sets[name].last=int(q.sequence)
		var data: Dictionary=sets[name].data
		if (int(q.code)&65535)>=int(data.get("count",0)):
			manager.diagnose("voice.sound-id-invalid","Native soundset sound ID is beyond its array",int(q.id),{"soundsetId":int(q.soundset),"voiceCode":int(q.code)&65535,"count":int(data.get("count",0))});stats.suppressed+=1;continue
		var sound_entry: Variant=Ssf.entry(data,int(q.code))
		if sound_entry is Dictionary and sound_entry.has("error"):
			manager.diagnose("network.voice-resource-failed",str(sound_entry.error),int(q.id),{"voiceCode":int(q.code)});stats.suppressed+=1;continue
		var network_prepared: Dictionary={}
		if q.has("networkTicket"):
			var current_actor: Dictionary=object.duplicate(true);current_actor.areaId=int(manager.world.area_id)
			network_prepared=network_voice.prepare(q.networkTicket,current_actor,sets[name].data)
			if not network_prepared.get("ready",false):stats.stale+=1;continue
			if not bool(q.captionSent) and not network_prepared.caption.is_empty():
				if q.captionSink is Callable and q.captionSink.is_valid():
					var caption: Dictionary=network_prepared.caption.duplicate(true)
					caption.merge({"areaId":int(manager.world.area_id),"generation":int(manager.world.generation),"lifetime":int(q.lifetime),"connection":int(q.captionConnection),"waitForCompletion":true},true)
					var caption_result: Variant=q.captionSink.call(caption)
					if caption_result is Dictionary and bool(caption_result.get("pending",false)):
						waiting.append(q)
						continue
					if caption_result is Dictionary and bool(caption_result.get("retired",false)):stats.stale+=1;continue
					if caption_result is Dictionary and not caption_result.get("ready",false):manager.diagnose("network.voice-caption-failed",str(caption_result.get("reason","Voice caption could not be published")),int(q.id),{"voiceCode":int(q.code)})
				q.captionSent=true
				var current_after_caption: Dictionary=object.duplicate(true);current_after_caption.areaId=int(manager.world.area_id)
				if not network_voice.current(q.networkTicket,current_after_caption):stats.stale+=1;continue
			if network_prepared.audio.is_empty():stats.suppressed+=1;continue
		var raw_ref:=""
		if q.has("networkTicket"):raw_ref=str(network_prepared.audio.resRef)
		elif sound_entry is Dictionary:raw_ref=str(sound_entry.get("resRef",""))
		var res_ref:=Sound.resource_ref(raw_ref).to_lower()
		if res_ref.is_empty():stats.suppressed+=1;continue
		var wave: Dictionary=wave_probe(res_ref)
		if str(wave.state)=="pending":waiting.append(q);continue
		if str(wave.state)!="ready":
			failed_waves[res_ref]=true
			manager.diagnose("network.voice-wave-unavailable",str(wave.get("error","Native voice wave is unavailable")),int(q.id),{"resRef":res_ref});stats.suppressed+=1;continue
		var position: Variant=position_for(object)
		if not position is Array or position.size()!=3: waiting.append(q); continue
		if not records.has(int(q.id)): records[int(q.id)]={"id":q.id,"lifetime":q.lifetime,"soundsetId":q.soundset,"sound":null,"delay":0,"validSequence":-1,"height":1.5}
		var r: Dictionary=records[int(q.id)]
		if int(q.sequence)<int(r.validSequence): stats.stale+=1; continue
		r.soundsetId=q.soundset
		var admitted: Array=[false]; var old: Variant=r.sound
		var destroy_sound: Callable=func(sound):
			event("replace",{"objectId":int(q.id),"sound":manager.world_audio.voices.get(int(sound),{}).duplicate(true)})
			manager.world_audio.destroy(int(sound))
		var providers:={"demandSet":func(_id):return data,"entry":func(sound_set,code):return Ssf.entry(sound_set,code),"releaseSet":func(_data):pass,
			"exists":func(resource):admitted[0]=waves.get(Sound.resource_ref(str(resource)).to_lower(),{}).get("state","")=="ready"; return admitted[0],"controlled":func():return int(q.id)==int(manager.world.controlled_id),"player":func():return players.has(int(q.id)),
			"sizeCategory":func():return Fields.integer(manager.tables.appearance,int(object.appearance.appearance),"SIZECATEGORY"),"destroySound":destroy_sound,"createSound":func(resource):return create_source(str(resource),int(q.id)),
			"sound3d":func(sound,value):manager.world_audio.setting(int(sound),"setting1401d9e90",int(value)),"soundPriority":func(sound,value):manager.world_audio.setting(int(sound),"setting1401da060",int(value)),
			"position":func():return position,"updateSound":manager.world_audio.move,"playSound":manager.world_audio.play}
		var started:=false
		if q.has("networkTicket"):
			var current_actor: Dictionary=object.duplicate(true);current_actor.areaId=int(manager.world.area_id)
			var size_category: int=Fields.integer(manager.tables.appearance,int(object.appearance.appearance),"SIZECATEGORY")
			var ready: Dictionary=network_voice.admit_audio(q.networkTicket,current_actor,network_prepared.audio,true,int(q.id)==int(manager.world.controlled_id),players.has(int(q.id)),size_category)
			if ready.get("ready",false):
				var play: Dictionary=ready.play
				r.validSequence=int(q.sequence)
				r.height=float(play.height)
				started=Voice.start(r,str(play.resRef),{"positional":int(play.positional),"priority":int(play.priority),"height":float(play.height)},providers)
		else:
			started=Voice.play(r,int(q.code),int(q.positional),providers)
			if started:r.height=1.5
		if admitted[0]: r.validSequence=q.sequence
		if started:
			stats.started+=1; stats.replaced+=int(old!=null)
			var controlled:=int(q.id)==int(manager.world.controlled_id)
			var quick_chat: bool=q.has("networkTicket") and bool(q.networkTicket.quickChat)
			var voice_priority:=6 if controlled else 7 if quick_chat or players.has(int(q.id)) else 15 if Fields.integer(manager.tables.appearance,int(object.appearance.appearance),"SIZECATEGORY")<4 else 14
			event("voice",{"objectId":int(q.id),"voiceCode":int(q.code),"soundsetId":int(q.soundset),"quickChat":quick_chat,"resRef":res_ref,"priority":voice_priority})
		else: stats.suppressed+=1
		event("request",{"actor":q.id,"code":q.code,"set":q.soundset,"sequence":q.sequence,"started":started,"sound":r.sound})
	queue=waiting
	# The old rejected SSF promise is removed after its waiting requests see the
	# failure, so a later voice request can fetch that resource again.
	for name in failed_sets:
		sets.erase(name);requested.erase(name)
	for ref in failed_waves:waves.erase(ref)
func forget(id: int) -> void:
	network_voice.forget_actor(id)
	actor_references.erase(id)
	if not records.has(id): return
	var r: Dictionary=records[id]
	if r.sound!=null:
		event("destroy",{"objectId":id,"sound":manager.world_audio.voices.get(int(r.sound),{}).duplicate(true)})
		manager.world_audio.destroy(int(r.sound)); r.sound=null; stats.destroyed+=1
	records.erase(id)
func snapshot() -> Dictionary:
	var sources: Array=[]
	for id in records:
		var record: Dictionary=records[id]
		if record.sound!=null:sources.append({"id":id,"sound":manager.world_audio.voices.get(int(record.sound),{}).duplicate(true)})
	return {"stats":stats.duplicate(),"owners":records.size(),"pending":queue.size(),"sources":sources,"sets":sets.size(),"jobs":jobs.size(),"retiring":retiring,"events":history.duplicate(true),"scope":"Original creature voice source gate/SSF/priorities/replacement for combat barks and server voice26/1. Full mixer priority/device/audibility remains open."}
func begin_retirement() -> void:
	if closed or retiring: return
	retiring=true; queue.clear()
	network_voice.reset()
	for id in records.keys(): forget(int(id))
	# Live-world asset_owners includes this service. Its existing retirement
	# scheduler invalidates the epoch and drains actual workers without joining
	# them on the first transition frame. Final close releases the service.
func detach_prepared_data() -> Dictionary:
	var payload:={"table":table.duplicate(),"sets":sets.duplicate()}
	table={}; sets={}; return payload
func close() -> void:
	if closed: return
	closed=true
	network_voice.reset()
	if is_instance_valid(manager.world_audio):manager.world_audio.voice_object_lookup=Callable()
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(combat_event): combat.engine.presentation_event.disconnect(combat_event)
	for id in records.keys(): forget(int(id))
	queue.clear(); sets.clear(); waves.clear(); requested.clear(); jobs.clear(); players.clear(); actor_references.clear(); table.clear()
	if is_instance_valid(assets): assets.close(); assets.queue_free()
	assets=null; combat=null; manager=null
