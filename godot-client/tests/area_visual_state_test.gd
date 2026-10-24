extends SceneTree
const Core = preload("res://systems/area_visual_state.gd")
const Compare = preload("res://tests/client_fade_test.gd")
func _initialize() -> void:
	var output := "";var input := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.substr(9)
		if arg.begins_with("--fixture="): input = arg.substr(10)
	if output.is_empty() or input.is_empty() or FileAccess.file_exists(output): quit(2);return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input))
	if fixture.target != "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a":quit(2);return
	var failures: Array = [];var count := 0;var comparisons := 0
	for row in fixture.cases:
		var c: Dictionary = row.case
		if c.kind == "load": continue
		count += 1
		var e := {"position":[1.25,-2,3.5],"since":{"day":1,"time":2},"elapsed58":0,"sound170":null,"retire178":0,"remaining17c":0,"visual180":-1,"phase184":0,"retiring188":0,"suppressed18c":0,"instant190":0,"destroy194":1,"orient198":0,"detach19c":0,"skipRetirement1a0":0,"repeat1a4":0,"model":{},"destroyed":false}
		e.merge(c.get("state",{}),true);e.model = null if c.get("model") == false else {};e.sound170 = {} if c.get("sound",false) else null
		var calls: Array = []
		var p := {"string":func(_id,key):calls.append(["query",key]);return c.get("entries",{}).get(key,{"found":false,"value":0}),
			"speed40":func():return 0.75,"now":func():return c.get("now",{"day":2,"time":10000}),"difference":func(_a,_b):return c.get("difference",{"day":0,"time":1}),
			"oneShot":func(a,b,d,g,h,i):calls.append(["oneShot",a,b,d,g,h,i]),"animationLength":func(_e,phase):calls.append(["length",phase]);return c.get("length",1250.5),"play":func(_e,a,b,d,g):calls.append(["play",a,b,d,g]),
			"createSound":func(name):calls.append(["createSound",name]);return {},"sound3d":func(_s,v):calls.append(["sound3d",v]),"soundPriority":func(_s,v):calls.append(["soundPriority",v]),"soundLooping":func(_s,v):calls.append(["soundLooping",v]),"playSound":func(_s):calls.append(["playSound"]),"stopSound":func(_s):calls.append(["stopSound"]),"destroySound":func(_s):calls.append(["destroySound"]),"updateSound":func(_s,a,b):calls.append(["updateSound",a,b]),
			"setScene":func(_e,scene):calls.append(["setScene",0 if scene == null else scene]),"destroy":func(state):state.destroyed = true;calls.append(["destroy"])}
		if c.kind == "start": Core.start(e,int(c.phase),p)
		else: Core.advance(e,p)
		var actual := {}
		for key in row.state:
			actual[key] = (e.sound170 != null) if key == "sound" else (e.since if key == "since" else (int(e[key])&0xffffffff))
		for pair in [[calls,row.calls],[actual,row.state],[e.destroyed,row.destroyed]]:
			comparisons += 1
			if not Compare.same(pair[0],pair[1]): failures.append({"case":c,"actual":pair[0],"expected":pair[1]})
	var file := FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":failures.is_empty(),"cases":count,"comparisons":comparisons,"failures":failures,"sourceSha256":FileAccess.get_sha256("res://systems/area_visual_state.gd"),"oracleSha256":FileAccess.get_sha256(input),"scope":"Original area-effect phase/AI calls and state; shared JS loader selection tested independently"},"\t"));file.close()
	print("AREA_VISUAL_STATE ",count," cases; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
