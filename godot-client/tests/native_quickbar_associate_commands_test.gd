extends SceneTree
const Model=preload("res://systems/native_data/quickbar_associate_commands.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String,detail: Variant=null) -> void:
	checks+=1
	if not value and failures.size()<30:failures.append({"label":label,"detail":detail})
func whole(value: Variant) -> Variant:
	if value is float and is_finite(value) and value==floor(value):return int(value)
	if value is Array:return value.map(whole)
	if value is Dictionary:
		var result: Dictionary={}
		for key in value:result[key]=whole(value[key])
		return result
	return value
func objects_for(values: Array) -> Dictionary:
	var result: Dictionary={}
	for source in values:
		var id:=int(source.id)
		result[id]={"id":id,"objectType":int(source.get("objectType",5)),"replicationRemoved":source.get("removed",false),"replicated":{"master":int(source.master),"field908":int(source.type),"name":{"firstName":{"text":"Member"+str(id)},"lastName":{"text":""}}}}
	return result
func normalize(entries: Array) -> Array:
	var result: Array=[]
	for entry in entries:
		var value: Dictionary={"kind":entry.kind,"slot":entry.slot,"icon":entry.icon}
		if entry.kind=="action":
			for key in ["titleRef","command","partyIndex","objectId"]:value[key]=entry[key]
		elif entry.kind=="more":value.merge({"titleRef":entry.titleRef,"offset":entry.offset})
		else:
			value.merge({"partyIndex":entry.partyIndex,"objectId":entry.objectId,"label":str(entry.name.firstName.text) if entry.name is Dictionary else ""})
		result.append(value)
	return result
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):args[arg.substr(2).get_slice("=",0)]=arg.substr(arg.find("=")+1)
	var oracle: Variant=whole(JSON.parse_string(FileAccess.get_file_as_string(str(args.oracle))))
	check(oracle is Dictionary and oracle.get("success",false) and oracle.get("target")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Pinned original machine-code oracle")
	for row in oracle.cases:
		var source: Dictionary=row.case;var actor: Dictionary={"id":source.controlledId,"objectType":5}
		var objects:=objects_for(source.objects)
		var context:=Model.snapshot(actor,source.members,objects,true)
		check(context.ready,str(source.name)+" received context")
		check(normalize(Model.root(context).entries)==row.root,str(source.name)+" original complete root",normalize(Model.root(context).entries))
		for page in row.pages:check(normalize(Model.page(context,int(page.offset)).entries)==page.entries,str(source.name)+" original page"+str(page.offset))
		for child in row.children:
			var model:=Model.child(context,int(child.objectId),int(child.partyIndex))
			check(model.ready and normalize(model.entries)==child.entries,str(source.name)+" original child"+str(child.partyIndex))
			for index in model.entries.size():
				var entry: Dictionary=model.entries[index]
				var packed: int=((int(entry.command)&65535)<<16)|1
				check(packed==int(child.assignments[index].packed) and int(entry.objectId)==int(child.assignments[index].objectId),str(source.name)+" original995f10 assignment"+str(index))
	var actor: Dictionary={"id":8,"objectType":5}
	var objects:=objects_for([{"id":4294967295,"master":8,"type":1}])
	var context:=Model.snapshot(actor,[4294967295],objects,true)
	check(context.ready and Model.root(context).entries[0].objectId==4294967295,"Descending FFFFFFFF is valid, not INVALID")
	check(not Model.snapshot(actor,[],objects,false).ready,"Unknown party publication stays unavailable")
	check(not Model.snapshot(actor,null,objects,true).ready,"Missing party array stays unavailable")
	check(not Model.snapshot({"id":Model.INVALID,"objectType":5},[],objects,true).ready,"Invalid controlled creature rejected")
	check(not Model.snapshot(actor,["8"],objects,true).ready,"Malformed party ID is not invented")
	var incomplete:=objects.duplicate(true);incomplete[4294967295].replicated.erase("field908")
	check(not Model.snapshot(actor,[4294967295],incomplete,true).ready,"Missing received associate type remains explicit")
	incomplete=objects.duplicate(true);incomplete[4294967295].replicated.erase("master")
	check(not Model.snapshot(actor,[4294967295],incomplete,true).ready,"Missing received master remains explicit")
	check(Model.root(Model.snapshot(actor,[4294967295],{},true)).entries.is_empty(),"Not-yet-known creature contributes no invented associate")
	objects[4294967295].rendered=false
	check(Model.snapshot(actor,[4294967295],objects,true).associates.size()==1,"Known associate participates before visuals load")
	objects[4294967295].areaId=99
	check(Model.snapshot(actor,[4294967295],objects,true).associates.size()==1,"Party query uses original ownership without invented area restriction")
	objects[4294967295].replicated.name.firstName.text="Later"
	check(context.associates[0].name.firstName.text=="Member4294967295","Source mutation cannot alter detached name view")
	var branches:=Model.root({"ready":true,"associates":[context.associates[0],context.associates[0]],"invalidPartyIndex":-1})
	branches.entries[0].name.firstName.text="Consumer edit"
	check(context.associates[0].name.firstName.text=="Member4294967295","Consumer branch mutation cannot alter snapshot")
	check(not Model.child(context,4294967295,9).ready,"Foreign party index cannot select another target")
	objects[4294967295].replicationRemoved=true
	check(not Model.child(Model.snapshot(actor,[4294967295],objects,true),4294967295,0).ready,"Removal retires current child plan")
	objects[4294967295].replicationRemoved=false;objects[4294967295].replicated.master=9
	check(not Model.child(Model.snapshot(actor,[4294967295],objects,true),4294967295,0).ready,"Ownership change retires current child plan")
	check(not Model.page(context,-1).ready and not Model.page(context,2).ready,"Retired page offsets rejected")
	var sentinel:=Model.root(Model.snapshot(actor,[Model.INVALID],{},true))
	check(sentinel.entries.size()==3 and sentinel.entries.all(func(entry):return not entry.targetAvailable),"Original sentinel descriptors never grant a valid creature target")
	check(not Model.action_rows({"objectId":3,"partyIndex":32768})[0].indexAvailable,"Signed SHORT callback overflow cannot resolve a different member")
	var began:=Time.get_ticks_usec()
	for index in 1000:Model.root(context)
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":oracle.cases.size(),"root_1000_usec":Time.get_ticks_usec()-began,"scope":"Original machine-code root/page/child/callback descriptor equality and detached known-party policy only; unknown/deleted/foreign and previsual entities. No Desktop integration, server, original pixels, gameplay or GPU performance acceptance."}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	quit(0 if report.success else 1)
func _initialize() -> void:call_deferred("run")
