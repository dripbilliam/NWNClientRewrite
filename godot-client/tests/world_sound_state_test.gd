extends SceneTree
const State = preload("res://systems/world_sound_state.gd")
static func bits(v: float) -> int:
	var bytes := PackedByteArray();bytes.resize(4);bytes.encode_float(0,v);return bytes.decode_u32(0)
func _initialize() -> void:
	var audio_path := "";var delay_path := "";var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--audio-oracle="):audio_path = arg.substr(15)
		if arg.begins_with("--delay-oracle="):delay_path = arg.substr(15)
		if arg.begins_with("--report="):output = arg.substr(9)
	if output.is_empty() or audio_path.is_empty() or delay_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	var audio: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(audio_path));var delay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(delay_path))
	var target := "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
	if audio.target != target or delay.target != target:quit(2);return
	var comparisons := 0;var failures: Array = [];var cases := {"listener":0,"height":0,"delay":0}
	for row in audio.cases:
		if row.kind == "listener" and not row.calls.is_empty():
			cases.listener += 1
			var c: Dictionary = row.case;var actual := State.listener(c.player,c.camera,c.quaternion)
			for pair in [[actual.position,row.calls[0].value],[actual.forward,row.calls[1].forward],[actual.up,row.calls[1].up]]:
				for i in 3:
					comparisons += 1
					if bits(pair[0][i]) != bits(pair[1][i]):failures.append({"kind":"listener","case":c,"actual":pair[0],"expected":pair[1]})
		elif row.kind == "wrapper":
			cases.height += 1
			var actual := State.position(row.position,row.height)
			for i in 3:
				comparisons += 1
				if bits(actual[i]) != bits(row.calls[0].position[i]):failures.append({"kind":"height","case":row,"actual":actual})
	for row in delay.cases:
		if row.kind != "due":continue
		cases.delay += 1;comparisons += 1
		var c: Dictionary = row.case
		if State.delay_due(int(c.now),int(c.start),int(c.delay)) != row.due:failures.append({"kind":"delay","case":row})
	var authored := []
	for pair in [[State.resource_ref("abcdefghijklmnopq"),"abcdefghijklmnop"],[State.resource_ref("Voice-é"),"Voice-é"],[State.resource_ref(""),""]]:authored.append(pair[0] == pair[1])
	var profile := State.profile();profile.positional = true
	for d in [0.0,1.0,5.0,20.0,25.0]:
		var expected := State.f(State.f(127.0/255.0)*(1.0-(clampf(d,1,20)-1.0)/19.0));authored.append(bits(State.gain(profile,d)) == bits(expected))
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty() and authored.all(func(v):return v),"cases":cases,"comparisons":comparisons,"failures":failures,"authoredChecks":authored,"sourceSha256":FileAccess.get_sha256("res://systems/world_sound_state.gd"),"audioOracleSha256":FileAccess.get_sha256(audio_path),"delayOracleSha256":FileAccess.get_sha256(delay_path),"scope":"Retained original listener/height/delay observations; attenuation and resource-name examples are separately authored checks, not native binary mixer evidence"},"\t"));file.close()
	print("WORLD_SOUND_STATE ",comparisons," original comparisons, ",failures.size()," failures");quit(0 if failures.is_empty() and authored.all(func(v):return v) else 1)
