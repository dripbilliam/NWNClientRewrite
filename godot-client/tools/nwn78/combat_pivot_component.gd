extends SceneTree
# Private bounded test of the duplicated combat pivot refresh. The candidate
# suppresses only the second refresh after base_frame updated every actor.
const CombatEngine=preload("res://systems/combat_animation.gd")
const CandidateEngine=preload("res://tools/nwn78/combat_animation_pivot_candidate.gd")
class Rigs extends Node:
	signal animation_event(id: int,name: String,serial: int)
	var entities: Dictionary={}
var output:=""
var checks:=0
var failures: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func leg(count: int, candidate: bool) -> Dictionary:
	var host:=Node3D.new();root.add_child(host)
	var rigs:=Rigs.new();host.add_child(rigs)
	var pivots: Dictionary={}
	for i in count:
		var pivot:=Node3D.new();host.add_child(pivot)
		pivot.position=Vector3(i%11,float(i%7),i/11)
		pivot.rotation.y=float(i%19)*0.13
		pivots[i]=pivot
		rigs.entities[i]={"root":pivot,"context":{"seed":1},"loop_map":{}}
	var engine=(CandidateEngine if candidate else CombatEngine).new();engine.clock_ms=func():return 1000
	engine.configure(rigs,pivots)
	for i in count:engine.actors[i]={"lifetime":1,"objectType":5,"animationSpeed":1.0}
	for frame in 200:
		for i in count:engine.base_frame(i,9)
		engine.update(0.016,1000+frame*16)
	var samples: Array=[]
	for frame in 160:
		var before:=Time.get_ticks_usec()
		for i in count:
			if frame%3==0:pivots[i].rotation.y+=0.001
			engine.base_frame(i,9)
		if frame%7==0:
			pivots[0].position.x+=0.01
			pivots[0].rotation.y+=0.01
			engine.actors[1].position=Vector3(-77,-88,-99)
			engine.actors[1].orientation=Vector3(1,1,1)
		engine.update(0.016,4200+frame*16)
		samples.append(Time.get_ticks_usec()-before)
	samples.sort()
	var signature: Array=[]
	for i in count:
		signature.append([engine.actors[i].position,engine.actors[i].orientation,engine.states[i].observed,engine.states[i].visual])
	var result:={"count":count,"candidate":candidate,"median_frame_us":samples[80],"p95_frame_us":samples[152],"digest":var_to_bytes(signature).hex_encode(),"states":engine.states.size(),"actors":engine.actors.size()}
	engine.reset();host.free()
	return result
func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var cases: Array=[]
	for count in [32,128]:
		var legs: Array=[]
		for candidate in [false,true,true,false]:
			legs.append(leg(count,candidate))
			await process_frame
		for item in legs:
			check(item.states==count and item.actors==count,"all combat actor states retained")
			check(item.digest==legs[0].digest,"final actor pivot and animation state identical")
		cases.append({"count":count,"legs":legs})
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":cases,"scope":"Current pinned combat_animation.gd actual SceneTree; isolated second pivot refresh suppression; no original assets or FPS"},"\t"))
	file.close();quit(0 if failures.is_empty() else 1)
