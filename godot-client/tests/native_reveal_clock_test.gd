extends SceneTree
const Services=preload("res://systems/native_data/client_clock_services.gd")
const World=preload("res://systems/native_data/world_timer.gd")
var checks:=0
var failures: Array=[]
class Samples extends RefCounted:
	var values: Array=[100,1000,8000,12100,18000,34000,50000,61000,72000,91000,101000,111000,121000,131000,141000]
	var reads:=0
	func read() -> Dictionary:
		var value: int=values[mini(reads,values.size()-1)];reads+=1;return World.words_from_int(value)
class Lower extends RefCounted:
	func object(_id: int):return null
	func as_object(value):return value
	func scene(_object):return null
	func scene_virtual(_scene,_offset):pass
	func reset(_object,_day,_time):return {"ready":true,"baseNoop":true}
	func text(_id):pass
	func audio(_enabled):pass
	func ports() -> Dictionary:return {"object":object,"asObject":as_object,"scene":scene,"sceneVirtual":scene_virtual,"resetObjectTimes":reset,"pauseText":text,"audio":audio}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func event(serial: int,payload: Dictionary) -> Dictionary:return {"kind":"native-clock-protocol","version":1,"connection":7,"serial":serial,"history":{"complete":true,"reason":null},"event":payload}
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var service:=Services.new();var samples:=Samples.new();var lower:=Lower.new()
	check(not service.reveal_timing(1).get("ready",false),"missing process never invents zero snapshot")
	check(service.construct_process(samples.read,{"processConstructionKnown":true,"gui":{"known":true,"value":null},"profileMode":0,"controlledId":7},lower.ports()).ready,"existing three native timers constructed")
	check(samples.reads==3 and not service.reveal_timing(1).get("ready",false),"construction has no reveal-frame authority")
	check(service.attach_connection(7).ready and service.begin_frame(1).ready,"existing frame prefix snapshots timers")
	check(not service.reveal_timing(1).get("ready",false),"missing accepted begin does not certify pause history")
	check(service.receive_clock(event(1,{"type":"begin","lifecycleBound":true})).ready,"ordered native clock begin admitted")
	var reads:=samples.reads;var before: Dictionary=service.state_view()
	var timing:=service.reveal_timing(1)
	check(timing.ready and timing.available and timing.source=="native-primary-world-snapshot-v1" and timing.snapshot_us==12000,"exact primary-world difference selected")
	check(timing.snapshot_words=={"hi":0,"lo":12000} and samples.reads==reads,"getter reads existing snapshot without source sample")
	check(timing.now_day==service._timers.world.time().day and timing.now_ms==service._timers.world.time().time,"optional calendar uses same existing world owner")
	check(service.state_view()==before,"read-only getter does not taint/reset/advance owner")
	check(not service.reveal_timing(0).get("ready",false) and not service.reveal_timing(2).get("ready",false) and not service.reveal_timing(true).get("ready",false),"stale/future/malformed frame rejected")
	check(service.finish_ai(1,{"module":false,"area":false,"completePass":true}).ready,"existing AI finish boundary completes")
	check(service.gui_delta(1).seconds==World.f32(0.026) and service.reveal_timing(1).snapshot_us==12000,"GUI T2 26ms never substitutes world12ms")
	timing.snapshot_words.lo=0
	check(service.reveal_timing(1).snapshot_words.lo==12000,"detached difference cannot mutate native counter")
	check(service.begin_frame(2).ready,"next ordinary prefix")
	var paused:=service.receive_clock(event(2,{"type":"module-pause-state","mask":1,"value":1,"exclusionIds":[]}))
	check(paused.ready,"native pause uses existing owner transition")
	check(service.finish_ai(2,{"module":false,"area":false,"completePass":true}).ready,"pause frame completes")
	check(service.begin_frame(3).ready,"paused frame prefix skips world snapshot")
	var paused_world: Dictionary=service._timers.world.snapshot_difference();reads=samples.reads
	var paused_timing:=service.reveal_timing(3)
	check(paused_timing.ready and paused_timing.snapshot_words==paused_world.microseconds and samples.reads==reads,"paused snapshot retains native value rather than invented zero/resample")
	var clock=service._timers.world;var stored: Dictionary=clock.state_view()
	clock.counter={"hi":0,"lo":5};clock.previous_counter={"hi":0xffffffff,"lo":0xfffffff0}
	check(service.reveal_timing(3).snapshot_us==21,"unsigned64 subtraction wrap reaches exact signed carrier")
	clock.counter={"hi":0x7fffffff,"lo":0xffffffff};clock.previous_counter={"hi":0,"lo":0}
	check(service.reveal_timing(3).snapshot_us==9223372036854775807,"signed63 maximum retained without double rounding")
	clock.counter={"hi":0x80000000,"lo":0};clock.previous_counter={"hi":0,"lo":0}
	check(not service.reveal_timing(3).get("ready",false),"unsigned64 high bit explicit unavailable in current fade carrier")
	clock.restore_state(stored)
	service.receive_clock(event(4,{"type":"module-info","minutesPerHour":5}))
	check(not service.reveal_timing(3).get("ready",false),"protocol gap taints snapshot history without invented fallback")
	service.release_process({"processExiting":true})
	check(not service.reveal_timing(3).get("ready",false),"process release retires getter")
	var report:={"checks":checks,"failures":failures,"scope":"Existing native primary-world snapshot getter, no native extension/sample provider/GPU/server/OS time; deterministic scalar/limb/pause/history and mutation gates"}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
