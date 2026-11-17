extends Node
# Original area sound objects use the native state machine around the existing
# Godot effect-audio source. Canonical packets remain owned by NetworkWorld.
const State=preload("res://systems/world_sound_state.gd")
var audio
var time_source: Callable
var registry_source: Callable
var area: Dictionary={}
var owners: Dictionary={}
var diagnostics: Array[String]=[]
var closed:=false

func configure(source,clock: Callable,registry: Callable=Callable())->void:
	audio=source;time_source=clock;registry_source=registry

func attach(area_state: Dictionary,registry: Dictionary,source)->void:
	detach()
	area=area_state.duplicate(true);audio=source
	for record in registry.values():
		if int(record.get("objectType",0))==16 and int(record.get("areaId",-1))==int(area.get("id",-2)):add(record)

func detach()->void:
	for id in owners.keys():stop_voice(owners[id])
	owners.clear();area.clear()

static func f(value: float)->float:return State.f(value)
static func interval(base: int,variation: int,sample: int)->Variant:
	if base==0:return null
	if variation==0:return base&0xffffffff
	var divisor: int=(variation*2)&0xffffffff
	if divisor==0:return null
	return maxi(0,base-variation+(sample&0xffffffff)%divisor)

func add(record: Dictionary)->void:
	var id:=int(record.get("id",-1));var sound: Variant=record.get("state")
	if owners.has(id) or area.is_empty() or int(record.get("areaId",-1))!=int(area.id) or not sound is Dictionary:return
	if not sound.get("fields") is Dictionary or not sound.get("refs") is Array or not sound.get("position") is Array or sound.position.size()!=3:
		diagnostics.append("Sound object state is unavailable: "+str(id));return
	var fields: Dictionary=sound.get("fields",{})
	var refs: Array=[]
	for value in sound.get("refs",[]):refs.append(State.resource_ref(str(value)).to_lower())
	var positional:=bool(fields.get("30c",false));var looping:=bool(fields.get("310",false))
	var continuous:=bool(fields.get("358",false));var random_position:=bool(fields.get("32c",false))
	var gap: Variant=interval(int(fields.get("348",0)),int(fields.get("34c",0)),randi())
	var owner: Dictionary={"id":id,"refs":refs,"position":sound.get("position",[0.0,0.0,0.0]).duplicate(),"height":float(sound.get("position",[0.0,0.0,0.0])[2]),"active":int(fields.get("308",0)),"positional":positional,"looping":looping,"volume":int(fields.get("314",127)),"volumeVariation":int(fields.get("318",0)),"times":int(fields.get("31c",0)),"pitchVariation":float(fields.get("320",0.0)),"hours":int(fields.get("324",0)),"interval":int(fields.get("348",0)),"intervalVariation":int(fields.get("34c",0)),"continuous":continuous,"randomList":bool(fields.get("35c",false)),"randomPosition":random_position,"ranges":[float(fields.get("330",0.0)),float(fields.get("334",0.0))],"referenceDistance":float(fields.get("350",1.0)),"maxDistance":float(fields.get("354",20.0)),"priority":(3 if positional else 2) if looping else (20 if positional else 19),"allowed":true,"first":true,"index":0,"remaining":0,"gap":int(gap) if gap!=null else 0,"lastTime":Time.get_ticks_msec(),"loopPending":looping and bool(fields.get("308",0)),"pending":false,"voice":-1,"selected":"","pitch":1.0}
	if continuous and refs.size()==1 and not random_position and int(fields.get("348",0))==0:owner.looping=true
	owner.loopPending=bool(owner.looping) and bool(owner.active)
	if refs.is_empty() and owner.active:
		owner.active=0;diagnostics.append("Active sound object has no references: "+str(id))
	owners[id]=owner
	gate(owner,current_time())

func current_time()->Dictionary:
	var value: Variant=time_source.call() if time_source.is_valid() else {}
	return value if value is Dictionary else {}

func gate(owner: Dictionary,time: Dictionary)->void:
	var hour:=int(time.get("hour",0));var period:=int(time.get("timeOfDay",0))
	if int(owner.times)==0:owner.allowed=(int(owner.hours)&(1<<(hour&31)))!=0
	elif period<2 or period==3:owner.allowed=int(owner.times)!=2
	elif period in [2,4]:owner.allowed=int(owner.times)!=1

func stop_voice(owner: Dictionary)->void:
	if audio!=null and is_instance_valid(audio) and int(owner.voice)>=0:
		audio.stop(int(owner.voice));audio.destroy(int(owner.voice))
	owner.voice=-1;owner.pending=false

func command(message: Dictionary,record: Dictionary={}) ->void:
	if closed or area.is_empty():return
	var id:=int(message.get("objectId",-1));var operation:=int(message.get("operation",-1))
	if operation==6:
		if not record.is_empty():add(record)
		return
	if not owners.has(id):return
	var owner: Dictionary=owners[id]
	match operation:
		2:
			owner.active=1;owner.first=true;owner.gap=0;owner.remaining=0;owner.lastTime=Time.get_ticks_msec();owner.loopPending=bool(owner.looping)
		3:
			owner.active=0;owner.gap=0;owner.remaining=0;stop_voice(owner)
		4:
			owner.volume=int(message.get("volume",0))
			if int(owner.voice)>=0 and audio!=null and is_instance_valid(audio) and audio.voices.has(int(owner.voice)):audio.voices[int(owner.voice)].profile.volume=int(owner.volume)&255
		5:
			if record.get("state") is Dictionary:owner.position=record.state.get("position",owner.position).duplicate()
			if int(owner.voice)>=0 and audio!=null and is_instance_valid(audio):audio.move(int(owner.voice),owner.position)
		7:stop_voice(owner);owners.erase(id)

func choose(owner: Dictionary)->String:
	var refs: Array=owner.refs
	if refs.is_empty():return ""
	if not bool(owner.first):
		if int(owner.index)<refs.size()-1:
			owner.index+=1;return str(refs[owner.index])
		if not bool(owner.continuous):return ""
		if bool(owner.randomList):refs.shuffle();owner.refs=refs
	else:owner.first=false
	owner.index=0
	return str(refs[0])

func vary_position(owner: Dictionary)->bool:
	var point: Array=[0.0,0.0,float(owner.position[2])]
	for axis in range(2):
		var maximum:=f(float(area.get("width",0) if axis==0 else area.get("height",0))*10.0)
		var radius:=float(owner.ranges[axis]);var low:=0.0 if radius==0 else maxf(0.0,f(float(owner.position[axis])-radius))
		var span:=maximum if radius==0 else f(minf(maximum,f(float(owner.position[axis])+radius))-low)
		point[axis]=f(low+(float(randi()%maxi(1,int(f(span*100.0))))/100.0 if span>0 else 0.0))
	var width:=int(area.get("width",0));var height:=int(area.get("height",0));var x:=-1;var y:=-1
	for i in range(width):
		if f(float(i*10))<=float(point[0]) and float(point[0])<=f(float((i+1)*10)):x=i;break
	for i in range(height):
		if f(float(i*10))<=float(point[1]) and float(point[1])<=f(float((i+1)*10)):y=i;break
	var tiles: Array=area.get("tiles",[])
	if x<0 or y<0 or x+width*y>=tiles.size():return false
	var elevation: Variant=tiles[x+width*y].get("fields",{}).get("18")
	if not elevation is int:return false
	point[2]=f(f(float(elevation))+f(float(owner.height)));owner.position=point
	return true

func begin_voice(owner: Dictionary)->void:
	var reference:=choose(owner)
	if reference.is_empty():owner.active=0;owner.gap=0;return
	if bool(owner.randomPosition) and not vary_position(owner):diagnostics.append("Sound random position has no area tile: "+str(owner.id));owner.active=0;return
	if audio==null or not is_instance_valid(audio):return
	stop_voice(owner)
	var voice:=int(audio.create_sound(reference,int(owner.id)))
	if voice<0:
		owner.active=0;owner.pending=false;owner.loopPending=false
		diagnostics.append("Sound resource create failed: "+str(owner.id))
		return
	owner.voice=voice;owner.selected=reference;owner.pending=true
	audio.setting(voice,"setting1401d9e90",1 if owner.positional else 0)
	audio.setting(voice,"setting1401d9f90",1 if owner.looping else 0)
	audio.setting(voice,"setting1401da060",int(owner.priority))
	var row: Dictionary=audio.voices.get(voice,{})
	if not row.is_empty():
		row.profile.referenceDistance=float(owner.referenceDistance);row.profile.maxDistance=float(owner.maxDistance)
		var variation:=int(owner.volumeVariation)
		row.profile.volume=clampi(int(owner.volume)+int(randi()%maxi(1,variation*2))-variation,0,127) if variation>0 and not bool(owner.looping) else int(owner.volume)&255
	audio.move(voice,owner.position);audio.play(voice)

func advance(now: int,time: Dictionary)->void:
	if closed or area.is_empty():return
	var registry: Variant=registry_source.call() if registry_source.is_valid() else null
	for id in owners.keys():
		var owner: Dictionary=owners[id]
		if registry is Dictionary:
			var record: Variant=registry.get(id)
			if not record is Dictionary or int(record.get("objectType",0))!=16 or int(record.get("areaId",-1))!=int(area.id):
				stop_voice(owner);owners.erase(id);continue
		gate(owner,time)
		if not bool(owner.active) or not bool(owner.allowed):
			if int(owner.voice)>=0:stop_voice(owner)
			if not bool(owner.allowed) and bool(owner.looping):owner.loopPending=true
			continue
		if bool(owner.pending):
			if audio==null or not is_instance_valid(audio):continue
			var row: Dictionary=audio.voices.get(int(owner.voice),{})
			if row.is_empty() or str(row.get("stage",""))=="failed":
				diagnostics.append("Sound resource failed before playback: "+str(id))
				stop_voice(owner);owner.active=0;continue
			if str(row.get("stage",""))!="playing":continue
			owner.pending=false
			if not row.get("resourceId") is int:
				diagnostics.append("Sound resource identity is unavailable: "+str(id))
				stop_voice(owner);owner.active=0;continue
			var resource: Variant=audio.resources.get(int(row.resourceId))
			var stream: Variant=resource.get("stream") if resource is Dictionary else null
			if not stream is Object or not is_instance_valid(stream) or not stream.has_method("get_length"):
				diagnostics.append("Sound resource stream is unavailable: "+str(id))
				stop_voice(owner);owner.active=0;continue
			var duration:=roundi(stream.get_length()*1000.0)
			owner.remaining=duration
			var metadata: Variant=resource.get("metadata",{})
			var rate:=int(metadata.get("sampleRate",0)) if metadata is Dictionary else 0
			if rate>0 and float(owner.pitchVariation)!=0.0:
				var add: bool=(randi()&1)!=0
				var span:=int(f(float(rate)*f(float(owner.pitchVariation)))) if add else int(f(f(float(rate)*f(0.5))*f(float(owner.pitchVariation))))
				var changed_rate:=rate+(1 if add else -1)*int(randi()%maxi(1,span))
				if changed_rate>0:owner.pitch=float(changed_rate)/float(rate)
			if is_instance_valid(row.get("player")):row.player.pitch_scale=float(owner.pitch)
			if bool(owner.looping):owner.loopPending=false
			if duration==0:
				if bool(owner.looping):owner.active=0;stop_voice(owner)
				elif owner.refs.size()<2:owner.active=0;stop_voice(owner)
				else:
					owner.refs.remove_at(int(owner.index));owner.index=maxi(0,int(owner.index)-1)
			continue
		if bool(owner.looping):
			if bool(owner.loopPending):owner.loopPending=false;owner.first=true;begin_voice(owner)
			continue
		var elapsed:=maxi(0,now-int(owner.lastTime));owner.lastTime=now
		if int(owner.remaining)>0:
			owner.remaining=maxi(0,int(owner.remaining)-elapsed)
			if int(owner.remaining)>0:continue
			elapsed=0
		if int(owner.gap)>0:
			owner.gap=maxi(0,int(owner.gap)-elapsed)
			if int(owner.gap)>0:continue
		if int(owner.voice)>=0:stop_voice(owner)
		if not bool(owner.first) and int(owner.index)>=owner.refs.size()-1 and not bool(owner.continuous):owner.active=0;continue
		begin_voice(owner)
		if not bool(owner.pending):continue
		if int(owner.interval)>0:
			var gap: Variant=interval(int(owner.interval),int(owner.intervalVariation),randi())
			owner.gap=int(gap) if gap!=null else 0

func _process(_delta: float)->void:
	advance(Time.get_ticks_msec(),current_time())

func snapshot()->Dictionary:
	var rows: Array=[]
	for owner in owners.values():rows.append({"id":owner.id,"active":owner.active,"allowed":owner.allowed,"looping":owner.looping,"position":owner.position.duplicate(),"voice":owner.voice,"pending":owner.pending,"refs":owner.refs.duplicate(),"remaining":owner.remaining,"gap":owner.gap})
	return {"areaId":area.get("id"),"objects":rows,"diagnostics":diagnostics.duplicate()}

func close()->void:
	if closed:return
	detach();closed=true
