extends Node
# Per-world equivalent of the old renderer's dense vertex preparation pool.
# Simulation and atlas clocks stay on the emitter owner; only copied draw data
# crosses to workers. Completed frames return to the scene thread for upload.
const Vertices=preload("res://systems/native_render/particle_vertices.gd")
const WorkerTrig=preload("res://systems/native_render/particle_worker_trig.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const HEADER_FIELDS=["renderMode1a8","lifeExp","flags","ageMode1cc","xGrid","yGrid","elevationThreshold","alphaStart","alphaEnd","sizeStart","sizeEnd","sizeStartY","sizeEndY","fps","frameStart","frameEnd","blendMode68","twoSided"]
class Submitter extends Node:
	var preparation_owner: Node
	func _process(_delta: float) -> void: preparation_owner.submit()
var scope_root: Node3D
var submitter: Node
var members: Dictionary={}
var member_tokens: Dictionary={}
var member_revision:=0
var items: Array=[]
var pending_items: Array=[]
var threads: Array[Thread]=[]
var completed_workers: Dictionary={}
var generation:=0
var pending_generation:=0
var started_ms:=0
var invalidated:=false
var failed:=false
var failure_message:=""
var closed:=false
var dense:=false
var stats: Dictionary={"frames":0,"completedFrames":0,"emitters":0,"applied":0,"discarded":0,"skippedFrames":0,"failedJobs":0,"staleFrames":0,"packMs":0.0,"lastLatencyMs":0.0,"maxLatencyMs":0.0}

func _enter_tree() -> void: process_priority=69
func configure(root: Node3D) -> void:
	scope_root=root
	root.set_meta("native_particle_vertex_preparation",self)
	submitter=Submitter.new()
	submitter.preparation_owner=self
	submitter.process_priority=120 # After ordinary (70) and native-surface (110) emitters.
	add_child(submitter)
func register(emitter: Node3D) -> void:
	member_revision+=1
	members[emitter.get_instance_id()]=weakref(emitter)
	member_tokens[emitter.get_instance_id()]=member_revision
func unregister(emitter: Node3D) -> void:
	members.erase(emitter.get_instance_id())
	member_tokens.erase(emitter.get_instance_id())
static func particle_count(emitter: Node3D) -> int:
	if emitter.native_owner!=null: return int(emitter.native_active)
	return emitter._state.active188.records.size() if not emitter._state.is_empty() else 0
static func drawable_current(emitter: Node3D) -> bool:
	if particle_count(emitter)==0: return false
	var state: Dictionary=emitter.native_owner.call("dispatch",11,{},{}) if emitter.native_owner!=null else emitter._state
	return Vertices.draw_count(state)>0

func _process(_delta: float) -> void:
	if closed: return
	poll()
	var active:=0
	for id in members.keys():
		var emitter: Object=members[id].get_ref()
		if not is_instance_valid(emitter) or emitter.retired:
			members.erase(id)
			member_tokens.erase(id)
			continue
		# The old dense gate counts every retained entry, including one whose
		# simulation or presentation was disabled earlier in this world.
		active+=particle_count(emitter)
	dense=active>=512 and not failed
	if not threads.is_empty() and Time.get_ticks_msec()-started_ms>250 and not invalidated:
		invalidated=true; generation+=1; stats.staleFrames+=1
	elif not threads.is_empty() and not invalidated and dense: stats.skippedFrames+=1

func plan(emitter: Node3D) -> Dictionary:
	if closed or not dense or not members.has(emitter.get_instance_id()) or emitter.native_instance_streams or emitter.original_texture==null or not str(emitter._state.get("chunkName","")).is_empty() or emitter.providers.has("sineFloat") or emitter.providers.has("cosineFloat"):
		return {"enabled":false,"collect":false}
	if not threads.is_empty():
		if invalidated: return {"enabled":false,"collect":false}
		return {"enabled":true,"collect":false}
	return {"enabled":true,"collect":true}

static func draw_instance(value: Variant) -> Variant:
	if value==null: return null
	return {"fade":M.f(value.fade),"height50":M.f(value.height50),"opacity70":M.f(value.opacity70)}

static func draw_snapshot(state: Dictionary) -> Dictionary:
	# This is the old worker wire shape, projected before the thread boundary.
	# Free records, scene owners, callbacks and services stay on the main thread.
	var head: Dictionary={}
	for name in HEADER_FIELDS: head[name]=state[name]
	var source: Variant=state.get("source50")
	head.source50={"opacity108":M.f(source.opacity108),"instance":draw_instance(source.get("instance"))} if source!=null else null
	head.instance100=draw_instance(state.get("instance100"))
	for name in ["quaternion1d0","position1e0","colorStart","colorEnd"]: head[name]=M.values(state[name])
	var mode:=int(head.renderMode1a8)
	var ordinary:=mode in [0,1,2,4]
	var atlas:=int(head.xGrid)>1 or int(head.yGrid)>1
	var records: Array=[]
	for particle in state.active188.records:
		var stopped:=int(particle.stopped70)!=0
		var row: Dictionary={"position10":M.values(particle.position10),"trail64":[0.0,0.0,0.0],"quaternion34":[0.0,0.0,0.0,0.0],"direction4c":[0.0,0.0,0.0],"rotation1c":0.0,"age":M.f(particle.age),"field48":0.0,"frame44":Vertices.signed32(int(particle.frame44)) if atlas else 0,"stopped70":M.f(particle.stopped70)}
		if mode==6: row.trail64=M.values(particle.trail64)
		if mode==5 or ordinary and stopped: row.quaternion34=M.values(particle.quaternion34)
		if ordinary:
			row.rotation1c=M.f(particle.rotation1c)
			if stopped or int(head.flags)&512: row.direction4c=M.values(particle.direction4c)
		records.append(row)
	head.active188={"records":records}
	return head

func capture(emitter: Node3D,state: Dictionary,factor: float,camera: Array,tint: Array) -> void:
	if closed or failed or not members.has(emitter.get_instance_id()): return
	items.append({"key":items.size(),"id":emitter.get_instance_id(),"member_token":member_tokens.get(emitter.get_instance_id(),-1),"emitter":weakref(emitter),"owner":emitter.native_owner,"state":draw_snapshot(state),"factor":M.f(factor),"camera":M.values(camera),"tint":M.values(tint)})

func submit() -> void:
	if closed or failed or not threads.is_empty() or items.is_empty():
		items.clear()
		return
	var began:=Time.get_ticks_usec()
	pending_items=items; items=[]
	var limit: int=mini(4,maxi(1,floori(float(OS.get_processor_count())/2.0)))
	var groups: Array=[]
	for _index in mini(limit,pending_items.size()): groups.append({"weight":0,"items":[]})
	for item in pending_items:
		var selected: Dictionary=groups[0]
		for group in groups:
			if int(group.weight)<int(selected.weight): selected=group
		selected.items.append({"key":item.key,"state":item.state,"factor":item.factor,"camera":item.camera,"tint":item.tint})
		selected.weight+=item.state.active188.records.size()
	started_ms=Time.get_ticks_msec();pending_generation=generation;invalidated=false
	completed_workers.clear()
	stats.frames+=1;stats.emitters+=pending_items.size()
	for group in groups:
		var worker:=Thread.new()
		var status:=worker.start(Callable(self,"build_group").bind(group.items))
		if status!=OK:
			failed=true;generation+=1;stats.failedJobs+=1;failure_message="Particle vertex worker could not start ("+str(status)+")";push_warning(failure_message)
			break
		threads.append(worker)
	if failed and threads.is_empty():
		stats.discarded+=pending_items.size();stats.completedFrames+=1;pending_items.clear()
	stats.packMs+=float(Time.get_ticks_usec()-began)/1000.0

func build_group(group: Array) -> Array:
	var results: Array=[]
	for item in group:
		var factor: float=item.factor
		var camera: Array=item.camera
		var tint: Array=item.tint
		var providers:={"sourceFactor":func(_source):return factor,"cameraQuaternion":func():return camera,"lightColor":func(_position):return tint,"sineFloat":WorkerTrig.sine,"cosineFloat":WorkerTrig.cosine,"nativeTrig":true}
		results.append({"key":item.key,"out":Vertices.build(item.state,providers,true)})
	return results

func poll() -> void:
	if threads.is_empty(): return
	for index in threads.size():
		if completed_workers.has(index) or threads[index].is_alive(): continue
		var result: Variant=threads[index].wait_to_finish()
		completed_workers[index]=true
		if not (result is Array):
			failed=true;stats.failedJobs+=1;failure_message="Particle vertex worker failed; synchronous preparation will resume";push_warning(failure_message)
			continue
		for frame in result:
			var key:=int(frame.get("key",-1))
			if key<0 or key>=pending_items.size(): stats.discarded+=1;continue
			var item: Dictionary=pending_items[key]
			var emitter: Object=item.emitter.get_ref()
			if invalidated or failed or pending_generation!=generation or not is_instance_valid(emitter) or emitter.retired or not emitter.failure.is_empty() or emitter.native_owner!=item.owner or member_tokens.get(int(item.id),-1)!=int(item.member_token) or not drawable_current(emitter):
				stats.discarded+=1
				continue
			var output: Dictionary=frame.get("out",{})
			if output.has("error"): emitter.fail(str(output.error))
			elif not emitter.receive_prepared_vertices(output): emitter.fail("Native particle prepared surface publication rejected")
			else: stats.applied+=1
	if completed_workers.size()!=threads.size(): return
	var elapsed:=Time.get_ticks_msec()-started_ms
	stats.completedFrames+=1;stats.lastLatencyMs=float(elapsed);stats.maxLatencyMs=maxf(float(stats.maxLatencyMs),float(elapsed))
	threads.clear();completed_workers.clear();invalidated=false
	pending_items.clear()

func snapshot() -> Dictionary:
	var result: Dictionary=stats.duplicate()
	result.merge({"pending":not threads.is_empty(),"closed":closed,"failed":failed,"failure":failure_message,"workers":threads.size(),"members":members.size()},true)
	return result
func close() -> void:
	if closed: return
	closed=true;generation+=1
	if is_instance_valid(submitter): submitter.set_process(false)
	for index in threads.size():
		if not completed_workers.has(index): threads[index].wait_to_finish()
	threads.clear();completed_workers.clear();pending_items.clear();items.clear();members.clear();member_tokens.clear()
	if is_instance_valid(scope_root) and scope_root.get_meta("native_particle_vertex_preparation",null)==self: scope_root.remove_meta("native_particle_vertex_preparation")
	set_process(false)
func _exit_tree() -> void: close()
