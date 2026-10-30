extends SceneTree
const World=preload("res://systems/native_render/live_world.gd")
class Body:
	extends Node3D
	var rigs
	func setup(id: int) -> void:
		rigs=preload("res://systems/model_rigs.gd").new(); add_child(rigs)
		var defaults:=[{"position":[0,0,0],"quaternion":[0,0,0,1],"scale":[1,1,1]}]
		var map:={"0":"pause1","4":"run","24":"step_f","25":"step_b","26":"step_l","27":"step_r","80":"turn_l","81":"turn_r","82":"turn_l","83":"turn_r","17":"castup","250":"castout"}
		var clips: Array=[]; var seen: Dictionary={}
		for name in map.values():
			if seen.has(name): continue
			seen[name]=true; clips.append({"name":name,"length":1.0,"transition":0.0,"events":[],"tracks":[] if name=="pause1" else [{"part":0,"property":"position","keys":[{"time":0.0,"value":[0,0,0]},{"time":1.0,"value":[0,0.5,0]}]}]})
		var source:={"id":id,"context":{"fieldDE":1,"fieldDD":1,"fieldDF":2,"fieldE0":0},"bodyType":1,"nodes":[{"name":"root","parent":-1,"position":[0,0,0],"quaternion":[0,0,0,1],"scale":[1,1,1]}],"models":[{"asset":0,"parts":[0],"follow":true,"clip":"pause1","loop":true}],"clipMap":map}
		rigs.configure({"meshes_by_name":{}},{id:self},{"rigs":{"version":1,"assets":[{"name":"authored","defaults":defaults,"clips":clips}],"entities":[source]},"meshes":[]})
		set_meta("native_combat_actor",{"id":id,"lifetime":1,"objectType":5})
	func set_animation(code: int,speed: float) -> void: rigs.set_animation(1,code,speed)
	func retire() -> void: queue_free()
var checks:=0
var failures: Array=[]
var ms:=1000
func check(ok: bool,reason: String) -> void:
	checks+=1
	if not ok: failures.append(reason); print("FAIL ",reason)
func object(id: int) -> Dictionary:
	return {"id":id,"nativeLifetime":1,"areaId":42,"objectType":5,"appearance":{"appearance":0},"replicated":{"position":[0.0,0.0,0.0] if id==1 else [5.0,5.0,0.0],"orientation":{"vector":[1.0,0.0,0.0]},"animation":0,"animationSpeed":1.0,"walkRate":1000,"runRate":1000}}
func make_world():
	var world:=World.new(); root.add_child(world); world.set_process(false); world.area_id=42; world.generation=7; world.receive([object(1),object(2)],1)
	for id in [1,2]:
		var body:=Body.new(); world.add_child(body); body.setup(id); world.instances[id]=body; world.installed[id]=world.signature(world.desired[id].object); world.sync_combat(id)
		world.motion.adopt([{"id":id,"state":{"modelType":1,"walkDistance":1.0,"runDistance":1.0}}])
	world.combat.engine.clock_ms=func():return ms; world.combat.engine.last_ms=ms
	return world
func tick(world,count: int=1) -> void:
	for index in count:
		ms+=16; world._process(0.016)
		for body in world.instances.values(): body.rigs._update(0.016)
func correction(world,point: Array,revision: int=1) -> void:
	var original:=object(1); var updated:=original.duplicate(true); updated.replicated.position=point
	world.observe_movement([{"id":1,"revision":revision,"created":false,"initial":original.replicated,"changes":{"position":point,"animation":0}}])
	world.receive_delta([updated],[],1)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	for sample in [{"point":[1.0,0.0,0.0],"code":24},{"point":[-1.0,0.0,0.0],"code":25},{"point":[0.0,-1.0,0.0],"code":26},{"point":[0.0,1.0,0.0],"code":27}]:
		var world=make_world(); var body: Body=world.instances[1]; correction(world,sample.point); tick(world)
		var state: Dictionary=world.combat.engine.states[1]; var model: Dictionary=body.rigs.entities[1].models[0]
		check(int(state.visual)==int(sample.code) and not state.current.is_empty(),"Computed correction enters actual private playback: "+str(sample.code))
		check(absf(float(model.speed)-(1000.0/496.0))<0.00001 and not model.loop,"Original remaining-timer speed fits a non-looping step")
		var before:=float(model.last_time); var pose: Vector3=body.rigs.entities[1].nodes[0].position; tick(world,5)
		check(float(model.last_time)>before and body.rigs.entities[1].nodes[0].position!=pose,"Correction clip clock and actual model-part pose advance")
		check(int(world.combat.engine.stats.movement_cues)==1,"Repeated idle observations do not restart/enqueue the correction every frame")
		check(int(world.combat.engine.states[2].visual)==0 and world.instances[2].rigs.entities[2].models[0].clip=="pause1","A second actor retains independent idle playback")
		check(world.motion.objects[1].position==Vector3(sample.point[0],sample.point[1],sample.point[2]) and world.desired[1].object.replicated.position==sample.point,"Playback does not alter the received correction destination")
		tick(world,40); check(int(state.visual)==0 and state.current.is_empty() and body.rigs.entities[1].models[0].clip=="pause1","Correction completion restores the replicated idle base")
		world.close(); world.queue_free(); await process_frame; await process_frame
	var cast_world=make_world(); correction(cast_world,[1.0,0.0,0.0])
	cast_world.combat.receive({"serial":1,"events":[{"id":1,"lifetime":1,"action":"cast-animation","animation":17,"record":{"type":4},"ageMs":0}]})
	tick(cast_world,5)
	check(int(cast_world.combat.engine.states[1].visual)==17 and cast_world.combat.engine.stats.movement_cues==0,"Received cast work has priority over a simultaneous correction")
	check(cast_world.motion.objects[1].visualAnimation==17 and cast_world.motion.objects[1].get("correctionCue")==null,"Motion observes the actual cast state and stops requesting idle correction steps")
	cast_world.close(); cast_world.queue_free(); await process_frame; await process_frame
	var moving=make_world(); correction(moving,[1.0,0.0,0.0]); tick(moving)
	moving.motion.observe(1,{"animation":4,"path":[[1.0,0.0],[5.0,0.0]],"field8F4":1,"field8EC":1.0},false); tick(moving)
	check(int(moving.combat.engine.states[1].visual)==4 and moving.combat.engine.states[1].current.is_empty(),"Actual run-path input supersedes the local correction step immediately")
	check(moving.instances[1].rigs.entities[1].models[0].loop,"Resumed locomotion keeps a cycling gait")
	moving.close(); moving.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"game_network_connections":0,"scope":"Authored received correction -> live motion -> actual combat queue and private AnimationPlayer/part pose in four directions; timing, restore, independent actor, cast priority and gait interruption. No server or GPU visual acceptance."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
