extends SceneTree
const Voice=preload("res://systems/native_data/native_network_creature_voice.gd")

func _initialize()->void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/nwn79_creature_voice_fixture.json"))
	if not parsed is Dictionary or int(parsed.get("schema",0))!=1 or not parsed.get("cases") is Array:fail("Creature-voice oracle fixture unavailable");return
	var cases: Array=parsed.cases
	var origins: Dictionary={};var kinds: Dictionary={};var saw_high_id:=false;var saw_quick_max:=false;var saw_voice_max:=false
	for row in cases:
		var packet: PackedByteArray=str(row.packet).hex_decode()
		var actual: Dictionary=Voice.decode_packet(packet)
		if actual.has("error") or canonical(actual)!=canonical(row.expected):fail("Creature-voice oracle differs at "+str(row.name)+": "+str(actual.get("error","fields")));return
		origins[str(row.origin)]=int(origins.get(str(row.origin),0))+1
		kinds[str(actual.kind)]=int(kinds.get(str(actual.kind),0))+1
		saw_high_id=saw_high_id or int(actual.objectId)>=0x80000000
		saw_quick_max=saw_quick_max or actual.kind=="quick-chat" and int(actual.quickChat)==65535
		saw_voice_max=saw_voice_max or actual.kind=="voice-play" and int(actual.voiceCode)==255
		if actual.has("actor") or actual.has("sound") or actual.has("caption"):
			fail("Voice decoder invented actor/audio/caption state");return
		for length in range(packet.size()):
			if not Voice.decode_packet(packet.slice(0,length)).has("error"):fail("Truncated creature-voice packet accepted at "+str(row.name)+" length "+str(length));return
		var overlong:=packet.duplicate();overlong.append_array(PackedByteArray([0,0]))
		if not Voice.decode_packet(overlong).has("error"):fail("Trailing creature-voice bytes accepted at "+str(row.name));return
	if cases.size()!=118 or int(parsed.get("originalNativeVoiceWire",-1))!=60 or int(parsed.get("originalNativeQuickChatRelay",-1))!=54 or int(parsed.get("authoredWriter",-1))!=4 or int(parsed.get("capturedNative",-1))!=0 or int(origins.get("original native sender/writer and voice receiver observation",0))!=60 or int(origins.get("original native quick-chat relay sender observation",0))!=54 or int(origins.get("authored original-format writer checked against original JS receiver",0))!=4:
		fail("Creature-voice provenance changed");return
	if int(kinds.get("quick-chat",0))==0 or int(kinds.get("voice-play",0))==0 or not saw_high_id or not saw_quick_max or not saw_voice_max:
		fail("Creature-voice field coverage changed");return
	for mutation in [PackedByteArray(),PackedByteArray([80,22,0]),PackedByteArray([80,26,1]),PackedByteArray([80,22,1,7,0,0,0,0]),PackedByteArray([80,26,2,7,0,0,0,0]),PackedByteArray([112,26,1,7,0,0,0,0])]:
		if not Voice.decode_packet(mutation).has("error"):fail("Unsupported creature-voice envelope accepted");return
	print("NWN79 Godot creature-voice decoder PASS: native_voice_wire=60 native_quickchat_relay=54 authored=4 captured_native=0 malformed_checked=true")
	quit(0)

func canonical(value: Variant)->Variant:
	if value is bool:return 1.0 if value else 0.0
	if value is int or value is float:return float(value)
	if value is Array:
		var array: Array=[]
		for item in value:array.append(canonical(item))
		return array
	if value is Dictionary:
		var dictionary: Dictionary={}
		for key in value.keys():dictionary[key]=canonical(value[key])
		return dictionary
	return value

func fail(reason: String)->void:
	printerr("NWN79 Godot creature-voice decoder failed: "+reason)
	quit(1)
