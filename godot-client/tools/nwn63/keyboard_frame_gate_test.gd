extends SceneTree

const Keyboard=preload("res://systems/native_keyboard.gd")
var failures: Array[String]=[]
var checks:=0

func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)

func _initialize()->void:call_deferred("run")

func os_key(target: Node,code: int,pressed: bool,echo: bool=false)->void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	event.echo=echo
	target._input(event)

func run()->void:
	var current: Dictionary={"identity":"area/actor/1","id":7,"state":{"lifetime":1,"orientation":Vector3.RIGHT,"position":Vector3(2,3,0)}}
	var sent: Array=[]
	var calls: Dictionary={"previews":0,"ends":0,"reenter":false}
	var input:=Keyboard.new()
	root.add_child(input)
	input.require_focus=false
	input.context_query=func():return current
	input.transmit=func(value):
		sent.append(value.duplicate(true))
		if calls.reenter and value.get("operation")=="drive":
			calls.reenter=false
			input.key(KEY_Q,true,false,true)
	input.predict=func(_id,_flags,_heading):
		calls.previews+=1
		return {}
	input.end_prediction=func(_id):calls.ends+=1
	input.set_frame_input_admission(true)
	check(input.can_process() and not input.is_processing(),"owner can flush admission although keyboard _process is disabled")
	var generation:=input._stop_generation
	input.flush_input_frame(1,1000)
	check(input.stats.admission_flushes==0 and input._stop_generation==generation,"idle frame skips keyboard scheduling and stop reset")
	os_key(input,KEY_W,true)
	os_key(input,KEY_W,true,true)
	check(input.held.has(KEY_W) and input._admitted_events==2,"repeated OS key-down admitted")
	check(sent.is_empty() and calls.previews==0,"OS events do not solve before frame boundary")
	input.flush_input_frame(2,1000)
	check(sent.size()==1 and sent[0].operation=="drive" and calls.previews==1,"two key events produce one drive and preview")
	check(input.stats.admission_flush_events==2 and input.stats.admission_coalesced_events==1,"duplicate event is counted as coalesced")
	input.flush_input_frame(2,1000)
	check(sent.size()==1 and calls.previews==1 and input.stats.admission_frame_guard==1,"second owner call in frame cannot solve again")
	input.flush_input_frame(3,1250)
	check(sent.size()==2 and not sent[-1].transmit and calls.previews==2,"held preview tick remains scheduled at 250 ms")
	input.flush_input_frame(4,1500)
	check(sent.size()==3 and sent[-1].transmit and calls.previews==3,"held wire refresh remains scheduled at 500 ms")
	os_key(input,KEY_W,false)
	check(not input.held.has(KEY_W),"OS release admitted")
	check(sent[-1].operation=="stop" and calls.previews==3,"release cancels immediately without a solve")
	generation=input._stop_generation
	input.flush_input_frame(5,1501)
	check(input._stop_generation==generation and calls.previews==3,"post-release idle frame does not reset cancellation token")
	# A synchronous transmit callback can admit a second direction. Its event
	# belongs to the next frame, even when the first frame clears input_pending.
	calls.reenter=true
	input.key(KEY_W,true,false,true)
	input.flush_input_frame(6,2000)
	check(calls.previews==4 and input._admitted_events==1 and input.input_pending,"reentrant event remains queued")
	input.flush_input_frame(7,2001)
	check(calls.previews==5 and input.last_flags==7,"reentrant direction solves once at next boundary")
	var count:=sent.size()
	current.identity="area/actor/2"
	input.flush_input_frame(8,2002)
	check(sent.size()==count and input.held.is_empty() and not input.moving,"owner change cancels without commanding replacement actor")
	var admission_stats: Dictionary=input.stats.duplicate(true)
	input.free()
	var immediate:=Keyboard.new()
	root.add_child(immediate)
	immediate.require_focus=false
	immediate.context_query=func():return current
	immediate.transmit=func(_value):pass
	var immediate_calls: Dictionary={"previews":0}
	immediate.predict=func(_id,_flags,_heading):
		immediate_calls.previews+=1
		return {}
	immediate.set_process(false)
	os_key(immediate,KEY_W,true)
	os_key(immediate,KEY_W,true,true)
	check(immediate_calls.previews==2,"legacy immediate route solves both repeated key events")
	immediate.free()
	print(JSON.stringify({"checks":checks,"failures":failures,"admission":admission_stats,"scope":"Headless keyboard event/held-tick/cancel/reentrant correctness; no FPS or live-server claim"}))
	quit(0 if failures.is_empty() else 1)
