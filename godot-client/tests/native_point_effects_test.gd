extends SceneTree
const Routing=preload("res://systems/native_data/object_visual_route.gd")
const Area=preload("res://systems/native_data/area_visual_definition.gd")
const Live=preload("res://systems/native_render/live_world.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
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
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("oracle") or not FileAccess.file_exists(args.oracle): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	for row in fixture.routes:
		var calls: Array=[]; var next:=[10]
		var result:=Routing.deliver(row.message,{"visualType":func(_id):return {"found":true,"value":row.type},"object":func(id):return row.objects.get(str(id)),"renderObject":func(actor):return actor,
			"createDummy":func(role,p,lifetime):
				calls.append({"role":role,"position":p,"lifetime":lifetime})
				if role=="source": return null
				var actor:={"id":next[0],"objectType":5}; next[0]+=1; return actor,
			"add":func(actor,record):calls.append({"actor":actor.id,"record":record})})
		check(result==int(row.expected.result) and same(calls,row.expected.calls),str(row.label)+" original receiver routing and callback order")
	for row in fixture.areas:
		var loader:=Area.new(); var result:=loader.prepare(row.message,row.table,int(row.quality))
		check(loader.failure.is_empty() and not result.is_empty(),str(row.label)+" native area definition prepares")
		if result.is_empty(): continue
		check(same(result.state,row.expected.state) and same(result.query,row.expected.query) and same(result.warnings,row.expected.warnings) and same(result.resources.keys(),row.expected.resources),str(row.label)+" original area state/table/resource decisions")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":fixture.scope},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
