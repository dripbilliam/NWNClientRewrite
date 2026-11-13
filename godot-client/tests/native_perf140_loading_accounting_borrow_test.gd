extends SceneTree
const Backend=preload("res://systems/native_data/resource_index_backend.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
signal sample_signal
var checks:=0
var failures: Array=[]
var observations: Array=[]
var packets: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func reference(value: Variant,maximum: int) -> Dictionary:
	return ClassDB.class_call_static(&"NwnResourceIndex",&"retained_cost",value,maximum)
func accessed(value: Variant,maximum: int,borrowed: bool) -> Dictionary:
	return ClassDB.class_call_static(&"NwnResourceIndex",&"retained_cost_access",value,maximum,borrowed)
func strip_access(value: Dictionary) -> Dictionary:
	var copy:=value.duplicate(); copy.erase("borrowed_reads"); copy.erase("copied_reads"); return copy
func sample(label: String,value: Variant,maximum: int=1024*1024*1024,safe_serialize: bool=true) -> void:
	var before:=Cache.digest(var_to_bytes(value)) if safe_serialize else ""
	var expected:=reference(value,maximum); var borrowed:=accessed(value,maximum,true); var fallback:=accessed(value,maximum,false)
	check(strip_access(borrowed)==expected,"All charge/traversal/sharing/bounds/error fields equal original: "+label)
	check(strip_access(fallback)==expected,"Forced conversion fallback equals original: "+label)
	if not expected.has("error"):
		check(int(fallback.get("borrowed_reads",-1))==0,"Forced fallback never borrows internal storage: "+label)
		check(int(borrowed.get("borrowed_reads",0))+int(borrowed.get("copied_reads",0))==int(fallback.get("copied_reads",0)),"Access paths visit exactly the same supported builtin observations: "+label)
	if safe_serialize: check(Cache.digest(var_to_bytes(value))==before,"No access path mutates data or IEEE bits: "+label)
	observations.append({"label":label,"reference":expected,"borrowed":borrowed,"fallback":fallback})
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var available:=ClassDB.class_exists(&"NwnResourceIndex") and ClassDB.class_has_method(&"NwnResourceIndex",&"retained_cost_access")
	check(available,"Private DLL actually registers optional access method")
	if not available: finish(args.report); return
	var values: Array=[null,true,false,123,-123,1.234,-0.0,"", "μexact😀",&"shared-name",NodePath("owner/child"),Vector2.ONE,Vector2i.ONE,Rect2(),Rect2i(),Vector3.ONE,Vector3i.ONE,Vector4.ONE,Vector4i.ONE,Plane(),Quaternion(),AABB(),Basis(),Transform2D(),Transform3D(),Projection(),Color(0.1,0.2,0.3,0.4),PackedByteArray(),PackedInt32Array(),PackedInt64Array(),PackedFloat32Array(),PackedFloat64Array(),PackedStringArray(),PackedVector2Array(),PackedVector3Array(),PackedVector4Array(),PackedColorArray(),[],{},[1,"two",{"a":Vector3.ONE}]]
	values.append_array([PackedByteArray([0,1,255]),PackedInt32Array([-2147483648,-1,0,2147483647]),PackedInt64Array([-9223372036854775807,0,9223372036854775807]),PackedFloat32Array([-0.0,1.0,-1.0]),PackedFloat64Array([-0.0,1.23456789012345]),PackedStringArray(["abc","abc","μ"]),PackedVector2Array([Vector2.ONE,Vector2.ZERO]),PackedVector3Array([Vector3.ONE,Vector3.ZERO]),PackedVector4Array([Vector4.ONE,Vector4.ZERO]),PackedColorArray([Color.BLUE,Color(0.1,0.2,0.3,0.4)])])
	for index in values.size(): sample("variant-"+str(index)+"-type-"+str(typeof(values[index])),values[index])
	var words:=PackedByteArray(); words.resize(32)
	for index in 8: words.encode_u32(index*4,[0,0x80000000,0x7f800000,0xff800000,0x7f800001,0x7fc12345,0x00000001,0x80000001][index])
	sample("IEEE-special-packed-stream",words.to_float32_array())
	var typed_ints: Array[int]=[1,2,3]; var typed_vectors: Array[Vector3]=[Vector3.ONE,Vector3.ZERO]
	var typed_dictionary: Dictionary[String,int]={"a":1,"b":2}
	sample("typed-int-array",typed_ints); sample("typed-vector-array",typed_vectors); sample("typed-dictionary",typed_dictionary)
	var shared:=PackedFloat64Array(); shared.resize(8192); shared[5]=1.23456789012345
	var leaf:={"packed":shared,"text":"same-owner"}; var alias: Array=[]
	for index in 128: alias.append({"leaf":leaf,"same":shared,"number":index})
	sample("repeated-dictionaries-and-packed-buffers",alias)
	var borrowed_probe:=accessed(alias,1024*1024*1024,true)
	check(int(borrowed_probe.get("borrowed_reads",0))>0 and int(borrowed_probe.get("copied_reads",-1))==0,"Actual supported API getters are exercised, not an unnoticed fallback")
	var independent:=shared.duplicate(); independent[0]=123.0; independent[0]=shared[0]
	sample("equal-independent-packed-storage",[shared,independent])
	check(reference([shared,shared],1024*1024*1024).estimated_bytes<reference([shared,independent],1024*1024*1024).estimated_bytes,"Original backing-storage distinction stays visible")
	sample("equal-independent-containers",[leaf,leaf.duplicate(true)])
	var cycle: Array=[]; cycle.append(cycle); sample("array-cycle",cycle,1024*1024*1024,false); cycle.clear()
	var cycle_dictionary: Dictionary={}; cycle_dictionary["self"]=cycle_dictionary
	sample("dictionary-cycle",cycle_dictionary,1024*1024*1024,false); cycle_dictionary.clear()
	var object:=RefCounted.new()
	sample("object-rejection",object,1024*1024*1024,false)
	sample("callable-rejection",Callable(self,"reference"),1024*1024*1024,false)
	sample("signal-rejection",Signal(self,"sample_signal"),1024*1024*1024,false)
	sample("RID-rejection",RID(),1024*1024*1024,false)
	object=null
	for maximum in [1,95,96,97,1024,1024*1024,1<<40]: sample("budget-"+str(maximum),alias,maximum)
	for maximum in [-1,0,(1<<40)+1]: sample("invalid-budget-"+str(maximum),{"value":1},maximum)
	var depth_root: Array=[]; var cursor:=depth_root
	for index in 132:
		var child: Array=[]; cursor.append(child); cursor=child
	sample("depth-rejection",depth_root,1024*1024*1024,false)
	# A result must not leave a cached raw pointer into former live data. Mutating,
	# clearing and rebuilding the same wrappers is admitted anew on every call.
	var changing:={"rows":[{"values":PackedFloat32Array([1.0,2.0])}]}
	for index in 32:
		sample("lifetime-"+str(index),changing)
		changing.rows[0].values.append(float(index)); changing["new-"+str(index)]=[index,str(index)]
	changing.clear(); sample("cleared-root",changing)
	for index in 32: sample("fresh-root-"+str(index),{"packed":PackedByteArray([index]),"name":"fresh-"+str(index)})
	# Real native threads share only a stable read-only graph. Every read finishes
	# before the owner mutates/clears it. The oracle does not mutate worker inputs.
	var threads: Array=[]; var wakes: Array=[]
	for index in 8:
		var wake:=Semaphore.new(); wakes.append(wake); var thread:=Thread.new()
		var callable:=func():
			wake.wait(); var results: Array=[]
			for repeat in 8:
				var old:=reference(alias,1024*1024*1024); var direct:=accessed(alias,1024*1024*1024,true); var converted:=accessed(alias,1024*1024*1024,false)
				results.append(strip_access(direct)==old and strip_access(converted)==old and int(direct.get("borrowed_reads",0))>0)
			return results
		check(thread.start(callable)==OK,"Concurrent readonly accounting worker starts: "+str(index)); threads.append(thread)
	for wake in wakes: wake.post()
	for index in threads.size():
		var results: Array=threads[index].wait_to_finish()
		for repeat in results.size(): check(results[repeat],"Concurrent exact original/fallback oracle "+str(index)+":"+str(repeat))
	OS.set_environment("NWN_RESOURCE_ACCOUNTING","serialized")
	check(not Backend.accounting_available() and Backend.retained_cost({"value":1},1024).is_empty(),"Explicit serialized policy bypasses native access in either mode")
	OS.set_environment("NWN_RESOURCE_ACCOUNTING","")
	if args.has("recorded-catalog"):
		var catalog:=Recorded.new(); check(catalog.mount(args["recorded-catalog"]),"Sealed catalog mounts")
		var service:=Assets.new(); root.add_child(service); service.maximum_workers=1; service.prework_read=false; service.prework_write=false; service.configure(catalog)
		service.completed.connect(func(_id,result):packets.append(result))
		for name in str(args.get("models","")).split(",",false):
			packets.clear(); var id: int=service.request(name,2002,"static-model")
			check(id>0,"Captured static model request is accepted: "+name)
			var waited:=Time.get_ticks_msec()
			while packets.is_empty() and Time.get_ticks_msec()-waited<10000: await process_frame
			check(not packets.is_empty(),"Captured static model completes: "+name)
			if packets.is_empty(): continue
			var packet: Dictionary=packets[0]; check(str(packet.get("error","")).is_empty(),"Captured model/image preparation is valid: "+name)
			if str(packet.get("error","")).is_empty(): sample("captured-bundle-"+name,service.bundle_content(packet))
		service.close(); service.free(); catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	finish(args.report)
func finish(filename: String) -> void:
	var file:=FileAccess.open(filename,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"publicConnections":0,"scope":"Same-DLL exact original/native-borrow/forced-conversion oracle. All returned semantic fields, conservative charges, alias identity, mutation/lifetime, actual read-only concurrency, bounds and error outcomes. Functional clocks are not performance evidence."},"  "));file.close();quit(0 if failures.is_empty() else 1)
