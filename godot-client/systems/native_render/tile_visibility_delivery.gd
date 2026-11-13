extends RefCounted
# A bounded handoff queue, not a map/world store. Fresh wire operations wait for
# their admitted native world; no snapshot-state polling or per-frame scan.
const Scope=preload("res://systems/native_render/native_scene_visibility.gd")
const MAX_EVENTS:=512
const MAX_UNITS:=262144
var connection:=-1
var serial:=-1
var pending: Array=[]
var units:=0
var active_units:=0
var active_count:=0
var revision:=0
var closed:=false
var failure:=""
var stats:={"queued":0,"accepted":0,"retired":0,"duplicates":0,"unavailable":0}
func reset(value: int) -> void:
	revision+=1;connection=value;serial=-1;pending.clear();units=0;active_units=0;active_count=0;closed=false;failure=""
func push(frame: Dictionary) -> bool:
	if closed:return false
	var scope:=Scope.wire_scope(frame)
	if scope.is_empty() or scope.connection_epoch!=connection:
		stats.unavailable+=1;return false
	var order: Variant=frame.get("serial")
	if not Scope.Tiles._integer(order,0,Scope.Tiles.MAX_SAFE_SERIAL):stats.unavailable+=1;return false
	if int(order)<=serial:stats.duplicates+=1;return false
	var change: Variant=frame.get("change")
	if not change is Dictionary:stats.unavailable+=1;return false
	var payload: Variant=change.get("bytes",change.get("points"))
	if not payload is Array and not payload is PackedByteArray:stats.unavailable+=1;return false
	if pending.size()+active_count>=MAX_EVENTS or units+active_units+payload.size()>MAX_UNITS:
		failure="Native tile delivery queue capacity exceeded";stats.unavailable+=1;return false
	serial=int(order);var detached:=frame.duplicate(true)
	pending.append({"frame":detached,"units":payload.size()});units+=payload.size();stats.queued+=1;return true
func drain(consumer: Callable) -> void:
	if closed or not consumer.is_valid():return
	# Drain only at state-publication boundaries. Reentrant deliveries append to
	# the following batch instead of changing this pass's iteration/membership.
	var epoch:=revision;var batch:=pending;pending=[];active_units=units;active_count=batch.size();units=0
	for index in batch.size():
		var row: Dictionary=batch[index]
		if closed or revision!=epoch:return
		var outcome: Variant=consumer.call(row.frame)
		if closed or revision!=epoch:return
		match str(outcome.get("status","wait")) if outcome is Dictionary else "wait":
			"accepted":stats.accepted+=1
			"retired":stats.retired+=1
			_:
				# A later event must not pass an earlier waiting native setter.
				pending=batch.slice(index)+pending;units+=active_units
				active_count=0;active_units=0;return
		active_count-=1;active_units-=int(row.units)
func snapshot() -> Dictionary:
	return {"connection":connection,"closed":closed,"pending":pending.size(),"units":units,"failure":failure,"stats":stats.duplicate()}
func close() -> void:
	revision+=1;closed=true;pending.clear();units=0;active_units=0;active_count=0
