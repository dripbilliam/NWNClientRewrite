extends "res://tests/native_parry_world_test.gd"
const Ssf=preload("res://systems/native_data/sound_set.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const NativeEntry=preload("res://native_live_world.gd") # Compile actual delivery; do not start its protocol connection.
const LiveWorld=preload("res://systems/native_render/live_world.gd")
class MemoryCatalog extends RefCounted:
	var source
	var authored: Dictionary={}
	var failure:=""
	func fork():
		var copy=MemoryCatalog.new(); copy.source=source.fork(); copy.authored=authored.duplicate(); return copy
	func preparation_cache(): return source.preparation_cache()
	func has_resource(name: String,type: int) -> bool: return authored.has(name.to_lower()+":"+str(type)) or source.has_resource(name,type)
	func get_resource(name: String,type: int) -> PackedByteArray:
		failure=""; var key:=name.to_lower()+":"+str(type)
		if authored.has(key): return authored[key]
		var bytes: PackedByteArray=source.get_resource(name,type); failure=source.failure; return bytes
func sound_set(entries: Array) -> PackedByteArray:
	var bytes:=PackedByteArray(); bytes.resize(40+entries.size()*4+entries.size()*20); bytes.fill(0)
	for i in 8: bytes[i]="SSF V1.0".unicode_at(i)
	bytes.encode_u32(8,entries.size()); bytes.encode_u32(12,40)
	for index in entries.size():
		var at:=40+entries.size()*4+index*20; bytes.encode_u32(40+index*4,at)
		var name: String=entries[index]
		for i in mini(16,name.length()): bytes[at+i]=name.unicode_at(i)
		bytes.encode_u32(at+16,0xffffffff)
	return bytes
func tone() -> PackedByteArray:
	var bytes:=PackedByteArray(); bytes.resize(44+16000); bytes.fill(0)
	for pair in [[0,"RIFF"],[8,"WAVE"],[12,"fmt "],[36,"data"]]:
		for i in 4: bytes[int(pair[0])+i]=str(pair[1]).unicode_at(i)
	bytes.encode_u32(4,bytes.size()-8); bytes.encode_u32(16,16); bytes.encode_u16(20,1); bytes.encode_u16(22,1); bytes.encode_u32(24,8000); bytes.encode_u32(28,16000); bytes.encode_u16(32,2); bytes.encode_u16(34,16); bytes.encode_u32(40,16000)
	for i in 8000: bytes.encode_s16(44+i*2,int(sin(float(i)*TAU*220/8000)*2000))
	return bytes
func original_voice(catalog) -> Dictionary:
	var raw: PackedByteArray=catalog.get_resource("soundset",2017); var parser:=Table.new(); var data:=parser.parse(raw.get_string_from_ascii())
	for index in data.orderedRows.size():
		var name:=str(data.orderedRows[index].get("RESREF",""))
		if name in ["","****"] or not catalog.has_resource(name,2060): continue
		var resource: PackedByteArray=catalog.get_resource(name,2060); var ssf:=Ssf.new(); var set_data:=ssf.parse(resource)
		if set_data.is_empty(): continue
		for code in [11,14,0]:
			var entry: Variant=Ssf.entry(set_data,code)
			if entry==null or str(entry.resRef).is_empty() or not catalog.has_resource(str(entry.resRef),4): continue
			var bytes: PackedByteArray=catalog.get_resource(str(entry.resRef),4)
			if bytes.size()>8 and bytes.slice(0,8).get_string_from_ascii()=="BMU V1.0": return {"id":index,"set":name,"code":code,"resource":str(entry.resRef),"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes)}
	return {}
func mixer_survivors(audio) -> int:
	return audio.retired_players.filter(func(ref):return ref.get_ref()!=null).size()+audio.retired_playback_refs.filter(func(ref):return ref.get_ref()!=null).size()
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original:=Catalog.new(); check(original.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original native audio mounts read-only")
	var chosen:=original_voice(original)
	check(not chosen.is_empty(),"An actual original SSF names an installed BMU voice")
	if chosen.is_empty(): quit(1); return
	var catalog:=MemoryCatalog.new(); catalog.source=original
	catalog.authored={"soundset:2017":"2DA V2.0\n\nRESREF\n0 testvoicea\n1 testvoiceb\n2 testbad\n3 testcold\n".to_ascii_buffer(),"testvoicea:2060":sound_set([chosen.resource,"","no_voice_file","testvoicepcm","testvoicepcm2"]),"testvoiceb:2060":sound_set(["testvoicepcm2"]),"testbad:2060":"bad".to_ascii_buffer(),"testcold:2060":sound_set([chosen.resource]),"testvoicepcm:4":tone(),"testvoicepcm2:4":tone()}
	var world:=ParryWorld.new(); world.catalog=catalog; root.add_child(world)
	world.combat=preload("res://systems/native_render/combat_presentation.gd").new(); world.add_child(world.combat)
	var actor:=Node3D.new(); world.add_child(actor); actor.position=Vector3(2,1,-3); world.instances[world.controlled_id]=actor
	var camera:=Camera3D.new(); world.add_child(camera); camera.position=Vector3(2,5,3); camera.make_current()
	var object:={"id":world.controlled_id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":0,"field8A0":0},"replicated":{"position":[2,3,1]}}
	world.desired[world.controlled_id]={"key":"one","object":object}; world.installed[world.controlled_id]="one"
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world); var voices=owner.creature_voices; var audio=owner.world_audio
	check(await wait_for(func():return owner.tables.size()==3 and not voices.table.is_empty()),"Active native appearance and custom soundset tables prepare")
	var canonical:=JSON.stringify(object); world.combat.engine.event("bark",world.controlled_id,{"code":0})
	check(await wait_for(func():return audio.stats.played>0 and voices.records.has(world.controlled_id)),"Actual combat event drives original BMU bytes through native SSF/MP3 playback")
	var r: Dictionary=voices.records[world.controlled_id]; var sound:=int(r.sound); var voice: Dictionary=audio.voices[sound]; var resource: Dictionary=audio.resources[voice.resourceId]
	check(resource.metadata.codec=="mp3" and resource.stream is AudioStreamMP3 and resource.stream.get_length()>0 and voice.profile.priority==6 and voice.profile.positional and voice.position==[2.0,3.0,2.5],"Original voice decodes with controlled priority6 and original height1.5")
	await create_timer(0.08).timeout
	check(is_instance_valid(voice.player) and voice.player.get_playback_position()>0,"Native Dummy audio advances an actual original voice clock; physical audibility is not claimed")
	actor.position+=Vector3(1,0,0); voices.advance()
	check(voice.position==[3.0,3.0,2.5],"Original8114d0 source refresh follows the current actor pose instead of its old snapshot position")
	for code in [1,2,65535]:
		voices.request(world.controlled_id,code); voices.advance()
		check(int(r.sound)==sound and audio.voices.has(sound),"Empty/missing/out-of-range SSF request preserves existing source "+str(code))
	check(JSON.stringify(object)==canonical,"Native SSF and playback change no canonical server state")
	voices.request(world.controlled_id,3); voices.advance()
	check(int(r.sound)!=sound and not audio.voices.has(sound) and r.delay==0,"Admitted replacement destroys the old native source and resets original delay")
	sound=int(r.sound)
	check(await wait_for(func():return audio.voices.has(sound) and is_instance_valid(audio.voices[sound].player)),"Authored PCM replacement also decodes through the shared native audio owner")
	var npc:=0x80000002; var other: Dictionary=object.duplicate(true); other.id=npc; other.appearance.field8A0=1; world.desired[npc]={"key":"two","object":other}
	voices.set_players([[7,{"objectId":npc}]])
	var packet:={"serial":1,"events":[{"objectId":npc,"voiceCode":256,"lifetime":1,"soundsetId":1}]}; voices.receive_raw(packet); voices.receive_raw(packet)
	check(await wait_for(func():return voices.records.has(npc) and audio.voices.has(int(voices.records[npc].sound))),"Decoded server voice26/1 binds the canonical actor and BYTE code exactly once")
	var npc_sound:=int(voices.records[npc].sound); check(audio.voices[npc_sound].profile.priority==7,"Server player membership selects original remote-player priority7")
	voices.set_players([]); voices.request(npc,0); voices.advance(); npc_sound=int(voices.records[npc].sound)
	var size: int=preload("res://systems/native_data/combat_actor.gd").integer(owner.tables.appearance,0,"SIZECATEGORY")
	check(audio.voices[npc_sound].profile.priority==(15 if size<4 else 14),"NPC priority derives from the active appearance size category")
	owner.tables.appearance.orderedRows[0].SIZECATEGORY="5"; voices.request(npc,0); voices.advance(); npc_sound=int(voices.records[npc].sound)
	check(audio.voices[npc_sound].profile.priority==14,"Active custom appearance size chooses original large-NPC priority14")
	object.appearance.field8A0=2; voices.request(world.controlled_id,0)
	check(await wait_for(func():return voices.queue.is_empty() and voices.sets.has("testbad")),"Malformed custom SSF terminates its pending request without touching an existing source")
	check(int(r.sound)==sound and audio.voices.has(sound) and voices.stats.failed==1,"Failed SSF load preserves old voice, with an explicit resource diagnostic")
	object.appearance.field8A0=65535; voices.request(world.controlled_id,0); voices.advance()
	check(int(r.sound)==sound and audio.voices.has(sound),"Disabled soundset suppresses new requests without inventing a source stop")
	voices.receive_raw({"serial":2,"events":[{"objectId":0x80000003,"voiceCode":0,"lifetime":8,"soundsetId":1}]}); voices.advance()
	check(voices.queue.size()==1,"Voice received before its native snapshot retains its captured canonical lifetime")
	var late: Dictionary=other.duplicate(true); late.id=0x80000003; late.nativeLifetime=9; world.desired[late.id]={"key":"late","object":late}; voices.advance()
	check(voices.queue.is_empty() and not voices.records.has(late.id),"A later actor reuse cannot inherit the deferred older voice")
	world.desired.erase(npc); voices.advance()
	check(not voices.records.has(npc) and not audio.voices.has(npc_sound),"Canonical removal destroys that actor's native voice source")
	var snapshot: Dictionary=voices.snapshot(); var audio_snapshot: Dictionary=audio.snapshot()
	object.appearance.field8A0=3; voices.request(world.controlled_id,0); voices.advance()
	check(not voices.jobs.is_empty() and not voices.queue.is_empty(),"Cold SSF remains an owned native worker job while the actor is admitted")
	var retirement_scope:=LiveWorld.new(); retirement_scope.effects=owner
	check(retirement_scope.asset_owners().has(voices.assets) and voices.assets.running.values().all(func(task):return retirement_scope.worker_tasks().has(task)),"Actual live-world retirement inventory includes the independent native voice asset service and worker handles")
	retirement_scope.begin_retirement(); retirement_scope.effects=null; retirement_scope.free()
	voices.receive_raw({"serial":3,"events":[{"objectId":world.controlled_id,"voiceCode":0,"lifetime":1,"soundsetId":3}]}); voices.advance()
	check(voices.retiring and voices.records.is_empty() and voices.queue.is_empty() and audio.voices.is_empty(),"Transition start stops actor voices and rejects new/late requests before background SSF draining")
	resource={}; voice={}; owner.close(); world.combat.close(); await settle_retirement()
	var deadline:=Time.get_ticks_msec()+2000
	while mixer_survivors(audio)>0 and Time.get_ticks_msec()<deadline: await create_timer(0.02).timeout
	check(voices.records.is_empty() and voices.queue.is_empty() and voices.manager==null and mixer_survivors(audio)==0,"World close releases native actors, asset jobs and actual mixer playback references")
	world.instances.clear(); world.desired.clear(); world.pool.clear(); world.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalVoice":chosen,"driver":AudioServer.get_driver_name(),"voices":snapshot,"audio":audio_snapshot,"scope":"Actual original BMU voice selected from original SSF, native active tables/SSF, combat signal and decoded server delivery, real Dummy MP3/PCM playback, priority/height, replacement/failure/stale and mixer retirement. No game server, graphical workload or physical audibility acceptance."},"\t")); file.close()
	print("NATIVE_CREATURE_VOICE_WORLD ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
