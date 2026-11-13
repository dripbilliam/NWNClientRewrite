extends SceneTree
const Probe=preload("res://tests/native_live_script_floating_probe.gd")
const Entry=preload("res://tests/native_script_floating_world.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	check(Entry!=null,"Exact current full native entry compiles without session/world instantiation")
	var probe:=Probe.new();root.add_child(probe)
	var raw:="<c"+String.chr(255)+String.chr(255)+String.chr(1)+">Native observed text</c>"
	probe.scope={"connection":3,"generation":2,"areaId":7};probe.source={"id":42,"objectType":5,"areaId":7,"nativeLifetime":1,"knownLifetime":2}
	# Authored values test validation/serialization only. They are never live
	# world-anchor evidence and no Owner, View, camera, pose or clock is injected.
	var event:={"witness":[42,1,2],"scope":[3,2,7]};var paint:={"witness":[42,1,2],"scope":[3,2,7],"point":Vector2(140,220),"alpha":0.75}
	var sample: Dictionary=probe.paint_values(paint,event,Vector2(140,220),0.75,true,true)
	check(sample.get("ready",false) and sample.point==[140.0,220.0] and sample.alpha==sample.viewAlpha,"Scoped finite exact cached point/alpha are projected to detached numeric arrays")
	check(not probe.paint_values(paint,event,Vector2(141,220),0.75,true,true).ready and not probe.paint_values(paint,event,Vector2(140,220),0.74,true,true).ready,"Offset view position or alpha cannot pass cached-paint equality")
	check(not probe.paint_values(paint,event,Vector2(140,220),0.75,false,true).ready and not probe.paint_values(paint,event,Vector2(140,220),0.75,true,false).ready,"Prepared layout alone cannot replace has_frame and visible-in-tree publication")
	var wrong: Dictionary=paint.duplicate(true);wrong.witness[2]=3
	check(not probe.paint_values(wrong,event,Vector2(140,220),0.75,true,true).ready,"A reused target known lifetime rejects paint evidence")
	wrong=paint.duplicate(true);wrong.scope[0]=4
	check(not probe.paint_values(wrong,event,Vector2(140,220),0.75,true,true).ready and not probe.paint_values(paint,{"witness":[42,2,2],"scope":[3,2,7]},Vector2(140,220),0.75,true,true).ready,"Old connection or event/native lifetime cannot borrow another paint witness")
	wrong=paint.duplicate(true);wrong.point=Vector2(INF,0)
	check(not probe.paint_values(wrong,event,Vector2(140,220),0.75,true,true).ready and not probe.paint_values(paint,event,Vector2(NAN,220),0.75,true,true).ready,"Nonfinite cached or Canvas points reject before JSON")
	wrong=paint.duplicate(true);wrong.alpha=NAN
	check(not probe.paint_values(wrong,event,Vector2(140,220),0.75,true,true).ready and not probe.paint_values(paint,event,Vector2(140,220),INF,true,true).ready,"Nonfinite cached or View alpha rejects before JSON")
	sample.erase("ready");sample.frame=100;sample.remaining=1.2
	var second: Dictionary=sample.duplicate(true);second.frame=101;second.remaining=1.18
	probe.anchor_bindings={"ownerToGameplay":true,"gameplayToNativeRoot":true,"ownerMethod":"script_floating_anchor","rootMethod":"native_script_floating_anchor","rootScript":"res://tests/native_script_floating_world.gd","worldInstance":10,"cameraInstance":11}
	probe.observed_log({"type":94,"flags":128,"chat_mask":128,"text":"Native observed text","raw":raw,"rich":{"text":"Native observed text","spans":[{"text":"Native observed text","color":"#ffff01"}]}})
	probe.observed[1]={"serial":1,"type":94,"duration":1.5,"activeSeen":true,"body":raw,"plain":"Native observed text","viewScript":"res://systems/native_script_floating_view.gd","paintSamples":[sample,second,second.duplicate(true)],"lastPaintState":"published"}
	var payload: Dictionary=probe.completion_payload();var encoded:=JSON.stringify(payload)
	check(encoded.find(String.chr(1))<0 and not payload.logs[0].has("raw") and not payload.logs[0].has("rich"),"Actual Godot command JSON contains no literal native RGB control and no rich/raw string graph")
	check(PackedByteArray(payload.logs[0].rawUtf8).get_string_from_utf8()==raw and PackedByteArray(payload.events[0].bodyUtf8).get_string_from_utf8()==raw,"Explicit UTF8 integer arrays retain native control-bearing observations without loss")
	check(payload.scope==probe.scope and payload.source==probe.source and payload.events[0].duration==1.5 and payload.logs[0].chat_mask==128,"Detached scalar identity/timing/log flags remain exact across the completion schema")
	var roundtrip: Variant=JSON.parse_string(encoded)
	check(roundtrip is Dictionary and roundtrip.events[0].paintSamples.size()==2 and roundtrip.events[0].paintSamples[0].point==roundtrip.events[0].paintSamples[0].viewPosition and roundtrip.events[0].paintSamples[0].visibleInTree and roundtrip.anchorBindings.rootMethod=="native_script_floating_anchor","Actual Godot JSON roundtrip preserves bounded paint arrays/visibility and callable-chain observations")
	payload.scope.connection=99;payload.logs[0].rawUtf8[0]=0;payload.events[0].paintSamples[0].witness[0]=999;payload.anchorBindings.ownerToGameplay=false
	check(probe.scope.connection==3 and probe.logs[0].raw==raw and probe.observed[1].paintSamples[0].witness[0]==42 and probe.anchor_bindings.ownerToGameplay,"Building/mutating the observation DTO cannot mutate received rows, paint witnesses or identity")
	var safe: Dictionary=probe.completion_payload();probe.queue_free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"completion":safe,"scope":"Actual final native graph/probe compile and Godot JSON completion DTO, parsed by Node runner; authored paint values exercise schema rejection/serialization only, never live paint authority. Control-bearing strings use explicit UTF8 integer arrays. No session/world/server/key/GPU instance."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
