extends SceneTree
const SOURCE="extends Node3D\nvar native_properties: Dictionary={}\nvar native_state: Dictionary={}\nvar native_properties_revision: int=0\n"
const REORDERED="extends Node3D\nvar native_properties_revision: int=0\nvar native_state: Dictionary={}\nvar native_properties: Dictionary={}\n"
var checks: Array=[]
var observations: Array=[]
var output:=""
var selected:=false
class Finalizer extends RefCounted:
	var action: Callable
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE and action.is_valid():action.call()
func check(value: bool,label: String)->void:checks.append({"ok":value,"label":label})
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	selected=OS.get_cmdline_user_args().has("--light-member-read=indices")
	call_deferred("run")
func group(count: int)->Dictionary:
	var host:=Node3D.new();root.add_child(host)
	var writer:=GDScript.new();writer.source_code=SOURCE
	check(writer.reload()==OK,"Current typed writer compiles")
	var nodes: Array=[]
	var registry: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	check(registry.call("dispatch",6,{"script":writer,"sha256":SOURCE.sha256_text()}).get("accepted",false),"Exact current writer enrolled")
	for index in count:
		var node=writer.new();host.add_child(node);node.position=Vector3(index,0,0)
		node.native_properties={"radius":8.0,"color":[.2,.4,.6]};node.native_state={"range":12.0};node.native_properties_revision=1
		node.set_meta("native_enhanced_light",true);node.set_meta("native_light_priority",0)
		nodes.append(node);registry.call("dispatch",0,{"id":node.get_instance_id(),"source":host.get_instance_id()})
	return {"host":host,"writer":writer,"nodes":nodes,"registry":registry}
func cold(g: Dictionary)->Dictionary:return g.registry.call("dispatch",9,{})
func poll(g: Dictionary,label: String)->Dictionary:
	var result: Dictionary=g.registry.call("dispatch",1,{"planes":[],"view_changed":false})
	var normalized: Dictionary=result.duplicate(true)
	for row in normalized.get("rows",[]):row.id=g.nodes.find(instance_from_id(row.id))+1;row.owner=1
	for key in ["removed","retired"]:
		if normalized.has(key):normalized[key]=normalized[key].map(func(value):return g.nodes.find(instance_from_id(value))+1)
	observations.append({"label":label,"payload":var_to_bytes(normalized).hex_encode()})
	return result
func close(g: Dictionary)->void:
	g.registry.call("dispatch",8,{});g.host.free();g.clear()
func reorder_current(writer: GDScript,nodes: Array)->void:
	# Release Godot does not resize/remap old instance storage on reload(true).
	# Keep slot count equal and explicitly restore current values by field name.
	var saved: Array=[]
	for node in nodes:saved.append([node.get("native_properties"),node.get("native_state"),node.get("native_properties_revision")])
	writer.source_code=REORDERED;check(writer.reload(true)==OK,"Equal-count compiled member order changes")
	for index in nodes.size():
		nodes[index].set("native_properties",saved[index][0]);nodes[index].set("native_state",saved[index][1]);nodes[index].set("native_properties_revision",saved[index][2])
	writer.source_code=SOURCE
func quiet_many()->void:
	var g:=group(64);check(poll(g,"64:first").rows.size()==64,"Initial64 current rows publish")
	var before:=cold(g)
	check(poll(g,"64:quiet").get("reused",0)==64,"Quiet64 keeps all rows")
	var after:=cold(g)
	check(int(after.plain_member_index_reads)-int(before.plain_member_index_reads)==192 if selected else int(after.plain_member_index_reads)==0,"Actual192 index reads or exact default-OFF witness")
	check(int(after.plain_member_index_proofs)-int(before.plain_member_index_proofs)==1 if selected else int(after.plain_member_index_proofs)==0,"Quiet64 has one poll-local layout proof")
	g.nodes[31].native_state.range=3.5;g.nodes[47].set_meta("native_light_priority",9)
	check(not poll(g,"64:live").has("error"),"Current live state/meta changes remain visible")
	before=cold(g);poll(g,"64:new-poll");after=cold(g)
	check(int(after.plain_schema_checks)-int(before.plain_schema_checks)==1,"No proof survives a new poll")
	reorder_current(g.writer,g.nodes)
	before=cold(g);check(not poll(g,"64:reordered-restored-text").has("error"),"Current compiled indices used after restored source text")
	after=cold(g);check(int(after.plain_member_index_reads)-int(before.plain_member_index_reads)==192 if selected else true,"Reordered current schema really exercises all indexed reads")
	close(g)
func scratch_reload(field: String)->void:
	var g:=group(3);var events: Array=[];var finalizer:=Finalizer.new()
	var shared: Dictionary={field:finalizer};shared.make_read_only()
	if field=="radius":g.nodes[0].native_properties=shared
	else:g.nodes[0].native_state=shared
	check(poll(g,"scratch:"+field+":prime").get("error","")=="Native particle value must be numeric","Read-only object primes original scratch and original numeric failure")
	shared.assign({field:8.0}) # Native Dictionary::assign preserves its shared scratch.
	check(shared.is_read_only() and shared.get(field)==8.0,"Read-only map assignment leaves scratch separately retained")
	var writer: GDScript=g.writer;var nodes: Array=g.nodes
	finalizer.action=func():
		events.append("scratch-predelete")
		reorder_current(writer,nodes)
	finalizer=null
	check(events.is_empty(),"Scratch is finalizer's last strong owner before native read")
	var before:=cold(g);var result:=poll(g,"scratch:"+field+":numeric-reload");var after:=cold(g)
	check(events==["scratch-predelete"],"Actual native scratch replacement invokes PREDELETE exactly once")
	check(not result.has("error") and result.rows.size()==3,"Same-row remaining reads and later rows survive scratch schema reload")
	check(int(after.plain_member_scratch_barriers)-int(before.plain_member_scratch_barriers)==1 if selected else int(after.plain_member_scratch_barriers)==0,"Read-only scratch explicitly ends indexed segment")
	check(int(after.plain_member_index_reads)-int(before.plain_member_index_reads)==(7 if field=="radius" else 8) if selected else true,"No stale same-row indexed member is read after scratch callback")
	observations.append({"label":"scratch-events:"+field,"events":events.duplicate()})
	close(g);shared={}
func invalid_objects()->void:
	for location in ["radius","range","enhanced","priority"]:
		var g:=group(1);var value:=RefCounted.new()
		if location=="radius":g.nodes[0].native_properties.radius=value
		elif location=="range":g.nodes[0].native_state.range=value
		elif location=="enhanced":g.nodes[0].set_meta("native_enhanced_light",value)
		else:g.nodes[0].set_meta("native_light_priority",value)
		var before:=cold(g);var result:=poll(g,"invalid-object:"+location);var after:=cold(g)
		check(result.get("error","")==("Native particle value must be integer" if location=="priority" else "Native particle value must be numeric"),"Invalid current Object retains original error: "+location)
		check(int(after.plain_member_index_reads)-int(before.plain_member_index_reads)==(1 if location in ["radius","enhanced"] else 2) if selected else true,"Invalid Object fails before any later indexed member: "+location)
		close(g);value=null
func run()->void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var probe: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry");var diagnostic: Dictionary=probe.call("dispatch",9,{})
	check(bool(diagnostic.get("plain_member_index_requested",false))==selected,"Actual requested member-index flag observed")
	check(bool(diagnostic.get("plain_member_index_active",false))==selected,"Member indices require actual typed+segments selection")
	probe.call("dispatch",8,{});probe=null
	quiet_many();scratch_reload("radius");scratch_reload("range");invalid_objects()
	await process_frame
	var success:=checks.all(func(row):return row.ok)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":success,"checks":checks,"observations":observations,"scope":"Actual engine current-member/index/64-row/layout-reload/read-only scratch PREDELETE/error semantics; headless only"}));file.close();quit(0 if success else 1)
