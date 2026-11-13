extends SceneTree
const Combat=preload("res://systems/combat_animation.gd")
var checks:=0
var failures: Array=[]
var observations: Array=[]
var receive_us: Array=[]
var fake_ms:=1000
class Playback extends Node:
	signal animation_event(id: int,name: String,serial: int)
	var entities: Dictionary={}
	var played: Array=[]
	func clip_length(_id: int,_animation: int,_side: int=-1) -> float: return 1.0
	func clip_name(_id: int,animation: int,_side: int=-1) -> String: return str(animation)
	func set_playback(id: int,animation: int,speed: float,loop: bool,restart: bool,side: int) -> void: played.append({"id":id,"animation":animation,"speed":speed,"loop":loop,"restart":restart,"side":side})
	func set_animation(id: int,animation: int,speed: float) -> void: set_playback(id,animation,speed,true,false,0)
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var parts:=arg.trim_prefix("--").split("=",true,1)
		if parts.size()==2: args[parts[0]]=parts[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-combat-base-handoff-original-v1.json"))
	var rigs:=Playback.new(); root.add_child(rigs)
	var pivot:=Node3D.new(); root.add_child(pivot)
	rigs.entities[1]={"root":pivot,"context":{"fieldDE":1,"fieldDD":1,"fieldDF":2,"fieldE0":0},"body_type":1,"loop_map":{}}
	var actor:={"id":1,"lifetime":1,"objectType":5,"animationSpeed":1.0}
	var engine:=Combat.new(); engine.clock_ms=func():return fake_ms
	for row in oracle.cases:
		engine.configure(rigs,{1:pivot}); engine.receive({"kind":"combat-actors","actors":[actor]})
		engine.base_frame(1,int(row.case.current)); var state: Dictionary=engine.states[1]
		state.base=0; state.current={"remaining":int(row.case.remaining)}; rigs.played.clear()
		var animation:=int(row.case.desired); var cast:=17+(animation-250) if animation!=261 else 61
		engine.base_frame(1,cast)
		check(int(state.visual)==int(row.result.current) and int(state.base)==int(row.result.base),"Original cast base handoff %s"%JSON.stringify(row.case))
		var count: int=row.result.calls.filter(func(call):return call.kind=="play").size()
		check(rigs.played.size()==count,"Original immediate/deferred playback count %s"%JSON.stringify(row.case))
		observations.append({"case":row.case,"expected":row.result,"actual":{"visual":state.visual,"base":state.base,"plays":rigs.played.size()}})
	for gait in [2,3,4,78,79,84,85,86,87]:
		for cast in [17,18,19,20,61]:
			engine.configure(rigs,{1:pivot}); engine.receive({"kind":"combat-actors","actors":[actor]}); engine.base_frame(1,gait)
			var began:=Time.get_ticks_usec()
			engine.receive({"kind":"combat-events","events":[{"id":1,"lifetime":1,"action":"cast-animation","animation":cast,"record":{"type":4},"ageMs":0}]}); engine.update()
			receive_us.append(Time.get_ticks_usec()-began)
			check(int(engine.states[1].visual)==cast and int(engine.states[1].current.get("remaining",-1))==500,"Received cast starts from gait%s cast%s without later idle"%[gait,cast])
	engine.reset(); check(not rigs.animation_event.is_connected(engine.model_event),"Closing handoff owner releases real model callback")
	pivot.free(); rigs.free(); await process_frame
	receive_us.sort()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"originalCases":oracle.cases.size(),"receiveCpuUs":{"count":receive_us.size(),"median":receive_us[int(receive_us.size()/2)],"p95":receive_us[int(ceil(receive_us.size()*0.95))-1],"max":receive_us[-1]},"scope":"Actual combat scheduler against120 original SetBaseAnimation cases and45 authored received gait-to-cast events. Captured model playback, no game server/render/pixel acceptance."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
