extends Node
const Timing=preload("res://systems/native_render/frame_profile.gd")
# Native scene lifetime; no pointer to an emitter or to another admitted world.
const Points=preload("res://systems/native_render/point_wind.gd")
var state:=Points.empty()
var maximum_records:=32768
var closed:=false
var failure:=""
var stats:={"added":0,"expired":0,"frames":0,"samples":0,"peak_records":0}
func _ready() -> void: process_priority=10
func add_source(position: Array,radius: float,duration: float,strength: float) -> bool:
	if closed: failure="Native point-wind scene is retired"; return false
	if state.records.size()>=maximum_records: failure="Native point-wind source allocation exceeds explicit limit"; return false
	Points.add(state,position,radius,duration,strength); stats.added+=1; stats.peak_records=maxi(stats.peak_records,state.records.size()); return true
func tick(delta: float) -> void:
	if closed: return
	var before: int=state.records.size(); Points.advance(state,delta); stats.expired+=before-state.records.size(); stats.frames+=1
func point_vector(position: Array) -> Array:
	stats.samples+=1
	return Points.sample(state,position)
func _process(delta: float) -> void:
	var began:=Timing.begin()
	_profile_process(delta)
	Timing.finish("callback_wind",began)
func _profile_process(delta: float) -> void: tick(delta)
func snapshot() -> Dictionary:
	var out:=stats.duplicate()
	out.merge({"records":state.records.size(),"capacity":state.capacity,"failure":failure,"closed":closed,"native_only":true,"complete_wind_manager":false,"scope":"Point-source registration/lifetime/vector only; ambient/noise, grass and full original frame/bucket ordering remain incomplete"})
	return out
func close() -> void:
	if closed: return
	closed=true; set_process(false); state.records.clear(); state.capacity=0
func _exit_tree() -> void: close()
