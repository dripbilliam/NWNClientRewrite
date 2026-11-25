extends SceneTree
const Combat=preload("res://systems/combat_animation.gd")
const Fixture=preload("res://tests/native_combat_handoff_test.gd")
const MotionData=preload("res://systems/native_data/combat_motion.gd")
var checks:=0
var failures: Array=[]
var fake_ms:=1000
var engine
var rigs
var pivots: Dictionary={}
var actors: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func configure(base: int=0) -> void:
	engine.configure(rigs,pivots); engine.receive({"kind":"combat-actors","actors":actors}); engine.base_frame(1,base); engine.base_frame(2,0)
func motion(value: Variant) -> void:
	if engine.has_method("motion_frame"): engine.call("motion_frame",1,value)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var parts:=arg.trim_prefix("--").split("=",true,1)
		if parts.size()==2: args[parts[0]]=parts[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	rigs=Fixture.Playback.new(); root.add_child(rigs); engine=Combat.new(); engine.clock_ms=func():return fake_ms
	for id in [1,2]:
		var pivot:=Node3D.new(); root.add_child(pivot); pivot.position=Vector3(0,0,-2.5) if id==2 else Vector3.ZERO; pivots[id]=pivot
		rigs.entities[id]={"root":pivot,"context":{"fieldDE":1,"fieldDD":1,"fieldDF":2,"fieldE0":0},"body_type":1,"loop_map":{}}
		actors.append({"id":id,"lifetime":id,"objectType":5,"animationSpeed":1.0,"equipment":{},"monk":false,"hitDistance":0.5,"preferredDistance":2.0,"weaponScale":1.0,"targetHeight":"","facingTarget":0x7f000000,"hitPoints":100,"abortOnParry":0})
	var gait: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-combat-gait-base-original-v1.json"))
	for row in gait.cases:
		configure(int(row.case.current)); var state: Dictionary=engine.states[1]; state.base=int(row.case.base)
		engine.base_frame(1,int(row.case.desired))
		check(int(state.base)==int(row.result.base) and int(state.visual)==int(row.result.current),"Original gait retains independent resting owner %s"%JSON.stringify(row.case))
	var boundary: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-combat-locomotion-handoff-original-v1.json"))
	check(engine.has_method("motion_frame"),"Native remaining-path boundary has an explicit presentation owner")
	for row in boundary.cases:
		configure(int(row.case.base)); engine.base_frame(1,int(row.case.visual)); motion(false); engine.update()
		check(int(engine.states[1].base)==int(row.result.base) and int(engine.states[1].visual)==int(row.result.visual),"Original empty-path model boundary restores retained base %s"%JSON.stringify(row.case))
	var attack:={"type":1,"sourceId":1,"targetId":2,"duration":1000,"result":1,"reaction":14,"reactionDuration":500,"reactionDelay":0,"attackType":0,"ranged":0,"weaponAttackType":1,"killingBlow":0,"damage":1}
	for code in Combat.GAITS:
		configure(); engine.base_frame(1,code); engine.base_frame(1,9); motion(false)
		engine.receive({"kind":"combat-events","events":[{"id":1,"lifetime":1,"action":"attack-animation","records":[attack],"ageMs":0}]}); engine.update()
		check(int(engine.stats.attacks)==1 and int(engine.states[1].visual) in [200,201,202] and engine.states[1].pending==null,"Received attack starts after actual known path exhaustion from gait%s"%code)
		if code in [2,4]:
			var labels: Array=engine.events.map(func(event):return str(event.kind)+":"+str(event.get("animation",-1)))
			check(labels.find("prepare-moving-melee:-1")>=0 and labels.find("prepare-moving-melee:-1")<labels.rfind("play:0"),"Received moving-melee admission precedes no-path restore for gait%s"%code)
	var cleared := {"replicated":{"animation":1.0,"field700":0.0,"field8D6":0.0,"facingTarget":2130706432.0,"path":[]},"playerState":{"actionQueue":[]}}
	configure()
	engine.base_frame(1,1,1.0,false,true,cleared)
	check(int(engine.states[1].base)==0 and int(engine.states[1].visual)==0 and int(engine.stats.attacks)==0,"A fresh controlled actor with the retained ready code and explicit cleared combat joins in ordinary idle")
	var neutral_facing:=cleared.duplicate(true)
	neutral_facing.replicated.facingTarget=2.0
	configure()
	engine.actors[1].facingTarget=2
	engine.base_frame(1,1,1.0,false,true,neutral_facing)
	check(int(engine.states[1].base)==0 and int(engine.states[1].visual)==0 and engine.actors.has(2) and int(engine.actors[1].facingTarget)==2,"Neutral combat mode restores idle while a live facing lock remains")
	for retained in [{"field700":1.0},{"field700":true},{"field700":null},{"field8D6":null},{"field8D6":2.0,"facingTarget":2.0},{"field8D6":3.0},{"field8D6":14.0},{"path":[Vector3.ZERO]}]:
		var active:=cleared.duplicate(true)
		active.replicated.merge(retained,true)
		configure()
		engine.base_frame(1,1,1.0,false,true,active)
		check(int(engine.states[1].visual)==1,"Ready stays eligible when authority reports or does not rule out an active state %s"%str(retained))
	var local_action:=cleared.duplicate(true)
	local_action.playerState.actionQueue=[{"type":3}]
	configure()
	engine.base_frame(1,1,1.0,false,true,local_action)
	check(int(engine.states[1].visual)==1,"An authoritative queued attack retains the ready base")
	for path_state in [null,true]:
		configure()
		engine.base_frame(1,1,1.0,path_state,true,cleared)
		check(int(engine.states[1].visual)==1,"An active or unknown presentation path cannot infer idle")
	configure()
	engine.base_frame(1,1,1.0,false,true)
	check(int(engine.states[1].visual)==1,"A noncontrolled actor retains its received ready animation")
	configure()
	engine.insert(1,{"animation":200,"duration":250,"speed":1.0,"record":null,"delay":0})
	engine.base_frame(1,1,1.0,false,true,cleared)
	check(int(engine.states[1].base)==1 and not engine.states[1].queue.entries.is_empty(),"Local queued attack presentation retains its base and animation cue")
	engine.update()
	check(int(engine.states[1].visual)==200,"Queued attack animation plays despite the cleared base snapshot")
	configure(); engine.base_frame(1,4); motion(true); engine.update()
	check(int(engine.states[1].visual)==4,"A known remaining path retains its locomotion visual")
	motion(false); motion(null); engine.update(); check(int(engine.states[1].visual)==4,"Unavailable path context retires prior false without stopping a gait")
	motion(false); motion({"unknown":true}); engine.update(); check(int(engine.states[1].visual)==4,"Malformed context cannot become an inferred no-path state")
	motion(false); engine.update(); check(int(engine.states[1].visual)==0,"Known exhausted path explicitly restores the retained loop")
	var before: int=rigs.played.size()
	for index in 4: engine.base_frame(1,4); motion(false); engine.update()
	check(rigs.played.size()==before,"Repeated unchanged empty-path gait observations do not replay gait/rest each frame")
	configure(); motion(false); var replacement: Array=actors.duplicate(true); replacement[0].lifetime=9; engine.receive({"kind":"combat-actors","actors":replacement}); engine.base_frame(1,4); engine.update()
	check(int(engine.states[1].visual)==4,"A recreated actor cannot retain the previous lifetime's no-path context")
	engine.reset(); check(not rigs.animation_event.is_connected(engine.model_event),"Motion-boundary retirement releases model event owner")
	for row in [[{},null],[{"path":[],"cursor":0,"active":false},false],[{"path":[Vector3.ZERO],"cursor":0,"active":true},true],[{"path":[Vector3.ZERO],"cursor":1,"active":true},false],[{"path":[],"cursor":0,"active":0},null],[{"path":[],"cursor":-1,"active":true},null],[{"path":[],"cursor":0.5,"active":true},null],[{"path":"unknown","cursor":0,"active":false},null]]:
		var actual: Variant=MotionData.remaining_path(row[0]); var expected: Variant=row[1]
		check(typeof(actual)==typeof(expected) and actual==expected,"Known/unknown native remaining-path contract %s"%str(row[0]))
	for pivot in pivots.values(): pivot.free()
	rigs.free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gaitOriginalCases":gait.cases.size(),"modelUpdateOriginalCases":boundary.cases.size(),"scope":"Actual scheduler vs36 original gait/base and18 no-path model-update cases; authored attack/path-availability/lifetime boundaries, captured playback. No LiveWorld hook, game server or pixel acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
