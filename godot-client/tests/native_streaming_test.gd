extends SceneTree
const Store=preload("res://systems/native_data/preparation_store.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const ActorData=preload("res://systems/native_data/actor_model.gd")
class RigProbe extends RefCounted:
	func clip_length(_id: int,_code: int) -> float: return 1.0
class ActorProbe extends Node3D:
	var rigs:=RigProbe.new()
	func set_animation(_code: int,_speed: float) -> void: pass
	func retire() -> void: queue_free()
class BatchProbe extends Node:
	var actors: Dictionary={}
	var done:=false
	var closed:=false
	var stats:={"errors":[]}
	func close() -> void: closed=true
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var store:=Store.new(); var epoch:=store.generation(); var original:={"nested":[{"value":1}],"packed":PackedByteArray([1,2,3])}
	store.save_data("request","content",original,epoch); original.nested[0].value=9
	var first:=store.load_data("request",epoch); check(first.nested[0].value==1,"Cache publication isolates worker source mutation")
	first.nested[0].value=7; check(store.load_data("request",epoch).nested[0].value==1,"Independent actor results cannot mutate cached preparation")
	store.clear(); check(store.load_data("request",epoch).is_empty(),"Mount generation retires old bindings")
	store.save_data("late","late",original,epoch); check(store.snapshot().entries==0,"Late old worker cannot repopulate a new catalog cache")
	store.maximum_entries=2; epoch=store.generation()
	for index in 3: store.save_data(str(index),str(index),{"value":index},epoch)
	check(store.snapshot().entries==2 and store.snapshot().evictions==1 and store.load_data("0",epoch).is_empty(),"Preparation memory is bounded and evicts old bindings")
	var owner:=World.new(); root.add_child(owner); owner.set_process(false); owner.area_id=42
	var a:={"id":1,"areaId":42,"objectType":5,"appearance":{"appearance":0},"replicated":{"position":[1.0,2.0,0.0],"animation":0}}
	var b: Dictionary=a.duplicate(true); b.id=2
	owner.receive([a,b],1)
	var batch:=BatchProbe.new(); owner.add_child(batch)
	var actor:=ActorProbe.new(); batch.add_child(actor); batch.actors[1]=actor
	owner.batches.append({"owner":batch,"actors":true,"keys":{1:owner.signature(a),2:owner.signature(b)}})
	owner._process(0.01)
	check(owner.instances.has(1) and not batch.closed and not batch.done,"Ready actor is admitted while another actor in its batch is unfinished")
	check(not owner.instances.has(2),"Unprepared hierarchy is not attached")
	var obsolete:=ActorProbe.new(); batch.add_child(obsolete); batch.actors[2]=obsolete
	b.appearance.appearance=1; owner.receive([a,b],1); owner._process(0.01); owner._process(0.01)
	check(not owner.instances.has(2) and owner.stats.stale_results==1,"Obsolete ready actor is discarded once, without exposing a stale appearance")
	batch.done=true; owner._process(0.01); check(batch.closed and owner.batches.is_empty(),"Completed preparation owner closes after its live actors were adopted")
	owner.close(); owner.free(); await process_frame; await process_frame
	# Actual original animated model preparation is shared across fresh worker
	# owners/catalog forks, but result graphs remain privately owned.
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture)); var catalog:=Catalog.new()
	check(catalog.mount_install(oracle.install),"Original catalog for preparation reuse")
	check(catalog.mount_erf(str(oracle.install).path_join("data/nwm/Prelude.nwm"),100000000),"Original Prelude mount")
	var female_bytes: PackedByteArray=catalog.get_resource("pfh0",2002); var female_parser:=ActorData.new(); var female: Dictionary=female_parser.parse(female_bytes)
	check(female_parser.failure.is_empty() and female.get("nodes",[]).size()==57,"Installed female humanoid preserves all 57 physical nodes")
	check(female.get("nodes",[]).filter(func(node): return node.name=="Impact").size()==2,"Both original duplicate Impact nodes survive without rejecting the crowd")
	var fork=catalog.fork(); check(fork.preparation_cache()==catalog.preparation_cache(),"Catalog forks share the same bounded memory tier")
	var timings: Array=[]; var expected:=""
	var selected_timings: Array=[]; var reference:=Assets.new()
	for name in ["pmh0","pmh0_shol016","pme0_robe005","pme0_bicepr008","pmd0"]:
		var raw: PackedByteArray=catalog.get_resource(name,2002)
		var began:=Time.get_ticks_usec()
		var full: Dictionary=reference.actor_data(catalog,name,raw,ProjectSettings.globalize_path("user://native-prepared-v2"),[])
		var full_ms:=(Time.get_ticks_usec()-began)/1000.0
		began=Time.get_ticks_usec()
		var selected: Dictionary=reference.actor_data(catalog,name,raw,ProjectSettings.globalize_path("user://native-prepared-v2"),[],{})
		var selected_ms:=(Time.get_ticks_usec()-began)/1000.0
		check(str(full.error).is_empty() and str(selected.error).is_empty(),"Original full/selected inheritance succeeds: "+name)
		if not str(full.error).is_empty() or not str(selected.error).is_empty(): continue
		var full_rig: Dictionary=ActorData.new().rig_asset(full.value); var selected_rig: Dictionary=ActorData.new().rig_asset(selected.value)
		check(Cache.digest(var_to_bytes(full_rig))==Cache.digest(var_to_bytes(selected_rig)),"Every bound original key, clip/event and rest transform survives selection: "+name)
		check(full.animation_sources==selected.animation_sources,"Original inheritance dependency identity survives selection: "+name)
		selected_timings.append({"name":name,"full_ms":full_ms,"selected_ms":selected_ms,"full_bytes":var_to_bytes(full.value).size(),"selected_bytes":var_to_bytes(selected.value).size()})
	reference.free()
	for pass_index in 2:
		var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); assets.cache_directory=ProjectSettings.globalize_path("user://native-prepared-v2")
		var results: Array=[]; assets.completed.connect(func(_id,result): results.append(result))
		assets.request("pmh0",2002,"actor-model",{"relevant_tracks":true})
		var deadline:=Time.get_ticks_msec()+30000
		while results.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
		check(not results.is_empty(),"Original model worker finishes %d"%pass_index)
		if not results.is_empty():
			var result: Dictionary=results[0]; check(str(result.error).is_empty(),"Original model preparation succeeds %d"%pass_index)
			check(bool(result.get("memory_cache_hit",false))==(pass_index==1),"Second independent worker reuses prepared source/rig data")
			var identity:=Cache.digest(var_to_bytes(result.value))
			if pass_index==0: expected=identity; result.value.nodes[0].name="authored mutation"
			else: check(identity==expected,"Returned animated model graph remains exact after previous consumer mutation")
			timings.append({"pass":pass_index,"worker_ms":result.worker_ms,"memory_hit":result.get("memory_cache_hit",false),"phases":result.get("phases",{})})
		assets.close(); assets.queue_free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"timings":timings,"selection":selected_timings,"memory":catalog.preparation_cache().snapshot(),"scope":"Headless bounded native preparation reuse/private ownership, exact bound-clip inheritance selection and independent early/stale actor admission. Live area timings and visual parity are separate."},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures,"timings":timings})); quit(0 if failures.is_empty() else 1)
