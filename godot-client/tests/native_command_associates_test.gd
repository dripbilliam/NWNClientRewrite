extends SceneTree
const Policy=preload("res://systems/native_data/staged_command_associates.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<20:failures.append(label)
func snapshot(value: Dictionary) -> Dictionary:
	var objects: Dictionary={};var party: Array=[]
	for item in value.objects:
		var id:=int(item.id);objects[id]={"id":id,"objectType":5,"clientKnownLifetime":id+1,"replicated":{"field908":int(item.type),"master":int(item.master),"name":"Associate_"+str(id)}}
	for id in value.ids:party.append({"id":int(id)})
	return Policy.capture(party,1,99,func(id):return objects.get(id),func(object,_id):return object.replicated.name)
func compare(actual: Array,expected: Array,label: String) -> void:
	check(actual.size()==expected.size(),label+" count")
	for index in mini(actual.size(),expected.size()):
		var a: Dictionary=actual[index];var b: Dictionary=expected[index]
		check(int(a.slot)==int(b.slot) and a.icon==b.icon and a.labelRef==b.labelRef and a.label==b.label and a.callback==b.callback and int(a.low32)==int(b.low32),label+" row "+str(index))
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:="";var oracles: Array=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--oracle="):oracles.append(arg.trim_prefix("--oracle="))
	if output.is_empty() or oracles.is_empty() or FileAccess.file_exists(output):quit(2);return
	for path in oracles:
		var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		check(oracle.success==true,"Original oracle successful")
		for row in oracle.rows:
			var captured:=snapshot(row.case);var plan:=Policy.root_plan(captured,int(row.case.mode),row.case.dmExe)
			check(captured.known and captured.associates.size()==int(row.queries.count),"Original native count")
			compare(plan.rows,row.entries,"Original root")
			check(int(plan.cursor)==int(row.cursorAfterRoot),"Original iterator cursor")
			for page in row.morePages:
				plan=Policy.more_plan(captured,int(plan.cursor));compare(plan.rows,page.entries,"Original More")
				check(int(plan.cursor)==int(page.cursor),"Original More cursor")
			for submenu in row.get("submenus",[]):
				var index:=String(submenu.branchArgument).hex_to_int();var direct:=Policy.direct(index)
				compare(direct,submenu.entries,"Original named submenu")
				for offset in direct.size():
					var binding:=Policy.callback_binding(captured,int(direct[offset].low32));var assignment: Dictionary=submenu.assignments[offset]
					check(int(binding.associateId)==int(assignment.actorId) and int(binding.intParam)==int(assignment.command) and int(binding.associateType)==int(assignment.associateType),"Original named callback target and signed command")
		for row in oracle.get("callbacks",[]):
			var captured:=snapshot({"ids":[100,101],"objects":[{"id":100,"type":1,"master":99},{"id":101,"type":1,"master":99}]})
			var actual:=Policy.callback_binding(captured,String(row.argumentHex).hex_to_int());var expected: Dictionary=row.assignment[0]
			check(int(actual.associateId)==int(expected.actorId) and int(actual.intParam)==int(expected.command),"Original signed SHORT index/command boundaries")
	var objects:={100:{"id":100,"objectType":5,"clientKnownLifetime":7,"replicated":{"field908":1,"master":99,"name":"Received name"}}}
	var party:=[{"id":100}]
	var lookup:=func(id):return objects.get(id)
	var name_of:=func(object,_id):return object.replicated.name
	var captured:=Policy.capture(party,3,99,lookup,name_of);var rows:=Policy.materialize(captured,Policy.root_plan(captured,1));var leaf: Dictionary=rows[5]
	check(leaf.binding=={"type":39,"intParam":-19,"associateType":1,"associateId":100},"Original direct sector1 binding")
	check(Policy.selection_valid(captured,Policy.capture(party,3,99,lookup,name_of),leaf),"Current canonical lifetime admits assignment")
	objects[100].clientKnownLifetime=8
	check(not Policy.selection_valid(captured,Policy.capture(party,3,99,lookup,name_of),leaf),"ID reuse rejects old assignment")
	objects[100].clientKnownLifetime=7;objects[100].replicated.master=101
	check(not Policy.selection_valid(captured,Policy.capture(party,3,99,lookup,name_of),leaf),"Current master loss rejects old assignment")
	objects[100].replicated.master=99;objects[100].replicated.erase("field908")
	check(not Policy.capture(party,3,99,lookup,name_of).known,"Undisclosed type is unavailable")
	objects[100].replicated.field908=1
	check(not Policy.selection_valid(captured,Policy.capture(party,4,99,lookup,name_of),leaf),"Revision change retires private menu")
	party.clear();objects[100].replicated.name="Changed"
	check(captured.rawIds==[100] and captured.associates[0].name=="Received name","Capture isolates only scalar query metadata")
	check(Policy.root_plan(captured,0,{"permission":true}).rows.size()==5,"Received DM permission never implies DM executable")
	check(Policy.root_plan(captured,0,true).rows.size()==8,"Explicit original DM executable opens independent gate")
	check(Policy.root_plan({"known":false},1).rows.size()==5,"Unavailable metadata preserves five base rows")
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"STAGED new scalar policy versus unchanged original menu/query/callback execution; no production import/network/GPU/user process."},"  "));file.close();quit(0 if failures.is_empty() else 1)
