extends SceneTree
# Actual three _process methods; no resources, visual Controls or runtime root.
const GuiClock=preload("res://systems/native_data/gui_clock_delta.gd")
const Ordinary=preload("res://systems/native_overhead_speech.gd")
const Registry=preload("res://systems/native_overhead_popup_registry.gd")
const ScriptFloating=preload("res://systems/native_script_floating.gd")
const CaptionState=preload("res://systems/native_data/popup_caption_state.gd")
class ClockReader extends RefCounted:
	var sample: Variant={"ready":true,"seconds":0.25}
	var calls:=0
	func read()->Variant:
		calls+=1
		return sample
var checks:=0
var failures: Array=[]
var context_reads:=0
var context:={"connection":3,"generation":7,"areaId":91}
var rows:={42:{"id":42,"objectType":5,"areaId":91,"nativeLifetime":8,"clientKnownLifetime":13}}
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func inert_context()->Dictionary:return {}
func registry_context()->Dictionary:
	context_reads+=1
	return context
func row(id: int)->Dictionary:return rows.get(id,{})
func _initialize()->void:run.call_deferred()
func helper_cases()->void:
	var reader:=ClockReader.new()
	reader.sample={"ready":true,"seconds":0.25,"extra":{"mutable":[1]}}
	var result: Dictionary=GuiClock.read(reader.read,99.0)
	check(result=={"ready":true,"seconds":0.25},"Helper projects ready native scalar instead of renderer99 and drops extras")
	reader.sample.seconds=77.0;reader.sample.extra.mutable[0]=2
	check(result.seconds==0.25 and not result.has("extra"),"Helper result is detached from later source mutation")
	var invalid: Array=[null,1,true,[],{}, {"ready":false,"seconds":0.25},{"ready":true},{"ready":true,"seconds":"0.25"},{"ready":true,"seconds":true},{"ready":true,"seconds":NAN},{"ready":true,"seconds":INF},{"ready":true,"seconds":-0.25}]
	for index in invalid.size():
		reader.sample=invalid[index]
		check(GuiClock.read(reader.read,99.0)=={"ready":false},"Malformed/nonfinite/negative native sample stays unavailable "+str(index))
	reader.sample={"ready":true,"seconds":0}
	check(GuiClock.read(reader.read,99.0)=={"ready":true,"seconds":0.0},"Native ready zero is distinct from unavailable")
	check(GuiClock.read(Callable(),0.125)=={"ready":true,"seconds":0.125},"Unset reader retains explicit legacy renderer delta")
	check(GuiClock.read(Callable(),NAN)=={"ready":false},"Unset reader still rejects nonfinite renderer delta")
func closure_cleanup(node,label: String)->void:
	var reader:=ClockReader.new();var reference: WeakRef=weakref(reader)
	node.gui_delta_reader=reader.read
	check(node.gui_delta_reader.is_valid() and node.gui_delta_reader.get_object()==reader,label+" callable is valid while its provider is externally owned")
	node.close()
	check(node.gui_delta_reader.is_null(),label+" close explicitly unsets native GUI reader")
	check(is_instance_valid(reader) and reference.get_ref()==reader,label+" external provider remains valid after owner close")
	reader=null
	check(reference.get_ref()==null,label+" dropping the external strong reference releases its provider")
	check(not node.is_processing(),label+" close leaves processing disabled")
	node.free()
func ordinary_cases()->void:
	var node=Ordinary.new();node.context_reader=inert_context
	node.before_scope[42]={"message":{"channel":1},"elapsed":0.0}
	var reader:=ClockReader.new();node.gui_delta_reader=reader.read
	node._process(99.0)
	check(node.before_scope.has(42) and node.before_scope[42].elapsed==0.25,"Actual ordinary _process consumes native0.25, not renderer99 or expiry")
	check(node.before_scope[42].elapsedFrame==Engine.get_process_frames() and reader.calls==1,"Ordinary native elapsed marks the actual GUI frame once")
	reader.sample={"ready":false};node.before_scope[42].erase("elapsedFrame")
	node._process(99.0)
	check(node.before_scope[42].elapsed==0.25,"Unavailable native ordinary reader does not advance pending elapsed")
	check(not node.before_scope[42].has("elapsedFrame"),"Unavailable ordinary delta is not fabricated zero with frame side effects")
	reader.sample={"ready":true,"seconds":0.0};node._process(99.0)
	check(node.before_scope[42].elapsed==0.25 and node.before_scope[42].elapsedFrame==Engine.get_process_frames(),"Ready zero executes the ordinary frame path without time advance")
	node.gui_delta_reader=Callable();node._process(0.125)
	check(node.before_scope[42].elapsed==0.375,"Unconfigured actual ordinary _process retains legacy delta")
	closure_cleanup(node,"Ordinary")
func registry_cases()->void:
	var node=Registry.new();node.configure(registry_context,row)
	var record: Dictionary=node.caption_record(42,rows[42])
	check(not record.is_empty(),"Actual Registry creates a current exact-life caption")
	check(CaptionState.write(record,"x",{"text":"x","spans":[]},"speech","",1.0,1,true,1).ready,"Actual CaptionState supplies the registered timer")
	node.track_clock(42)
	var reader:=ClockReader.new();node.gui_delta_reader=reader.read
	context_reads=0;node._process(99.0)
	check(record.remaining==0.75 and record.guiRegistered,"Actual Registry _process advances sole caption by native0.25")
	check(context_reads==2,"Registry runs actual advance_clocks and frame_layout independently")
	reader.sample={"ready":false};context_reads=0;node._process(99.0)
	check(record.remaining==0.75 and record.guiRegistered,"Unavailable Registry input cannot use renderer99 or expire caption")
	check(context_reads==1,"Registry still executes actual frame_layout when native time is unavailable")
	reader.sample={"ready":true,"seconds":0.25};record.remaining=1.0;record.accountedGuiFrame=Engine.get_process_frames()
	node._process(99.0)
	check(record.remaining==1.0 and record.accountedGuiFrame==-1,"Actual Registry preserves one-clock same-frame handoff skip")
	await process_frame
	node._process(99.0)
	check(record.remaining==0.75,"Next actual GUI frame consumes native delta after the one handoff skip")
	reader.sample={"ready":true,"seconds":0.0};record.remaining=0.0;record.guiRegistered=true;node.track_clock(42)
	node._process(99.0)
	check(record.remaining==0.0 and record.guiRegistered,"Ready zero preserves original strict-negative ordinary expiry boundary")
	node.gui_delta_reader=Callable();record.remaining=1.0;node._process(0.125)
	check(record.remaining==0.875,"Unconfigured actual Registry _process retains legacy delta")
	closure_cleanup(node,"Registry")
func script_cases()->void:
	var node=ScriptFloating.new();node.context_reader=inert_context
	# Already activated orphan GUI: timers continue without a current raw target,
	# model, anchor, font or view. This is separate from FIFO activation admission.
	node.entries[1]={"status":"active","remaining":1.5,"bodyReady":true,"showChat":false,"orphan":true,"target":42,"event":{"scope":[3,7,91],"witness":[42,8,13]}}
	node.active_entries[1]=true
	var reader:=ClockReader.new();node.gui_delta_reader=reader.read
	node._process(99.0)
	check(node.nominal_usec==250000.0 and node.nominal_ms==250,"Actual Script _process GUI accumulator uses native0.25, not renderer99")
	check(node.entries.has(1) and node.entries[1].remaining==1.25,"Actual active Script GUI lifetime consumes native input without visuals")
	reader.sample={"ready":false};node._process(99.0)
	check(node.nominal_usec==250000.0 and node.entries[1].remaining==1.25,"Unavailable Script GUI input advances neither accumulator nor active widget")
	reader.sample={"ready":true,"seconds":0.0};node._process(99.0)
	check(node.nominal_ms==250 and node.entries[1].remaining==1.25,"Ready zero is admitted without a renderer fallback")
	node.gui_delta_reader=Callable();node._process(0.125)
	check(node.nominal_ms==375 and node.entries[1].remaining==1.125,"Unconfigured actual Script _process retains legacy delta")
	closure_cleanup(node,"ScriptFloating")
func run()->void:
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var parsed: Resource=ResourceLoader.load("res://native_session_world.gd")
	check(parsed is Script,"Actual current SessionWorld/LiveWorld source closure parses without root instantiation")
	parsed=null
	helper_cases();ordinary_cases();await registry_cases();script_cases()
	await process_frame;await process_frame
	var file:=FileAccess.open(report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"sourceParseOnly":true,"actualOwnerMethods":3,"rootInstances":0,"visualNodes":0,"assetsRequested":0,"scope":"Actual three native speech _process methods with authored GUI reader scalars, inert contexts, real CaptionState and orphan active GUI lifetime; current Root source parse only. No pixels, provider/lower-owner parity or gameplay acceptance."},"\t"));file.close()
	quit(0 if failures.is_empty() else 1)
