extends "res://systems/world_audio.gd"
# Native catalog bytes feed the retained listener/source owner directly.
# Other NWN audio encodings remain explicit diagnostics, never JS preparation.
func _resource_failure(voice: Dictionary,reason: String) -> void:
	var object_id:=int(voice.get("objectId",0x7f000000))
	var name:=str(voice.get("name",""))
	var channel:=str(voice.get("channel",""))
	if bool(voice.get("oneShot",false)):
		client.diagnose("audio.sound-failed",reason,0,{"resRef":name,"objectId":object_id})
	elif channel!="placed":
		client.diagnose("audio.effect-sound-failed",reason,int(voice.get("effectId",0)),{"resRef":name,"objectId":object_id,"channel":channel})

func resource_ready(id: int,result: Dictionary) -> void:
	if closed or not resources.has(id): return
	var row: Dictionary=resources[id]; var bytes: PackedByteArray=result.get("bytes",PackedByteArray()); var data: Dictionary=result.get("value",{})
	if not str(result.get("error","")).is_empty() or data.is_empty():
		var reason:=str(result.get("error",""))
		if reason.is_empty():reason="Original WAV decoder/resource unavailable: "+str(row.name)
		client.diagnose("visual.audio-resource-unavailable",reason,0); _fail_resource(row,reason); return
	var stream: AudioStream
	if data.codec=="pcm16":
		var wave:=AudioStreamWAV.new(); wave.format=AudioStreamWAV.FORMAT_16_BITS; wave.stereo=int(data.channels)==2; wave.mix_rate=int(data.sampleRate); wave.data=data.pcm; stream=wave
	elif data.codec=="mp3":
		var mp3:=AudioStreamMP3.new(); mp3.data=bytes.slice(8); stream=mp3
	else: stream=AudioStreamWAV.load_from_buffer(bytes)
	if stream==null or stream.get_length()<=0: _fail_resource(row,"Native WAV duration metadata is unavailable"); return
	row.stream=stream; row.metadata={"channels":int(data.channels),"sampleRate":int(data.sampleRate),"frames":int(data.frames) if data.get("frames") is int else roundi(stream.get_length()*int(data.sampleRate)),"bytes":bytes.size(),"codec":data.codec,"timing":data.timing}; row.bytes=bytes.size()
	cache_bytes+=bytes.size(); stats.imports+=1
	for voice in voices.values():
		if voice.resourceId==id:
			# BufferAudioSource's load completion increments loaded even if its
			# owner stopped while the resource was pending.
			if not voice.loadedNames.has(voice.name):
				voice.loadedNames[voice.name]=true;voice.loadedCount=int(voice.get("loadedCount",0))+1
			_tick(voice)
	_trim()
