extends RefCounted
var closed:=false
var retiring:=false
var stats:={"errors":[]}
var hidden: Dictionary={}
var base_scenery_population_known:=true
var base_scenery_progress_dirty:=true
var base_scenery_omitted: Dictionary={}
var base_scenery_unaddressable_omitted:=false
var base_live_revision:=0
var base_live_idle_revision:=-1
var opened_at:=Time.get_ticks_usec()
var controlled_id:=1
var area_id:=1
var desired: Dictionary={}
var installed: Dictionary={}
var failed_objects: Dictionary={}
var instances: Dictionary={}
var batches: Array=[]
var control_ready:=false
var terrain_ready:=false
var has_priority_origin:=true
var priority_origin:=Vector3.ZERO
var entry_prefetch_enabled:=true
var entry_prefetch_limit:=8
var entry_prefetch_radius:=20.
var maximum_static_batch:=64
var maximum_base_static_batch:=64
var maximum_actor_batch:=32
var maximum_stream_wave:=64
func ready_for_control() -> bool:return control_ready
func ready_for_admission() -> bool:return terrain_ready
func object_pose(object: Dictionary) -> Dictionary:
	var value: Variant=object.get("replicated",{}).get("position",object.get("staticState",{}).get("position"))
	if not value is Array or value.size()!=3:return {}
	for part in value:
		if not (part is int or part is float) or not is_finite(float(part)):return {}
	return {"position":Vector3(value[0],value[2],-value[1])}
const BaseScenery=preload("res://base_world_scenery.gd")
