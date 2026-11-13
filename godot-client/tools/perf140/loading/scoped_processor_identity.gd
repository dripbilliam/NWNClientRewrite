extends RefCounted
# Private candidate helper. A generated, source-pinned graph describes each
# artifact. A mismatch disables optional prework; it never blesses a partial
# graph, a manual revision, or an empty parent key.
const DESCRIPTOR:="res://systems/native_data/scoped_processor_graph.json"
const FORMAT:="native-processor-graph-v1"
static var gate:=Mutex.new()
static var descriptor: Dictionary={}
static var hashes: Dictionary={}
static var identities: Dictionary={}
static var failures: Dictionary={}
static var source_reads:=0
static var engine_gate:=Mutex.new()
static var engine_initialized:=false
static var engine_sha256:=""
static var engine_error:=""
static var engine_reads:=0
static func valid_digest(value: Variant) -> bool:
	return value is String and value.length()==64 and value==value.to_lower() and value.is_valid_hex_number(false)
static func valid_path(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.begins_with("/") or value.contains("\\") or value.contains(":"): return false
	for component in value.split("/"):
		if component.is_empty() or component in [".",".."]: return false
	return true
static func file_hash(relative: String) -> String:
	if not hashes.has(relative):
		hashes[relative]=FileAccess.get_sha256("res://"+relative) if FileAccess.file_exists("res://"+relative) else ""
		source_reads+=1
	return str(hashes[relative])
static func engine_identity() -> String:
	# Version/commit metadata alone cannot identify locally modified engines.
	# One synchronized process memo is shared by all kinds/services/workers.
	engine_gate.lock()
	if not engine_initialized:
		engine_initialized=true
		var executable:=OS.get_executable_path()
		if not executable.is_absolute_path() or not FileAccess.file_exists(executable): engine_error="unavailable-executable"
		else:
			engine_reads+=1; var measured:=FileAccess.get_sha256(executable)
			if valid_digest(measured): engine_sha256=measured
			else: engine_error="unverified-executable"
	var resolved_sha:=engine_sha256; engine_gate.unlock(); return resolved_sha
static func engine_status() -> Dictionary:
	engine_gate.lock(); var result:={"initialized":engine_initialized,"sha256":engine_sha256,"error":engine_error,"reads":engine_reads}; engine_gate.unlock(); return result
static func runtime_context(graph: Dictionary) -> Dictionary:
	var arguments: Array=[]; var environment: Array=[]; var classes: Array=[]
	for field in ["argument_prefixes","environment","native_classes"]:
		if not graph.get(field) is Array: return {}
		for value in graph[field]:
			if not value is String or value.is_empty(): return {}
	for argument in OS.get_cmdline_user_args():
		for prefix in graph.get("argument_prefixes",[]):
			if argument.begins_with(str(prefix)): arguments.append(argument); break
	for name in graph.get("environment",[]): environment.append([name,OS.get_environment(str(name))])
	for name in graph.get("native_classes",[]): classes.append([name,ClassDB.class_exists(str(name))])
	var executable_identity:=engine_identity()
	if not valid_digest(executable_identity): return {}
	var result:={"engine":Engine.get_version_info(),"engine_sha256":executable_identity,"arguments":arguments,"environment":environment,"classes":classes,"schema":FORMAT}
	if graph.get("kind")=="finished-icon-v1":
		# NativeItemIcons actually renders pixels in a SubViewport. Query actual
		# backends (including command-line/automatic fallback), once per kind.
		result.renderer=[RenderingServer.get_current_rendering_method(),RenderingServer.get_current_rendering_driver_name(),DisplayServer.get_name()]
	return result
static func resolve(kind: String) -> String:
	gate.lock()
	if not identities.has(kind):
		if descriptor.is_empty():
			var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTOR)) if FileAccess.file_exists(DESCRIPTOR) else null
			if parsed is Dictionary: descriptor=parsed
		var graph: Variant=descriptor.get("graphs",{}).get(kind) if descriptor.get("graphs") is Dictionary else null
		var proof:=verify(kind,descriptor,graph,file_hash,runtime_context(graph) if graph is Dictionary else {})
		identities[kind]=str(proof.get("identity","")); failures[kind]=str(proof.get("error",""))
	var resolved:=str(identities[kind]); gate.unlock(); return resolved
static func status() -> Dictionary:
	gate.lock(); var result:={"identities":identities.duplicate(),"failures":failures.duplicate(),"source_reads":source_reads,"engine_fingerprint":engine_status()}; gate.unlock(); return result
static func verify(kind: String,description: Dictionary,graph: Variant,read_hash: Callable,context: Dictionary) -> Dictionary:
	# Pure seam for isolated contract tests; no static memo is changed here.
	if kind not in ["static-model","actor-model","gui-icon-v1","finished-icon-v1","rejection:static-model","rejection:actor-model","rejection:gui-icon-v1"]:
		return {"identity":"","error":"unsupported-artifact"}
	if description.get("format")!=FORMAT or not valid_digest(description.get("generator")) or not graph is Dictionary or graph.get("ready")!=true or graph.get("kind")!=kind:
		return {"identity":"","error":"unverified-graph"}
	if not graph.get("files") is Array or graph.files.is_empty() or not graph.get("libraries") is Array or not graph.get("argument_prefixes") is Array or not graph.get("environment") is Array or not graph.get("native_classes") is Array:
		return {"identity":"","error":"invalid-graph-shape"}
	if not read_hash.is_valid() or context.is_empty(): return {"identity":"","error":"missing-runtime-proof"}
	if not valid_digest(context.get("engine_sha256")): return {"identity":"","error":"missing-engine-proof"}
	if kind=="finished-icon-v1":
		if not context.get("renderer") is Array or context.renderer.size()!=3: return {"identity":"","error":"missing-renderer-proof"}
		for value in context.renderer:
			if not value is String: return {"identity":"","error":"invalid-renderer-proof"}
	var sources: Array=[]; var libraries: Array=[]; var seen: Dictionary={}; var previous:=""
	for row in graph.files:
		if not row is Dictionary or not valid_path(row.get("path")) or not valid_digest(row.get("sha256")) or str(row.path)<=previous or seen.has(row.path): return {"identity":"","error":"invalid-source-row"}
		previous=str(row.path); seen[row.path]=true
		var actual: Variant=read_hash.call(str(row.path))
		if not valid_digest(actual) or actual!=row.sha256: return {"identity":"","error":"source-drift:"+str(row.path)}
		sources.append([row.path,actual])
	previous=""
	for relative in graph.libraries:
		if not valid_path(relative) or str(relative)<=previous: return {"identity":"","error":"invalid-library-row"}
		previous=str(relative); var actual: Variant=read_hash.call(str(relative))
		if not valid_digest(actual): return {"identity":"","error":"missing-library:"+str(relative)}
		libraries.append([relative,actual])
	var input:=[FORMAT,kind,description.generator,sources,libraries,[graph.argument_prefixes,graph.environment,graph.native_classes],context]
	return {"identity":var_to_bytes(input).hex_encode().sha256_text(),"error":"","sources":sources.size(),"libraries":libraries.size()}
