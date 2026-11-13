extends RefCounted
const Metadata=preload("res://systems/native_data/world_snapshot_metadata.gd")
# One worker owns the argument Array. Nested received dictionaries are borrowed
# read-only until the session's ordered admission barrier releases this job.
# Read result only after is_task_completed + wait_for_task_completion.
var result: Dictionary={}
static func verified_output(source_rows: Array,prepared: Array,offset: int) -> bool:
	if source_rows.size()!=prepared.size():return false
	for index in prepared.size():
		var source: Variant=source_rows[index];var row: Variant=prepared[index]
		if not source is Dictionary or not source.has("id") or not row is Dictionary or not row.get("index") is int or int(row.index)!=offset+index or not row.get("id") is int or int(row.id)!=int(source.id) or not row.get("accepted") is bool or not row.get("pose") is Dictionary or not row.get("classification") is Dictionary or not row.get("key") is String or not row.get("omission") is String:return false
		if row.accepted and (not row.pose.get("position") is Vector3 or not (row.pose.get("rotation") is float or row.pose.get("rotation") is int) or row.key.length()!=64 or not row.classification.get("available") is bool or not row.classification.get("base") is bool or not row.classification.get("reason") is String):return false
		if not row.accepted and (not row.pose.is_empty() or not row.classification.is_empty() or not row.key.is_empty()):return false
	return true
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
	if not verified_output(owned_rows,prepared,offset):
		owned_rows.clear();result.error="worker-output-verification-failed";result.worker_ms=(Time.get_ticks_usec()-began)/1000.0;return
	for row in prepared:
		row.pose.make_read_only();row.classification.make_read_only();row.make_read_only()
	prepared.make_read_only()
	# The original decoded dictionaries are borrowed read-only through ordered
	# admission. Preserve their identity, never their own Array, for a cheap
	# main-thread scope/source check after worker-side shape validation.
	var source_refs:=owned_rows.duplicate()
	source_refs.make_read_only()
	# Clear only our Array, never nested borrowed rows. No received row is kept
	# by the output. Main can discard a stale job after its task has completed.
	owned_rows.clear()
	result={"version":Metadata.VERSION,"error":"","scope":scope,"area_id":area_id,"offset":offset,"rows":prepared,"source_refs":source_refs,"worker_verified":true,"thread":OS.get_thread_caller_id(),"worker_ms":(Time.get_ticks_usec()-began)/1000.0}
