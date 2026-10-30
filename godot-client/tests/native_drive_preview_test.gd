extends SceneTree
const Plan=preload("res://systems/native_data/drive_preview.gd")
const Motion=preload("res://systems/network_motion.gd")
const Keyboard=preload("res://systems/native_keyboard.gd")
const World=preload("res://systems/native_render/live_world.gd")
class FreeCollision:
	extends Node
	func query(_id: int) -> Callable: return func(_a,_b):return true
	func close() -> void: pass
class TestWorld:
	extends World
	func ready_for_control() -> bool: return not closed
var checks:=0
var failures: Array=[]
var maximum_error:=0.0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<30: failures.append(label)
func close_vector(actual: Vector3,expected: Variant,label: String) -> void:
	var error:=actual.distance_to(Motion.vector(expected)); maximum_error=maxf(maximum_error,error); check(error<0.00002,label+": "+str(error))
func _initialize() -> void: call_deferred("run")
func fixture(name: String) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../backups/animations/"+name)))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	var oracle:=fixture("native-drive-preview-v1.json")
	for row in oracle.cases:
		var input: Dictionary=row.case; var plan:=Plan.plan(Motion.vector(input.position),Motion.vector(input.orientation),input.walkRate,input.runRate,int(input.flags))
		check(int(plan.animation)==int(row.animations[0]),"Original movement animation flags "+str(input.flags))
		close_vector(plan.target,row.paths[0].target,"Original endpoint flags "+str(input.flags))
		if int(input.flags)&48: close_vector(plan.facing,row.targetOrientation,"Original drive turn facing")
	for row in oracle.partialLines:
		var wall:=float(row.case.wall); var path:=Plan.path(Motion.vector(row.case.position),Motion.vector(row.case.target),Motion.vector(row.case.position),func(_a,b):return b.x<=wall)
		close_vector(path.target,row.paths[0].points[-1],"Original partial path")
	# Query answers are frozen original lower providers, not invented collision.
	var slides:=fixture("native-drive-slide-v1.json")
	var slide_index:=0
	for row in slides.cases:
		var cursor: Array=[0]; var query_errors: Array=[]; var calls: Array=row.queries
		var clear:=func(a: Vector3,b: Vector3):
			var i:=int(cursor[0]); cursor[0]+=1
			if i>=calls.size(): query_errors.append("extra query"); return false
			if a.distance_to(Motion.vector(calls[i].start))>0.00002 or b.distance_to(Motion.vector(calls[i].end))>0.00002: query_errors.append("query mismatch")
			return bool(calls[i].clear)
		var result:=Plan.path(Motion.vector(row.case.position),Motion.vector(row.case.target),Motion.vector(row.case.get("render",row.case.position)),clear)
		check(query_errors.is_empty() and int(cursor[0])==calls.size(),"Original angular-slide query order/endpoints "+str(slide_index))
		check(result.is_empty()==row.paths.is_empty(),"Original blocked/slide result")
		if not result.is_empty(): close_vector(result.target,row.paths[-1].points[-1],"Original angular-slide endpoint"); check(absf(float(result.factor)-float(row.factor))<0.00002,"Original slide factor")
		slide_index+=1
	for row in fixture("native-path-acceptance-v1.json").cases:
		var input: Dictionary=row.case; var cursor: Array=[0]; var errors: Array=[]; var calls: Array=row.queries
		var clear:=func(a,b):
			var i:=int(cursor[0]); cursor[0]+=1
			if i>=calls.size(): errors.append("extra query"); return false
			if a.distance_to(Motion.vector(calls[i].start))>0.00002 or b.distance_to(Motion.vector(calls[i].end))>0.00002: errors.append("query mismatch")
			return int(calls[i].result)==1
		var state: Dictionary=input.duplicate(true); state.path=input.priorPath
		var result:=Plan.repair(state,input.path,Motion.vector(input.serverPosition),clear)
		check(errors.is_empty() and int(cursor[0])==calls.size(),"Original acknowledgement connectivity query order")
		check(result.is_empty()==row.installed.is_empty(),"Original acknowledgement admission gate")
		if not result.is_empty():
			check(result.path.size()==row.installed[0].size(),"Original acknowledgement repaired waypoint count")
			for i in mini(result.path.size(),row.installed[0].size()): close_vector(result.path[i],row.installed[0][i],"Original repaired waypoint")
			check(result.has("reset")==not row.rendered.is_empty(),"Original authoritative reset gate")
			if result.has("reset"): close_vector(result.reset,row.rendered[0],"Original authoritative reset")
	var distances: Dictionary={}
	for mode in ["run","walk","left","right","diagonal"]:
		var world:=TestWorld.new(); root.add_child(world); world.set_process(false); world.controlled_id=1
		world.drive_collision=FreeCollision.new(); world.add_child(world.drive_collision)
		var canonical:={"position":[0,0,0],"animation":0,"orientation":[1,0,0],"walkRate":2000,"runRate":4000}; var canonical_before:=canonical.duplicate(true)
		world.desired[1]={"object":{"replicated":canonical}}
		var state:=world.motion.ensure(1,canonical)
		var keyboard:=Keyboard.new(); root.add_child(keyboard); keyboard.set_process(false); keyboard.require_focus=false
		keyboard.context_query=func():return {"id":1,"identity":"authored/1","state":state,"position":Vector3.ZERO}
		var sent: Array=[]; keyboard.transmit=func(message):sent.append(message.duplicate(true))
		keyboard.predict=world.preview_drive; keyboard.end_prediction=world.end_drive
		if mode=="walk": keyboard.key(KEY_SHIFT,true)
		if mode in ["run","walk","diagonal"]: keyboard.key(KEY_W,true)
		if mode in ["left","diagonal"]: keyboard.key(KEY_Q,true)
		if mode=="right": keyboard.key(KEY_E,true)
		var began:=Time.get_ticks_usec()/1000.0; var prior: Vector3=state.render; var stationary:=0; var idle:=0
		for frame in 180:
			keyboard.update_input(began+frame*(1000.0/60)); world.motion.update(1.0/60)
			if state.render.distance_to(prior)<0.0001: stationary+=1
			if int(state.animation) in [0,1]: idle+=1
			prior=state.render; world.motion.finish_frame(1)
		distances[mode]=state.render.length()
		check(stationary==0 and idle==0,"No held-input stationary/idle frames: "+mode)
		check(canonical==canonical_before,"Prediction leaves canonical server data unchanged")
		if mode in ["left","right"]:
			close_vector(state.orientation,[1,0,0],"Strafe preserves forward facing")
			check(absf(state.render.x)<0.001 and state.render.y*(1 if mode=="left" else -1)>4.7,"Strafe moves sideways at original1600 rate")
		check(sent.filter(func(m):return m.operation=="drive" and m.transmit).size()<=7,"Original500ms wire interval is preserved")
		check(sent.filter(func(m):return m.operation=="drive" and not m.transmit).size()>0,"Native250ms preview tick advances sequence without a packet")
		var ack_serial:=keyboard.request_serial
		keyboard.result({"actorId":1,"lifetime":state.lifetime,"requestId":ack_serial,"sequence":9})
		world.observe_movement([{"id":1,"revision":1,"changes":{"animation":0,"path":[],"actionFlag":8},"initial":canonical}])
		check(state.active and int(state.animation) not in [0,1],"Older idle reply cannot cancel newer drive preview")
		keyboard.key(KEY_W,false); keyboard.stop(); keyboard.result({"actorId":1,"lifetime":state.lifetime,"requestId":101,"sequence":10})
		check(int(state.driveSequence)==9 and not state.driveHeld,"Released input rejects late acknowledgements and ends held prediction")
		keyboard.key(KEY_W,true); var rejected:=int(keyboard.stats.stale_acks)
		keyboard.result({"actorId":1,"lifetime":state.lifetime,"requestId":ack_serial,"sequence":7})
		check(int(state.driveSequence)==9 and int(keyboard.stats.stale_acks)==rejected+1,"A re-press rejects a prior hold's late acknowledgement")
		keyboard.stop()
		keyboard.free(); world.free(); await process_frame
	check(absf(float(distances.run)-12)<0.01 and absf(float(distances.walk)-6)<0.01,"Run/walk use actual4000/2000 millimetres per second")
	check(absf(float(distances.diagonal)-float(distances.run))<0.01,"Diagonal run is normalized without a speed boost")
	await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"maximum_oracle_error":maximum_error,"distances":distances,"network":false,"scope":"Unchanged original vector/slide/path-admission observations and actual native driver/live-world preview over authored clear geometry; authoritative local integration separate"},"  ")+"\n"); quit(0 if failures.is_empty() else 1)
