extends RefCounted
# Native actor-owned source+e8: original SSF, voice gate and source replacement.
# Only decoded protocol identities and combat bark codes enter this owner.
const Voice=preload("res://systems/native_data/creature_voice.gd")
const Ssf=preload("res://systems/native_data/sound_set.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Fields=preload("res://systems/native_data/combat_actor.gd")
const Sound=preload("res://systems/world_sound_state.gd")
var manager
var combat
var assets
var table: Dictionary={}
var table_failed:=false
var jobs: Dictionary={}
var sets: Dictionary={}
var requested: Dictionary={}
var records: Dictionary={}
var players: Dictionary={}
var queue: Array=[]
var history: Array=[]
var serial:=0
var wire_serial:=-1
var closed:=false
var retiring:=false
var stats:={"requested":0,"started":0,"replaced":0,"destroyed":0,"suppressed":0,"stale":0,"failed":0,"overflow":0,"set_imports":0}
func configure(owner) -> void:
	manager=owner; combat=manager.world.get("combat")
	if is_instance_valid(combat): combat.engine.presentation_event.connect(combat_event)
	assets=Assets.new(); manager.add_child(assets); assets.configure(manager.world.catalog); assets.cache_directory=manager.world.cache_path; assets.maximum_workers=1; assets.completed.connect(prepared)
	var job: int=assets.request("soundset",2017,"2da")
	if job>=0: jobs[job]="@table"
	else: table_failed=true; diagnose(assets.failure,0)
func diagnose(reason: String,id: int) -> void:
	stats.failed+=1; manager.diagnose("voice.native-resource-unavailable",reason,id)
func event(kind: String,detail: Dictionary) -> void:
	if history.size()>=128: history.pop_front()
	var row:={"kind":kind}; row.merge(detail); history.append(row)
func prepared(job: int,result: Dictionary) -> void:
	if closed or retiring or not jobs.has(job): return
	var name: String=jobs[job]; jobs.erase(job)
	if name=="@table":
		table_failed=not str(result.error).is_empty()
		if table_failed: diagnose(str(result.error),0)
		else: table=result.value
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
func receive_raw(message: Dictionary) -> void:
	if closed or retiring or int(message.get("serial",-1))<=wire_serial: return
	wire_serial=int(message.serial)
	for value in message.get("events",[]): request(int(value.objectId),int(value.voiceCode)&255,1,int(value.lifetime),int(value.soundsetId))
func request(id: int,code: int,positional: int=1,lifetime: int=0,soundset: int=-1) -> void:
	if closed or retiring: return
	var object: Variant=manager.object(id)
	if object==null and lifetime<=0: stats.stale+=1; return
	if object!=null and int(object.get("objectType",0))!=5: stats.suppressed+=1; return
	if queue.size()>=256: stats.overflow+=1; return
	serial+=1
	queue.append({"id":id,"code":code&65535,"positional":positional,"lifetime":lifetime if lifetime>0 else int(object.get("nativeLifetime",0)),"soundset":soundset if soundset>=0 else int(object.get("appearance",{}).get("field8A0",65535))&65535,"sequence":serial})
	stats.requested+=1
func valid(r: Dictionary) -> bool:
	var object: Variant=manager.object(int(r.id))
	return object!=null and int(object.get("objectType",0))==5 and int(object.get("nativeLifetime",0))==int(r.lifetime)
func position_for(object: Dictionary) -> Variant:
	var host=manager.host(int(object.id))
	if is_instance_valid(host):
		var p: Vector3=host.global_position
		return [p.x,-p.z,p.y]
	return object.get("replicated",{}).get("position")
func create_source(resource: String) -> Variant:
	var id: int=manager.world_audio.create_sound(resource)
	return id if id>=0 else null
func advance() -> void:
	if closed or retiring: return
	for id in records.keys():
		if not valid(records[id]): forget(int(id)); stats.stale+=1
		elif records[id].sound!=null:
			# Original8114d0 updates the still-owned +e8 source at height1.5,
			# including finished/nonpositional sources. Follow the current actor
			# pose rather than leaving voices at their initial request location.
			var point: Variant=position_for(manager.object(int(id)))
			if point is Array and point.size()==3: manager.world_audio.move(int(records[id].sound),point,1.5)
	var waiting: Array=[]
	for q in queue:
		var object: Variant=manager.object(int(q.id))
		if object==null or int(object.get("nativeLifetime",0))<int(q.lifetime): waiting.append(q); continue
		if int(object.get("nativeLifetime",0))!=int(q.lifetime) or int(object.get("objectType",0))!=5 or (int(object.get("appearance",{}).get("field8A0",65535))&65535)!=int(q.soundset): stats.stale+=1; continue
		if int(q.soundset)==65535 or table_failed: stats.suppressed+=1; continue
		if table.is_empty() or not manager.tables.has("appearance"): waiting.append(q); continue
		var rows: Array=table.get("orderedRows",[])
		if int(q.soundset)>=(rows.size()&65535): diagnose("Soundset index exceeds active table",int(q.id)); continue
		var name:=Sound.resource_ref(str(rows[int(q.soundset)].get("RESREF",""))).to_lower()
		if name in ["","****"]: stats.suppressed+=1; continue
		if not sets.has(name):
			if not requested.has(name):
				var job: int=assets.request(name,2060,"ssf-native-v1")
				if job>=0: jobs[job]=name; requested[name]=true
			waiting.append(q); continue
		if not str(sets[name].error).is_empty(): stats.suppressed+=1; continue
		sets[name].last=int(q.sequence)
		var position: Variant=position_for(object)
		if not position is Array or position.size()!=3: waiting.append(q); continue
		if not records.has(int(q.id)): records[int(q.id)]={"id":q.id,"lifetime":q.lifetime,"soundsetId":q.soundset,"sound":null,"delay":0,"validSequence":-1}
		var r: Dictionary=records[int(q.id)]
		if int(q.sequence)<int(r.validSequence): stats.stale+=1; continue
		r.soundsetId=q.soundset
		var data: Dictionary=sets[name].data; var admitted: Array=[false]; var old: Variant=r.sound
		var providers:={"demandSet":func(_id):return data,"entry":func(sound_set,code):return Ssf.entry(sound_set,code),"releaseSet":func(_data):pass,
			"exists":func(resource):admitted[0]=manager.world.catalog.has_resource(resource,4); return admitted[0],"controlled":func():return int(q.id)==int(manager.world.controlled_id),"player":func():return players.has(int(q.id)),
			"sizeCategory":func():return Fields.integer(manager.tables.appearance,int(object.appearance.appearance),"SIZECATEGORY"),"destroySound":manager.world_audio.destroy,"createSound":create_source,
			"sound3d":func(sound,value):manager.world_audio.setting(int(sound),"setting1401d9e90",int(value)),"soundPriority":func(sound,value):manager.world_audio.setting(int(sound),"setting1401da060",int(value)),
			"position":func():return position,"updateSound":manager.world_audio.move,"playSound":manager.world_audio.play}
		var started:=Voice.play(r,int(q.code),int(q.positional),providers)
		if admitted[0]: r.validSequence=q.sequence
		if started: stats.started+=1; stats.replaced+=int(old!=null)
		else: stats.suppressed+=1
		event("request",{"actor":q.id,"code":q.code,"set":q.soundset,"sequence":q.sequence,"started":started,"sound":r.sound})
	queue=waiting
	# Bounded decoded SSF cache. Preserve sets still needed by pending requests.
	while sets.size()>128:
		var candidate:=""; var oldest:=9223372036854775807
		for name in sets:
			if sets[name].last<oldest and not queue.any(func(q):return str(rows_ref(int(q.soundset)))==name): candidate=name; oldest=int(sets[name].last)
		if candidate.is_empty(): break
		sets.erase(candidate); requested.erase(candidate)
func rows_ref(id: int) -> String:
	var rows: Array=table.get("orderedRows",[])
	return Sound.resource_ref(str(rows[id].get("RESREF",""))).to_lower() if id>=0 and id<rows.size() else ""
func forget(id: int) -> void:
	if not records.has(id): return
	var r: Dictionary=records[id]
	if r.sound!=null: manager.world_audio.destroy(int(r.sound)); r.sound=null; stats.destroyed+=1
	records.erase(id)
func snapshot() -> Dictionary:
	return {"stats":stats.duplicate(),"owners":records.size(),"pending":queue.size(),"sets":sets.size(),"jobs":jobs.size(),"retiring":retiring,"events":history.duplicate(true),"scope":"Original creature voice source gate/SSF/priorities/replacement for combat barks and server voice26/1. Quick-chat/captions, full mixer priority/device/audibility and real-server acceptance remain open."}
func begin_retirement() -> void:
	if closed or retiring: return
	retiring=true; queue.clear()
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
	if is_instance_valid(combat) and combat.engine.presentation_event.is_connected(combat_event): combat.engine.presentation_event.disconnect(combat_event)
	for id in records.keys(): forget(int(id))
	queue.clear(); sets.clear(); requested.clear(); jobs.clear(); players.clear(); table.clear()
	if is_instance_valid(assets): assets.close(); assets.queue_free()
	assets=null; combat=null; manager=null
