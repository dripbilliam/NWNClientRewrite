extends "res://native_live_world.gd"
# Select this script only in a private diagnostic replay. It preserves the
# normal session driver, then captures at most one streaming, quiet and moving
# world census. It must not be used as an FPS measurement source.
const Census=preload("res://tools/nwn78/persistent_state_census.gd")
var _nwn78_samples: Array=[]
var _nwn78_done: Dictionary={}
var _nwn78_report_path: String=""
var _nwn78_epoch: int=-1
var _nwn78_source_first: Dictionary={}

func _nwn78_path() -> String:
	if not _nwn78_report_path.is_empty():return _nwn78_report_path
	_nwn78_report_path=str(args.get("report","res://nwn78-diagnostic.json")).trim_suffix(".json")+".nwn78-census.json"
	return _nwn78_report_path

func _profile_tick() -> void:
	super._profile_tick()
	if closing or not is_instance_valid(world) or world.closed or world.retiring:return
	if _nwn78_epoch!=world.generation:
		_nwn78_epoch=world.generation;_nwn78_done.clear()
	var installed_count: int=world.instances.size()
	var wanted_count: int=world.desired.size()
	var streaming: bool=wanted_count>0 and installed_count>=300 and installed_count<wanted_count and not world.batches.is_empty()
	var settled: bool=wanted_count>0 and installed_count==wanted_count and world.batches.is_empty()
	var motion: Dictionary=world.motion.objects.get(world.controlled_id,{})
	var phase: String="streaming" if streaming else "moving" if settled and bool(motion.get("active",false)) else "quiet" if settled and not bool(motion.get("active",false)) else ""
	if phase.is_empty() or _nwn78_done.has(phase):return
	_nwn78_done[phase]=true
	call_deferred("_nwn78_capture",phase,world.get_instance_id(),world.generation)

func _nwn78_capture(phase: String,identity: int,generation: int) -> void:
	if closing or not is_instance_valid(world) or world.get_instance_id()!=identity or world.generation!=generation:return
	var sample: Dictionary=Census.capture(world,phase)
	_nwn78_samples.append(sample)
	var source: Dictionary={}
	for file in ["native_live_world.gd","systems/native_render/live_world.gd","systems/native_render/live_world_pending_appearances.gd","systems/network_motion.gd","systems/native_render/scene_query_index.gd","systems/native_render/drive_collision_indexed.gd"]:
		source[file]=FileAccess.get_sha256("res://"+file)
	if _nwn78_source_first.is_empty():_nwn78_source_first=source.duplicate()
	var expected_script:="res://systems/native_render/live_world_pending_appearances.gd"
	var result:={"ticket":"NWN-78","samples":_nwn78_samples,"source_sha256":source,"source_stable":source==_nwn78_source_first,"expected_world_script":expected_script,"world_script_selected":str(sample.world_script)==expected_script,"complete":{"streaming":_nwn78_done.has("streaming"),"quiet":_nwn78_done.has("quiet"),"moving":_nwn78_done.has("moving")},"scope":"Private diagnostic replay only; full one-shot scene census intentionally excluded from matched FPS windows."}
	var output:=FileAccess.open(_nwn78_path(),FileAccess.WRITE)
	if output!=null:output.store_string(JSON.stringify(result,"\t")+"\n");output.close()
