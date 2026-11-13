extends RefCounted
const Metadata=preload("res://systems/native_data/world_snapshot_metadata.gd")
# One worker owns the argument Array. Nested received dictionaries are borrowed
# read-only until the session's ordered admission barrier releases this job.
# Read result only after is_task_completed + wait_for_task_completion.
var result: Dictionary={}
func run(owned_rows: Array,area_id: int,offset: int,scope: Array) -> void:
	var began:=Time.get_ticks_usec()
	# A runtime failure inside preparation must still produce a terminal failure
	# packet after the task completes. The owner counts its original packet size.
	result={"version":Metadata.VERSION,"error":"worker-preparation-interrupted","scope":scope,"area_id":area_id,"offset":offset,"rows":[],"thread":OS.get_thread_caller_id(),"worker_ms":0.0}
	for row in owned_rows:
		var reason:=Metadata.validation_error(row)
		if not reason.is_empty():
			owned_rows.clear();result.error=reason;result.worker_ms=(Time.get_ticks_usec()-began)/1000.0;return
	var prepared:=Metadata.prepare(owned_rows,area_id,offset)
	# Clear only our Array, never nested borrowed rows. No received row is kept
	# by the output. Main can discard a stale job after its task has completed.
	owned_rows.clear()
	result={"version":Metadata.VERSION,"error":"","scope":scope,"area_id":area_id,"offset":offset,"rows":prepared,"thread":OS.get_thread_caller_id(),"worker_ms":(Time.get_ticks_usec()-began)/1000.0}
