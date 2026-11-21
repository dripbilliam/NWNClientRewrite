extends Node
# Current-area music/ambient presentation. Server 40/1..8 changes this owner's
# state; no command creates a game object or changes the authoritative clock.
const Assets=preload("res://systems/native_data/asset_service.gd")
const ScriptString=preload("res://systems/native_data/native_script_string.gd")
const State=preload("res://systems/world_sound_state.gd")
const DEFAULTS={"8":1,"c":5000,"10":2,"14":3,"18":0,"1c":1,"20":1,"24":1,"28":2,"2c":0,"2d":0}
const MAX_PENDING=128
var catalog
var assets
var owned_assets:=false
var cache_path: String=""
var music: AudioStreamPlayer
var ambient: AudioStreamPlayer
var stinger_voices: Array=[]
var stinger_cache: Dictionary={}
var area_id: int=-1
var generation:=0
var active:=false
var loading:=false
var closed:=false
var day:=true
var fields: Dictionary={}
var tracks: Dictionary={}
var tables: Dictionary={}
var pending: Array[Dictionary]=[]
var jobs: Dictionary={}
var channels: Dictionary={}
var delay_ms:=30000
var retry:=0
var ambient_failed:=0
var last_time: Variant=null
var long_fade:=false
var category:=0
var failure: String=""
var diagnostic: Callable
var diagnostics: Array=[]
var reported_adapter:=false
var stats: Dictionary={"requests":0,"loads":0,"misses":0,"stale":0,"commands":0,"overflows":0}

func report_failure(code: String,reason: String,context: Dictionary={}) -> void:
	var event: Dictionary={"code":code,"reason":reason,"context":context.duplicate(true)}
	diagnostics.append(event)
	if diagnostics.size()>128:diagnostics.pop_front()
	if diagnostic.is_valid():diagnostic.call(code,reason,context)

func configure(source,cache_directory: String="",asset_service: Node=null)->void:
	catalog=source;cache_path=cache_directory;closed=false
	assets=asset_service
	if assets==null:
		assets=Assets.new();owned_assets=true;add_child(assets);assets.configure(source);assets.cache_directory=cache_directory;assets.maximum_workers=2
	else:owned_assets=false
	assets.completed.connect(prepared)
	music=AudioStreamPlayer.new();ambient=AudioStreamPlayer.new();add_child(music);add_child(ambient)
	music.finished.connect(func():
		if active and str(channels.music.status)=="playing":channels.music.status="idle")
	ambient.finished.connect(func():
		if active and str(channels.ambient.status)=="playing":channels.ambient.status="idle")
	set_process(true)

func attach(area: Dictionary,time_of_day: int=-1)->bool:
	if closed or assets==null or not area.get("ambient") is Dictionary:return false
	detach()
	area_id=int(area.get("id",-1));if area_id<0:return false
	fields=DEFAULTS.duplicate(true);fields.merge(area.ambient,true)
	day=_day(time_of_day if time_of_day>=0 else int(area.get("time",{}).get("timeOfDay",0)))
	delay_ms=30000 if not area.ambient.has("c") else maxi(1,int(fields.c))
	retry=0;ambient_failed=0;last_time=null;long_fade=false;category=0;tracks.clear()
	loading=true
	for name in ["ambientmusic","ambientsound"]:
		if tables.has(name):continue
		var id: int=assets.request(name,2017,"2da")
		if id<0:
			failure="Missing native ambient table "+name+": "+str(assets.failure);loading=false
			report_failure("network.ambient-load-failed",failure,{"areaId":area_id});return false
		jobs[id]={"generation":generation,"kind":"table","name":name};stats.requests+=1
	_tables_ready()
	return true

func receive(command: Dictionary)->bool:
	if closed or str(command.get("kind",""))!="ambient-command":return false
	if area_id<0:
		report_failure("network.ambient-owner-unavailable","Area audio command has no active presentation owner",{"areaId":area_id,"operation":int(command.get("operation",0))});return false
	if int(command.get("operation",0))<1 or int(command.get("operation",0))>8:return false
	if loading:
		if pending.size()>=MAX_PENDING:
			stats.overflows+=1;report_failure("network.ambient-command-overflow","Too many area audio commands awaiting tables",{"areaId":area_id});return false
		pending.append(command.duplicate(true));return true
	if not active:
		report_failure("network.ambient-owner-unavailable","Area audio command has no active presentation owner",{"areaId":area_id,"operation":int(command.operation)});return false
	_apply(command);return true

func day_night(time_of_day: int)->void:
	if not active:return
	if time_of_day not in [0,1,2,3,4]:return
	var selected:=_day(time_of_day)
	if selected==day:return
	var old_music: String="10" if day else "14"
	var old_ambient: String="24" if day else "28"
	if same_file(stream_file("music"),track_key(old_music)):
		long_fade=true;music_toggle(false);retry=10;music_toggle(true);long_fade=false
	if same_file(stream_file("ambient"),track_key(old_ambient)):
		ambient_toggle(false);ambient_toggle(true)
	day=selected

func _day(time_of_day: int)->bool:return time_of_day<2 or time_of_day==3

static func same_file(a: String,b: String)->bool:return a.to_lower()==b.to_lower()
func load_track(key: String,music_track: bool,id: int)->void:
	var selected: Dictionary=track(tables.get("ambientmusic" if music_track else "ambientsound",{}),id,music_track)
	if selected.has("error"):
		report_failure("network.ambient-resource-case-unhandled",str(selected.error),{"areaId":area_id,"table":"ambientmusic" if music_track else "ambientsound","id":id})
	tracks[key]={"resource":str(selected.get("resource","")),"stingers":selected.get("stingers",[])}
	if not music_track and not str(selected.get("resource","")).is_empty():ambient_failed=0
func track_key(key: String)->String:return str(tracks.get(key,{}).get("resource",""))
func stream_file(channel: String)->String:return str(channels.get(channel,{}).get("name",""))
func stream_is_playing(channel: String)->bool:return str(channels.get(channel,{}).get("status","idle")) in ["loading","queued","playing","fading"]
func schedule_failure(accepted: bool)->void:
	if not accepted:retry=10000
func music_toggle(play_value: bool)->void:
	if not active:return
	if not play_value:
		stream_fade("music",10000 if long_fade else 800);fields["8"]=0;return
	if not stream_is_playing("music"):
		retry=0;schedule_failure(stream_play("music",track_key("10" if day else "14"),8))
	fields["8"]=1
func ambient_toggle(play_value: bool)->void:
	if not active:return
	if not play_value:
		stream_fade("ambient",6000);fields["20"]=0;ambient_failed=0;return
	if not stream_is_playing("ambient"):
		stream_volume("ambient",int(fields.get("2c" if day else "2d",0)))
		ambient_failed=0 if stream_play("ambient",track_key("24" if day else "28"),4) else 1
	fields["20"]=1
func battle_toggle(play_value: bool)->void:
	if not play_value:
		if int(fields.get("18",0))!=0:
			stream_fade("music",800)
			_play_stinger();music_toggle(true)
		fields["18"]=0;return
	if active and not track_key("1c").is_empty():
		fields["18"]=1
		if not stream_is_playing("music"):
			retry=0;schedule_failure(stream_play("music",track_key("1c"),8))
		elif not same_file(stream_file("music"),track_key("1c")):
			stream_fade("music",800);fields["8"]=0;retry=10;last_time=Time.get_ticks_msec()
func start_owner()->void:
	active=true
	if int(fields.get("18",0))!=0:battle_toggle(true)
	else:music_toggle(bool(fields.get("8",0)))
	ambient_toggle(bool(fields.get("20",0)))

func _apply(command: Dictionary)->void:
	stats.commands+=1
	var op:=int(command.operation);var value:=int(command.get("value",0));var day_value:=bool(command.get("day",false))
	match op:
		1:music_toggle(bool(command.get("play",false)))
		2:
			if value>0:delay_ms=value
		4:battle_toggle(bool(command.get("play",false)))
		6:ambient_toggle(bool(command.get("play",false)))
		3,5,7:
			var music_track: bool=op!=7
			var key: String="1c" if op==5 else "10" if music_track and day_value else "14" if music_track else "24" if day_value else "28"
			var channel: String="music" if music_track else "ambient"
			var stop_current: bool=stream_is_playing(channel) and same_file(stream_file(channel),track_key(key))
			if op==5:
				if stop_current:battle_toggle(false)
				load_track(key,true,value);fields[key]=value
				if stop_current:battle_toggle(true)
			else:
				if stop_current:
					if music_track:music_toggle(false)
					else:ambient_toggle(false)
				load_track(key,music_track,value);fields[key]=value
				if music_track:music_toggle(true);retry=1
				else:ambient_toggle(true)
		8:
			var key: String="2c" if day_value else "2d"
			var track_name: String="24" if day_value else "28"
			if int(fields.get(key,0))!=value:
				if stream_is_playing("ambient") and same_file(stream_file("ambient"),track_key(track_name)):stream_volume("ambient",value&255)
				fields[key]=value&255

func _play_stinger()->void:
	if not active:return
	var stingers: Array=tracks.get("1c",{}).get("stingers",[])
	if stingers.is_empty() or str(stingers[0]).is_empty():return
	var count:=1
	if stingers.size()>1 and not str(stingers[1]).is_empty():
		count=2
		if stingers.size()>2 and not str(stingers[2]).is_empty():count=3
	# NativeAmbientOwner's default RNG returns one of 0x8000 values before the
	# stinger-count modulus, including the slight three-track remainder bias.
	stinger_one_shot(str(stingers[int((randi()%0x8000)%count)]))

func stinger_one_shot(res_ref: String)->void:
	var name:=_ref(res_ref)
	if name.is_empty():return
	if stinger_cache.has(name):
		start_stinger(stinger_cache[name]);return
	var type:=resource_type(catalog,name,"stinger")
	if type<0:
		report_failure("audio.sound-failed","Native stinger resource is unavailable: "+name,{"areaId":area_id,"resRef":name});return
	var id: int=assets.request(name,type,"wave-native-v1")
	if id<0:
		report_failure("audio.sound-failed",str(assets.failure),{"areaId":area_id,"resRef":name});return
	jobs[id]={"generation":generation,"kind":"stinger","name":name};stats.requests+=1

func start_stinger(cue: AudioStream)->void:
	if cue==null:return
	var player:=AudioStreamPlayer.new();add_child(player);player.stream=cue
	if cue is AudioStreamWAV:cue.loop_mode=AudioStreamWAV.LOOP_DISABLED
	elif cue is AudioStreamMP3 or cue is AudioStreamOggVorbis:cue.loop=false
	stinger_voices.append(player)
	player.finished.connect(func():
		stinger_voices.erase(player);player.stop();player.stream=null;player.queue_free())
	player.play();stats.loads+=1

func _tables_ready()->void:
	if not loading or not tables.has("ambientmusic") or not tables.has("ambientsound"):return
	loading=false
	if not reported_adapter:
		reported_adapter=true
		report_failure("network.ambient-mixer-clock-unimplemented","Native area audio mixer settings and synchronized pause timing are not connected; category gain defaults and a monotonic presentation clock are used")
	channels={"music":{"name":"","status":"idle","job":-1,"generation":0,"loop":false,"volume":127,"loaded":0,"started":0},"ambient":{"name":"","status":"idle","job":-1,"generation":0,"loop":true,"volume":127,"loaded":0,"started":0}}
	for key in ["10","14","1c","24","28"]:load_track(key,key not in ["24","28"],int(fields.get(key,0)))
	last_time=Time.get_ticks_msec()
	start_owner()
	for command in pending:
		if not active:break
		_apply(command)
	pending.clear()

static func _track_cell(row: Dictionary,name: String)->Dictionary:
	var value: Variant=row.get(name)
	# JS `!value` is type-specific. Comparing a 2DA String with false or 0
	# is an invalid GDScript operation and prevents all ambient tracks.
	if value==null:return {"value":""}
	if value is bool and not value:return {"value":""}
	if value is int or value is float:
		if float(value)==0.0 or is_nan(float(value)):return {"value":""}
	if value is String and (value.is_empty() or value=="****"):return {"value":""}
	return ScriptString.change_case(str(value),true)
static func track(table: Dictionary,id: int,music_track: bool)->Dictionary:
	var rows: Array=table.get("orderedRows",[])
	var row: Dictionary=rows[id] if id>=0 and id<rows.size() and rows[id] is Dictionary else {}
	var resource_value: Dictionary=_track_cell(row,"Resource")
	if resource_value.has("error"):return {"resource":"","stingers":[],"error":resource_value.error}
	var resource:=str(resource_value.value)
	var stingers: Array[String]=[]
	if music_track:
		for name in ["Stinger1","Stinger2","Stinger3"]:
			var converted: Dictionary=_track_cell(row,name)
			if converted.has("error"):return {"resource":"","stingers":[],"error":converted.error}
			stingers.append(str(converted.value))
	return {"resource":resource,"stingers":stingers}

static func _ref(value: String)->String:
	if value=="****" or value.is_empty():return ""
	return State.resource_ref(value).to_lower()

func stream_player(channel: String)->AudioStreamPlayer:
	return music if channel=="music" else ambient
func stream_stop(channel: String)->void:
	if not channels.has(channel):return
	var state: Dictionary=channels[channel]
	state.generation=int(state.get("generation",0))+1;state.job=-1;state.status="idle"
	state.erase("fadeStart");state.erase("fadeEnd");state.erase("fadeVolume")
	var player: AudioStreamPlayer=stream_player(channel)
	player.stop();player.stream=null
func stream_volume(channel: String,value: int)->void:
	if not channels.has(channel):return
	var state: Dictionary=channels[channel];state.volume=value&255
	if str(state.status)!="fading":stream_player(channel).volume_linear=State.f(float(int(state.volume))/127.0)
func stream_fade(channel: String,duration: int)->void:
	if not stream_is_playing(channel):return
	var state: Dictionary=channels[channel]
	var player: AudioStreamPlayer=stream_player(channel)
	if duration<=0 or player.stream==null:stream_stop(channel);return
	if state.has("fadeEnd"):return
	state.fadeStart=Time.get_ticks_msec();state.fadeEnd=int(state.fadeStart)+duration;state.fadeVolume=State.f(float(int(state.volume))/127.0);state.status="fading"
func stream_failed(channel: String,name: String,reason: String)->void:
	stream_stop(channel)
	var state: Dictionary=channels[channel];state.status="failed";stats.misses+=1
	failure=reason
	if channel=="ambient":ambient_failed=1
	elif channel=="music":retry=10000;last_time=Time.get_ticks_msec()
	report_failure("audio.sound-failed" if channel=="stinger" else "network.ambient-resource-failed",reason,{"areaId":area_id,"stream":channel,"resRef":name})
func stream_play(channel: String,res_ref: String,_type: int)->bool:
	if closed or res_ref.is_empty() or not channels.has(channel):return false
	var name:=_ref(res_ref)
	if name.is_empty():return false
	stream_stop(channel)
	var state: Dictionary=channels[channel]
	state.name=name;state.status="loading"
	var type:=resource_type(catalog,name,channel)
	if type<0:
		stream_failed(channel,name,"Native ambient resource is unavailable: "+name);return true
	var id: int=assets.request(name,type,"wave-native-v1")
	if id<0:
		stream_failed(channel,name,str(assets.failure));return true
	state.job=id
	jobs[id]={"generation":generation,"streamGeneration":int(state.generation),"kind":"stream","channel":channel,"name":name};stats.requests+=1
	return true

static func resource_type(source: Variant,name: String,channel: String)->int:
	# The native audio lookup prefers BMU for a WAV request. A music request
	# is strict BMU; ambient and one-shot stingers request WAV resources.
	if source.has_method("audio_resource_type"):return source.audio_resource_type(name,4 if channel in ["ambient","stinger"] else 8)
	if source.has_resource(name,8):return 8
	if channel in ["ambient","stinger"] and source.has_resource(name,4):return 4
	return -1

func prepared(id: int,result: Dictionary)->void:
	if not jobs.has(id):return
	var job: Dictionary=jobs[id];jobs.erase(id)
	if closed or int(job.generation)!=generation:stats.stale+=1;return
	if job.kind=="table":
		if not str(result.get("error","")).is_empty() or not result.get("value") is Dictionary:
			failure="Native ambient table unavailable: "+str(job.name);loading=false;pending.clear()
			report_failure("network.ambient-load-failed",failure,{"areaId":area_id});return
		tables[str(job.name)]=result.value;_tables_ready();return
	if job.kind=="stinger":
		var cue: AudioStream=_stream(result)
		if cue==null:
			report_failure("audio.sound-failed","Native stinger resource is unavailable: "+str(job.name),{"areaId":area_id,"resRef":str(job.name)});return
		stinger_cache[str(job.name)]=cue;start_stinger(cue);return
	var channel:=str(job.channel);var state: Dictionary=channels.get(channel,{})
	if state.is_empty() or int(state.job)!=id or int(state.generation)!=int(job.get("streamGeneration",-1)) or str(state.name)!=str(job.name):stats.stale+=1;return
	var stream:=_stream(result)
	if stream==null:stream_failed(channel,str(job.name),stream_failure_reason(result,str(job.name)));return
	var player: AudioStreamPlayer=stream_player(channel)
	player.stream=stream
	if stream is AudioStreamWAV:stream.loop_mode=AudioStreamWAV.LOOP_FORWARD if bool(state.loop) else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:stream.loop=bool(state.loop)
	player.volume_linear=State.f(float(int(state.volume))/127.0)
	state.loaded=int(state.loaded)+1;state.status="queued";stats.loads+=1
	player.play();state.started=int(state.started)+1;state.status="playing";state.job=-1

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

static func stream_failure_reason(result: Dictionary,name: String)->String:
	var resource_error:=str(result.get("error",""))
	if not resource_error.is_empty():return resource_error
	var data: Variant=result.get("value")
	if data is Dictionary and not data.is_empty():
		if str(data.get("codec",""))=="mp3":
			var bytes: PackedByteArray=result.get("bytes",PackedByteArray())
			if bytes.size()<=8 or bytes.slice(0,8).get_string_from_ascii()!="BMU V1.0":return "Invalid native BMU header"
		return "Native audio stream decode failed"
	return "Native ambient stream unavailable: "+name

func _process(_delta: float)->void:
	if not active or closed:return
	var now:=Time.get_ticks_msec()
	for channel in ["music","ambient"]:
		var state: Dictionary=channels.get(channel,{})
		if not state.has("fadeEnd"):continue
		if now>=int(state.fadeEnd):stream_stop(channel);continue
		var amount:=1.0-float(now-int(state.fadeStart))/float(int(state.fadeEnd)-int(state.fadeStart))
		stream_player(channel).volume_linear=State.f(float(state.fadeVolume)*clampf(amount,0.0,1.0))
	frame(now)

func frame(now: int)->void:
	if not active:return
	if not stream_is_playing("music"):
		if retry==0:
			if int(fields.get("8",0))!=0 or int(fields.get("18",0))!=0:
				retry=1000 if int(fields.get("18",0))!=0 else maxi(1,delay_ms);last_time=now
		else:
			var elapsed:=0 if last_time==null else maxi(0,now-int(last_time))
			if retry<=elapsed:
				retry=0
				if int(fields.get("18",0))!=0:battle_toggle(true)
				else:music_toggle(true)
			else:retry-=elapsed;last_time=now
	if not stream_is_playing("ambient") and int(fields.get("20",0))!=0 and ambient_failed==0:ambient_toggle(true)

func detach()->void:
	generation+=1;active=false;loading=false;area_id=-1;pending.clear();jobs.clear();retry=0;last_time=null;ambient_failed=0;tracks.clear()
	for channel in ["music","ambient"]:stream_stop(channel)
	channels.clear()

func snapshot()->Dictionary:
	var stream_rows: Dictionary={}
	for channel in ["music","ambient"]:
		if not channels.has(channel):continue
		var state: Dictionary=channels[channel]
		stream_rows[channel]={"file":str(state.name),"status":str(state.status),"loop":bool(state.loop),"volume":int(state.volume),"loaded":int(state.loaded),"started":int(state.started)}
	var owner: Variant={"fields":fields.duplicate(true),"delay":delay_ms,"retry":retry,"ambientFailed":ambient_failed,"enabled":active,"day":day,"category":category,"singleStream":false,"tracks":tracks.duplicate(true)} if active else null
	return {"areaId":area_id,"generation":generation,"active":active,"loading":loading,"pending":pending.size(),"owner":owner,"streams":stream_rows if active else null,"fields":fields.duplicate(true),"day":day,"channels":channels.duplicate(true),"failure":failure,"diagnostics":diagnostics.duplicate(true),"stats":stats.duplicate()}

func close()->void:
	if closed:return
	detach();closed=true;stinger_cache.clear();set_process(false)
	for player in stinger_voices:
		if is_instance_valid(player):player.stop();player.stream=null;player.queue_free()
	stinger_voices.clear()
	if assets!=null and assets.completed.is_connected(prepared):assets.completed.disconnect(prepared)
	if owned_assets and assets!=null:assets.close();assets.queue_free()

func _exit_tree()->void:close()
