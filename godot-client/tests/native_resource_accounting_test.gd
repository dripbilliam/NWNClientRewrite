extends SceneTree
const Backend=preload("res://systems/native_data/resource_index_backend.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func cost(value: Variant,maximum: int=1024*1024*1024) -> Dictionary:
	return Backend.retained_cost(value,maximum)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var available:=ClassDB.class_exists(&"NwnResourceIndex") and ClassDB.class_has_method(&"NwnResourceIndex",&"retained_cost")
	check(available,"Native nonserializing data accountant is actually registered")
	var values: Array=[null,true,123,1.234,"μexact",&"shared name",Vector2.ONE,Vector2i.ONE,Rect2(),Vector3.ONE,Vector3i.ONE,Vector4.ONE,Vector4i.ONE,Plane(),Quaternion(),AABB(),Basis(),Transform2D(),Transform3D(),Projection(),Color.RED,PackedByteArray([1,2]),PackedInt32Array([1,2]),PackedInt64Array([1,2]),PackedFloat32Array([1.0,2.0]),PackedFloat64Array([1.0,2.0]),PackedStringArray(["abc","μ"]),PackedVector2Array([Vector2.ONE]),PackedVector3Array([Vector3.ONE]),PackedVector4Array([Vector4.ONE]),PackedColorArray([Color.BLUE]),[],{},[1,"two",{"a":Vector3.ONE}]]
	for value in values:
		var before:=Cache.digest(var_to_bytes(value)); var measured:=cost(value)
		check(measured.has("estimated_bytes") and measured.estimated_bytes>0 and measured.bounded==0,"Supported data type has bounded accounting: "+str(typeof(value)))
		check(before==Cache.digest(var_to_bytes(value)),"Accounting never changes input data: "+str(typeof(value)))
	var packed:=PackedFloat64Array(); packed.resize(1024*1024); packed[123]=1.23456789012345
	var repeated: Array=[]
	for index in 12: repeated.append({"values":packed,"first":index,"rows":1024})
	var began:=Time.get_ticks_usec(); var shared_cost:=cost(repeated); var accounting_ms:=(Time.get_ticks_usec()-began)/1000.0
	began=Time.get_ticks_usec(); var serialized_size:=var_to_bytes(repeated).size(); var serialization_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(shared_cost.shared>=11 and shared_cost.estimated_bytes<serialized_size/3,"Shared packed controller buffers are charged once instead of serialized per track")
	var independent:=packed.duplicate(); independent[0]=1.0; independent[0]=packed[0]
	check(cost([packed,packed]).estimated_bytes<cost([packed,independent]).estimated_bytes,"Identical independent buffers are distinct from shared backing storage")
	var shared_array: Array=["same"]; var shared_dict: Dictionary={"child":shared_array}
	check(cost([shared_dict,shared_dict]).shared>0 and cost([shared_dict,shared_dict]).estimated_bytes<cost([shared_dict,shared_dict.duplicate(true)]).estimated_bytes,"Container identity is accounted without conflating equal independent owners")
	var cycle: Array=[]; cycle.append(cycle); var cycle_cost:=cost(cycle); cycle.clear()
	check(cycle_cost.has("estimated_bytes") and cycle_cost.shared==1,"A repeated container reference terminates instead of recursing indefinitely")
	var bounded:=cost(repeated,1024)
	check(bounded.bounded==1 and bounded.estimated_bytes==1025,"Over-budget accounting stops early with a non-retainable charge")
	var object:=RefCounted.new(); check(cost(object).has("error"),"Live object graphs are rejected by the data-only accountant"); object=null
	var store:=Store.new(); store.maximum_bytes=20*1024*1024; var value:={"tracks":repeated}; store.save_data("same","same",value,store.generation(),-1,true)
	check(store.retained_size("same",store.generation())>0 and store.bytes<=store.maximum_bytes,"Real residency uses owned-buffer charge to retain an in-budget shared source")
	var copy:=store.load_data("same",store.generation()); copy.tracks.clear()
	check(store.load_data("same",store.generation()).tracks.size()==12,"Private cache consumer containers remain isolated")
	check(store.snapshot().accounting.native==1 and store.snapshot().accounting.shared_storage>=11,"Cache reports actual native accounting work and shared storage")
	OS.set_environment("NWN_RESOURCE_ACCOUNTING","serialized"); var reference:=Store.new(); reference.save_data("plain","plain",{"answer":42},reference.generation()); OS.set_environment("NWN_RESOURCE_ACCOUNTING","")
	check(reference.snapshot().accounting.serialized==1 and reference.load_data("plain",reference.generation()).answer==42,"Explicit serialized reference path remains functional")
	var samples: Array=[]
	if args.has("catalog"):
		var catalog:=Recorded.new(); check(catalog.mount(args.catalog),"Exact original captured model sources mount")
		var assets:=Assets.new(); root.add_child(assets)
		for name in ["pme0","a_ba","h_ba_custom"]:
			var bytes: PackedByteArray=catalog.get_resource(name,2002); var result:=assets.decode(bytes,2002,Actor.SOURCE_DECODER,"")
			check(result.error.is_empty(),"Original model decodes for accounting: "+name)
			began=Time.get_ticks_usec(); var measured:=cost({"result":result}); var ms:=(Time.get_ticks_usec()-began)/1000.0
			began=Time.get_ticks_usec(); var size:=var_to_bytes({"result":result}).size(); var serial_ms:=(Time.get_ticks_usec()-began)/1000.0
			check(measured.has("estimated_bytes") and measured.bounded==0,"Original model graph is accounted without fallback: "+name)
			samples.append({"name":name,"estimate":measured,"native_ms":ms,"serialized_bytes":size,"serialize_ms":serial_ms})
		assets.close(); assets.free()
	var report:=FileAccess.open(args.report,FileAccess.WRITE); report.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"shared_buffer":{"native_ms":accounting_ms,"serialize_ms":serialization_ms,"estimated":shared_cost,"serialized_bytes":serialized_size},"samples":samples,"publicConnections":0,"scope":"All supported data value types, shared versus independent buffers/containers, cycles, limits, live-object rejection, actual cache retention/private owners, and optional exact original models. Conservative cache charge, not exact RSS or a native executable timing claim."},"  ")); report.close(); quit(0 if failures.is_empty() else 1)
