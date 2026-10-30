extends RefCounted
# A narrowly pinned cached-original supplement. It fills recording gaps only;
# it cannot override recorded resources, raster choices or original misses.
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var store
var entries: Dictionary={}
var failure:=""
var evidence: Dictionary={}
static func valid_reference(name: Variant) -> bool:
	if not name is String or name.is_empty() or name.length()>32 or name!=name.to_lower() or "/" in name or "\\" in name or ":" in name: return false
	for character in name:
		if character.unicode_at(0)<32: return false
	return true
static func integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high and float(value)==floor(float(value))
func reject(reason: String) -> bool:
	failure=reason
	close()
	return false
func configure(captured: RefCounted,descriptor: Dictionary) -> bool:
	if store!=null or not entries.is_empty(): return reject("Cached capture source is already configured")
	if descriptor.get("version")!=1 or descriptor.get("eventsSha256")!=captured.events_sha256 or descriptor.get("context")!=captured.context_id: return reject("Cached source belongs to another capture/context")
	var bindings: Variant=descriptor.get("bindings"); var rasters: Variant=descriptor.get("rasters"); var source: Variant=descriptor.get("source")
	if not bindings is Array or bindings.is_empty() or bindings.size()>128 or not rasters is Array or rasters.is_empty() or rasters.size()>4096 or not source is Dictionary: return reject("Cached capture source descriptor exceeds bounds")
	if not Store.valid_hash(str(source.get("manifest",""))) or not str(source.get("cacheDirectory","")).is_absolute_path(): return reject("Invalid cached manifest/directory")
	var native_directory:=str(source.get("nativeDirectory","")); var helper:=""
	if not native_directory.is_empty():
		if not native_directory.is_absolute_path(): return reject("Invalid native cache directory")
		helper=ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe").simplify_path()
	store=Store.new()
	if not store.configure(source.cacheDirectory,native_directory,helper): return reject("Cached capture source cannot open native storage")
	var manifest: Dictionary=store.manifest(source.manifest)
	if manifest.has("error"): return reject(manifest.error)
	var identities: Array=[]
	for binding in bindings:
		if not binding is Dictionary or not valid_reference(binding.get("name")) or binding.get("type")!=2002 or not captured.digest_valid(binding.get("sha256")): return reject("Invalid captured model binding")
		var key:=str(binding.name)+":"+str(int(binding.type)); var selected: Dictionary=manifest.entries.get(key,{})
		if selected.is_empty() or not Store.valid_hash(str(binding.get("sha1",""))) or selected.hash!=binding.sha1: return reject("Captured binding differs from cached manifest")
		var original: PackedByteArray=captured.get_resource(binding.name,int(binding.type))
		if not captured.failure.is_empty() or Cache.digest(original)!=binding.sha256 or Store.sha1(original)!=binding.sha1: return reject("Captured binding content differs")
		var actual: Dictionary=store.resource(selected)
		if actual.has("error") or Cache.digest(actual.get("bytes",PackedByteArray()))!=binding.sha256: return reject("Cached binding content differs")
		identities.append({"name":binding.name,"type":binding.type,"sha1":binding.sha1,"sha256":binding.sha256})
	var proposed: Dictionary={}
	for row in rasters:
		if not row is Dictionary or not valid_reference(row.get("name")) or not integer(row.get("type"),0,65535) or int(row.type) not in [2073,2033,2059,3] or not Store.valid_hash(str(row.get("sha1",""))): return reject("Invalid cached raster binding")
		var key:=str(row.name)+":"+str(int(row.type)); var selected: Dictionary=manifest.entries.get(key,{})
		if selected.is_empty() or selected.hash!=row.sha1 or proposed.has(key): return reject("Cached raster differs from manifest or repeats")
		proposed[key]=selected
	entries=proposed; evidence={"manifest":source.manifest,"bindings":identities,"rasters":rasters.duplicate(true),"rendering_prepared":false}
	return true
func location(name: String,type: int) -> Dictionary: return entries.get(name.to_lower()+":"+str(type),{})
func raster_location(name: String) -> Dictionary:
	for type in [2073,2033,2059,3]:
		if not location(name,type).is_empty(): return {"name":name.to_lower(),"type":type}
	return {}
func resource(name: String,type: int) -> Dictionary:
	var selected:=location(name,type)
	if selected.is_empty() or store==null: return {"error":"Resource is not in the pinned cached supplement"}
	return store.resource(selected)
func close() -> void:
	entries.clear()
	if store!=null: store.close(); store=null
