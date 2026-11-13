extends SceneTree
# Actual current/frozen World.receive owners; no scene admission or asset jobs.
const Current=preload("res://systems/native_render/live_world.gd")
const Before=preload("res://tests/fixtures/native_world_snapshot_before_world.gd")
const Metadata=preload("res://systems/native_data/world_snapshot_metadata.gd")
var checks:=0
var failures: Array=[]
class Combat extends RefCounted:
	var forgotten: Array=[]
	func forget(id: int,removed: bool=false) -> void:forgotten.append([id,removed])
	func close() -> void:pass
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func digest(value: Variant) -> String:return Metadata.digest(var_to_bytes(value))
func source(id: int,kind: int=9) -> Dictionary:
	var row:={"id":id,"objectType":kind,"areaId":7,"nativeLifetime":1,"clientKnownLifetime":2,"replicated":{"position":[1,2,3],"orientation":[0.25,0.75,0],"animation":0,"appearance":17,"walkRate":2,"runRate":4}}
	if kind==9:row.staticState={"id":id,"appearance":17,"position":[1,2,3],"orientation":[0.25,0.75,0]}
	return row
func packet(rows: Array) -> Dictionary:return {"version":1,"error":"","scope":[1,3,50,7],"area_id":7,"count":rows.size(),"rows":Metadata.prepare(rows,7)}
func state(owner) -> Dictionary:
	var motion: Dictionary={}
	for id in owner.motion.objects:
		var value: Dictionary=owner.motion.objects[id]
		motion[id]={"position":value.position,"orientation":value.orientation,"animation":value.animation}
	return {"desired":owner.desired,"omitted":owner.base_scenery_omitted,"unaddressable":owner.base_scenery_unaddressable_omitted,"progress":owner.base_scenery_progress_counts,"population_revision":owner.base_scenery_population_revision,"live_revision":owner.base_live_revision,"schedule":owner.base_stream_schedule.entries,"motion":motion,"forgotten":owner.combat.forgotten,"removed":owner.stats.removed,"replacements":owner.stats.get("lifetime_replacements",0)}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(FileAccess.get_sha256("res://tests/fixtures/native_world_snapshot_before_world.gd")=="8db15cb3d3482febc725d5218ec5488c491e88278410359dc12f28cfca03f7ee","Exact dirty pre-integration World is frozen")
	var before:=Before.new();var current:=Current.new()
	for owner in [before,current]:owner.area_id=7;owner.generation=3;owner.combat=Combat.new();owner.continuous_base_stream=true
	var initial: Array=[source(1,5),source(2),source(3,10),source(4,1),source(5),source(-1)]
	initial[4].replicated.position=[];initial[5].replicated.position=[]
	var unscoped:=source(6,7);unscoped.erase("areaId");initial.append(unscoped)
	var duplicate: Array=[source(2),source(2),source(5),source(5)]
	duplicate[0].nativeLifetime=3;duplicate[1].nativeLifetime=4;duplicate[1].replicated.appearance=18
	duplicate[3].replicated.position=[]
	var changed: Array=[source(2),source(1,5)]
	changed[0].replicated.position=[9,8,7];changed[0].replicated.appearance=20
	var stages: Array=[initial,duplicate,changed,[]]
	for index in stages.size():
		var rows: Array=stages[index];var prior:=digest(rows)
		check(current.stage_received_metadata(rows,packet(rows)),"Current World admits complete private metadata: "+str(index))
		before.receive(rows,1);current.receive(rows,1)
		check(digest(state(current))==digest(state(before)),"Exact current/frozen full receive semantics including duplicate/omitted rows: "+str(index))
		check(digest(rows)==prior,"World metadata does not rewrite canonical row bytes: "+str(index))
		check(current._staged_received_metadata.is_empty() and current._boundary_received_metadata.is_empty(),"Metadata expires at its single receive boundary: "+str(index))
	# A staged packet cannot transfer to another Array even when rows are shared.
	var rows: Array=[source(11)];var copy:=rows.duplicate()
	var prepared_boundaries: int=current.received_metadata_stats.prepared_boundaries
	check(current.stage_received_metadata(rows,packet(rows)),"Array identity fallback begins with valid staging")
	before.receive(copy,1);current.receive(copy,1)
	check(current.received_metadata_stats.prepared_boundaries==prepared_boundaries and digest(state(current))==digest(state(before)),"Different Array takes unchanged synchronous fallback")
	# Rows received afterward must never inherit the preceding boundary's key/pose.
	rows=[source(11)];rows[0].replicated.position=[7,6,5];rows[0].replicated.appearance=30
	before.receive(rows,1);current.receive(rows,1)
	check(digest(state(current))==digest(state(before)),"Unstaged subsequent receive retains the frozen synchronous path")
	for kind in ["version","generation","area","count","index","id","false-row"]:
		var bad:=packet(rows)
		match kind:
			"version":bad.version=2
			"generation":bad.scope[1]=4
			"area":bad.area_id=8
			"count":bad.count=2
			"index":bad.rows[0].index=1
			"id":bad.rows[0].id=99
			"false-row":bad.rows[0].accepted=false
		check(not current.stage_received_metadata(rows,bad),"Malformed private metadata falls back before consumption: "+kind)
		before.receive(rows,1);current.receive(rows,1)
		check(digest(state(current))==digest(state(before)),"Malformed metadata preserves original application: "+kind)
	before.close();current.close();before.free();current.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"public_connections":0,"scope":"Actual full World.receive current versus exact pre-integration source; no scene instantiation/admission, native asset jobs, rendering or FPS measurement."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();quit(0 if failures.is_empty() else 1)
