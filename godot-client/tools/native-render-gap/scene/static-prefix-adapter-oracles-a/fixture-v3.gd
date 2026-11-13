extends SceneTree
# One ROLE + one CASE per future child process. This file only records actual
# observations; a separate closure/error/transcript comparator must accept them.
const Collision=preload("res://systems/native_render/drive_collision_indexed.gd")
const ScratchPrimer=preload("res://tools/native-render-gap/scene/static-prefix-adapter-oracles-a/scratch-primer-v3.gd")
class Finalizer extends RefCounted:
	var action: Callable
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE and action.is_valid():action.call()
class KeyFinalizer extends RefCounted:
	var events: Array
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:events.append(["object-key-predelete"])
class TracedIndex extends RefCounted:
	var owner: WeakRef
	var label: String
	var mode: String
	var events: Array
	var ready:=true
	func _notification(what: int)->void:
		if what==NOTIFICATION_PREDELETE:events.append(["index-predelete",label])
	func query(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:
		events.append(["query",label,ticket.duplicate(true),a,b,radius,exclude,creatures])
		var current=owner.get_ref()
		if label=="old-object-key" and mode=="object-key-replace-final":
			current.static_groups={};current.models={};current.model_bounds={}
			events.append(["object-key-replaced-live-maps"])
		elif label=="old-object-key" and mode=="object-key-erase-final-error":
			var keys: Array=current.static_groups.keys()
			var current_key: Variant=keys[-1]
			current.static_groups.erase(current_key);current.models.erase(current_key);current.model_bounds.erase(current_key)
			events.append(["object-key-erased-live-maps"])
		if label=="old-first":
			if mode=="replace-groups-then-all-far" or mode=="replace-groups-then-empty":
				var replacement: Dictionary={}
				for key in ["first","second","third"]:
					var spy:=TracedIndex.new();spy.owner=owner;spy.label="new-"+key;spy.mode=mode;spy.events=events
					replacement[key]={"bounds":{} if mode.ends_with("empty") else {"min_x":1000.0,"min_y":1000.0,"max_x":1001.0,"max_y":1001.0},"index":spy,"ticket":{"key":key}}
				current.static_groups=replacement
				events.append(["replaced-live-groups"])
			elif mode=="replace-states-then-all-far":
				current.model_bounds={"first":[],"second":[],"third":[]}
				current.static_groups.second.bounds={"min_x":1000.0,"min_y":1000.0,"max_x":1001.0,"max_y":1001.0}
				current.static_groups.third.bounds=current.static_groups.second.bounds
			elif mode=="erase-current-key-error":current.static_groups.erase("first")
			elif mode=="clear-origin-error":current.static_groups.clear()
			elif mode=="free-owner-error":current.free()
			elif mode=="reentrant-query":
				mode="ordinary" # Bounded one nested query, not recursive forever.
				events.append(["nested-begin"])
				var nested: Dictionary=current.static_candidates(a,b,radius,exclude)
				events.append(["nested-end",nested.duplicate(true)])
		return {"ready":ready,"rows":[]}
	func query_flat_control(ticket: Dictionary,a: Vector3,b: Vector3,radius: float,exclude: int,creatures: bool)->Dictionary:return query(ticket,a,b,radius,exclude,creatures)
var output:=""
var mode:=""
var role:=""
var candidate_script:=""
var events: Array=[]
var checks: Array=[]
var factory
func check(ok: bool,label: String)->void:checks.append({"ok":ok,"label":label})
func state()->Dictionary:return {"min":Vector3(-1,-1,-1),"max":Vector3(1,1,1),"radius":1.0}
func build_owner()->Node:
	var owner: Node=factory.create_owner() if role=="candidate" else Collision.new()
	owner.set_process(false)
	var keys: Array=["first","second","third"]
	if mode.begins_with("object-key-"):
		var key:=KeyFinalizer.new();key.events=events;keys[2]=key
	for key in keys:
		var label: String="object-key" if key is KeyFinalizer else str(key)
		var spy:=TracedIndex.new();spy.owner=weakref(owner);spy.label="old-"+label;spy.mode=mode;spy.events=events
		if mode=="early-query-unready" and key=="first":spy.ready=false
		if mode=="object-key-unready" and key is KeyFinalizer:spy.ready=false
		owner.static_groups[key]={"bounds":{"min_x":-1.0,"min_y":-1.0,"max_x":1.0,"max_y":1.0},"index":spy,"ticket":{"key":label}}
		owner.models[key]={"states":[{}]};owner.model_bounds[key]=[state()]
	if mode=="late-pending":owner.model_bounds.third[0].pending=true
	elif mode=="typed-bounds":
		var value: Dictionary[String,float]={"min_x":-1.0,"min_y":-1.0,"max_x":1.0,"max_y":1.0}
		owner.static_groups.first.bounds=value
	elif mode=="typed-states":
		var value: Array[Dictionary]=[state()];owner.model_bounds.first=value
	elif mode=="typed-live-groups":
		var value: Dictionary[String,Dictionary]={};value.assign(owner.static_groups);owner.static_groups=value
	elif mode=="readonly-group":owner.static_groups.first.make_read_only()
	elif mode=="readonly-states":owner.model_bounds.first.make_read_only()
	elif mode=="readonly-state":owner.model_bounds.first[0].make_read_only()
	elif mode=="radius-object-error":owner.model_bounds.first[0].radius=RefCounted.new()
	elif mode=="bounds-object-error":owner.static_groups.first.bounds.min_x=RefCounted.new()
	elif mode=="bool-numeric":owner.model_bounds.first[0].radius=true;owner.static_groups.first.bounds.min_x=false
	elif mode=="nan-radius":owner.model_bounds.first[0].radius=NAN
	elif mode=="inf-radius":owner.model_bounds.first[0].radius=INF
	return owner
func key_labels(value: Dictionary)->Array:
	var result: Array=[]
	for key in value:result.append("object-key" if key is KeyFinalizer else key)
	return result
func readonly_scratch(owner: Node)->Dictionary:
	var finalizer:=Finalizer.new()
	var shared: Dictionary={"radius":finalizer};shared.make_read_only()
	var primer:=ScratchPrimer.new()
	var live: Dictionary=primer.prime(root,shared)
	if live.get("pending",true) or not live.get("primed",false):return {"pending":true,"reason":"Actual known native scratch priming did not succeed","primer":primer,"live":live}
	if mode=="readonly-bounds-scratch":
		shared.assign({"radius":8.0,"min_x":-1.0,"min_y":-1.0,"max_x":1.0,"max_y":1.0})
		owner.static_groups.first.bounds=shared
	else:
		shared.assign({"radius":1.0,"min":Vector3(-1,-1,-1),"max":Vector3(1,1,1)})
		owner.model_bounds.first=[shared]
	var target: WeakRef=weakref(owner)
	var trace: Array=events
	finalizer.action=func():
		trace.append(["readonly-scratch-predelete"])
		var current=target.get_ref()
		if is_instance_valid(current):current.model_bounds.third[0].pending=true
	finalizer=null
	check(shared.is_read_only(),"Native assign preserved actual readonly map")
	check(events.is_empty(),"Scratch is finalizer's sole remaining owner before collision query")
	shared={}
	return {"pending":false,"primer":primer,"live":live}
func checkpoint(value: Dictionary)->void:
	var file:=FileAccess.open(output+".checkpoint.json",FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		elif arg.begins_with("--case="):mode=arg.trim_prefix("--case=")
		elif arg.begins_with("--role="):role=arg.trim_prefix("--role=")
		elif arg.begins_with("--candidate-script="):candidate_script=arg.trim_prefix("--candidate-script=")
	call_deferred("run")
func run()->void:
	if output.is_empty() or mode.is_empty() or role not in ["baseline","candidate"] or FileAccess.file_exists(output):quit(2);return
	if role=="candidate":
		if candidate_script.is_empty():quit(2);return
		var script=load(candidate_script)
		if script==null:quit(2);return
		factory=script.new()
		if not factory.has_method("create_owner") or not factory.has_method("oracle_statistics"):quit(2);return
	var owner: Node=build_owner()
	var scratch: Dictionary={}
	if mode.begins_with("readonly-") and mode.ends_with("-scratch"):
		scratch=readonly_scratch(owner)
		if scratch.get("pending",true):
			checkpoint({"pending":true,"reason":scratch.get("reason"),"role":role,"case":mode});owner.free();quit(2);return
	checkpoint({"phase":"before-original-call","role":role,"case":mode,"events":events.duplicate(true)})
	var result: Variant=owner.static_candidates(Vector3.ZERO,Vector3.ONE,0.5,77)
	events.append(["after-query-return"])
	var use: Dictionary={}
	var post: Dictionary={"owner_valid":is_instance_valid(owner)}
	if is_instance_valid(owner):
		if role=="candidate":use=factory.oracle_statistics(owner)
		post.group_keys=key_labels(owner.static_groups);post.model_keys=key_labels(owner.models)
		owner.static_groups={};events.append(["after-clear-static-groups"])
		owner.model_bounds={};owner.models={};owner.source_rows={}
		owner.free();events.append(["after-owner-free"])
	if not scratch.is_empty():scratch.primer.close(scratch.live);scratch.clear();events.append(["after-primer-close"])
	var report:={"status":"OBSERVATION_ONLY_EXTERNAL_DIFFERENTIAL_AND_ERROR_ACCEPTANCE_REQUIRED","success":false,"role":role,"case":mode,"checks":checks,"events":events,"result_bytes":var_to_bytes(result).hex_encode(),"post":post,"actual_use":use,"scope":"One isolated actual-Godot observation; compare baseline/candidate result+PREDELETE/query/cleanup transcript and raw error log plus natural process exit. No standalone PASS or FPS claim."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close();factory=null
	await process_frame;await process_frame
	quit(0)
