extends SceneTree
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Before=preload("res://tests/fixtures/native_perf140_loading_prepared_cache_before.gd")
var checks:=0
var failures: Array=[]
var args: Dictionary={}
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message)
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	call_deferred("run")
func contract(script,scope: String) -> void:
	var base: String=str(args.cache_root).path_join(scope)
	var directory:=base.path_join("one/two/three/four/five")
	var cache=script.new()
	check(not cache.configure("res://"),scope+": source directory remains rejected")
	check(not cache.configure("res://not-a-cache"),scope+": source child remains rejected")
	check(not cache.configure("res://a/../b"),scope+": source normalization remains rejected")
	check(not cache.configure("relative-cache"),scope+": relative source child remains rejected")
	check(cache.configure(directory),scope+": a fresh directory is created")
	check(DirAccess.dir_exists_absolute(directory),scope+": creation reaches leaf")
	check(cache.directory==ProjectSettings.globalize_path(directory).replace("\\","/").simplify_path(),scope+": normalized directory is exposed")
	check(cache.configure(directory+"/../five/"),scope+": existing normalized directory is accepted")
	var identity:=Cache.key("a".repeat(64),"directory-fixture")
	var value:={"array":[3,4,5],"packed":PackedFloat32Array([1.25,2.5]),"name":"existing schema"}
	check(cache.save_data(identity,"a".repeat(64),"directory-fixture",value),scope+": ordinary cache publication works")
	check(cache.load_data(identity,"a".repeat(64),"directory-fixture")==value,scope+": original payload round trips")
	var other=script.new();check(other.configure(directory),scope+": another owner configures the same directory")
	check(other.load_data(identity,"a".repeat(64),"directory-fixture")==value,scope+": another owner reads the same data")
	check(other.load_data(identity,"b".repeat(64),"directory-fixture").is_empty(),scope+": changed source remains rejected")
	check(other.load_data(identity,"a".repeat(64),"wrong").is_empty(),scope+": changed decoder remains rejected")
	# Only known, owned files and an empty leaf are removed; never recursive.
	check(DirAccess.remove_absolute(cache.filename(identity))==OK,scope+": remove owned cache payload")
	check(DirAccess.remove_absolute(directory)==OK,scope+": remove now-empty owned leaf")
	check(not DirAccess.dir_exists_absolute(directory),scope+": external deletion is represented")
	check(other.configure(directory),scope+": reconfiguration recreates a deleted directory")
	check(DirAccess.dir_exists_absolute(directory),scope+": recreated leaf exists")
	check(other.save_data(identity,"a".repeat(64),"directory-fixture",value),scope+": recreated cache accepts publication")
	check(other.load_data(identity,"a".repeat(64),"directory-fixture")==value,scope+": recreated data remains valid")
func elapsed(script,directory: String,iterations: int) -> int:
	var began:=Time.get_ticks_usec()
	for ignored in iterations:
		var cache=script.new()
		if not cache.configure(directory):failures.append("Timing configure unexpectedly failed")
	return Time.get_ticks_usec()-began
func benchmark() -> Dictionary:
	var directory:=str(args.cache_root).path_join("timing/a/b/c/d/e")
	var setup:=Before.new();check(setup.configure(directory),"Timing directory is available")
	var before: Array=[];var target: Array=[];var iterations:=128
	# Interleave ordering. This measures configure only, with an existing path.
	for repetition in 7:
		if repetition%2==0:
			before.append(elapsed(Before,directory,iterations));target.append(elapsed(Cache,directory,iterations))
		else:
			target.append(elapsed(Cache,directory,iterations));before.append(elapsed(Before,directory,iterations))
	var old_sorted:=before.duplicate();old_sorted.sort();var new_sorted:=target.duplicate();new_sorted.sort()
	return {"iterations":iterations,"repetitions":7,"before_us":before,"target_us":target,"before_median_us":old_sorted[3],"target_median_us":new_sorted[3],"scope":"Interleaved headless existing-directory configure microbenchmark; includes filesystem work, not rendering, real-area entry or FPS"}
func run() -> void:
	if not args.has("cache-root") or not args.has("report"):quit(2);return
	args.cache_root=args["cache-root"]
	contract(Before,"before");contract(Cache,"target")
	var timing:=benchmark() if args.get("benchmark","false")=="true" else {}
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"timing":timing,"scope":"Headless prepared-directory and unchanged cache publication/identity checks; no graphics or server connections"}
	var file:=FileAccess.open(str(args.report),FileAccess.WRITE);file.store_string(JSON.stringify(proof));file.close()
	print(JSON.stringify(proof));quit(0 if failures.is_empty() else 1)
