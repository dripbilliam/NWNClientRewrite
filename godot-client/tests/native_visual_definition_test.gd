extends SceneTree
const Definition=preload("res://systems/native_data/visual_definition.gd")
const LiveWorld=preload("res://systems/native_render/live_world.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func same(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in a.size():
			if not same(a[index],b[index]): return false
		return true
	return a==b
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var map: Dictionary=JSON.parse_string('{"keys":[0],"entries":[{"key":0,"value":{"identity":true}}]}')
	check(Definition.identity(map),"JSON numeric transform keys retain native identity semantics")
	map.entries[0].value={"channels":[]}
	for i in 10: map.entries[0].value.channels.append({"value":1.0 if i in [0,1,2,9] else 0.0,"duration":0.0})
	check(Definition.identity(map),"Original default controller channels are identity")
	map.entries[0].value.channels[3].value=2
	check(not Definition.identity(map),"Nonidentity controller maps remain explicit")
	var fixture: Array=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	for entry in fixture:
		var hosts: Dictionary={}
		for key in entry.hosts: hosts[int(key)]=entry.hosts[key]
		var loader:=Definition.new(); var actual:=loader.prepare(entry.actor,entry.record,entry.tables,hosts,entry.settings)
		check(not actual.is_empty(),"Original loader case prepares: "+str(entry.label))
		if actual.is_empty(): continue
		for key in ["state","programs","visual","hosts"]: check(same(actual[key],entry.expected[key]),str(entry.label)+" matches retained original-derived "+key)
		var names: Array=actual.resources.keys(); names.sort(); check(names==entry.expected.resources,str(entry.label)+" selects the same original resources")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Native active-table visual loader versus retained original-derived reference; not fresh binary or live rendering parity"},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
