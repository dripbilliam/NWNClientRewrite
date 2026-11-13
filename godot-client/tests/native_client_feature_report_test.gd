extends SceneTree
# Pure startup contract checks on current source. No World, GPU fixture, server
# connection, native rebuild, or performance claim is involved.
const FeatureReport=preload("res://systems/native_render/native_feature_report.gd")
const REGISTRY_PATH:="res://systems/native_data/client_feature_registry.json"
var checks:=0
var failures: Array[String]=[]
var definitions: Dictionary={}
var retained: Array=[] # Retain callback owners until render observations drain.
var registry_sha:=""
var available_builtin:=false
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func report(arguments: PackedStringArray,host: Dictionary={}) -> Dictionary:
	var owner:=FeatureReport.new();retained.append(owner)
	var accepted: bool=owner.configure(arguments,host)
	return {"owner":owner,"accepted":accepted,"snapshot":owner.snapshot()}
func arguments_for(name: String,value: String) -> PackedStringArray:
	var result:=PackedStringArray()
	for dependency in definitions[name].get("requires",{}):
		result.append("--"+str(dependency)+"="+str(definitions[name].requires[dependency]))
	result.append("--"+name+"="+value)
	return result
func rejects(arguments: PackedStringArray,fragment: String,label: String) -> void:
	var value:=report(arguments)
	check(not value.accepted and not value.snapshot.valid and not value.snapshot.errors.is_empty(),label+" rejects instead of silently accepting")
	check(str(value.snapshot.errors).contains(fragment),label+" has an actionable feature error")
func defaults() -> void:
	var children:=root.get_child_count()
	var value:=report(PackedStringArray())
	check(value.accepted and value.snapshot.configured and value.snapshot.valid and value.snapshot.errors.is_empty(),"Actual default startup configures successfully")
	check(root.get_child_count()==children,"Startup report creates no scene/world owner")
	check(value.snapshot.registry.path==REGISTRY_PATH and value.snapshot.registry.sha256==registry_sha,"Report pins the actual authoritative registry bytes")
	var expected_native:=0
	for name in definitions:
		var row: Dictionary=definitions[name]
		if row.target=="native":
			expected_native+=1
			check(value.snapshot.parsed_native_options.has(name) and value.snapshot.parsed_native_options[name].value==row.default and not value.snapshot.parsed_native_options[name].explicit and value.snapshot.parsed_native_options[name].target=="native","Schema native default is reported exactly: "+name)
		else:check(not value.snapshot.parsed_native_options.has(name),"Host/engine option is not misrepresented as a native option: "+name)
	check(value.snapshot.parsed_native_options.size()==expected_native,"No invented or omitted native default options")
	check(value.snapshot.parsed_native_options["drive-collision"].value=="indexed" and not value.snapshot.parsed_native_options["drive-collision"].explicit,"Ordinary feature report consumes indexed default without inventing an explicit flag")
	check(value.snapshot.capabilities.light_input_registry.has("available") and value.snapshot.capabilities.light_input_registry.has("reason"),"Capability absence remains explicit")
	available_builtin=bool(value.snapshot.capabilities.light_input_registry.available)
	check(value.snapshot.rendering.display==DisplayServer.get_name() and value.snapshot.rendering.render_thread_requirement=="not-requested","Default thread observation is not claimed as a requested policy match")
	check(value.snapshot.engine==Engine.get_version_info() and value.snapshot.executable==OS.get_executable_path(),"Report identifies the actual running engine")
func scalar_choices_and_bare() -> void:
	for name: String in definitions:
		var row: Dictionary=definitions[name]
		if row.get("choices") is Array:
			for choice in row.choices:
				var value:=report(arguments_for(name,str(choice)))
				var unsupported_builtin: bool=name=="light-input-registry" and choice=="builtin" and not available_builtin
				check(value.accepted!=unsupported_builtin,"Schema choice is validated with actual capability: "+name+"="+str(choice))
				if row.target=="native":check(value.snapshot.parsed_native_options[name].value==choice and value.snapshot.parsed_native_options[name].explicit,"Explicit native scalar is preserved: "+name+"="+str(choice))
				if unsupported_builtin:check(not value.snapshot.valid and not value.snapshot.errors.is_empty() and value.snapshot.parsed_native_options[name].value=="builtin","Unavailable explicit builtin rejects without substituting script")
		if row.has("nativeBare") or row.has("bare"):
			var value:=report(PackedStringArray(["--"+name]))
			var expected: Variant=row.get("nativeBare",row.get("bare"))
			check(value.accepted and value.snapshot.parsed_native_options[name].value==expected and value.snapshot.parsed_native_options[name].explicit,"Documented bare flag follows schema: "+name)
	var history:=report(PackedStringArray(["--native-light-history"]))
	check(str(definitions["native-light-history"].nativeBare)=="1" and history.accepted and history.snapshot.parsed_native_options["native-light-history"].value==definitions["native-light-history"].nativeBare,"Existing bare native-light-history means its schema nativeBare value1")
func invalid_arguments() -> void:
	for name: String in definitions:
		var row: Dictionary=definitions[name]
		if row.get("choices") is Array:
			rejects(PackedStringArray(["--"+name+"=unsupported-test-value"]),name,"Unsupported scalar "+name)
		if not row.has("bare") and not row.has("nativeBare"):
			rejects(PackedStringArray(["--"+name]),name,"Missing scalar "+name)
	rejects(PackedStringArray(["--particle-presentation=shared","--particle-presentation=individual"]),"particle-presentation","Conflicting duplicate")
	rejects(PackedStringArray(["--native-light-history","--native-light-history=1"]),"native-light-history","Identical effective duplicate")
	rejects(PackedStringArray(["--drive-collision=indexed","--drive-collision=indexed"]),"drive-collision","Identical scalar duplicate")
	var clean:=report(PackedStringArray(["--not-a-registry-feature=opaque","--drive-collision-extra=indexed"]))
	check(clean.accepted and not clean.snapshot.parsed_native_options.has("not-a-registry-feature") and clean.snapshot.parsed_native_options["drive-collision"].value==definitions["drive-collision"].default,"Other ingress flags are left to their owner without polluting native selection")
func integer_budget_dependencies() -> void:
	var name:="native-draw-cache-gib"
	var row: Dictionary=definitions[name]
	check(row.type=="integer" and row.minimum<=int(row.default) and int(row.default)<=row.maximum,"Cache budget type/range/default comes from authoritative schema")
	for budget in [str(int(row.minimum)),str(int(row.maximum)),str(row.default)]:
		var value:=report(arguments_for(name,budget))
		check(value.accepted and str(value.snapshot.parsed_native_options[name].value)==budget,"Canonical in-range integer cache budget: "+budget)
	for budget in [str(int(row.minimum)-1),str(int(row.maximum)+1),"25.0","025","+25","25GiB","NaN",""]:
		rejects(arguments_for(name,budget),name,"Invalid cache budget "+budget)
	var dependent:=report(PackedStringArray(["--"+name+"="+str(int(row.minimum))]))
	check(not dependent.accepted and str(dependent.snapshot.errors).contains("requires --native-draw-cache=prepared"),"Explicit budget requires its schema prepared-cache dependency")
	rejects(PackedStringArray(["--native-draw-cache=off","--"+name+"="+str(int(row.minimum))]),"requires --native-draw-cache=prepared","Disabled cache plus explicit budget")
	var reverse:=report(PackedStringArray(["--"+name+"="+str(int(row.minimum)),"--native-draw-cache=prepared"]))
	check(reverse.accepted,"Dependency resolution uses final values independent of argument order")
func isolation_and_lifetime() -> void:
	var host:={"render-thread":{"value":"separate","explicit":true},"metadata":{"nested":[{"state":"initial"}]}}
	var input:=PackedStringArray(["--drive-collision=indexed"])
	var value:=report(input,host)
	check(value.accepted,"Detached host request configures")
	host.metadata.nested[0].state="changed after configure";host["render-thread"].value="safe";input[0]="--drive-collision=legacy"
	var before: Dictionary=value.owner.snapshot()
	check(before.requested.metadata.nested[0].state=="initial" and before.requested["render-thread"].value=="separate" and before.parsed_native_options["drive-collision"].value=="indexed","Caller mutations cannot rewrite stored request/options")
	before.requested.metadata.nested[0].state="changed snapshot";before.parsed_native_options["drive-collision"].value="bad";before.registry.sha256="bad";before.capabilities.light_input_registry.reason="changed snapshot";before.errors.append("injected");before.rendering.render_thread["observed"]=false
	var after: Dictionary=value.owner.snapshot()
	check(after.requested.metadata.nested[0].state=="initial" and after.parsed_native_options["drive-collision"].value=="indexed" and after.registry.sha256==registry_sha and after.errors.is_empty(),"Nested requested/options/registry/errors snapshots cannot mutate live report")
	check(after.capabilities.light_input_registry.reason!="changed snapshot","Capability snapshots are detached")
	check(not value.owner.configure(PackedStringArray(["--drive-collision=legacy"]),{"reconfigured":true}),"A second configure call explicitly rejects")
	var final: Dictionary=value.owner.snapshot()
	check(final.requested==after.requested and final.parsed_native_options==after.parsed_native_options and final.errors==after.errors,"Rejected reconfiguration leaves accepted policy unchanged")
	var failed:=report(PackedStringArray(["--drive-collision=bad"]))
	check(not failed.owner.configure(PackedStringArray()) and not failed.owner.snapshot().valid,"Failed first configuration also cannot be silently replaced")
func thread_evidence() -> void:
	check(DisplayServer.get_name()=="headless","This fixture is explicitly headless")
	for requested in ["safe","separate"]:
		var value:=report(PackedStringArray(),{"render-thread":{"value":requested}})
		check(value.accepted and value.snapshot.rendering.render_thread_requirement=="headless-not-a-gpu-thread-proof","Headless "+requested+" request cannot claim GPU-thread verification")
		check(value.snapshot.rendering.render_thread.has("observed"),"Thread observation availability remains explicit: "+requested)
		if value.snapshot.rendering.render_thread.get("observed",false):check(value.snapshot.rendering.render_thread.has("thread_id") and value.snapshot.rendering.render_thread.has("main_thread_id") and value.snapshot.rendering.render_thread.has("separate"),"Observed thread IDs are real evidence fields: "+requested)
func run() -> void:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(REGISTRY_PATH))
	check(parsed is Dictionary and parsed.get("version")==1 and parsed.get("features") is Array,"Authoritative schema loads without substitution")
	if not parsed is Dictionary or not parsed.get("features") is Array:quit(1);return
	registry_sha=FileAccess.get_sha256(REGISTRY_PATH)
	for row: Dictionary in parsed.features:definitions[str(row.name)]=row
	defaults();scalar_choices_and_bare();invalid_arguments();integer_budget_dependencies();isolation_and_lifetime();thread_evidence()
	await process_frame;await process_frame
	retained.clear()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"schema_sha256":registry_sha,"builtin_light_available":available_builtin,"headless":true,"network":false,"scope":"Actual native startup feature registry/defaults/scalars/bare flags/integer dependency validation, detached host+report views, configure-once lifecycle and explicit headless thread limitation. No World, GPU/visual/live validation or performance proof."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null:file.store_string(JSON.stringify(result,"  ")+"\n")
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
