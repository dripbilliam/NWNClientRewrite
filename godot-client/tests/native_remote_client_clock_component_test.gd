extends SceneTree
const NativeWorldTimer=preload("res://systems/native_data/world_timer.gd")
const Pause=preload("res://systems/native_data/client_pause_state.gd")
class Microseconds extends RefCounted:
	var value:=0
	var reads:=0
	func read()->int:reads+=1;return value
class WordMicroseconds extends RefCounted:
	var value: Variant=null
	var reads:=0
	func read()->Variant:reads+=1;return value
class Trace extends RefCounted:
	var c: Dictionary={}
	var calls: Array=[]
	var objects: Dictionary={}
	var clocks: Dictionary={}
	var owned: Dictionary={}
	var allocations:=0
	var unconsumed: Array=[]
	var index:=0
	var component
	const FIELDS=["mode","fixedRate","counter","previousCounter","paused","pausedDay","pausedTime","dayOffset","timeOffset","minutesPerHour","dayLength","secondsPerDay"]
	func _init(input: Dictionary)->void:
		c=input.duplicate(true)
		for id in [11,22,4026531841]:objects[id]={"id":id,"day":77,"time":88}
		var names:=["world","one","two"]
		for at in 3:
			var counter:=NativeWorldTimer.add_counter(NativeWorldTimer.words_from_int(0x123456789abcdef0),at*1000)
			clocks[names[at]]={"name":names[at],"mode":at%2,"fixedRate":30+at,"counter":counter,"previousCounter":NativeWorldTimer.add_counter(counter,-100),"paused":at%2,"pausedDay":100+at,"pausedTime":200+at,"dayOffset":300+at,"timeOffset":400+at,"minutesPerHour":5+at,"dayLength":7200000+at,"secondsPerDay":7200+at}
		component=Pause.new()
		component.configure({"flags":c.get("flags",0),"exclusions":{"known":true,"ids":null if c.get("nullList",false) else c.get("old",[11])},"gui":{"known":true,"value":null if c.get("gui")==false else {}},"profileMode":c.get("profileMode",0),"controlledId":c.get("controlledId",11)},{"world":clocks.world,"timer1":clocks.one,"timer2":clocks.two},callbacks())
	func callbacks()->Dictionary:
		return {"pause":on_pause,"unpause":on_unpause,"snapshot":on_snapshot,"syncPrevious":on_sync,"reset":on_reset,"time":on_time,"object":on_object,"asObject":on_as_object,"scene":on_scene,"sceneVirtual":on_scene_virtual,"resetObjectTimes":on_reset_object,"pauseText":on_pause_text,"audio":on_audio,"disposeIncoming":on_dispose,"guiActive":on_gui_active,"guiBlocked":on_gui_blocked,"guiSetFlags":on_gui_set,"guiClearFlags":on_gui_clear}
	func on_pause(t)->void:calls.append(["pause",t.name]);t.paused=1
	func on_unpause(t)->void:calls.append(["unpause",t.name]);t.paused=0
	func on_snapshot(t)->void:calls.append(["snapshot",t.name]);t.previousCounter=t.counter.duplicate();t.counter=NativeWorldTimer.add_counter(t.counter,100)
	func on_sync(t)->void:calls.append(["sync",t.name]);t.previousCounter=t.counter.duplicate()
	func on_reset(t,from)->void:
		calls.append(["reset",t.name,from.name])
		for key in FIELDS:t[key]=from[key].duplicate(true) if from[key] is Dictionary else from[key]
	func on_time(t)->Dictionary:
		calls.append(["time",t.name])
		var pair: Array={"world":[10,100],"one":[20,200],"two":[30,300]}[t.name]
		return {"day":pair[0],"time":pair[1]}
	func on_object(id: int)->Variant:calls.append(["object",id]);return objects.get(id)
	func on_as_object(object)->Variant:calls.append(["asObject",object.id]);return null if c.get("asObject")==false else object
	func on_scene(object)->Variant:calls.append(["scene",object.id]);return null if c.get("scene")==false else {}
	func on_scene_virtual(_scene,offset: int)->void:calls.append(["sceneVirtual",offset])
	func on_reset_object(object,day: int,time: int)->void:calls.append(["resetObject",object.id,day,time]);Pause.write_creature_stamp(object,day,time)
	func on_pause_text(id: int)->void:calls.append(["pauseText",id])
	func on_audio(value: bool)->void:
		if c.get("audio")!=false:calls.append(["audio",value])
	func on_dispose(incoming)->void:calls.append(["dispose"]);incoming.ids=[];incoming.disposed=true
	func on_gui_active(_gui)->int:calls.append(["guiActive"]);return int(c.get("guiActive",1))
	func on_gui_blocked(_gui,value: int)->void:calls.append(["guiBlocked",value])
	func on_gui_set(_gui,value: int)->void:calls.append(["guiSet",value])
	func on_gui_clear(_gui,value: int)->void:calls.append(["guiClear",value])
	func timer_views()->Dictionary:
		var result: Dictionary={}
		for key in clocks:
			var row: Dictionary={}
			for field in FIELDS:row[field]=clocks[key][field].duplicate(true) if clocks[key][field] is Dictionary else clocks[key][field]
			result[key]=row
		return result
	func stamps()->Dictionary:
		var result: Dictionary={}
		for id in objects:result[str(id)]=[objects[id].day,objects[id].time]
		return result
	func receiver()->Dictionary:
		return {"allocateIncoming":allocate,"byte":read_byte,"bool":read_bool,"word":read_word,"objectId":read_object_id,"overflow":read_overflow,"apply":reader_apply,"gui":reader_gui,"refreshGui":refresh_gui,"unconsumedIncoming":on_unconsumed}
	func allocate(value)->void:allocations+=1;owned=value
	func read_byte(bits: int,mode: int)->int:calls.append(["byte",bits,mode]);return int(c.get("mask",0))
	func read_bool()->int:calls.append(["bool"]);return int(c.get("value",0))
	func read_word(bits: int)->int:calls.append(["word",bits]);return c.get("incoming",[]).size()
	func read_object_id()->int:
		calls.append(["objectId"]);var id:=int(c.incoming[index]);index+=1;return id
	func read_overflow()->int:calls.append(["overflow"]);return int(c.get("overflow",0))
	func reader_apply(mask: int,value: int,incoming)->void:calls.append(["apply",mask,NativeWorldTimer.u32(value),incoming.ids.duplicate()])
	func reader_gui()->Variant:calls.append(["gui"]);return null if c.get("gui")==false else {"fieldA8":c.get("guiA8",1)}
	func refresh_gui()->void:calls.append(["refreshGui"])
	func on_unconsumed(value,reason: String)->void:unconsumed.append({"same":is_same(value,owned),"reason":reason})
var checks:=0
var failures: Array=[]
var fixture: Dictionary={}
var float_readback: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
static func same(a: Variant,b: Variant)->bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for at in a.size():
			if not same(a[at],b[at]):return false
		return true
	if (a is int or a is float) and (b is int or b is float):return a==b
	return typeof(a)==typeof(b) and a==b
func equal(a: Variant,b: Variant,label: String)->void:check(same(a,b),label)
func original_pause()->void:
	var modes: Dictionary={}
	for at in fixture.pause.size():
		var row: Dictionary=fixture.pause[at];var c: Dictionary=row["case"];var trace:=Trace.new(c);var component=trace.component
		modes[c.mode]=int(modes.get(c.mode,0))+1
		var incoming: Variant=null if c.get("nullIncoming",false) else Pause.owned_incoming(c.get("incoming",[]))
		var result: Dictionary={}
		match str(c.mode):
			"set":result=component.apply(c.mask,c.value,incoming)
			"clear":result=component.clear_exclusions()
			"timer":result=component.active_timer(c.id)
			"excluded":result=component.excluded(c.id)
			"reset":trace.on_reset_object(trace.objects[11],int(c.day),int(c.time));result={"ready":true}
			"receive":result=Pause.receive_message(trace.receiver())
		check(result.get("ready",false),"Original pause case is defined "+str(at))
		equal(trace.calls,row.calls,"Exact original callback order "+str(at))
		equal(component.flags,row.flags,"Exact original flag byte "+str(at))
		equal(component.exclusions,row.exclusions,"Exact original null/list state "+str(at))
		equal(trace.timer_views(),row.timers,"Exact original timer fields/snapshot/reset copy "+str(at))
		equal(trace.stamps(),row.stamps,"Exact original object reset stamps "+str(at))
		if c.mode=="timer":equal(str(result.get("timer",{}).get("name","")),row.result,"Original selected timer "+str(at))
		if c.mode=="excluded":equal(result.get("value"),row.result,"Original null/list membership "+str(at))
		if c.mode=="receive":
			equal(result.get("result"),row.result,"Original receiver result "+str(at))
			check(trace.allocations==1 and not trace.owned.disposed and not row.disposed,"Original receiver allocation remains explicitly unconsumed "+str(at))
			check(trace.owned.capacity==(32 if c.incoming.size()>16 else (16 if not c.incoming.is_empty() else 0)),"Original scalar receiver capacity growth "+str(at))
			check(trace.unconsumed.size()==1 and trace.unconsumed[0].same and trace.unconsumed[0].reason==("overflow" if c.overflow else "unchanged-state"),"Explicit native receiver unconsumed reason "+str(at))
		else:equal(bool(incoming.get("disposed",false)) if incoming is Dictionary else false,row.disposed,"Original incoming consumption "+str(at))
		component.close()
	equal(modes,{"set":295,"clear":12,"timer":32,"excluded":32,"receive":384,"reset":4},"All759 original pause cases exercised, including independently stubbed receiver apply boundary")
func original_creature()->void:
	for at in fixture.creature.size():
		var row: Dictionary=fixture.creature[at];var c: Dictionary=row["case"]
		var result:=NativeWorldTimer.subtract_world_times({"day":c.now[0],"time":c.now[1]},{"day":c.previous[0],"time":c.previous[1]},1000)
		check(result.ready and NativeWorldTimer.u32(result.status)==int(row.status),"Original creature subtract status "+str(at))
		if int(row.status)==0:check(result.outputsDefined and result.day==row.outputDay and result.time==row.outputTime and result.time==row.elapsed,"Original defined creature day/remainder "+str(at))
		else:check(not result.outputsDefined and not result.has("day") and not result.has("time") and row.outputDay==c.seedDay and row.outputTime==c.seedTime,"Original backwards outputs remain explicitly unwritten, never copied seeded scratch "+str(at))
func original_seconds()->void:
	for at in fixture.seconds.size():
		var row: Dictionary=fixture.seconds[at];var value: float=NAN if row.value is String and row.value=="NaN" else float(row.value)
		var result:=NativeWorldTimer.seconds_to_world_delta(value,row.length)
		check(result.ready and result.day==row.result.day and result.time==row.result.time,"Original FLOAT-seconds repeated subtraction/cast "+str(at))
func timer_reference()->void:
	for c in fixture.timerCases:
		var source:=Microseconds.new();source.value=str(c.epoch).to_int() if c.constructorProviderRepresentable else 0
		var timer:=NativeWorldTimer.new();check(timer.initialize(source.read).ready,"Explicit known ctor initializes independent timer "+str(c.label))
		if not c.constructorProviderRepresentable:check(timer.restore_state(c.initial).ready,"Explicit u64 oracle state is not a fabricated signed provider sample")
		equal(timer.state_view(),c.initial,"Constructor/explicit fullu64 state matches reference "+str(c.label));equal(timer.time(),{"ready":true,"day":c.time.day,"time":c.time.time},"Initial native offsets normalize "+str(c.label))
		for at in c.steps.size():
			var step: Dictionary=c.steps[at];var action: Dictionary=step.action;var result: Dictionary={"ready":true}
			match str(action.kind):
				"provider":source.value=str(action.value).to_int()
				"snapshot":result=timer.snapshot()
				"setTime":result=timer.set_time(action.day,action.time,action.get("snapshot",0))
				"minutes":result=timer.set_minutes_per_hour(action.value)
				"pause":result=timer.pause()
				"unpause":result=timer.unpause()
				"mode":timer.mode=action.value;timer.fixed_rate=action.fixedRate
				"calendar":result=timer.set_calendar(action.args[0],action.args[1],action.args[2],action.args[3],action.args[4],action.args[5],action.args[6],action.args[7] if action.args.size()>7 else 0)
				"readCalendar":result=timer.calendar(action.value)
				"readParts":result=timer.time_parts(action.value)
			check(result.ready,"Known timer operation succeeds "+str(c.label)+"/"+str(at))
			equal(timer.state_view(),step.state,"Every defined timer field matches reference "+str(c.label)+"/"+str(at))
			equal(timer.time(),{"ready":true,"day":step.time.day,"time":step.time.time},"Exact unsigned counter/offset world time "+str(c.label)+"/"+str(at))
			equal(timer.snapshot_difference(),{"ready":true,"microseconds":step.difference},"Native snapshot getter retains full modularu64 "+str(c.label)+"/"+str(at))
			var actual_seconds: float=NativeWorldTimer.frame_seconds_from_difference(step.difference).seconds
			var actual_bytes:=PackedByteArray();actual_bytes.resize(4);actual_bytes.encode_float(0,actual_seconds)
			var parsed_bytes:=PackedByteArray();parsed_bytes.resize(4);parsed_bytes.encode_float(0,step.frameSeconds)
			check(actual_bytes.decode_u32(0)==int(step.frameSecondsBits),"Only native frame caller narrows to signedDWORD/FLOAT "+str(c.label)+"/"+str(at))
			if actual_seconds!=step.frameSeconds:
				var actual_double:=PackedByteArray();actual_double.resize(8);actual_double.encode_double(0,actual_seconds)
				var parsed_double:=PackedByteArray();parsed_double.resize(8);parsed_double.encode_double(0,step.frameSeconds)
				float_readback.append({"case":c.label,"step":at,"actual":actual_seconds,"parsedExpectedDouble":step.frameSeconds,"actualBits":actual_bytes.decode_u32(0),"expectedFloatBits":step.frameSecondsBits,"parsedExpectedFloatBits":parsed_bytes.decode_u32(0),"actualDoubleBytes":Array(actual_double),"parsedExpectedDoubleBytes":Array(parsed_double)})
			if step.result is Dictionary:
				var expected: Dictionary=step.result.duplicate();expected.ready=true;equal(result,expected,"Native calendar reference result "+str(c.label)+"/"+str(at))
		timer.close()
	for at in fixture.arithmetic.size():
		var row: Dictionary=fixture.arithmetic[at];var added:=NativeWorldTimer.add_world_times(row.a,row.b,row.length);var subtracted:=NativeWorldTimer.subtract_world_times(row.a,row.b,row.length)
		check(added.ready and added.status==row.add.status and added.outputsDefined==(int(row.add.status)==0),"DWORD AddWorldTimes status/output "+str(at))
		if int(row.add.status)==0:check(added.day==row.add.day and added.time==row.add.time,"DWORD wrapped addition and one carry "+str(at))
		check(NativeWorldTimer.compare_world_times(row.a,row.b,row.length).status==row.compare,"Unsigned native CompareWorldTimes "+str(at))
		check(subtracted.ready and subtracted.status==row.subtract.status and subtracted.outputsDefined==(int(row.subtract.status)==0),"Native subtraction chronology/bypass "+str(at))
		if int(row.subtract.status)==0:check(subtracted.day==row.subtract.day and subtracted.time==row.subtract.time,"Unsigned one-borrow subtraction "+str(at))
func boundaries()->void:
	var unknown:=NativeWorldTimer.new();check(not unknown.time().ready and not unknown.snapshot().ready and not unknown.pause().ready,"new() does not infer a remote clock constructor or sample")
	var source:=Microseconds.new();var other_source:=Microseconds.new();other_source.value=9000000
	var a:=NativeWorldTimer.new();var b:=NativeWorldTimer.new();a.initialize(source.read);b.initialize(other_source.read);a.set_time(123,456);a.pause();a.snapshot()
	check(b.reset_from(a).ready and same(b.state_view(),a.state_view()),"Reset copies every defined timer field and pause/counter snapshot")
	other_source.value=9001000;b.snapshot();check(b.counter==NativeWorldTimer.words_from_int(9001000) and source.reads==2,"Reset retains destination's injected host provider")
	a.mode=1;a.fixed_rate=0;var saved:=a.state_view();check(not a.snapshot().ready and same(saved,a.state_view()),"Zero fixed-rate divisor is explicit unavailable and cannot partially mutate snapshots")
	var pause:=Pause.new();pause.configure({},{"world":{}},{})
	check(pause.active_timer(Pause.INVALID).ready and not pause.active_timer(11).ready and not pause.excluded(11).ready,"INVALID bypasses unknown flags/list; unknown list is never native null")
	pause.configure({"flags":2,"exclusions":{"known":true,"ids":null}},{"world":{},"timer1":{},"timer2":{}},{})
	check(pause.excluded(11).value==1 and pause.active_timer(11).slot=="timer2","Known native null list admits IDs under bit2")
	pause.configure({"flags":3,"exclusions":{"known":true,"ids":[]}},{"world":{},"timer1":{},"timer2":{}},{})
	check(pause.excluded(11).value==0 and pause.active_timer(11).slot=="world","Known empty list excludes IDs; bit2 does not fall through to bit1")
	var incoming:=Pause.owned_incoming([11,11]);saved=pause.state_view();check(pause.apply(3,3,incoming).ready and not incoming.disposed and same(saved,pause.state_view()),"Raw bit equality noop bypasses missing callbacks/GUI without consuming incoming")
	check(not pause.apply(2,1,incoming).ready and same(saved,pause.state_view()) and not incoming.disposed,"Unavailable transition providers cause no partial state/list/input mutation")
	var ids: Array=[11,22];var own:=Pause.owned_incoming(ids);ids[0]=99;check(own.ids==[11,22],"Owned incoming state is detached from received caller arrays")
	var trace:=Trace.new({"flags":0,"old":[11]});var appended:=[false]
	var callback=func(object,day,time):
		trace.on_reset_object(object,day,time)
		if not appended[0]:trace.component.exclusions.append(22);appended[0]=true
	trace.component.providers.resetObjectTimes=callback
	check(trace.component.clear_exclusions().ready and trace.calls.has(["resetObject",22,10,100]),"Old-list clearing re-reads live count after callbacks instead of snapshotting membership")
	trace.component.close();check(not trace.component.apply(1,1).ready and trace.component.providers.is_empty(),"Close drops callback/timer references and refuses stale transitions")
	for flags in [0,1,2,3,4,255]:
		var frame:=Trace.new({"flags":flags});var expected: Array=[]
		if (flags&3)==0:expected.append(["snapshot","world"])
		if (flags&2)==0:expected.append(["snapshot","one"])
		expected.append(["snapshot","two"])
		check(frame.component.snapshot_before_receive().ready and same(frame.calls,expected),"Source-proven conditional snapshot prefix before packet dispatch, flags="+str(flags));frame.component.close()
	check(not unknown.has_method("_process") and unknown.get_class()=="RefCounted" and pause.get_class()=="RefCounted","No Node, world store, frame callback or registry scan is introduced")
	unknown.close();a.close();b.close();pause.close()
func full_dword_normalization()->void:
	check(fixture.normalization.iterationBound==65536 and fixture.normalization.maximumIterations<=65536,"Separate full-DWORD literal-loop fixture is explicitly bounded and not a retained native-corpus replacement")
	for row in fixture.normalization.rows:
		var timer:=NativeWorldTimer.new()
		var state:={"ready":true,"mode":0,"fixedRate":null,"counter":{"hi":0,"lo":0},"previousCounter":{"hi":0,"lo":0},"paused":0,"pausedDay":null,"pausedTime":null,"dayOffset":row.day,"timeOffset":row.time,"minutesPerHour":5,"dayLength":row.length,"secondsPerDay":7200}
		check(timer.restore_state(state).ready,"Full-DWORD restored day length is admitted without a bypass clamp: "+str(row.label))
		equal(timer.time(),{"ready":true,"day":row.result.day,"time":row.result.time},"O(1) normalization equals literal native DWORD loops: "+str(row.label))
		if row.label=="reported-FFFFFFFF-two-underflows":check(timer.time().day==8 and timer.time().time==0 and row.result.underflowIterations==2,"Reported L=FFFFFFFF,t=2,day10 normalizes twice to day8/time0")
		timer.close()
func provider_words_cases()->void:
	for value in [0,123456789,9223372036854775807,{"hi":2147483648,"lo":0},{"hi":4294967295,"lo":4294967295},{"hi":4294967295.0,"lo":0.0}]:
		var source:=WordMicroseconds.new();source.value=value
		var expected:=NativeWorldTimer.words_from_int(value) if value is int else NativeWorldTimer.words(value)
		var timer:=NativeWorldTimer.new();check(timer.initialize(source.read).ready,"Known integer/fullu64 provider initializes without signed or FLOAT narrowing")
		equal(timer.counter,expected,"Constructor stores exact provider limbs including highbit")
		equal(timer.previous_counter,expected,"Constructor copies the same exact provider sample into previous counter")
		equal(timer.time(),{"ready":true,"day":fixture.timerCases[0].time.day,"time":fixture.timerCases[0].time.time},"Constructor offsets preserve native initial time for fullu64 provider")
		timer.close()
	var source:=WordMicroseconds.new();source.value={"hi":4294967295,"lo":4294967295,"unrelated":{"mutable":true}}
	var timer:=NativeWorldTimer.new();check(timer.initialize(source.read).ready,"Provider limb projection accepts/copies only known DWORD fields")
	source.value.hi=0;source.value.lo=0;source.value.unrelated.mutable=false
	check(timer.counter=={"hi":4294967295,"lo":4294967295} and timer.previous_counter==timer.counter and timer.counter.size()==2,"Caller mutation and unknown mutable keys never enter retained timer counters")
	check(timer.snapshot().ready and timer.counter=={"hi":0,"lo":0} and timer.previous_counter=={"hi":4294967295,"lo":4294967295},"Fullu64 wrap snapshot stores both samples without signed narrowing")
	equal(timer.snapshot_difference(),{"ready":true,"microseconds":{"hi":0,"lo":1}},"Modularu64 difference across wrap is exact")
	var invalid: Array=[null,-1,1.0,"1",{},{"hi":0},{"hi":-1,"lo":0},{"hi":4294967296,"lo":0},{"hi":0,"lo":0.5},{"hi":NAN,"lo":0},{"ready":false}]
	for value in invalid:
		var before:=timer.state_view();source.value=value
		check(not timer.snapshot().ready and same(before,timer.state_view()),"Unknown/malformed provider snapshot is atomically unavailable")
		var rejected:=WordMicroseconds.new();rejected.value=value
		check(not timer.initialize(rejected.read).ready and same(before,timer.state_view()) and timer.microseconds.get_object()==source,"Invalid reinitialize cannot replace current state/provider")
	timer.close()
func _initialize()->void:run.call_deferred()
func run()->void:
	var report:="";var fixture_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
		if arg.begins_with("--fixture="):fixture_path=arg.trim_prefix("--fixture=")
	if report.is_empty() or fixture_path.is_empty() or FileAccess.file_exists(report):quit(2);return
	fixture=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(fixture.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and fixture.pause.size()==759 and fixture.creature.size()==90 and fixture.seconds.size()==55,"Exact pinned original binary/corpus dimensions")
	original_pause();original_creature();original_seconds();timer_reference();boundaries();full_dword_normalization();provider_words_cases()
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalPauseCases":759,"originalCreatureCases":90,"originalSecondsCases":55,"normalizationCases":fixture.normalization.rows.size(),"normalizationLiteralIterations":fixture.normalization.totalIterations,"normalizationMaxIterations":fixture.normalization.maximumIterations,"floatJsonReadback":float_readback,"scope":"New native Godot RefCounted timer/pause algorithms vs retained unchanged-original corpus and explicit JS arithmetic reference. Separate authored full-DWORD literal-loop normalization cases are not new original execution. Pause callbacks/scalar-reader boundaries are controlled and are not real GUI/audio/object execution. No remote clock initialization, production hooks, packet replay, server/GPU/key/profile/build/user-process or pixels."})+"\n");file.close()
	print("NATIVE_REMOTE_CLIENT_CLOCK_COMPONENT ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)

