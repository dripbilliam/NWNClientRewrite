extends Node
# Current-area music/ambient presentation. Server 40/1..8 changes this owner's
# state; no command creates a game object or changes the authoritative clock.
const Assets=preload("res://systems/native_data/asset_service.gd")
const DEFAULTS={"8":1,"c":5000,"10":2,"14":3,"18":0,"1c":1,"20":1,"24":1,"28":2,"2c":0,"2d":0}
const MAX_PENDING=128
var catalog
var assets
var owned_assets:=false
var cache_path: String=""
var music: AudioStreamPlayer
var ambient: AudioStreamPlayer
var stinger: AudioStreamPlayer
var area_id: int=-1
var generation:=0
var active:=false
var loading:=false
var closed:=false
var day:=true
var fields: Dictionary={}
var tables: Dictionary={}
var pending: Array[Dictionary]=[]
var jobs: Dictionary={}
var channels: Dictionary={}
var delay_ms:=30000
var retry_at:=0
var failure: String=""
var stats: Dictionary={"requests":0,"loads":0,"misses":0,"stale":0,"commands":0,"overflows":0}

func configure(source,cache_directory: String="",asset_service: Node=null)->void:
	catalog=source;cache_path=cache_directory;closed=false
	assets=asset_service
	if assets==null:
		assets=Assets.new();owned_assets=true;add_child(assets);assets.configure(source);assets.cache_directory=cache_directory;assets.maximum_workers=2
	else:owned_assets=false
	assets.completed.connect(prepared)
	music=AudioStreamPlayer.new();ambient=AudioStreamPlayer.new();stinger=AudioStreamPlayer.new();add_child(music);add_child(ambient);add_child(stinger)
	music.finished.connect(func():
		if active and str(channels.music.status)=="playing":channels.music.status="idle";retry_at=Time.get_ticks_msec()+delay_ms)
	ambient.finished.connect(func():
		if active and str(channels.ambient.status)=="playing":channels.ambient.status="idle";_refresh())
	set_process(true)

func attach(area: Dictionary,time_of_day: int=-1)->bool:
	if closed or assets==null or not area.get("ambient") is Dictionary:return false
	detach()
	area_id=int(area.get("id",-1));if area_id<0:return false
	fields=DEFAULTS.duplicate(true);fields.merge(area.ambient,true)
	day=_day(time_of_day if time_of_day>=0 else int(area.get("time",{}).get("timeOfDay",0)))
	delay_ms=30000 if not area.ambient.has("c") else maxi(1,int(fields.c))
	loading=true
	for name in ["ambientmusic","ambientsound"]:
		if tables.has(name):continue
		var id: int=assets.request(name,2017,"2da")
		if id<0:failure="Missing native ambient table "+name+": "+str(assets.failure);loading=false;return false
		jobs[id]={"generation":generation,"kind":"table","name":name};stats.requests+=1
	_tables_ready()
	return true

func receive(command: Dictionary)->bool:
	if closed or area_id<0 or str(command.get("kind",""))!="ambient-command" or int(command.get("operation",0))<1 or int(command.get("operation",0))>8:return false
	if loading:
		if pending.size()>=MAX_PENDING:stats.overflows+=1;return false
		pending.append(command.duplicate(true));return true
	_apply(command);return true

func day_night(time_of_day: int)->void:
	if not active:return
	if time_of_day not in [0,1,2,3,4]:return
	var selected:=_day(time_of_day)
	if selected==day:return
	day=selected;_refresh()

func _day(time_of_day: int)->bool:return time_of_day<2 or time_of_day==3

func _apply(command: Dictionary)->void:
	stats.commands+=1
	var op:=int(command.operation)
	var battle_was_playing:=int(fields.get("18",0))!=0
	match op:
		1:fields["8"]=int(bool(command.get("play",false)))
		2:
			if int(command.get("value",0))>0:delay_ms=int(command.value)
		3:fields["10" if bool(command.get("day",false)) else "14"]=int(command.get("value",0))
		4:fields["18"]=int(bool(command.get("play",false)))
		5:fields["1c"]=int(command.get("value",0))
		6:fields["20"]=int(bool(command.get("play",false)))
		7:fields["24" if bool(command.get("day",false)) else "28"]=int(command.get("value",0))
		8:fields["2c" if bool(command.get("day",false)) else "2d"]=int(command.get("value",0))&255
	var force_channel:="music" if op==3 and bool(command.get("day",false))==day and not battle_was_playing else "music" if op==5 and battle_was_playing else "ambient" if op==7 and bool(command.get("day",false))==day else ""
	_refresh(force_channel)
	if op==4 and battle_was_playing and int(fields.get("18",0))==0:_play_stinger()

func _play_stinger()->void:
	var candidates: Array=track(tables.ambientmusic,int(fields.get("1c",0)),true).stingers.filter(func(name):return not str(name).is_empty())
	if candidates.is_empty():return
	var selected:=str(candidates[randi()%candidates.size()])
	_set_track("stinger",selected,true)

func _tables_ready()->void:
	if not loading or not tables.has("ambientmusic") or not tables.has("ambientsound"):return
	loading=false;active=true
	channels={"music":{"name":"","status":"idle","job":-1,"generation":generation},"ambient":{"name":"","status":"idle","job":-1,"generation":generation},"stinger":{"name":"","status":"idle","job":-1,"generation":generation}}
	_refresh()
	for command in pending:
		if not active:break
		_apply(command)
	pending.clear()

static func track(table: Dictionary,id: int,music_track: bool)->Dictionary:
	var rows: Array=table.get("orderedRows",[])
	var row: Dictionary=rows[id] if id>=0 and id<rows.size() and rows[id] is Dictionary else {}
	var resource:=_ref(str(row.get("Resource","")))
	var stingers: Array[String]=[]
	if music_track:
		for name in ["Stinger1","Stinger2","Stinger3"]:stingers.append(_ref(str(row.get(name,""))))
	return {"resource":resource,"stingers":stingers}

static func _ref(value: String)->String:
	if value=="****" or value.is_empty():return ""
	var result:=""
	for character in value:
		if character.unicode_at(0)==0 or result.length()==16:break
		result+=character
	return result.to_lower()

func _refresh(force_channel: String="")->void:
	if not active:return
	var music_id:=int(fields.get("1c",0)) if int(fields.get("18",0))!=0 else int(fields.get("10" if day else "14",0)) if int(fields.get("8",0))!=0 else -1
	var ambient_id:=int(fields.get("24" if day else "28",0)) if int(fields.get("20",0))!=0 else -1
	_set_track("music",track(tables.ambientmusic,music_id,true).resource,force_channel=="music")
	_set_track("ambient",track(tables.ambientsound,ambient_id,false).resource,force_channel=="ambient")
	ambient.volume_linear=float(int(fields.get("2c" if day else "2d",0))&255)/127.0

func _set_track(channel: String,name: String,force: bool=false)->void:
	var state: Dictionary=channels[channel]
	if not force and str(state.name)==name and str(state.status) in ["loading","playing","failed"]:return
	if not force and channel=="music" and str(state.name)==name and str(state.status)=="idle" and retry_at>0:return
	var player: AudioStreamPlayer=music if channel=="music" else ambient if channel=="ambient" else stinger
	player.stop();player.stream=null
	state.name=name;state.status="idle";state.job=-1
	if name.is_empty():return
	if name.contains("/") or name.contains("\\") or name.contains(":"):
		state.status="failed";stats.misses+=1;return
	var type:=4 if catalog.has_resource(name,4) else 8 if catalog.has_resource(name,8) else -1
	if type<0:state.status="failed";stats.misses+=1;return
	var id: int=assets.request(name,type,"wave-native-v1")
	if id<0:state.status="failed";failure=str(assets.failure);stats.misses+=1;return
	state.job=id;state.status="loading";state.generation=generation
	jobs[id]={"generation":generation,"kind":"stream","channel":channel,"name":name};stats.requests+=1

func prepared(id: int,result: Dictionary)->void:
	if not jobs.has(id):return
	var job: Dictionary=jobs[id];jobs.erase(id)
	if closed or int(job.generation)!=generation:stats.stale+=1;return
	if job.kind=="table":
		if not str(result.get("error","")).is_empty() or not result.get("value") is Dictionary:
			failure="Native ambient table unavailable: "+str(job.name);loading=false;pending.clear();return
		tables[str(job.name)]=result.value;_tables_ready();return
	var channel:=str(job.channel);var state: Dictionary=channels.get(channel,{})
	if state.is_empty() or int(state.job)!=id or str(state.name)!=str(job.name):stats.stale+=1;return
	var stream:=_stream(result)
	if stream==null:state.status="failed";stats.misses+=1;failure="Native ambient stream unavailable: "+str(job.name);return
	var player: AudioStreamPlayer=music if channel=="music" else ambient if channel=="ambient" else stinger
	player.stream=stream
	if stream is AudioStreamWAV:stream.loop_mode=AudioStreamWAV.LOOP_FORWARD if channel=="ambient" else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:stream.loop=channel=="ambient"
	player.play();state.status="playing";state.job=-1;stats.loads+=1

static func _stream(result: Dictionary)->AudioStream:
	if not str(result.get("error","")).is_empty() or not result.get("value") is Dictionary:return null
	var data: Dictionary=result.value;var bytes: PackedByteArray=result.get("bytes",PackedByteArray())
	if data.is_empty():return null
	var stream: AudioStream=null
	match str(data.get("codec","")):
		"pcm16":
			var wave:=AudioStreamWAV.new();wave.format=AudioStreamWAV.FORMAT_16_BITS;wave.stereo=int(data.get("channels",0))==2;wave.mix_rate=int(data.get("sampleRate",0));wave.data=data.get("pcm",PackedByteArray());stream=wave
		"mp3":
			if bytes.size()<=8 or bytes.slice(0,8).get_string_from_ascii()!="BMU V1.0":return null
			var mp3:=AudioStreamMP3.new();mp3.data=bytes.slice(8);stream=mp3
		"wav":stream=AudioStreamWAV.load_from_buffer(bytes)
	return stream if stream!=null and stream.get_length()>0 else null

func _process(_delta: float)->void:
	if not active or closed:return
	if channels.has("music") and str(channels.music.status)=="idle" and retry_at>0 and Time.get_ticks_msec()>=retry_at:
		retry_at=0;_refresh("music")

func detach()->void:
	generation+=1;active=false;loading=false;area_id=-1;pending.clear();jobs.clear();channels.clear();retry_at=0
	if music!=null:music.stop();music.stream=null
	if ambient!=null:ambient.stop();ambient.stream=null
	if stinger!=null:stinger.stop();stinger.stream=null

func snapshot()->Dictionary:
	return {"areaId":area_id,"generation":generation,"active":active,"loading":loading,"pending":pending.size(),"fields":fields.duplicate(true),"day":day,"channels":channels.duplicate(true),"failure":failure,"stats":stats.duplicate()}

func close()->void:
	if closed:return
	detach();closed=true;set_process(false)
	if assets!=null and assets.completed.is_connected(prepared):assets.completed.disconnect(prepared)
	if owned_assets and assets!=null:assets.close();assets.queue_free()

func _exit_tree()->void:close()
