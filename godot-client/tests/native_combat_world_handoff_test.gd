extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
const Actor=preload("res://systems/native_data/combat_actor.gd")
const Fixture=preload("res://tests/native_combat_handoff_test.gd")
var checks:=0
var failures: Array=[]
var fake_ms:=1000
class Body extends Node3D:
	var rigs
	func retire() -> void: queue_free()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var world:=World.new(); root.add_child(world); world.set_process(false); world.area_id=42; world.generation=7
	world.combat.engine.clock_ms=func():return fake_ms
	world.combat.engine.last_ms=fake_ms
	var tables:={"appearance":{"orderedRows":[{"HITDIST":"0.5","PREFATCKDIST":"2.0","WEAPONSCALE":"1.0","TARGETHEIGHT":"M","ABORTONPARRY":"0"}]},"baseitems":{"orderedRows":[]}}
	var sources: Array=[]
	for id in [1,2]: sources.append({"id":id,"nativeLifetime":id*10,"areaId":42,"objectType":5,"appearance":{"appearance":0},"replicated":{"position":[0.0,0.0,0.0] if id==1 else [2.5,0.0,0.0],"orientation":{"vector":[0.0,1.0,0.0]},"animation":0,"walkRate":1000.0,"runRate":1000.0,"stats":{"classes":[{"id":10}]},"hitPoints":{"current":100}}})
	world.receive(sources,1)
	for source in sources:
		var id:=int(source.id); var body:=Body.new(); world.add_child(body); body.rigs=Fixture.Playback.new(); body.add_child(body.rigs)
		body.rigs.entities[id]={"root":body,"context":{"fieldDE":1,"fieldDD":1,"fieldDF":2,"fieldE0":0},"body_type":1,"loop_map":{}}
		body.set_meta("native_combat_actor",Actor.project(source,tables)); world.instances[id]=body; world.installed[id]=world.signature(source); world.sync_combat(id)
		world.motion.adopt([{"id":id,"state":{"modelType":1,"walkDistance":1.0,"runDistance":1.0}}])
	world.apply_poses()
	world.observe_movement([{"id":1,"revision":1,"created":false,"initial":sources[0].replicated,"changes":{"animation":4,"path":[[0,0],[5,0]],"field8F4":1,"field8EC":1.0}}]); world._process(1.0/60.0)
	check(world.motion.objects[1].active and int(world.combat.engine.states[1].visual)==4,"Actual live-world path owns its native gait")
	check(int(world.combat.engine.states[1].base)==0,"Actual pose bridge retains its independent resting base")
	var before: Vector3=world.instances[1].position; var source_before:=JSON.stringify(sources)
	var attack:={"type":1,"sourceId":1,"targetId":2,"duration":1000,"result":1,"reaction":14,"reactionDuration":500,"reactionDelay":0,"attackType":0,"ranged":0,"weaponAttackType":1,"killingBlow":0,"damage":1}
	world.receive_combat({"generation":7,"areaId":42,"serial":1,"events":[{"id":1,"lifetime":10,"action":"attack-animation","records":[attack],"ageMs":0}]})
	world.observe_movement([{"id":1,"revision":2,"created":false,"initial":sources[0].replicated,"changes":{"animation":9,"path":[],"facingTarget":2}}]); fake_ms+=16; world._process(1.0/60.0)
	var state: Dictionary=world.combat.engine.states[1]
	check(not world.motion.objects[1].active and world.motion.objects[1].path.is_empty(),"Only the received empty path stops native movement")
	check(int(state.visual) in [200,201,202] and int(world.combat.engine.stats.attacks)==1 and state.pending==null,"Actual received attack-to-pose phase plays the deferred melee cue")
	check(before.is_equal_approx(world.instances[1].position) and source_before==JSON.stringify(sources),"Presentation handoff changes no authoritative source or motion position")
	var requests: int=world.instances[1].rigs.played.size()
	for index in 8: fake_ms+=16; world._process(1.0/60.0)
	check(int(state.visual) in [200,201,202] and int(world.instances[1].rigs.played.size())==requests,"Repeated attack-base observations retain one actual cue without gait replay")
	check(int(world.motion.objects[1].facingTarget)==2,"Attack handoff retains the exact received facing owner")
	world.close(); check(world.combat.engine.states.is_empty() and world.motion.objects.is_empty(),"World close releases presentation and native path owners")
	world.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual LiveWorld raw movement/combat -> native motion -> pose fourth-arg -> retained-base scheduler -> captured private playback; authored source state, no server/render/pixel claim."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
