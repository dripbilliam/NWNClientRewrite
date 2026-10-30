extends "res://tests/native_particle_schedule_test.gd"
const Voice=preload("res://systems/native_data/creature_voice.gd")
const Ssf=preload("res://systems/native_data/sound_set.gd")
const Bmu=preload("res://systems/native_data/bmu_wave.gd")
const Wave=preload("res://systems/native_data/wave_data.gd")
func image(c: Dictionary) -> PackedByteArray:
	var low:=int(c.version)==2; var rates:=[44100,48000,32000,22050,24000,16000]
	var bitrates:=[[0,32000,40000,48000,56000,64000,80000,96000,112000,128000,160000,192000,224000,256000,320000],[0,8000,16000,24000,32000,40000,48000,56000,64000,80000,96000,112000,128000,144000,160000]]
	var size:=int(int(bitrates[int(low)][int(c.bitrate)])*(72 if low else 144)/int(rates[int(low)*3+int(c.frequency)]))+int(c.padding)
	var header: int=(0xffe00000|(int(c.version)<<19)|(1<<17)|(int(not c.crc)<<16)|(int(c.bitrate)<<12)|(int(c.frequency)<<10)|(int(c.padding)<<9)|(int(c.mode)<<6))&0xffffffff
	var result: PackedByteArray="BMU V1.0".to_ascii_buffer(); var payload: PackedByteArray=PackedByteArray([73,68,51,0,0,0,0])
	for index in 2:
		var bytes:=PackedByteArray(); bytes.resize(size); bytes[0]=(header>>24)&255; bytes[1]=(header>>16)&255; bytes[2]=(header>>8)&255; bytes[3]=header&255
		if index==0 and c.info:
			var offset:=mini(size,4+(2 if c.crc else 0)+((9 if int(c.mode)==3 else 17) if low else (17 if int(c.mode)==3 else 32)))
			if offset+4>bytes.size(): bytes.resize(offset+4)
			for i in 4: bytes[offset+i]="Info".unicode_at(i)
		payload.append_array(bytes)
	var truncate:=int(c.get("truncate",0)); result.append_array(payload.slice(0,payload.size()-truncate) if truncate>0 else payload)
	return result
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:="res://../backups/animations/native-creature-voice-observations.json"; var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(oracle.target==BINARY_SHA and oracle.cases.size()==486,"Complete unchanged original807240 voice corpus and target")
	for row in oracle.cases:
		var c: Dictionary=row.case; var calls: Array=[]; var s:={"soundsetId":65535 if c.get("noSet",false) else int(c.get("setId",7)),"sound":{"name":"old"} if c.old else null,"delay":77}
		var p:={"demandSet":func(_id):calls.append(["demand"]); return null if c.get("demandFailure",false) else {},"entry":func(_data,code):calls.append(["entry",code]); return {"resRef":c.get("resRef","voice")},"releaseSet":func(_data):calls.append(["release"]),
			"exists":func(resource):calls.append(["exists",resource,4]); return not c.get("missingWave",false),"controlled":func():calls.append(["controlled"]); return c.controlled,"player":func():calls.append(["player"]); return c.player,"sizeCategory":func():calls.append(["size"]); return c.size,
			"destroySound":func(_sound):calls.append(["destroy"]),"createSound":func(resource):
				if c.get("allocationFailure",false): return null
				calls.append(["create",resource]); return {"name":"new"},
			"sound3d":func(_sound,value):calls.append(["3d",value]),"soundPriority":func(_sound,value):calls.append(["priority",value]),"position":func():return [1,2,3],"updateSound":func(_sound,point,height):calls.append(["position",point,height]),"playSound":func(_sound):calls.append(["play"])}
		Voice.play(s,int(c.code),int(c.positional),p)
		var actual:={"calls":calls,"state":{"delay":s.delay,"sound":s.sound.name if s.sound!=null else null}}; var expected:={"calls":row.calls,"state":row.state}
		check(same(actual,expected).is_empty(),"Original voice "+JSON.stringify(c)+" "+same(actual,expected))
	var bytes:=PackedByteArray(); bytes.resize(68); bytes.fill(0)
	for i in 8: bytes[i]="SSF V1.0".unicode_at(i)
	bytes.encode_u32(8,2); bytes.encode_u32(12,40); bytes.encode_u32(40,48); bytes.encode_u32(44,0)
	for i in 16: bytes[48+i]="abcdefghijklmnop".unicode_at(i)
	bytes.encode_u32(64,42)
	var parser:=Ssf.new(); var data:=parser.parse(bytes)
	check(parser.failure.is_empty() and Ssf.entry(data,0)=={"resRef":"abcdefghijklmnop","strRef":42} and Ssf.entry(data,1)==null and Ssf.entry(data,65536).strRef==42 and Ssf.entry(data,65535)==null,"Native SSF offsets, explicit null entry, 16-byte name and WORD index semantics")
	bytes.encode_u32(40,67); check(parser.parse(bytes).is_empty() and not parser.failure.is_empty(),"Malformed SSF entry is bounded locally")
	var mpeg_path:="res://../backups/animations/native-bmu-frame-observations.json"; var mpeg: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(mpeg_path))
	check(mpeg.target==BINARY_SHA and mpeg.cases.size()==294,"Original MPEG iterator/frame-owner corpus and target")
	var controlled_codec_cases:=0
	for row in mpeg.cases:
		var c: Dictionary=row.case
		if c.get("sideFailure",false) or c.get("mainFailure",false): controlled_codec_cases+=1; continue
		var raw:=image(c); var bmu:=Bmu.new(); var parsed:=bmu.parse(raw)
		if row.frames.is_empty(): check(parsed.is_empty() and not bmu.failure.is_empty(),"Original invalid MPEG header "+JSON.stringify(c)); continue
		var expected: Array=row.frames.duplicate(true)
		for entry in expected: entry.offset+=8
		var samples:=0
		for entry in expected: samples+=int(entry.samples)
		check(same(parsed.frames,expected).is_empty() and int(parsed.timing.duration)==int(float(samples)/int(parsed.sampleRate)*1000.0) and Wave.new().parse(raw)==parsed,"Original BMU frame/layout/timing "+JSON.stringify(c)+" "+same(parsed.frames,expected))
	check(Bmu.new().parse("BMU V1.0".to_ascii_buffer()).is_empty(),"Header-only BMU remains an explicit decode failure")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalVoiceSha256":FileAccess.get_sha256(path),"originalMpegSha256":FileAccess.get_sha256(mpeg_path),"controlledCodecCasesNotReimplemented":controlled_codec_cases,"scope":"Whole original807240 provider flow; bounded authored SSF; original MPEG layout/sample-count cases except codec-internal failure injection. Godot MP3 PCM equivalence, actual devices/servers and full mixer priority are separate acceptance."},"\t")); file.close()
	print("NATIVE_CREATURE_VOICE_DATA ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
