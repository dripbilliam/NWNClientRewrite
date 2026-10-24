extends SceneTree
const Fade = preload("res://systems/client_fade.gd")
static func bits(value: float) -> int:
	var bytes := PackedByteArray();bytes.resize(4);bytes.encode_float(0,value);return bytes.decode_u32(0)
static func same(a: Variant,b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return float(a) == float(b)
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	return typeof(a) == typeof(b) and a == b
func _initialize() -> void:
	var output := "";var input := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
		if arg.begins_with("--fixture="): input = arg.substr(10)
	if input.is_empty() or output.is_empty() or FileAccess.file_exists(output): quit(2);return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input))
	if fixture.binarySha256 != "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a": quit(2);return
	var failures: Array = [];var comparisons := 0;var cases := 0
	for row in fixture.rows:
		var c: Dictionary = row.case
		if c.modeName not in ["set","expiry"]: continue
		cases += 1
		var calls: Array = []
		var state := {"id":c.get("objectId",0x7f000000),"position":[0,0,0],"desiredPosition":[0,0,0],"appearance":0xaaaa,"temporary":c.get("temporary",0),"blocked":c.get("blocked",0),"fadeTarget":c.get("target",1),"fadeState":c.get("fade",1),"duration":c.get("duration",500),"delayEnabled":c.get("delay",0),"opacity":c.get("alpha",1),"since":{"day":9,"time":900},"visible":0,"deleted":false}
		var providers := {
			"worldTime":func():calls.append(["time"]);return {"day":10,"time":1000},
			"difference":func(_a,_b):calls.append(["difference"]);return {"day":c.get("elapsedDay",0),"time":c.get("elapsed",0)},
			"snapshotDifference":func():calls.append(["snapshot"]);return c.get("microseconds",16000),
			"modelHandle":func(_s):return c.get("handle",1),"mode":func():return c.get("mode",2),
			"controlledId":func():calls.append(["controlled"]);return c.get("controlled",7),
			"display":func(_s,offset):calls.append(["display",offset]),
			"targetAlpha":func(_s):calls.append(["targetAlpha"]);return c.get("targetAlpha",1),
			"alpha":func(_s,value,part):calls.append(["alpha",bits(value),part]),
			"handleScene":func(_s,on):calls.append(["handleScene",on])}
		var result := 0
		if c.modeName == "set": Fade.set_fade(state,int(c.newTarget),int(c.newDelay),int(c.newDuration),providers)
		else: result = Fade.update(state,providers)
		var actual := {"id":int(state.id)&0xffffffff,"position":state.position,"desired":state.desiredPosition,"appearance":state.appearance,"temporary":state.temporary,"target":state.fadeTarget,"fade":state.fadeState,"duration":int(state.duration)&0xffffffff,"delay":state.delayEnabled,"alpha":bits(state.opacity),"since":state.since,"visible":state.visible,"deleted":state.deleted}
		# Compare numeric values recursively: JSON loads doubles whereas native
		# state contains integers, and JSON.stringify preserves that distinction.
		for pair in [[calls,row.calls],[actual,row.state]]:
			comparisons += 1
			if not same(pair[0],pair[1]): failures.append({"case":c,"actual":pair[0],"expected":pair[1]})
		if c.modeName == "expiry":
			comparisons += 1
			if result != int(row.result): failures.append({"case":c,"result":result,"expected":row.result})
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"cases":cases,"comparisons":comparisons,"failures":failures,"sourceSha256":FileAccess.get_sha256("res://systems/client_fade.gd"),"oracleSha256":FileAccess.get_sha256(input),"scope":"Original-instruction client fade/expiry state and provider call ordering; native graphics/cache scene internals remain separate"},"\t"));file.close()
	print("CLIENT_FADE_TEST ",cases," cases, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
