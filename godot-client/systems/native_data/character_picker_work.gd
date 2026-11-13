extends Node
const PickerSnapshot=preload("res://systems/native_data/picker_table_snapshot.gd")
# Selected-character display work only. There is one running task and one
# replaceable pending input. No world, scene, TLK handle or Node reaches a worker.
signal completed
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Spells=preload("res://systems/native_data/pregame_spells.gd")
const Record=preload("res://systems/native_data/pregame_record.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
class Work extends RefCounted:
	var identity: Array=[]
	var source: Dictionary={}
	var tables: Dictionary={}
	var result: Dictionary={}
	var elapsed_ms:=0.0
	func run() -> void:
		var began:=Time.get_ticks_usec(); var resolved: Dictionary=tables.duplicate()
		resolved._native_resolved_ruleset=Values.resolved_ruleset(tables)
		result={"record":Record.compute(source.recordSource,resolved) if source.has("recordSource") else {},"skills":Skills.compute(source.skillSource,resolved) if source.has("skillSource") else {},"spells":Spells.compute(source.spellSource,resolved) if source.has("spellSource") else {}}
		var dependencies: Array=[]
		for projection in result.values():
			for name in projection.get("dependencies",[]): if not dependencies.has(name): dependencies.append(name)
		result.dependencies=dependencies; elapsed_ms=(Time.get_ticks_usec()-began)/1000.0
var wanted: Array=[]
var pending: Dictionary={}
var active: Work
var task:=-1
var result: Dictionary={}
var table_scope: Array=[]
var table_copies: Dictionary={}
var closed:=false
var stats:={"submitted":0,"accepted":0,"stale":0,"coalesced":0,"last_ms":0.0,"snapshot_ms":0.0,"table_copies":0}
static func projection_source(value: Variant) -> Dictionary:
	var source: Dictionary={}
	if value is Dictionary:
		for name in ["recordSource","skillSource","spellSource"]:
			if value.get(name) is Dictionary: source[name]=value[name]
	return source
static func required_tables(source: Dictionary,tables: Dictionary) -> Array:
	var names: Array=["classes","racialtypes","skills","ruleset","exptable","spells"]
	var stats_source: Dictionary=source.get("skillSource",source.get("recordSource",{}).get("stats",source.get("spellSource",{}).get("stats",{})))
	for item in stats_source.get("classes",[]).slice(0,8):
		var id:=int(item.id)&255; var data:=Skills.row(tables,"classes",id if id<(Skills.rows(tables,"classes").size()&255) else 0)
		for field in ["SkillsTable","StatGainTable","AttackBonusTable","SpellGainTable"]:
			var name:=Skills.table_name(data,field)
			if not name.is_empty() and not names.has(name): names.append(name)
	return names
func observe(scope: Array,value: Variant,tables: Dictionary,revision: int) -> bool:
	if closed: return false
	var source:=projection_source(value); var next: Array=[scope,revision,source] if not scope.is_empty() and not source.is_empty() else []
	if next==wanted: return false
	wanted=next.duplicate(true); result={}
	if not pending.is_empty(): stats.coalesced+=1
	pending={}
	if next.is_empty(): return true
	# The table owner publishes at revision boundaries. Deep-copy only selected
	# dependencies once per connection/data/revision, and reuse those detached
	# copies when changing characters. Never copy the complete live table set.
	var began:=Time.get_ticks_usec(); var capture_scope: Array=[scope.slice(0,2),revision]
	if capture_scope!=table_scope: table_scope=capture_scope.duplicate(true); table_copies.clear()
	var captured: Dictionary={}
	for name in required_tables(source,tables):
		if not tables.has(name): continue
		if not table_copies.has(name):
			# These numeric projectors address physical rows only. A parsed2DA
			# also retains row-label maps and raw cells; duplicating that redundant
			# metadata tripled the cold snapshot without supplying any input here.
			table_copies[name]=PickerSnapshot.capture_spells(tables[name],table_copies.get("classes",{})) if name=="spells" else {"orderedRows":tables[name].get("orderedRows",[]).duplicate(true)}; stats.table_copies+=1
		captured[name]=table_copies[name]
	stats.snapshot_ms=(Time.get_ticks_usec()-began)/1000.0
	pending={"identity":wanted.duplicate(true),"source":source.duplicate(true),"tables":captured}; dispatch(); return true
func dispatch() -> void:
	if closed or task>=0 or pending.is_empty(): return
	active=Work.new(); active.identity=pending.identity; active.source=pending.source; active.tables=pending.tables; pending={}; stats.submitted+=1
	task=WorkerThreadPool.add_task(active.run,false,"Native selected character details")
func _process(_delta: float) -> void:
	if closed or task<0 or not WorkerThreadPool.is_task_completed(task): return
	WorkerThreadPool.wait_for_task_completion(task); task=-1; var done:=active; active=null
	if done.identity==wanted:
		result=done.result; stats.accepted+=1; stats.last_ms=done.elapsed_ms; completed.emit()
	else: stats.stale+=1
	dispatch()
func retire() -> void:
	wanted=[]; pending={}; result={}; table_scope=[]; table_copies.clear()
func snapshot() -> Dictionary:
	var value: Dictionary=stats.duplicate(); value.pending=not pending.is_empty(); value.running=task>=0; value.closed=closed; return value
func close() -> void:
	if closed: return
	closed=true; retire()
	if task>=0: WorkerThreadPool.wait_for_task_completion(task)
	task=-1; active=null
func _exit_tree() -> void: close()
