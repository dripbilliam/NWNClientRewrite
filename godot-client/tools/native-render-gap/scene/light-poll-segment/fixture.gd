extends "res://fixture.gd"
# Additional actual-canonical multi-row proof tests. All objects remain live;
# old/fast owners see the same ObjectIDs, field values and callback sequence.
class RowFinalizer extends RefCounted:
	var callback: Callable
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE and callback.is_valid():callback.call()

func segment_group(count: int,opaque_index: int=-1)->Dictionary:
	var host:=Node3D.new();root.add_child(host)
	var writer:=GDScript.new();writer.source_code=canonical_source
	check(writer.reload()==OK,"Independent canonical multi-row writer compiles")
	var nodes: Array=[]
	for index in count:
		var lamp=Observed.new() if index==opaque_index else writer.new()
		lamp.name="lamp"+str(index);lamp.set_meta("native_enhanced_light",false);host.add_child(lamp)
		nodes.append(lamp)
	var old: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	var fast: RefCounted=ClassDB.instantiate("NwnBuiltinLightInputRegistry")
	check(fast.call("dispatch",6,{"script":writer,"sha256":canonical_hash}).get("accepted",false),"Multi-row exact canonical resource enrolled")
	for registry in [old,fast]:
		for lamp in nodes:registry.call("dispatch",0,{"id":lamp.get_instance_id(),"source":host.get_instance_id()})
	var group:={"host":host,"writer":writer,"nodes":nodes,"old":old,"fast":fast,"opaque":opaque_index,"releases":[]}
	reset_group(group)
	return group
func reset_group(group: Dictionary)->void:
	group.writer.source_code=canonical_source;check(group.writer.reload(true)==OK,"Multi-row schema restored before independent poll")
	for index in group.nodes.size():
		var lamp=group.nodes[index]
		if index==int(group.opaque):
			lamp.callback=Callable();lamp.trace=[];lamp.values={"radius":8.0,"color":[.8,.4,.2]};lamp.state_value={"range":8.0};lamp.revision_value=1
		else:
			if lamp.get_script()!=group.writer:lamp.set_script(group.writer)
			lamp.native_properties={"radius":8.0,"color":[.8,.4,.2]};lamp.native_state={"range":8.0};lamp.native_properties_revision=1
		lamp.set_meta("native_enhanced_light",true);lamp.set_meta("native_light_priority",0);lamp.set_meta("typed_getter_trace",[]);lamp.position=Vector3(float(index),0,0)
func group_poll(registry: RefCounted)->Dictionary:return registry.call("dispatch",1,{"planes":[],"view_changed":false})
func close_group(group: Dictionary)->void:
	for registry in [group.old,group.fast]:registry.call("dispatch",8,{})
	group.host.free();group.clear()
func group_getter_trace(group: Dictionary)->Array:
	var out: Array=[]
	for index in group.nodes.size():
		var node=group.nodes[index]
		out.append(node.trace.duplicate() if index==int(group.opaque) else node.get_meta("typed_getter_trace").duplicate())
	return out
func many_plain_rows()->void:
	var group:=segment_group(64)
	check(var_to_bytes(group_poll(group.old))==var_to_bytes(group_poll(group.fast)),"64 canonical initial publications exact")
	var before: Dictionary=group.fast.call("dispatch",9,{})
	check(var_to_bytes(group_poll(group.old))==var_to_bytes(group_poll(group.fast)),"64 canonical quiet rows exact")
	var after: Dictionary=group.fast.call("dispatch",9,{})
	check(int(after.plain_schema_checks)-int(before.plain_schema_checks)==1,"Quiet64 rows use one current schema proof")
	check(int(after.plain_segment_reuses)-int(before.plain_segment_reuses)==63,"Quiet64 rows prove63 reuse executions")
	before=after
	check(var_to_bytes(group_poll(group.old))==var_to_bytes(group_poll(group.fast)),"New poll still exact")
	after=group.fast.call("dispatch",9,{})
	check(int(after.plain_schema_checks)-int(before.plain_schema_checks)==1,"Proof cannot survive a poll boundary")
	group.nodes[31].native_state.range=3.5;group.nodes[47].set_meta("native_light_priority",9)
	check(var_to_bytes(group_poll(group.old))==var_to_bytes(group_poll(group.fast)),"Later live field/meta changes retain original results")
	close_group(group)
func getter_source()->String:
	return canonical_source.replace("var native_properties: Dictionary={}","var native_properties: Dictionary={}:\n\tget:\n\t\tif has_meta(\"typed_getter_trace\"):get_meta(\"typed_getter_trace\").append(\"properties\")\n\t\treturn native_properties")
func opaque_segments(action: String)->void:
	var group:=segment_group(4,1)
	group_poll(group.old);group_poll(group.fast)
	var results: Array=[];var traces: Array=[];var nested: Array=[]
	for registry in [group.old,group.fast]:
		reset_group(group)
		var writer: GDScript=group.writer;var nodes: Array=group.nodes;var nested_values: Array=[]
		group.nodes[1].callback=func():
			if action=="fields":nodes[2].native_state.range=4.25;nodes[3].native_properties.radius=1000.0
			elif action=="source-edit":writer.source_code=canonical_source+"\n# opaque mutation within one poll\n"
			elif action=="reload":writer.source_code=canonical_source+"\n# opaque reload\n";check(writer.reload(true)==OK,"Opaque plain reload executes")
			elif action=="getter-restored-text":writer.source_code=getter_source();check(writer.reload(true)==OK,"Opaque getter recompilation executes");writer.source_code=canonical_source
			elif action=="replace-instance":
				var replacement:=GDScript.new();replacement.source_code=canonical_source;check(replacement.reload()==OK,"Opaque replacement writer compiles")
				nodes[2].set_script(replacement);nodes[2].native_properties={"radius":8.0,"color":[.8,.4,.2]};nodes[2].native_state={"range":8.0};nodes[2].native_properties_revision=1
			elif action=="reentrant":nested_values.append(registry.call("dispatch",1,{"planes":[],"view_changed":false}))
			elif action=="erase":registry.call("dispatch",2,{"id":nodes[2].get_instance_id()})
			elif action=="close":registry.call("dispatch",8,{})
		results.append(group_poll(registry));traces.append(group_getter_trace(group));nested.append(nested_values)
	check(var_to_bytes(results[0])==var_to_bytes(results[1]),"Plain/opaque/plain "+action+" exact rows/error")
	check(traces[0]==traces[1],"Plain/opaque/plain "+action+" getter order exact")
	check(var_to_bytes(nested[0])==var_to_bytes(nested[1]),"Plain/opaque/plain "+action+" nested results exact")
	var diagnostic: Dictionary=group.fast.call("dispatch",9,{})
	check(int(diagnostic.plain_segment_invalidations)>0,"Opaque "+action+" executes proof invalidation")
	if action=="getter-restored-text":check(traces[1][2]==["properties"] and traces[1][3]==["properties"],"Later compiled getters really execute after restored source")
	if action=="reentrant":check(nested[1][0].get("error","")=="Native light input registry poll is reentrant","Multi-row reentrant poll still rejected")
	if action in ["erase","close"]:check(results[1].has("error"),"Multi-row membership "+action+" remains rejected")
	group.nodes[1].callback=Callable();close_group(group)
func destructor_segment()->void:
	var group:=segment_group(3);var results: Array=[];var traces: Array=[];var releases: Array=[]
	for registry in [group.old,group.fast]:
		reset_group(group)
		var writer: GDScript=group.writer;var trace: Array=[];var new_getter:=getter_source();var exact_source:=canonical_source
		var finalizer:=RowFinalizer.new()
		finalizer.callback=func():
			trace.append("row-finalized")
			writer.source_code=new_getter;check(writer.reload(true)==OK,"Published RefCounted PREDELETE reload executes");writer.source_code=exact_source
		group.nodes[1].native_properties.color=finalizer
		group_poll(registry) # Entry row retains this arbitrary Variant by contract.
		group.nodes[1].native_properties={"radius":8.0,"color":[.8,.4,.2]};group.nodes[1].native_properties_revision=2
		finalizer=null # The cached published row is now its only strong owner.
		results.append(group_poll(registry));traces.append(group_getter_trace(group));releases.append(trace.duplicate())
	check(var_to_bytes(results[0])==var_to_bytes(results[1]),"Published-row destructor mutation keeps exact rows")
	check(releases[0]==["row-finalized"] and releases[0]==releases[1],"Real PREDELETE exercised once per owner")
	check(traces[0]==traces[1] and traces[1][2]==["properties"],"Row replacement ends proof before later compiled getter")
	close_group(group)
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	canonical_source=canonical_writer.source_code;canonical_hash=canonical_source.sha256_text()
	check(OS.get_cmdline_user_args().has("--light-input-read=typed") and OS.get_cmdline_user_args().has("--light-input-proof=segments"),"Explicit segmented typed mode selected")
	live_changes();observed_fallback();callback_case("erase");callback_case("close");callback_case("reentrant");configure_callbacks();instance_and_source_changes();schema_and_hash_claims()
	many_plain_rows()
	for action in ["fields","source-edit","reload","getter-restored-text","replace-instance","reentrant","erase","close"]:opaque_segments(action)
	destructor_segment()
	await process_frame;finish()
