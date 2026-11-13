extends SceneTree
const NativeWorldTimer=preload("res://systems/native_data/world_timer.gd")
const PauseState=preload("res://systems/native_data/client_pause_state.gd")
class Samples extends RefCounted:
	var rows: Array=[]
	var last: Dictionary={}
	func read()->Variant:
		var sample: Dictionary=ClassDB.class_call_static("NwnClockSourceCandidate","sample")
		last=sample.duplicate(true)
		var words: Variant=sample.get("microseconds")
		if rows.size()<64:rows.append({"ready":sample.get("ready",false),"phase":sample.get("phase"),"source":sample.get("source"),"branch":sample.get("branch"),"microseconds":words.duplicate(true) if words is Dictionary else null})
		return sample.get("microseconds") if sample.get("ready",false) else null
class Operations extends RefCounted:
	var labels: Dictionary={}
	var sources: Dictionary={}
	var calls: Array=[]
	var errors: Array=[]
	func label(timer)->String:return str(labels[timer.get_instance_id()])
	func accepted(result: Dictionary,where: String)->void:
		if not result.get("ready",false):errors.append({"where":where,"result":result.duplicate(true)})
	func pause(timer)->void:calls.append(["pause",label(timer)]);accepted(timer.pause(),"pause")
	func unpause(timer)->void:calls.append(["unpause",label(timer)]);accepted(timer.unpause(),"unpause")
	func snapshot(timer)->void:
		var key:=label(timer);calls.append(["snapshot",key]);accepted(timer.snapshot(),"snapshot")
		if sources[key].last.get("ready",false) and timer.counter!=NativeWorldTimer.words(sources[key].last.microseconds):errors.append({"where":"snapshot-limb-mismatch","slot":key})
	func sync(timer)->void:calls.append(["sync",label(timer)]);accepted(timer.synchronize_previous(),"sync")
	func reset(timer,from)->void:
		calls.append(["reset",label(timer),label(from)]);accepted(timer.reset_from(from),"reset")
		if timer.microseconds.get_object()!=sources[label(timer)]:errors.append({"where":"reset-replaced-provider","slot":label(timer)})
	func time(timer)->Dictionary:return timer.time()
	func object(_id)->Variant:return null
	func as_object(_object)->Variant:return null
	func scene(_object)->Variant:return null
	func scene_virtual(_scene,_offset)->void:errors.append({"where":"unexpected-scene"})
	func reset_object(_object,_day,_time)->void:errors.append({"where":"unexpected-object"})
	func pause_text(id)->void:calls.append(["pauseText",id])
	func audio(value)->void:calls.append(["audio",value])
	func dispose(incoming)->void:incoming.ids=[];incoming.disposed=true
	func gui_active(_gui)->int:errors.append({"where":"unexpected-GUI"});return 0
	func gui_blocked(_gui,_value)->void:errors.append({"where":"unexpected-GUI"})
	func gui_flags(_gui,_value)->void:errors.append({"where":"unexpected-GUI"})
	func callbacks()->Dictionary:
		return {"pause":pause,"unpause":unpause,"snapshot":snapshot,"syncPrevious":sync,"reset":reset,"time":time,"object":object,"asObject":as_object,"scene":scene,"sceneVirtual":scene_virtual,"resetObjectTimes":reset_object,"pauseText":pause_text,"audio":audio,"disposeIncoming":dispose,"guiActive":gui_active,"guiBlocked":gui_blocked,"guiSetFlags":gui_flags,"guiClearFlags":gui_flags}
var checks:=0
var failures: Array=[]
var clocks: Dictionary={}
var sources: Dictionary={}
var component
var operations:=Operations.new()
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func verify_samples(label: String)->void:
	for key in clocks:
		var timer=clocks[key];var source=sources[key]
		check(timer.counter==NativeWorldTimer.words(source.last.get("microseconds")),"Actual DLL sample enters exact counter limbs: "+label+"/"+key)
		check(timer.microseconds.get_object()==source,"Each timer retains its own injected provider: "+label+"/"+key)
		check(source.rows.size()<=64 and source.rows.all(func(row):return row.ready and row.phase=="direct-real-only" and row.source=="native-direct-real-candidate-v1"),"Every actual sample remains explicitly directReal-only: "+label+"/"+key)
func finish(report: String)->void:
	var rows: Dictionary={}
	for key in sources:rows[key]=sources[key].rows.duplicate(true)
	if is_instance_valid(component):component.close()
	for timer in clocks.values():timer.close()
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":rows,"lowerProviderErrors":operations.errors.duplicate(true),"scope":"Private accepted directReal candidate DLL sample.microseconds -> actual Godot unsigned64 Timer construction/snapshots and Pause pre-receive prefix/ordered nested transition operations. Actual DLL/WinAPI samples; controlled absent world objects/GUI and recorded audio/text callbacks. No original nwmain execution, cached-thread phase, main descriptor install, global runtime activation, server/key/profile/GPU/build/user-process action."})+"\n");file.close()
	print("NATIVE_PRIVATE_CLOCK_TIMER ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
func _initialize()->void:run.call_deferred()
func run()->void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	check(ClassDB.class_exists("NwnClockSourceCandidate"),"Private copied candidate class is registered without a main project descriptor")
	if not ClassDB.class_exists("NwnClockSourceCandidate"):finish(report);return
	for key in ["world","one","two"]:
		var source:=Samples.new();var timer:=NativeWorldTimer.new();sources[key]=source;clocks[key]=timer
		var result:=timer.initialize(source.read)
		check(result.ready,"Actual directReal DLL microsecond words initialize independent timer "+key)
		if not result.ready:finish(report);return
		check(timer.counter==NativeWorldTimer.words(source.last.microseconds) and timer.previous_counter==timer.counter and source.rows.size()==1,"Each constructor stores exactly its one sampled fullu64 value "+key)
		operations.labels[timer.get_instance_id()]=key;operations.sources[key]=source
	verify_samples("constructed")
	component=PauseState.new();check(component.configure({"flags":0,"exclusions":{"known":true,"ids":[]},"gui":{"known":true,"value":null},"profileMode":0,"controlledId":PauseState.INVALID},{"world":clocks.world,"timer1":clocks.one,"timer2":clocks.two},operations.callbacks()).ready,"Explicit private component state binds all3 actual timers; no remote initialization is inferred")
	operations.calls.clear();check(component.snapshot_before_receive().ready and operations.calls==[["snapshot","world"],["snapshot","one"],["snapshot","two"]],"Unpaused prefix samples actualT0/T1/T2 in source order")
	verify_samples("unpaused-prefix")
	var before: Dictionary=clocks.world.time();operations.calls.clear()
	check(component.apply(1,1).ready and operations.calls==[["pause","world"],["snapshot","world"],["snapshot","world"],["audio",true]],"Mask1 ON preserves exact native pause/double-snapshot/audio order with real Timers")
	check(clocks.world.time()==before and clocks.world.paused==1,"World paused time survives actual provider snapshots")
	var frozen_counter: Dictionary=clocks.world.counter.duplicate();operations.calls.clear()
	check(component.snapshot_before_receive().ready and operations.calls==[["snapshot","one"],["snapshot","two"]] and clocks.world.counter==frozen_counter,"Mask1 prefix skipsT0 while actualT1/T2 continue")
	verify_samples("mask1-prefix")
	var one_before: Dictionary=clocks.one.time();operations.calls.clear()
	check(component.apply(2,1).ready and operations.calls==[["pause","world"],["snapshot","world"],["snapshot","world"],["pause","one"],["snapshot","one"],["snapshot","one"],["pauseText",205],["audio",true]],"Nested mask2 ON retains exact real timer callback order")
	check(clocks.world.time()==before and clocks.one.time()==one_before and clocks.one.paused==1,"Both paused stored times survive new directReal snapshots")
	var world_counter: Dictionary=clocks.world.counter.duplicate();var one_counter: Dictionary=clocks.one.counter.duplicate();operations.calls.clear()
	check(component.snapshot_before_receive().ready and operations.calls==[["snapshot","two"]] and clocks.world.counter==world_counter and clocks.one.counter==one_counter,"Both bits set prefix samples onlyT2")
	verify_samples("both-bits-prefix")
	operations.calls.clear()
	check(component.apply(2,0).ready and operations.calls==[["pause","two"],["reset","two","one"],["snapshot","two"],["snapshot","one"],["sync","two"],["sync","one"],["unpause","one"],["unpause","two"],["pauseText",206]],"Mask2 OFF keeps native reset/snapshot/sync/unpause ordering while mask1 remains")
	check(clocks.world.paused==1 and clocks.world.time()==before and clocks.one.paused==0 and clocks.two.paused==0,"Clearing onlymask2 leavesT0 paused while auxiliary clocks resume")
	check(clocks.one.snapshot_difference().microseconds=={"hi":0,"lo":0} and clocks.two.snapshot_difference().microseconds=={"hi":0,"lo":0},"SyncPrevious produces exact zero modularu64 difference without resampling")
	verify_samples("mask2-cleared")
	operations.calls.clear()
	check(component.apply(1,0).ready and operations.calls==[["pause","one"],["pause","two"],["reset","one","world"],["reset","two","world"],["snapshot","world"],["snapshot","one"],["snapshot","two"],["sync","two"],["sync","one"],["sync","world"],["unpause","world"],["unpause","one"],["unpause","two"],["audio",false]],"Mask1 OFF composes exact native all-timer reset/snapshot/resume order")
	check(clocks.world.time()==before and clocks.one.time()==before and clocks.two.time()==before,"All clocks resume the preserved native stored world pair at their own sampled counters")
	verify_samples("all-resumed")
	operations.calls.clear();check(component.snapshot_before_receive().ready and operations.calls==[["snapshot","world"],["snapshot","one"],["snapshot","two"]],"Resumed prefix returns to source-ordered3clock sampling")
	verify_samples("final-prefix")
	check(operations.errors.is_empty(),"Actual timer operations allready; no world/GUI/scene was fabricated and destination providers survived reset")
	finish(report)

