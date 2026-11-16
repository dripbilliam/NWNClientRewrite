extends SceneTree
const Owner=preload("res://systems/native_data/native_creature_voice_owner.gd")
const Decoder=preload("res://systems/native_data/native_network_creature_voice.gd")

func _initialize()->void:
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_creature_voice_fixture.json"))
	if not fixture is Dictionary or int(fixture.get("schema",0))!=1 or int(fixture.get("capturedNative",-1))!=0 or fixture.cases.size()<2:fail("Voice packet oracle unavailable");return
	var voice: Dictionary=Decoder.decode_packet(str(fixture.cases[0].packet).hex_decode())
	var quick: Dictionary=Decoder.decode_packet(str(fixture.cases[1].packet).hex_decode())
	if voice.get("kind")!="voice-play" or quick.get("kind")!="quick-chat" or int(voice.objectId)!=2147483648 or int(quick.objectId)!=2147483648:fail("Original voice packet identity changed");return
	var owner=Owner.new()
	var actor: Dictionary={"id":2147483648,"objectType":5,"areaId":77,"nativeLifetime":19,"appearance":{"field8A0":12},"replicationRemoved":false}
	if owner.receive(quick,actor).get("accepted",false):fail("Packet accepted outside area");return
	owner.begin_area(77,1)
	var first: Dictionary=owner.receive(voice,actor)
	var second: Dictionary=owner.receive(quick,actor)
	if not first.get("accepted",false) or not second.get("accepted",false) or int(first.ticket.sequence)>=int(second.ticket.sequence):fail("Voice/quick-chat request order changed");return
	var ssf: Dictionary={"count":1,"entries":[{"resRef":"v_hello","strRef":12345}]}
	var ready_quick: Dictionary=owner.prepare(second.ticket,actor,ssf)
	if not ready_quick.get("ready",false) or int(ready_quick.caption.strRef)!=12345 or int(ready_quick.caption.actorId)!=2147483648 or str(ready_quick.audio.resRef)!="v_hello":fail("Quick-chat caption/SSF mapping changed");return
	var ready_voice: Dictionary=owner.prepare(first.ticket,actor,ssf)
	if not ready_voice.get("ready",false) or not ready_voice.caption.is_empty() or str(ready_voice.audio.resRef)!="v_hello":fail("Voice packet incorrectly gained caption");return
	if owner.prepare(first.ticket,actor,{"count":2,"entries":[{"resRef":"v_hello","strRef":12345}]}).get("ready",true):fail("Malformed decoded SSF shape was accepted");return
	if owner.admit_audio(second.ticket,actor,ready_quick.audio,false,false,false,5).get("ready",false):fail("Missing WAV replaced existing voice");return
	var older: Dictionary=owner.admit_audio(first.ticket,actor,ready_voice.audio,true,false,false,3)
	if not older.get("ready",false) or int(older.play.priority)!=15 or float(older.play.height)!=1.5:fail("Non-player voice priority/height changed");return
	var newer: Dictionary=owner.admit_audio(second.ticket,actor,ready_quick.audio,true,false,false,5)
	if not newer.get("ready",false) or int(newer.play.priority)!=7 or float(newer.play.height)!=0.0 or not newer.play.replace:fail("Quick-chat priority/height/replacement changed");return
	if owner.admit_audio(first.ticket,actor,ready_voice.audio,true,false,false,3).get("ready",false):fail("Older delayed voice replaced newer admitted source");return
	var no_wave: Dictionary=owner.prepare(second.ticket,actor,{"count":1,"entries":[{"resRef":"","strRef":888}]})
	if not no_wave.get("ready",false) or int(no_wave.caption.strRef)!=888 or not no_wave.audio.is_empty():fail("Empty SSF WAV overrode caption semantics");return
	var no_caption: Dictionary=owner.prepare(second.ticket,actor,{"count":1,"entries":[{"resRef":"v_hello","strRef":4294967295}]})
	if not no_caption.get("ready",false) or not no_caption.caption.is_empty():fail("Invalid SSF string reference gained a caption");return
	var controlled: Dictionary=owner.receive(quick,actor)
	var prepared: Dictionary=owner.prepare(controlled.ticket,actor,ssf)
	if int(owner.admit_audio(controlled.ticket,actor,prepared.audio,true,true,false,5).play.priority)!=6:fail("Controlled voice priority changed");return
	var old_ticket: Dictionary=owner.receive(quick,actor).ticket
	owner.forget_actor(int(actor.id))
	if owner.current(old_ticket,actor):fail("Actor removal retained pending voice");return
	var replaced_actor: Dictionary=actor.duplicate(true);replaced_actor.nativeLifetime=20
	var replacement: Dictionary=owner.receive(quick,replaced_actor)
	if not replacement.get("accepted",false):fail("New actor lifetime rejected");return
	owner.begin_area(78,2)
	if owner.current(replacement.ticket,replaced_actor):fail("Area transition retained old voice ticket");return
	var wrong: Dictionary=replaced_actor.duplicate(true);wrong.areaId=78;wrong.objectType=10
	if owner.receive(quick,wrong).get("accepted",false):fail("Non-creature actor accepted voice");return
	wrong.objectType=5;wrong.appearance.field8A0=65535
	if owner.receive(quick,wrong).get("accepted",false):fail("No-soundset creature accepted voice");return
	owner.reset()
	if owner.snapshot().areaId!=-1 or owner.receive(quick,actor).get("accepted",false):fail("Session reset retained voice state");return
	print("NWN79 Godot creature voice owner PASS: original_wire=true captions=true missing_wave=true overlap=true area_lifetime=true")
	quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot creature voice owner failed: "+reason)
	quit(1)
