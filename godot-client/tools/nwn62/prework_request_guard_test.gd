extends SceneTree
const Prework=preload("res://systems/native_data/prework_store.gd")
class Catalog extends RefCounted:
	var owner:=RefCounted.new()
	func preparation_cache():return owner
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	var catalog:=Catalog.new()
	Prework.observed.clear()
	var descriptor: Array=[];descriptor.resize(2048)
	var options: Dictionary={"icon_descriptor":{"ignored":descriptor},"settings":{"levels":[1,2]}}
	Prework.remember_request(catalog,"sample",2002,"gui-icon-v1",options)
	var first: Array=Prework.known_requests(catalog)
	check(first.size()==1,"One eligible request retained")
	check(not first[0].options.has("icon_descriptor"),"Ignored descriptor is absent")
	check(first[0].options.settings.levels==[1,2],"Nested retained options are intact")
	var settings: Dictionary=options.settings;var levels: Array=settings.levels;levels[0]=9
	check(Prework.known_requests(catalog)[0].options.settings.levels==[1,2],"Retained nested options are detached")
	options.settings={"levels":[1,2]};options.icon_descriptor={"ignored":["different"]}
	Prework.remember_request(catalog,"sample",2002,"gui-icon-v1",options)
	check(Prework.known_requests(catalog).size()==1,"Changing only ignored descriptor preserves deduplication")
	options.settings={"levels":[1,3]}
	Prework.remember_request(catalog,"sample",2002,"gui-icon-v1",options)
	check(Prework.known_requests(catalog).size()==2,"Changed retained options create a distinct request")
	var scope:=int(catalog.owner.get_instance_id());var entries: Dictionary=Prework.observed[scope]
	entries.clear()
	for index in 8192:entries[str(index)]={"name":"prior"}
	var keys_before: Array=entries.keys()
	Prework.remember_request(catalog,"overflow",2002,"gui-icon-v1",options)
	check(entries.size()==8192 and entries.keys()==keys_before,"Full registry admits no extra request")
	Prework.forget(catalog)
	check(Prework.known_requests(catalog).is_empty(),"Retirement clears the registry")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"ignored_descriptor_elements_per_call":2048,"full_registry_entries":8192,"scope":"Prework request identity, nested option ownership, descriptor exclusion, duplicate equivalence, saturation and retirement. No loading or FPS claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
