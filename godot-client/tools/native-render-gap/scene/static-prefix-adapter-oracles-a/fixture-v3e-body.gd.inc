extends "res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/fixture-v3d.gd"
# NEW G rollback positives. The generated run() preserves isolated V3 reporting.
const ActualSpatialE=preload("res://systems/native_render/drive_spatial_index.gd")
class DeferredPayload extends RefCounted:
	var events: Array
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:events.append(["deferred-last-state-predelete"])
class ClearingSecondIndex extends RefCounted:
	var owner: WeakRef
	var events: Array
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:events.append(["second-index-predelete"])
	func query(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:
		events.append(["second-query",ticket.duplicate(true),a,b,radius,exclude,creatures])
		owner.get_ref().model_bounds.first.clear()
		events.append(["after-query-cleared-first-states"])
		return {"ready":true,"rows":[]}
	func query_flat_control(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:return query(ticket,a,b,radius,exclude,creatures)
class CallbackModel extends RefCounted:
	var owner: WeakRef
	var events: Array
	func is_empty()->bool:
		events.append(["unsupported-model-is-empty"])
		owner.get_ref().model_bounds.first.clear()
		events.append(["after-model-cleared-first-states"])
		return false
	func has(key: Variant)->bool:
		events.append(["unsupported-model-has",key])
		return false
func build_owner()->Node:
	var owner: Node=super.build_owner()
	if mode=="canonical-463-terminal":
		owner.static_groups={};owner.models={};owner.model_bounds={};owner.source_rows={}
		for index in 463:
			var key: String="canonical-%04d"%index
			var id:=1000+index;var witness: Array=[id+100,1]
			var center:=Vector3.ZERO if index==0 else Vector3(1000+index*4,1000,0)
			var spatial:=ActualSpatialE.new();var ticket: Dictionary=spatial.begin([771,3,91])
			var added: Dictionary=spatial.upsert_shape(ticket,id,witness,1,"pwk",center-Vector3.ONE,center+Vector3.ONE,false,index)
			check(added.get("accepted",false),"Actual canonical shape "+str(index))
			owner.static_groups[key]={"bounds":{"min_x":float(center.x)-1.0,"min_y":float(center.y)-1.0,"max_x":float(center.x)+1.0,"max_y":float(center.y)+1.0},"index":spatial,"ticket":ticket}
			owner.models[key]={"states":[{}]};owner.model_bounds[key]=[state()]
			owner.source_rows[id]={"witness":witness,"spec":{"door":false,"state":0},"pose":{"position":center,"rotation":0.0},"bounds_signature":[]}
		return owner
	if not mode.begins_with("g-rollback-"):return owner
	# First key executes no query: it is a FAR numeric group with a nonempty
	# state FOR. Its final Dict owns an ignored authored RefCounted payload.
	owner.static_groups.first.bounds={"min_x":1000.0,"min_y":1000.0,"max_x":1001.0,"max_y":1001.0}
	var payload:=DeferredPayload.new();payload.events=events
	var last: Dictionary=state();last.ignored_payload=payload
	owner.model_bounds.first=[state(),last]
	owner.static_groups.third.bounds={}
	var index:=ClearingSecondIndex.new();index.owner=weakref(owner);index.events=events
	owner.static_groups.second.index=index
	if mode=="g-rollback-far-pending":
		owner.models.erase("second") # Pending query never executes the state FOR.
	elif mode=="g-rollback-far-empty":
		owner.models.second={"states":[]};owner.model_bounds.second=[]
	elif mode=="g-rollback-far-model-callback":
		var model:=CallbackModel.new();model.owner=weakref(owner);model.events=events
		owner.models.second=model # Original is_empty callback occurs BEFORE state FOR.
	return owner
func verify_use(use: Dictionary)->void:
	if mode.begins_with("g-rollback-"):
		check(int(use.get("rollback_count",0))>0,"Actual native G rollback_count positive")
		check(int(use.get("rolled_back_unexecuted_skips",0))>0,"Actual G unexecuted skip rewind positive")
		check(int(use.get("native_scanned",0))>0,"Numeric FAR group actually scanned before rollback")
		check(int(use.get("native_fallback",0))>0,"Rewound current-key original prefix actually yielded")
		check(int(use.get("fast_terminal_scans",-1))==0,"Rollback route cannot claim native terminal END")
	elif mode=="canonical-463-terminal":
		check(int(use.get("native_scanned",0))==463,"Exactly463 canonical groups scanned natively")
		check(int(use.get("native_admit",0))==1,"Canonical near group admitted exactly once")
		check(int(use.get("native_fallback",-1))==0,"Canonical463 keeps fallback0")
		check(int(use.get("fast_terminal_scans",0))>0,"Actual native owned-map terminal END positive")
		check(int(use.get("rollback_count",-1))==0 and int(use.get("rolled_back_unexecuted_skips",-1))==0,"Canonical terminal END does not rewind")
	if mode.begins_with("g-rollback-") or mode=="canonical-463-terminal":check(int(use.get("native_cursor_calls",0))>0,"Actual cursor call required; no baseline-only pass")
func verify_result(result: Variant)->void:
	if mode=="canonical-463-terminal":check(result is Dictionary and result.get("ready",false) and result.get("rows",[]).size()==1,"Actual canonical full owner returns one near row")
func event_at(name: String)->int:
	for index in events.size():
		if events[index] is Array and not events[index].is_empty() and events[index][0]==name:return index
	return -1
func verify_events()->void:
	if not mode.begins_with("g-rollback-"):return
	var released:=event_at("deferred-last-state-predelete")
	var returned:=event_at("after-query-return")
	var query:=event_at("second-query")
	check(released>=0 and events.count(["deferred-last-state-predelete"])==1,"One actual deferred-state payload PREDELETE")
	check(query>=0,"Second original group query actually runs")
	check(released<returned,"Deferred state released before outer call returns")
	if mode=="g-rollback-far-model-callback":
		var cleared:=event_at("after-model-cleared-first-states")
		check(event_at("unsupported-model-is-empty")>=0 and cleared>=0,"Actual original unsupported model callback runs")
		check(cleared<released and released<query,"Payload retained through model callback, then state reset releases before query")
	else:
		var cleared:=event_at("after-query-cleared-first-states")
		check(cleared>=0 and query<cleared and cleared<released,"Payload retained through pending/empty-state query clear")
