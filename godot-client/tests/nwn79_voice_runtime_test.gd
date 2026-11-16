extends "res://tests/native_creature_voice_world_test.gd"
const VoiceWire=preload("res://systems/native_data/native_network_creature_voice.gd")
const GameplayUi=preload("res://systems/native_gameplay_ui.gd")
class ChatSink extends Node:
	var rows: Array=[]
	func append_message(row: Dictionary)->void:rows.append(row.duplicate(true))

func run()->void:
	var original:=Catalog.new();check(original.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original native resources mounted read-only")
	if not failures.is_empty():finish();return
	var ssf: PackedByteArray=sound_set(["testvoicepcm","missing_voice"])
	ssf.encode_u32(40+2*4+16,5189)
	ssf.encode_u32(40+2*4+20+16,5189)
	var catalog:=MemoryCatalog.new();catalog.source=original
	catalog.authored={"soundset:2017":"2DA V2.0\n\nRESREF\n0 testvoicea\n".to_ascii_buffer(),"testvoicea:2060":ssf,"testvoicepcm:4":tone()}
	var world:=ParryWorld.new();world.catalog=catalog;world.controlled_id=2147483648;root.add_child(world)
	world.combat=preload("res://systems/native_render/combat_presentation.gd").new();world.add_child(world.combat)
	var actor_node:=Node3D.new();world.add_child(actor_node);actor_node.position=Vector3(2,1,-3);world.instances[world.controlled_id]=actor_node
	var actor: Dictionary={"id":world.controlled_id,"objectType":5,"areaId":1,"nativeLifetime":1,"appearance":{"appearance":0,"field8A0":0},"replicated":{"position":[2,3,1],"name":{"text":"Nibs"}}}
	world.desired[world.controlled_id]={"key":"one","object":actor};world.installed[world.controlled_id]="one"
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	var effects:=Effects.new();world.add_child(effects);effects.configure(world)
	var voices=effects.creature_voices;var audio=effects.world_audio
	check(await wait_for(func():return effects.tables.size()==3 and not voices.table.is_empty()),"Native appearance and SSF tables ready")
	var ui=GameplayUi.new();root.add_child(ui);ui.set_process(false)
	var chat:=ChatSink.new();ui.add_child(chat);ui.chat=chat
	ui.generation=1;ui.area_id=1;ui.controlled_id=world.controlled_id;ui.native_connection_query=func():return 7
	ui.text.objects[world.controlled_id]=actor
	check(ui.text.base.open_file(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall/lang/en/data/dialog.tlk")),"Native base TLK opened read-only")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_creature_voice_fixture.json"))
	var quick: Dictionary=VoiceWire.decode_packet(str(fixture.cases[1].packet).hex_decode())
	var voice: Dictionary=VoiceWire.decode_packet(str(fixture.cases[0].packet).hex_decode())
	check(voices.receive_network(quick,Callable(ui,"receive_voice_caption"),7).get("accepted",false),"Decoded quick-chat accepted with scoped caption sink")
	check(await wait_for(func():voices.advance();return chat.rows.size()==1 and audio.stats.played>0 and voices.records.has(world.controlled_id)),"SSF quick-chat produces TLK caption and actual Godot audio source")
	if voices.records.has(world.controlled_id):
		var id: int=voices.records[world.controlled_id].sound
		check(audio.voices.has(id) and audio.voices[id].profile.priority==6 and audio.voices[id].position==[2.0,3.0,1.0],"Quick-chat uses controlled priority6 and height0: "+str(audio.voices[id].profile.priority)+" / "+str(audio.voices[id].position))
	check(chat.rows.size()==1 and str(chat.rows[0].text)==ui.text.raw({"strRef":5189}),"Quick-chat caption uses the existing TLK/chat text")
	var earlier_sound: int=voices.records[world.controlled_id].sound if voices.records.has(world.controlled_id) else -1
	check(voices.receive_network(voice).get("accepted",false),"Decoded 26/1 voice accepted")
	check(await wait_for(func():voices.advance();return voices.records.has(world.controlled_id) and int(voices.records[world.controlled_id].sound)!=earlier_sound and audio.stats.played>=2),"26/1 voice replaces quick-chat source")
	if voices.records.has(world.controlled_id):
		var id: int=voices.records[world.controlled_id].sound
		check(audio.voices.has(id) and audio.voices[id].position==[2.0,3.0,2.5],"26/1 retains native height1.5")
	check(chat.rows.size()==1,"26/1 voice does not emit a quick-chat caption")
	var missing: Dictionary=quick.duplicate(true);missing.quickChat=1
	var before: int=voices.records[world.controlled_id].sound if voices.records.has(world.controlled_id) else -1
	check(voices.receive_network(missing,Callable(ui,"receive_voice_caption"),7).get("accepted",false),"Missing-WAV quick-chat admitted for caption")
	check(await wait_for(func():voices.advance();return voices.queue.is_empty()),"Missing WAV request terminates")
	check(voices.records.has(world.controlled_id) and int(voices.records[world.controlled_id].sound)==before and chat.rows.size()==2,"Missing WAV preserves prior source but still captions")
	world.desired.erase(world.controlled_id);voices.advance()
	check(voices.records.is_empty() and audio.voices.is_empty(),"Actor removal cancels and destroys voice")
	voices.begin_retirement();effects.close();world.combat.close();ui.close();ui.queue_free();world.instances.clear();world.pool.clear();world.queue_free()
	await process_frame
	finish()

func finish()->void:
	print("NWN79 voice runtime ",checks," checks, ",failures.size()," failures: ",failures)
	quit(0 if failures.is_empty() else 1)
