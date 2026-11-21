extends Node
# Original area sound objects use the native state machine around the existing
# Godot effect-audio source. Canonical packets remain owned by NetworkWorld.
const State=preload("res://systems/world_sound_state.gd")
var audio
var time_source: Callable
var registry_source: Callable
var area_source: Callable
var area: Dictionary={}
var owners: Dictionary={}
var diagnostics: Array[String]=[]
var diagnostic: Callable
var reported_mixer:=false
var closed:=false

func configure(source,clock: Callable,registry: Callable=Callable(),current_area: Callable=Callable())->void:
	audio=source;time_source=clock;registry_source=registry;area_source=current_area
	reported_mixer=false;diagnostics.clear()
func report_diagnostic(code: String,reason: String,context: Dictionary={})->void:
	diagnostics.append(reason)
	if diagnostic.is_valid():diagnostic.call(code,reason,context)

func attach(area_state: Dictionary,registry: Dictionary,source)->void:
	detach()
	area=area_state.duplicate(true);audio=source
	for record in registry.values():
		if int(record.get("objectType",0))==16 and int(record.get("areaId",-1))==int(area.get("id",-2)):add(record)

func detach()->void:
	for id in owners.keys():stop_voice(owners[id],true)
	owners.clear();area.clear()

static func f(value: float)->float:return State.f(value)
static func native_random()->int:return randi()%0x8000
static func signed32(value: int)->int:
	var bits:=value&0xffffffff
	return bits-0x100000000 if bits>=0x80000000 else bits
static func interval(base: int,variation: int,sample: int)->Variant:
	base=signed32(base);variation=signed32(variation)
	if base==0:return null
	if variation==0:return base&0xffffffff
	var divisor: int=(variation*2)&0xffffffff
	if divisor==0:return null
	var value:=signed32(base-variation+(sample&0xffffffff)%divisor)
	return 0 if value<1 else value&0xffffffff

func add(record: Dictionary)->void:
	var id:=int(record.get("id",-1));var sound: Variant=record.get("state")
	if owners.has(id) or area.is_empty() or int(record.get("areaId",-1))!=int(area.id) or int(record.get("objectType",0))!=16 or not sound is Dictionary:return
	if not reported_mixer:
		reported_mixer=true
		report_diagnostic("network.placed-sound-mixer-unhandled","Native sound-object priority voice limits, range-resume sample phase and synchronized pause timing are not connected")
	if not sound.get("fields") is Dictionary or not sound.get("refs") is Array or not sound.get("position") is Array or sound.position.size()!=3:
		report_diagnostic("network.placed-sound-create-failed","Sound object state is unavailable: "+str(id),{"objectId":id});return
	var fields: Dictionary=sound.get("fields",{})
	var base_interval:=signed32(int(fields.get("348",0)));var variation:=signed32(int(fields.get("34c",0)))
	if base_interval!=0 and variation!=0 and ((variation*2)&0xffffffff)==0:
		report_diagnostic("network.placed-sound-create-failed","Native sound interval variation divides by zero",{"objectId":id});return
	var reference_distance:=float(fields.get("350",1.0));var max_distance:=float(fields.get("354",20.0))
	if not is_finite(reference_distance) or not is_finite(max_distance) or reference_distance<0 or max_distance<=0 or max_distance<reference_distance:
		report_diagnostic("network.placed-sound-create-failed","Native sound source distance is unavailable: "+str(id),{"objectId":id});return
	var refs: Array=[]
	for value in sound.get("refs",[]):refs.append(State.resource_ref(str(value)).to_lower())
	var positional:=bool(fields.get("30c",false));var looping:=bool(fields.get("310",false))
	var continuous:=bool(fields.get("358",false));var random_position:=bool(fields.get("32c",false))
	var gap: Variant=interval(int(fields.get("348",0)),int(fields.get("34c",0)),native_random())
	var owner: Dictionary={"id":id,"refs":refs,"position":sound.get("position",[0.0,0.0,0.0]).duplicate(),"height":float(sound.get("position",[0.0,0.0,0.0])[2]),"active":int(fields.get("308",0)),"positional":positional,"looping":looping,"volume":int(fields.get("314",127)),"volumeVariation":int(fields.get("318",0)),"times":int(fields.get("31c",0)),"pitchVariation":float(fields.get("320",0.0)),"hours":int(fields.get("324",0)),"interval":int(fields.get("348",0)),"intervalVariation":int(fields.get("34c",0)),"continuous":continuous,"randomList":bool(fields.get("35c",false)),"randomPosition":random_position,"ranges":[float(fields.get("330",0.0)),float(fields.get("334",0.0))],"referenceDistance":float(fields.get("350",1.0)),"maxDistance":float(fields.get("354",20.0)),"priority":(3 if positional else 2) if looping else (20 if positional else 19),"allowed":true,"first":true,"index":0,"remaining":0,"gap":int(gap) if gap!=null else 0,"lastTime":Time.get_ticks_msec(),"loopPending":looping and bool(fields.get("308",0)),"pending":false,"voice":-1,"selected":"","pitch":1.0}
	if continuous and refs.size()==1 and not random_position and int(fields.get("348",0))==0:owner.looping=true
	owner.loopPending=bool(owner.looping) and bool(owner.active)
	if refs.is_empty() and owner.active:
		owner.active=0;report_diagnostic("network.placed-sound-empty-list","Native active sound object has no sound references",{"objectId":id})
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

func stop_voice(owner: Dictionary,dispose: bool=false)->void:
	if audio!=null and is_instance_valid(audio) and int(owner.voice)>=0:
		audio.stop(int(owner.voice))
		if dispose:audio.destroy(int(owner.voice))
	if dispose:owner.voice=-1
	owner.pending=false

func command(message: Dictionary,record: Dictionary={}) ->void:
	if closed or area.is_empty() or str(message.get("kind",""))!="sound-object":return
	var id:=int(message.get("objectId",-1));var operation:=int(message.get("operation",-1))
	if operation==6:
		if not record.is_empty():add(record)
		return
	if not owners.has(id):return
	var owner: Dictionary=owners[id]
	match operation:
		2:
			var row: Dictionary=audio.voices.get(int(owner.voice),{}) if audio!=null and is_instance_valid(audio) else {}
			var hardware_playing: bool=is_instance_valid(row.get("player")) and row.player.playing
			if not hardware_playing:
				owner.gap=0;owner.remaining=0;owner.first=true;owner.lastTime=Time.get_ticks_msec();owner.pending=false
			if int(owner.active)!=1:
				owner.gap=0;owner.active=1
				if bool(owner.looping):owner.loopPending=true
		3:
			owner.active=0;owner.gap=0;owner.remaining=0;stop_voice(owner)
		4:
			owner.volume=int(message.get("volume",0))
			if int(owner.voice)>=0 and audio!=null and is_instance_valid(audio) and audio.voices.has(int(owner.voice)):
				audio.voices[int(owner.voice)].profile.volume=int(owner.volume)&255
				audio.refresh_voice(int(owner.voice))
		5:
			if record.get("state") is Dictionary:owner.position=record.state.get("position",owner.position).duplicate()
			if int(owner.voice)>=0 and audio!=null and is_instance_valid(audio):audio.move(int(owner.voice),owner.position)
		7:stop_voice(owner,true);owners.erase(id)

func choose(owner: Dictionary)->String:
	var refs: Array=owner.refs
	if refs.is_empty():return ""
	if not bool(owner.first):
		if int(owner.index)<refs.size()-1:
			owner.index+=1;return str(refs[owner.index])
		if not bool(owner.continuous):return ""
		if bool(owner.randomList):
			var old: Array=refs.duplicate();var next: Array=[]
			while not old.is_empty():next.append(old.pop_at(int(native_random()%old.size())))
			owner.refs=next;refs=next
	else:owner.first=false
	owner.index=0
	return str(refs[0])

func vary_position(owner: Dictionary)->bool:
	var point: Array=[0.0,0.0,float(owner.position[2])]
	for axis in range(2):
		var maximum:=f(float(area.get("width",0) if axis==0 else area.get("height",0))*10.0)
		var radius:=float(owner.ranges[axis]);var low:=0.0 if radius==0 else maxf(0.0,f(float(owner.position[axis])-radius))
		var span:=maximum if radius==0 else f(minf(maximum,f(float(owner.position[axis])+radius))-low)
		point[axis]=f(low)
		if span>0:
			var divisor:=int(f(span*100.0))
			if divisor<=0:return false
			point[axis]=f(float(point[axis])+f(float(native_random()%divisor)/100.0))
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
	if audio==null or not is_instance_valid(audio):return
	var voice:=int(owner.voice)
	if voice>=0 and audio.voices.has(voice):audio.set_res_ref(voice,reference)
	else:voice=int(audio.create_sound(reference,int(owner.id),int(owner.id),"placed",false))
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
		row.placed=true;row.waitForFrame=true
		row.profile.referenceDistance=float(owner.referenceDistance);row.profile.maxDistance=float(owner.maxDistance)
		if not bool(owner.looping):row.profile.pitchVariance=float(owner.pitchVariation)
		var variation:=int(owner.volumeVariation)
		row.profile.volume=clampi(int(owner.volume)+int(native_random()%maxi(1,variation*2))-variation,0,127) if variation>0 and not bool(owner.looping) else int(owner.volume)&255
	if not bool(owner.looping) and bool(owner.randomPosition) and not vary_position(owner):
		diagnostics.append("Sound random position has no area tile: "+str(owner.id));owner.active=0;owner.pending=false;return
	audio.move(voice,owner.position);audio.play(voice)
	finish_ready(owner)

func finish(owner: Dictionary,duration: int,looping: bool)->void:
	owner.remaining=duration&0xffffffff
	if looping:
		if duration==0:owner.active=0;owner.gap=0
		return
	if duration==0:
		if owner.refs.size()<2:owner.active=0;owner.gap=0;return
		owner.refs.remove_at(int(owner.index))
		if int(owner.index)>0:owner.index=int(owner.index)-1
	if bool(owner.continuous) or int(owner.index)<owner.refs.size()-1:
		var next_gap: Variant=interval(int(owner.interval),int(owner.intervalVariation),native_random())
		if next_gap!=null:owner.gap=int(next_gap)

func finish_ready(owner: Dictionary)->bool:
	if audio==null or not is_instance_valid(audio):return false
	var row: Dictionary=audio.voices.get(int(owner.voice),{})
	if row.is_empty():
		diagnostics.append("Sound resource failed before playback: "+str(owner.id))
		owner.pending=false;owner.active=0;return true
	if str(row.get("stage",""))=="failed":
		report_diagnostic("network.placed-sound-resource-failed",str(row.get("failure","Original audio resource is unavailable")),{"objectId":int(owner.id),"resRef":str(owner.selected)})
		owner.pending=false;finish(owner,0,bool(owner.looping));return true
	var resource: Variant=audio.resources.get(int(row.get("resourceId",-1)))
	var stream: Variant=resource.get("stream") if resource is Dictionary else null
	if stream==null:return false
	if not stream is Object or not is_instance_valid(stream) or not stream.has_method("get_length"):
		diagnostics.append("Sound resource stream is unavailable: "+str(owner.id))
		owner.pending=false;finish(owner,0,bool(owner.looping));return true
	if bool(row.get("waitForFrame",false)):
		row.waitForFrame=false;audio.play(int(row.id))
	owner.pending=false
	var metadata: Dictionary=resource.get("metadata",{})
	var timing: Dictionary=metadata.get("timing",{}) if metadata.get("timing") is Dictionary else {}
	finish(owner,int(timing.duration) if timing.has("duration") else int(stream.get_length()*1000.0),bool(owner.looping))
	return true

func advance(now: int,time: Dictionary)->void:
	if closed or area.is_empty():return
	if area_source.is_valid() and int(area_source.call())!=int(area.id):return
	var registry: Variant=registry_source.call() if registry_source.is_valid() else null
	for id in owners.keys():
		var owner: Dictionary=owners[id]
		if registry is Dictionary:
			var record: Variant=registry.get(id)
			if not record is Dictionary:
				stop_voice(owner,true);owners.erase(id);continue
		gate(owner,time)
		if not bool(owner.active) or not bool(owner.allowed):
			var row: Dictionary=audio.voices.get(int(owner.voice),{}) if audio!=null and is_instance_valid(audio) else {}
			if is_instance_valid(row.get("player")) and row.player.playing:
				stop_voice(owner)
				if not bool(owner.allowed) and bool(owner.looping):owner.loopPending=true
			continue
		if bool(owner.pending):
			finish_ready(owner)
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
		if not bool(owner.first) and int(owner.index)>=owner.refs.size()-1 and not bool(owner.continuous):owner.active=0;continue
		begin_voice(owner)

func _process(_delta: float)->void:
	advance(Time.get_ticks_msec(),current_time())

func snapshot()->Dictionary:
	var rows: Array=[]
	for owner in owners.values():
		var source: Dictionary={}
		if audio!=null and is_instance_valid(audio) and audio.voices.has(int(owner.voice)):source=audio.sound_source_snapshot(audio.voices[int(owner.voice)])
		rows.append({"id":owner.id,"active":owner.active,"allowed":owner.allowed,"looping":owner.looping,"priority":owner.priority,"index":owner.index,"refs":owner.refs.duplicate(),"position":owner.position.duplicate(),"remaining":owner.remaining,"gap":owner.gap,"pending":owner.pending,"source":source,"voice":owner.voice})
	return {"areaId":area.get("id"),"objects":rows,"diagnostics":diagnostics.duplicate()}

func close()->void:
	if closed:return
	detach();closed=true
