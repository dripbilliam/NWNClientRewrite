extends SceneTree

const World=preload("res://systems/native_render/live_world.gd")
const Keyboard=preload("res://systems/native_keyboard.gd")
const Trace=preload("res://systems/native_data/movement_timing.gd")
const ACTOR=4294967230
const FINAL=Vector3(20.3099994659424,123.23999786377,6.04509878158569)
const DRIFT=Vector3(19.0897006988525,123.917915344238,6.25200748443604)
var checks:=0
var failures: Array=[]
var recorded_reproduction: Dictionary={}

class Fixture:
	extends RefCounted
	var world
	var keyboard
	var state: Dictionary
	var received: Dictionary
	func _init(tree: SceneTree) -> void:
		world=World.new();tree.root.add_child(world);world.set_process(false)
		world.controlled_id=ACTOR;world.generation=2;world.area_id=2147618622
		world.motion.next_lifetime=4
		received={"position":[23.5900001525879,120.519996643066,6.08400869369507],"orientation":[-0.873772263526917,0.48633536696434,0],"animation":4,"walkRate":2200,"runRate":4400}
		world.desired[ACTOR]={"object":{"replicated":received}}
		state=world.motion.ensure(ACTOR,received)
		state.position=Vector3(20.4623241424561,123.087089538574,6.02220439910889);state.render=state.position
		world.motion.preview(ACTOR,{"animation":4,"factor":1.0,"facing":state.orientation},DRIFT)
		keyboard=Keyboard.new();tree.root.add_child(keyboard);keyboard.set_process(false)
		keyboard.context_query=context;keyboard.owner_identity="2/4294967230/4";keyboard.moving=true;keyboard.minimum_serial=351;keyboard.request_serial=359
	func context() -> Dictionary:
		return {"id":ACTOR,"identity":"2/%s/%s"%[ACTOR,state.lifetime],"state":state,"position":Vector3(23.59,120.52,6.084)}
	func ack(request: int,sequence: int,sent: bool) -> void:
		keyboard.result({"actorId":ACTOR,"lifetime":state.lifetime,"requestId":request,"sequence":sequence,"sent":sent})
	func stop() -> Dictionary:
		return Trace.replay({"actorId":ACTOR,"lifetime":state.lifetime,"requestId":360,"operation":"stop"},context(),keyboard,Callable(),world.end_drive)
	func correction(sequence: int=92,animation: int=0,path: Array=[]) -> void:
		world.observe_movement([{"id":ACTOR,"revision":207,"created":false,"changes":{"position":[FINAL.x,FINAL.y,FINAL.z],"orientation":{"yaw":60.900001525878906},"animation":animation,"path":path,"actionFlag":sequence},"initial":received}])
	func dispose() -> void:
		keyboard.context_query=Callable();keyboard.free();world.free()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func projection(state: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key in ["lifetime","active","script","driveHeld","driveSequence","driveSentSequence","driveSentRequestId","releasedTerminalCorrections","releasedTerminalSequence"]:
		if state.has(key):result[key]=state[key]
	for key in ["position","render"]:
		var value: Vector3=state[key];result[key]=[value.x,value.y,value.z]
	return result
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var f:=Fixture.new(self);var canonical:=f.received.duplicate(true)
	f.ack(358,92,true);f.ack(359,93,false)
	check(int(f.state.driveSequence)==93,"original local preview sequence still advances on unsent request359")
	check(int(f.state.get("driveSentSequence",-1))==92 and int(f.state.get("driveSentRequestId",-1))==358,"unsent request359 cannot replace the last sent wire sequence92")
	check(f.stop().accepted and not f.state.driveHeld,"recorded stop360 uses the ordinary live-world release")
	recorded_reproduction.before=projection(f.state);f.correction()
	check(not f.state.active and int(f.state.animation)==0 and f.state.path.is_empty(),"received revision207 idle stop retires released prediction")
	check(int(f.state.script)==0,"accepted released terminal reply ends script prediction ownership")
	check(f.state.position.distance_to(FINAL)<0.00002,"position comes from the actual authoritative correction")
	for tick in 90:f.world.motion.update(1.0/60.0)
	check(f.state.render.distance_to(FINAL)<0.00002 and f.state.render.distance_to(DRIFT)>1,"ordinary correction converges to server position instead of the preview endpoint")
	check(int(f.state.get("releasedTerminalCorrections",0))==1 and int(f.state.get("releasedTerminalSequence",-1))==92,"one explicitly matched released terminal correction is observable")
	var trace:=Trace.sample(f.context(),f.keyboard,1,2,2147618622)
	check(int(trace.state.get("driveSentSequence",-1))==92 and int(trace.state.get("releasedTerminalCorrections",0))==1,"detached movement diagnostics expose both wire ownership and actual acceptance")
	f.correction()
	check(int(f.state.get("releasedTerminalCorrections",0))==1,"duplicate movement revision cannot reapply terminal acceptance")
	check(f.received==canonical,"presentation correction never writes canonical received arrays")
	recorded_reproduction.after=projection(f.state);f.dispose()
	for mode in ["held","wrong-wire","no-wire","nonterminal","newer-wire"]:
		f=Fixture.new(self)
		if mode!="no-wire":f.ack(358,91 if mode=="wrong-wire" else 92,true)
		f.ack(359,93,false)
		if mode=="newer-wire":f.ack(360,94,true)
		if mode!="held":f.world.end_drive(ACTOR)
		var old_position: Vector3=f.state.position
		f.correction(92,4 if mode=="nonterminal" else 0,[[25,125]] if mode=="nonterminal" else [])
		check(f.state.active and f.state.position==old_position,"stale guard retained for "+mode)
		check(int(f.state.get("releasedTerminalCorrections",0))==0,"no released correction counted for "+mode)
		f.dispose()
	f=Fixture.new(self);f.ack(358,92,true);f.ack(359,93,false)
	var stale:=int(f.keyboard.stats.stale_acks);f.ack(357,91,true)
	check(int(f.state.get("driveSentSequence",-1))==92 and int(f.state.driveSequence)==93 and int(f.keyboard.stats.stale_acks)==stale+1,"older request cannot roll back either sequence")
	f.keyboard.result({"actorId":ACTOR,"lifetime":3,"requestId":360,"sequence":94,"sent":true})
	f.keyboard.result({"actorId":ACTOR-1,"lifetime":4,"requestId":360,"sequence":94,"sent":true})
	check(int(f.state.get("driveSentSequence",-1))==92 and int(f.keyboard.stats.stale_acks)==stale+3,"retired lifetime and other actor acknowledgements stay rejected")
	f.keyboard.owner_identity="old-generation/actor/lifetime";f.ack(360,94,true)
	check(int(f.state.get("driveSentSequence",-1))==92 and int(f.keyboard.stats.stale_acks)==stale+4,"changed context identity cannot publish a wire sequence")
	f.dispose()
	f=Fixture.new(self);f.ack(358,92,true);f.ack(359,93,false);f.keyboard.stop(false)
	stale=int(f.keyboard.stats.stale_acks);f.ack(400,94,true)
	check(int(f.state.get("driveSentSequence",-1))==92 and int(f.keyboard.stats.stale_acks)==stale+1,"released input rejects late acknowledgements")
	f.keyboard.owner_identity=str(f.context().identity);f.keyboard.moving=true;f.keyboard.minimum_serial=400;f.ack(359,95,true)
	check(int(f.state.get("driveSentSequence",-1))==92 and int(f.keyboard.stats.stale_acks)==stale+2,"new hold minimum serial rejects an earlier hold's acknowledgement")
	f.dispose()
	f=Fixture.new(self);f.ack(358,92,true);f.ack(359,93,false)
	var old_lifetime:=int(f.state.lifetime)
	f.world.motion.observe(ACTOR,{"position":[1,2,3],"animation":0},true,f.received)
	f.state=f.world.motion.objects[ACTOR]
	check(int(f.state.lifetime)!=old_lifetime and not f.state.has("driveSentSequence") and not f.state.has("driveSequence"),"same-ID recreation cannot inherit either prior sequence")
	f.keyboard.result({"actorId":ACTOR,"lifetime":old_lifetime,"requestId":400,"sequence":94,"sent":true})
	check(not f.state.has("driveSentSequence"),"late acknowledgement cannot recreate retired lifetime wire ownership")
	f.dispose()
	f=Fixture.new(self);f.ack(358,255,true);f.ack(359,0,false);f.stop();f.correction(255)
	check(int(f.state.driveSequence)==0 and int(f.state.get("driveSentSequence",-1))==255 and not f.state.active,"BYTE wrap preserves local0 and exact last-sent255 terminal match")
	f.dispose()
	f=Fixture.new(self);f.ack(358,0,true);f.ack(359,1,false);f.stop();f.correction(0)
	check(int(f.state.get("driveSentSequence",-1))==0 and not f.state.active,"existing unsequenced actionFlag0 acceptance is preserved across wrap")
	f.dispose()
	f=Fixture.new(self);f.ack(358,92,true);f.ack(359,93,false);f.stop()
	f.world.observe_movement([{"id":ACTOR,"revision":207,"created":false,"changes":{"animation":0,"path":[],"actionFlag":92},"initial":f.received}])
	check(f.state.active,"terminal release fallback requires a received position")
	f.dispose()
	for invalid_position in [[NAN,123.24,6.04],[20.31,123.24],Vector3(INF,123.24,6.04)]:
		f=Fixture.new(self);f.ack(358,92,true);f.ack(359,93,false);f.stop()
		f.world.observe_movement([{"id":ACTOR,"revision":207,"created":false,"changes":{"position":invalid_position,"animation":0,"path":[],"actionFlag":92},"initial":f.received}])
		check(f.state.active and int(f.state.get("releasedTerminalCorrections",0))==0,"malformed/nonfinite released position cannot bypass stale ownership")
		f.dispose()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"recorded_reproduction":recorded_reproduction,"server_connections":0,"scope":"Actual native keyboard acknowledgement, live-world release/observation and ordinary motion correction; no graphics, forced captured pose or server-state mutation"}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
