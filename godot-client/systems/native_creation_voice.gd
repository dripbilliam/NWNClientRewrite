extends Node
# Original SSF V1.0 and installed audio bytes; Godot owns decoding/playback.
const Assets=preload("res://systems/native_data/asset_service.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
var assets
var audio
var selected:=-1
var code:=0
var request_id:=-1
var stage:=""
var dead:=false
var last: Dictionary={}
func configure(catalog,player_owner) -> void:
	audio=player_owner; assets=Assets.new(); add_child(assets); assets.maximum_workers=1; assets.configure(catalog); assets.completed.connect(prepared)
func play(id: int,name: String) -> void:
	if dead: return
	stop()
	if id!=selected: selected=id; code=0
	var line:=code; code=(code+1)%49
	last={"voice":id,"code":line,"native":true}; audio.status="Loading sample "+str(line+1)+"…"
	stage="ssf"; request_id=assets.request(name,2060,"bytes")
func prepared(id: int,result: Dictionary) -> void:
	if dead or id!=request_id: return
	request_id=-1
	if not str(result.error).is_empty(): audio.status=str(result.error); return
	var bytes: PackedByteArray=result.bytes
	if stage=="ssf":
		var line:=int(last.code)
		if bytes.size()<40 or bytes.slice(0,8).get_string_from_ascii()!="SSF V1.0": audio.status="Unsupported soundset header."; return
		var count:=int(bytes.decode_u32(8)); var table:=int(bytes.decode_u32(12))
		if count>1000000 or table>bytes.size() or count*4>bytes.size()-table: audio.status="Invalid soundset table."; return
		var offset:=int(bytes.decode_u32(table+line*4)) if line<count else 0
		if offset==0: audio.status="No line in sample "+str(line+1)+". Play sample advances to the next line."; return
		if offset>bytes.size()-20: audio.status="Invalid soundset entry."; return
		var name:=Binary.new(bytes).text(offset,16,true)
		if name.is_empty(): audio.status="This sample is empty. Play sample for the next line."; return
		last.resource=name; stage="audio"; request_id=assets.request(name,4,"bytes"); return
	var stream: AudioStream
	var header:=bytes.slice(0,8).get_string_from_ascii() if bytes.size()>=8 else ""
	if header=="BMU V1.0":
		var mp3:=AudioStreamMP3.new(); mp3.data=bytes.slice(8); stream=mp3
	elif bytes.size()>=12 and bytes.slice(0,4).get_string_from_ascii()=="RIFF" and bytes.slice(8,12).get_string_from_ascii()=="WAVE": stream=AudioStreamWAV.load_from_buffer(bytes)
	elif bytes.size()>=4 and bytes.slice(0,4).get_string_from_ascii()=="OggS": stream=AudioStreamOggVorbis.load_from_buffer(bytes)
	elif bytes.size()>=3 and (bytes.slice(0,3).get_string_from_ascii()=="ID3" or bytes[0]==255 and (bytes[1]&224)==224):
		var mp3:=AudioStreamMP3.new(); mp3.data=bytes; stream=mp3
	if stream==null or stream.get_length()<=0: audio.status="Native decoder could not open this voice sample."; return
	audio.player.stream=stream; audio.player.play(); audio.played+=1; audio.status="Playing sample "+str(int(last.code)+1)+"."; last.seconds=stream.get_length(); last.played=true
func stop() -> void:
	request_id=-1; stage=""
	if is_instance_valid(audio): audio.stop()
func reset() -> void: stop(); selected=-1; code=0
func close() -> void: dead=true; reset(); assets.close()
