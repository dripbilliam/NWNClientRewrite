extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const OriginalRecorded=preload("res://tests/fixtures/native_perf140_loading_raster_recorded_before.gd")
class Target:
	extends "res://systems/native_data/resource_catalog.gd"
	var bindings: Dictionary={}
	var calls: Array=[]
	func location(name: String,type: int) -> Dictionary:
		calls.append([name,type]);return bindings.get(type,{})
class Original:
	extends "res://tests/fixtures/native_perf140_loading_raster_catalog_before.gd"
	var bindings: Dictionary={}
	var calls: Array=[]
	func location(name: String,type: int) -> Dictionary:
		calls.append([name,type]);return bindings.get(type,{})
var checks:=0
var failures: Array=[]
var args: Dictionary={}
var single_pass:=false
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	single_pass=args.get("expect-single-pass","false")=="true";call_deferred("run")
func binding(value: int) -> Dictionary:
	if value==0:return {}
	var layer: Dictionary={"kind":"key" if value==5 else "erf"}
	if value<5:layer.storage_class=[-1,2,5,3,1][value]
	elif value==7:layer.storage_class=7
	elif value==8:layer.storage_class=-3
	return {"layer":layer,"entry":{"unused":value}}
func matrix() -> Dictionary:
	var a:=Original.new();var b:=Target.new();var total_original:=0;var total_target:=0
	var types: Array=[2073,2033,2059,3]
	# Every format may be absent, any supported storage class, implicit key or
	# archive, or either of two unsupported storage classes.
	for pattern in 6561:
		var rest:=pattern;var bindings: Dictionary={};var first_loose:=-1
		for index in 4:
			var kind:=rest%9;rest=floori(rest/9.0);var value:=binding(kind)
			if not value.is_empty():bindings[types[index]]=value
			if first_loose<0 and kind==1:first_loose=index
		var before:=var_to_bytes(bindings);a.bindings=bindings;b.bindings=bindings;a.calls=[];b.calls=[]
		var expected: Dictionary=a.raster_location("MiXeD_Name");var actual: Dictionary=b.raster_location("MiXeD_Name")
		check(var_to_bytes(expected)==var_to_bytes(actual),"Exact original storage/format winner for pattern "+str(pattern))
		check(before==var_to_bytes(a.bindings) and before==var_to_bytes(b.bindings),"Selection does not mutate catalog bindings")
		if single_pass:check(b.calls.size()==(first_loose+1 if first_loose>=0 else 4),"At most one lookup per format with original loose early return")
		total_original+=a.calls.size();total_target+=b.calls.size()
	a.source_store.clear();b.source_store.clear();return {"patterns":6561,"original_lookups":total_original,"target_lookups":total_target}
func write(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir());var file:=FileAccess.open(path,FileAccess.WRITE);file.store_8(0);file.close()
func mounted_checks() -> void:
	var root:=ProjectSettings.globalize_path("res://selection-fixtures")
	write(root.path_join("low/shape.dds"));write(root.path_join("low/shape.tga"));write(root.path_join("high/shape.ktx"))
	var source:=Catalog.new();check(source.mount_directory(root.path_join("low"),100) and source.mount_directory(root.path_join("high"),200),"Layered raw fixtures mount")
	var unindexed: Dictionary=source.raster_location("SHAPE");source.build_resource_index();var indexed: Dictionary=source.raster_location("SHAPE")
	check(unindexed==indexed and indexed=={"name":"shape","type":2073},"Actual indexed and unindexed catalogs keep the authored format preference")
	check(source.raster_location("absent").is_empty() and source.recorded_texture_miss("absent"),"Missing raster remains an authoritative lookup miss")
	source.source_store.clear();source.prepared_store.clear()
func recorded_matrix() -> void:
	var a:=OriginalRecorded.new();var b:=Recorded.new();var types: Array=[2073,2033,2059,3]
	for pattern in 6561:
		var rest:=pattern;var availability: Dictionary={}
		for index in 4:
			var kind:=rest%9;rest=floori(rest/9.0);var value:=binding(kind)
			if not value.is_empty():availability["mixed_name:"+str(types[index])]=("2" if kind==8 else value.layer.get("storage_class",1 if value.layer.kind=="key" else 3))
		a.manifest={"availability":availability};b.manifest={"availability":availability};var before:=var_to_bytes(availability)
		check(var_to_bytes(a.raster_location("MiXeD_Name"))==var_to_bytes(b.raster_location("MiXeD_Name")),"Exact original recorded format/storage winner for pattern "+str(pattern))
		check(before==var_to_bytes(availability),"Recorded selection does not mutate manifest availability")
	a.prepared_store.clear();a.decoder_store.clear();b.prepared_store.clear();b.decoder_store.clear()
func run() -> void:
	var counts:=matrix();recorded_matrix();mounted_checks()
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"single_pass":single_pass,"counts":counts,"scope":"Headless exact original raster-selection oracle and lookup-count reduction; no graphical, network, frame-rate or loading-time acceptance"}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close();print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
