extends "res://base.gd"
const REPLACEMENT="extends Node3D\nvar native_properties: Dictionary={\"radius\":8.0}\nvar native_state: Dictionary:\n\tget:\n\t\tget_meta(\"replacement_trace\").append(\"state\")\n\t\treturn {\"range\":1.0}\nvar native_properties_revision: int:\n\tget:\n\t\tget_meta(\"replacement_trace\").append(\"revision\")\n\t\treturn 19\n"
func install_action(g: Dictionary,finalizer: RefCounted,events: Array,action: String)->void:
	var registry: RefCounted=g.registry;var nodes: Array=g.nodes;var writer: GDScript=g.writer
	var replacement:=GDScript.new();replacement.source_code=REPLACEMENT
	check(replacement.reload()==OK,"Replacement current-instance getter script compiles")
	finalizer.action=func():
		events.append("finalized:"+action)
		if action=="close":registry.call("dispatch",8,{})
		elif action=="erase":registry.call("dispatch",2,{"id":nodes[0].get_instance_id()})
		elif action=="erase-other":registry.call("dispatch",2,{"id":nodes[1].get_instance_id()})
		elif action=="rebind":registry.call("dispatch",0,{"id":nodes[0].get_instance_id(),"source":0})
		elif action=="free":nodes[0].free()
		elif action=="script":nodes[0].set_script(replacement)
		elif action=="reorder":reorder_current(writer,nodes)
		elif action=="reentrant":events.append(registry.call("dispatch",1,{"planes":[],"view_changed":false}).get("error",""))
func expected_error(action: String)->String:
	if action=="close":return "Native light input registry is closed"
	if action in ["erase","erase-other","rebind"]:return "Native light input registry membership changed during property read"
	if action=="free":return "Native light input registry light retired during property read"
	return ""
func assert_callback_result(g: Dictionary,result: Dictionary,events: Array,action: String,label: String)->void:
	check(events.count("finalized:"+action)==1,label+" invokes one actual PREDELETE")
	check(result.get("error","")==expected_error(action),label+" has defined guarded callback result")
	if action=="reentrant":check(events==["finalized:reentrant","Native light input registry poll is reentrant"],label+" rejects nested poll")
	observations.append({"label":label+":events","events":events.duplicate(),"current_getters":g.nodes[0].get_meta("replacement_trace",[]).duplicate() if is_instance_valid(g.nodes[0]) else []})
func destructive_scratch(field: String,action: String)->void:
	var g:=group(3);g.nodes[0].set_meta("replacement_trace",[])
	var events: Array=[];var finalizer:=Finalizer.new();var shared: Dictionary={field:finalizer};shared.make_read_only()
	if field=="radius":g.nodes[0].native_properties=shared
	else:g.nodes[0].native_state=shared
	check(poll(g,"lifetime:"+field+":"+action+":prime").get("error","")=="Native particle value must be numeric","Scratch object primes original error")
	shared.assign({field:8.0});install_action(g,finalizer,events,action);finalizer=null
	check(events.is_empty(),"Scratch retains finalizer until native numeric lookup")
	var result:=poll(g,"lifetime:"+field+":"+action)
	assert_callback_result(g,result,events,action,"Scratch "+field+" "+action)
	if action=="script":
		check(g.nodes[0].get_meta("replacement_trace")==(["state","revision"] if field=="radius" else ["revision"]),"Same-row name reads use replacement current ScriptInstance")
	close(g);shared={}
func readonly_row_scratch(action: String)->void:
	var g:=group(3);g.nodes[0].set_meta("replacement_trace",[])
	var initial:=poll(g,"readonly-row:"+action+":initial");var row: Dictionary=initial.rows[0];initial={}
	var events: Array=[];var finalizer:=Finalizer.new();var values:=row.duplicate();values.in_view=finalizer
	row.make_read_only();row.assign(values);values={}
	check(poll(g,"readonly-row:"+action+":prime").get("error","")=="Native particle value must be numeric","Readonly published row primes original in_view numeric error")
	values=row.duplicate();values.in_view=true;row.assign(values);values={}
	install_action(g,finalizer,events,action);finalizer=null
	check(events.is_empty(),"Published row scratch alone retains finalizer")
	var result:=poll(g,"readonly-row:"+action)
	assert_callback_result(g,result,events,action,"Readonly row "+action)
	if action=="script":check(g.nodes[0].get_meta("replacement_trace").is_empty(),"No stale ScriptInstance read occurs after completed row scratch")
	close(g);row={}
func published_release(action: String)->void:
	var g:=group(3);g.nodes[0].set_meta("replacement_trace",[])
	var events: Array=[];var finalizer:=Finalizer.new();g.nodes[0].native_properties.color=finalizer
	var initial: Dictionary=g.registry.call("dispatch",1,{"planes":[],"view_changed":false});check(not initial.has("error"),"Published row retains arbitrary authored color value");initial={}
	g.nodes[0].native_properties={"radius":8.0,"color":[.2,.4,.6]};g.nodes[0].native_properties_revision+=1
	install_action(g,finalizer,events,action);finalizer=null
	check(events.is_empty(),"Previous published row alone retains finalizer")
	var result:=poll(g,"published-release:"+action)
	assert_callback_result(g,result,events,action,"Detached published row "+action)
	check(int(cold(g).get("lifetime_detached_releases",0))>0,"Actual detached row release path exercised")
	close(g)
func api_release(operation: String)->void:
	var g:=group(3);var events: Array=[];var finalizer:=Finalizer.new();g.nodes[0].native_properties.color=finalizer
	var initial: Dictionary=g.registry.call("dispatch",1,{"planes":[],"view_changed":false});check(not initial.has("error"),"API release retains previous row payload");initial={}
	g.nodes[0].native_properties={"radius":8.0};var registry: RefCounted=g.registry;var nodes: Array=g.nodes
	finalizer.action=func():
		events.append("api-finalized")
		if operation=="close":
			registry.call("dispatch",8,{})
			events.append(registry.call("dispatch",0,{"id":nodes[1].get_instance_id(),"source":0}).get("error",""))
		else:registry.call("dispatch",2,{"id":nodes[0].get_instance_id()})
	finalizer=null
	var result: Dictionary
	if operation=="close":result=registry.call("dispatch",8,{})
	elif operation=="erase":result=registry.call("dispatch",2,{"id":nodes[0].get_instance_id()})
	else:result=registry.call("dispatch",0,{"id":nodes[0].get_instance_id(),"source":0})
	check(events.count("api-finalized")==1,"API "+operation+" release safely invokes finalizer once")
	check(bool(result.closed) if operation=="close" else int(result.members)==2,"API "+operation+" returns stable current registry state")
	if operation=="close":check(events==["api-finalized","Native light input registry is closed"],"Close marks active registry closed before detached finalizers")
	observations.append({"label":"api:"+operation,"events":events.duplicate(),"result":result})
	close(g)
func expanded_new_instances()->void:
	var host:=Node3D.new();root.add_child(host)
	var writer:=GDScript.new();writer.source_code=SOURCE.replace("extends Node3D\n","extends Node3D\nvar expanded_prefix: int=71\n")
	check(writer.reload()==OK,"Expanded schema compiles before creating new instances")
	var registry: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	check(registry.call("dispatch",6,{"script":writer,"sha256":writer.source_code.sha256_text()}).get("accepted",false),"New expanded schema enrolled")
	var nodes: Array=[]
	for index in 2:
		var node=writer.new();host.add_child(node);node.native_properties={"radius":8.0};node.native_state={"range":12.0};node.native_properties_revision=1;node.set_meta("native_enhanced_light",true)
		nodes.append(node);registry.call("dispatch",0,{"id":node.get_instance_id(),"source":host.get_instance_id()})
	var g:={"host":host,"writer":writer,"nodes":nodes,"registry":registry};var before:=cold(g)
	check(poll(g,"expanded-new:first").rows.size()==2,"New expanded instances have valid enlarged storage")
	var after:=cold(g);check(int(after.plain_member_index_reads)-int(before.plain_member_index_reads)==6 if selected else true,"Expanded fresh layout uses actual shifted member indices")
	close(g)
func detached_scope_release(field: String,action: String)->void:
	var g:=group(3);g.nodes[0].set_meta("replacement_trace",[])
	var events: Array=[];var switcher:=Finalizer.new();var payload:=Finalizer.new()
	var shared: Dictionary={field:switcher,"unused_payload":payload};shared.make_read_only()
	if field=="radius":g.nodes[0].native_properties=shared
	else:g.nodes[0].native_state=shared
	check(poll(g,"scope-release:"+field+":"+action+":prime").has("error"),"Scope fixture primes readonly switch scratch")
	shared.assign({field:8.0,"unused_payload":payload})
	var replacement:=GDScript.new();replacement.source_code=REPLACEMENT;check(replacement.reload()==OK,"Scope replacement script compiles")
	var node: Node3D=g.nodes[0];var registry: RefCounted=g.registry;var other_id: int=g.nodes[1].get_instance_id()
	switcher.action=func():events.append("switch-script");node.set_script(replacement)
	payload.action=func():
		events.append("scope-"+action)
		if action=="erase":registry.call("dispatch",2,{"id":other_id})
		elif action=="close":registry.call("dispatch",8,{})
		else:node.free()
	switcher=null;payload=null;shared={}
	check(events.is_empty(),"Old current member is sole Dictionary owner before opaque switch")
	var result:=poll(g,"scope-release:"+field+":"+action)
	check(events==["switch-script","scope-"+action],"Detached ignored payload finalizes after script replacement at row release")
	check(result.get("error","")==expected_error(action),"Scope release mutation is checked before next order iteration")
	observations.append({"label":"scope-events:"+field+":"+action,"events":events.duplicate()})
	close(g)
func run()->void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var probe: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry");var diagnostic: Dictionary=probe.call("dispatch",9,{})
	check(bool(diagnostic.get("lifetime_guard_requested",false)),"Independent lifetime correctness control selected")
	check(bool(diagnostic.get("plain_member_index_active",false))==selected,"Indices independently selected above lifetime control")
	probe.call("dispatch",8,{});probe=null
	quiet_many();scratch_reload("radius");scratch_reload("range");invalid_objects();expanded_new_instances()
	for action in ["reorder","script","free","close","erase","erase-other","rebind","reentrant"]:
		destructive_scratch("radius",action);destructive_scratch("range",action)
	for action in ["reorder","script","free","close","erase","reentrant"]:
		readonly_row_scratch(action);published_release(action)
	for operation in ["erase","rebind","close"]:api_release(operation)
	for field in ["radius","range"]:
		for action in ["erase","close","free"]:detached_scope_release(field,action)
	await process_frame
	var success:=checks.all(func(row):return row.ok)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":success,"checks":checks,"observations":observations,"scope":"Independent guarded lifetime control versus guarded+indices. Destructive V9 paths were unsafe; no legacy equivalence claim. Actual current-instance/Node/registry/row-finalizer and reentry checks; headless only."}));file.close();quit(0 if success else 1)
