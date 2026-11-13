extends Node
# Opt-in observation of the real native receive/queue/view/log owners. Stimulus
# uses ordinary native chat; no decoded event, actor, clock or server reply is
# injected by this probe. Final floating_owner schema is checked before authority runs.
var client
var ui
var floating_owner
var scope: Dictionary={}
var source: Dictionary={}
var checks:=0
var failures: Array=[]
var observed: Dictionary={}
var logs: Array=[]
var baseline_legacy: Array=[]
var baseline_feedback: Dictionary={}
var baseline_feedback_rows:=0
var legacy_duplicate:=false
var anchor_bindings: Dictionary={}
func check(value: bool,label: String)->bool:
	checks+=1
	if not value:failures.append(label)
	return value
func current()->bool:
	if not is_instance_valid(client) or client.closing or int(client.session_connection)!=int(scope.get("connection",-1)) or int(client.epoch)!=int(scope.get("generation",-1)) or not is_instance_valid(ui):return false
	var row: Dictionary=ui.text.objects.get(int(source.get("id",-1)),{})
	return int(ui.area_id)==int(scope.areaId) and int(row.get("nativeLifetime",-1))==int(source.get("nativeLifetime",-2)) and int(row.get("clientKnownLifetime",-1))==int(source.get("knownLifetime",-2)) and not row.get("replicationRemoved",false)
func observed_log(row: Dictionary)->void:
	if logs.size()<8:logs.append(row.duplicate(true))
func actual_anchor_bindings()->Dictionary:
	var first: Variant=floating_owner.get("anchor_reader");var second: Variant=ui.get("script_floating_anchor_query")
	var owner_link: bool=first is Callable and first.is_valid() and first.get_object()==ui and str(first.get_method())=="script_floating_anchor"
	var root_link: bool=second is Callable and second.is_valid() and second.get_object()==client and str(second.get_method())=="native_script_floating_anchor"
	return {"ownerToGameplay":owner_link,"gameplayToNativeRoot":root_link,"ownerMethod":str(first.get_method()) if first is Callable else "","rootMethod":str(second.get_method()) if second is Callable else "","rootScript":str(client.get_script().resource_path),"worldInstance":client.world.get_instance_id(),"cameraInstance":client.camera.get_instance_id() if is_instance_valid(client.camera) else 0}
func paint_values(paint: Variant,event: Dictionary,position_value: Variant,alpha_value: Variant,has_frame: bool,visible_in_tree: bool)->Dictionary:
	# Pure validation of the values read from the real Owner/View below. The
	# boundary fixture authors inputs only to test rejection/JSON detachment.
	var expected_witness: Array=[int(source.id),int(source.nativeLifetime),int(source.knownLifetime)]
	var expected_scope: Array=[int(scope.connection),int(scope.generation),int(scope.areaId)]
	if not paint is Dictionary or paint.get("witness")!=expected_witness or paint.get("scope")!=expected_scope or event.get("witness")!=expected_witness or event.get("scope")!=expected_scope:return {"ready":false,"reason":"scope-or-lifetime"}
	var point: Variant=paint.get("point");var alpha: Variant=paint.get("alpha")
	if not point is Vector2 or not position_value is Vector2 or not point.is_finite() or not position_value.is_finite():return {"ready":false,"reason":"nonfinite-point"}
	if not (alpha is float or alpha is int) or not (alpha_value is float or alpha_value is int) or not is_finite(float(alpha)) or not is_finite(float(alpha_value)) or alpha<0 or alpha>1:return {"ready":false,"reason":"nonfinite-alpha"}
	if not has_frame or not visible_in_tree:return {"ready":false,"reason":"view-not-published"}
	if point!=position_value or float(alpha)!=float(alpha_value):return {"ready":false,"reason":"view-cache-mismatch"}
	return {"ready":true,"point":[point.x,point.y],"viewPosition":[position_value.x,position_value.y],"alpha":float(alpha),"viewAlpha":float(alpha_value),"hasFrame":has_frame,"visibleInTree":visible_in_tree,"witness":expected_witness,"scope":expected_scope}
func observe_entries(previous: Array)->void:
	var entries: Variant=floating_owner.get("entries");var views: Variant=floating_owner.get("views")
	if not entries is Dictionary or not views is Dictionary:return
	for serial in entries:
		if previous.has(serial) or observed.size()>=8 and not observed.has(serial):continue
		var entry: Dictionary=entries[serial];var model: Dictionary=entry.get("model",{})
		if not observed.has(serial):observed[serial]={"serial":serial,"type":int(entry.get("type",-1)),"duration":entry.get("duration"),"activeSeen":false,"body":entry.get("body",model.get("text","")),"plain":str(model.get("program",{}).get("plain","")),"paintSamples":[],"lastPaintState":"waiting-view"}
		var view: Variant=views.get(serial)
		if is_instance_valid(view) and view is Control and view.get("layout_ready")==true:
			observed[serial].activeSeen=true;observed[serial].viewScript=str(view.get_script().resource_path);observed[serial].duration=entry.get("duration");observed[serial].body=entry.get("body",model.get("text",""));observed[serial].plain=str(model.get("program",{}).get("plain",""))
			if entry.get("status")=="active" and str(view.get_script().resource_path)=="res://systems/native_script_floating_view.gd":
				var sample:=paint_values(entry.get("lastPaint"),entry.get("event",{}),view.position,view.get("base_alpha"),view.get("has_frame")==true,view.is_visible_in_tree())
				observed[serial].lastPaintState=sample.get("reason","published")
				var samples: Array=observed[serial].paintSamples;var frame:=Engine.get_process_frames();var remaining:=float(entry.get("remaining",-1))
				if sample.get("ready",false) and samples.size()<2 and is_finite(remaining) and remaining>0 and (samples.is_empty() or int(samples[-1].frame)!=frame and float(samples[-1].remaining)!=remaining):
					sample.erase("ready");sample.frame=frame;sample.remaining=remaining;samples.append(sample)
func legacy_script_duplicate()->bool:
	var expected: Array=["NATIVE_SCRIPT94_NO_ECHO","NATIVE_SCRIPT94_ECHO"]
	for entry in observed.values():
		if not str(entry.plain).is_empty() and not expected.has(str(entry.plain)):expected.append(str(entry.plain))
	for row in ui.floating_rows:
		var label: Variant=row.get("label")
		if row.get("id")==source.id and is_instance_valid(label) and not baseline_legacy.has(label.get_instance_id()) and expected.has(str(label.get_parsed_text())):return true
	var counts: Dictionary={}
	for row in ui.feedback.floating:
		if row.get("objectId")!=source.id:continue
		var plain:=str(row.get("rich",{}).get("text",""))
		if expected.has(plain):counts[plain]=int(counts.get(plain,0))+1
	for plain in counts:
		if int(counts[plain])>int(baseline_feedback.get(plain,0)):return true
	return false
func completion_payload()->Dictionary:
	# Native color controls include U+0001. Godot JSON can leave those literal;
	# the command boundary therefore carries detached explicit UTF8 byte arrays.
	var safe_events: Array=[];var safe_logs: Array=[]
	for entry in observed.values():
		safe_events.append({"serial":entry.serial,"type":entry.type,"duration":entry.duration,"activeSeen":entry.activeSeen,"viewScript":str(entry.get("viewScript","")),"paintSamples":entry.get("paintSamples",[]).slice(0,2).duplicate(true),"lastPaintState":str(entry.get("lastPaintState","waiting-view")),"bodyUtf8":Array(str(entry.get("body","")).to_utf8_buffer()),"plainUtf8":Array(str(entry.get("plain","")).to_utf8_buffer())})
	for row in logs:
		safe_logs.append({"type":row.get("type"),"flags":row.get("flags"),"chat_mask":row.get("chat_mask"),"textUtf8":Array(str(row.get("text","")).to_utf8_buffer()),"rawUtf8":Array(str(row.get("raw","")).to_utf8_buffer())})
	return {"kind":"script-floating-finished","scope":scope.duplicate(true),"source":source.duplicate(true),"success":failures.is_empty(),"checks":checks,"failures":failures.duplicate(),"events":safe_events,"logs":safe_logs,"anchorBindings":anchor_bindings.duplicate(true),"projectionEvidence":"headless-projection-and-Canvas-visibility; no rendered pixels or movement acceptance","baselineLegacyRows":baseline_legacy.size(),"baselineFeedbackRows":baseline_feedback_rows,"legacyScriptDuplicate":legacy_duplicate,"textObservationEncoding":"utf8-integer-arrays"}
func finish()->void:
	if is_instance_valid(floating_owner) and floating_owner.has_signal("log_message") and floating_owner.log_message.is_connected(observed_log):floating_owner.log_message.disconnect(observed_log)
	if is_instance_valid(client) and not client.closing:client.send(completion_payload())
	queue_free()
func run(value)->void:
	client=value;ui=client.gameplay_ui
	if not is_instance_valid(client.world):client.fail("Owned ScriptFloating probe has no accepted world");queue_free();return
	scope={"connection":int(client.session_connection),"generation":int(client.epoch),"areaId":int(client.world.area_id)}
	if not check(is_instance_valid(ui) and is_instance_valid(ui.get("script_floating")),"Actual native Gameplay owns dedicated ScriptFloating presentation"):finish();return
	floating_owner=ui.get("script_floating")
	var row: Dictionary=ui.text.objects.get(int(ui.controlled_id),{})
	source={"id":row.get("id"),"objectType":row.get("objectType"),"areaId":row.get("areaId"),"nativeLifetime":row.get("nativeLifetime"),"knownLifetime":row.get("clientKnownLifetime")}
	var witnessed:=source.values().all(func(scalar):return (scalar is int or scalar is float) and is_finite(float(scalar)) and float(scalar)==float(int(scalar)))
	if not check(witnessed and source.objectType==5 and source.areaId==scope.areaId and source.nativeLifetime>0 and source.knownLifetime>0 and current(),"Actual disclosed controlled creature/current connection owns the stimulus"):finish();return
	if not check(str(floating_owner.get_script().resource_path)=="res://systems/native_script_floating.gd" and floating_owner.has_signal("log_message"),"Real source ScriptFloating owner and immediate log signal are used"):finish();return
	anchor_bindings=actual_anchor_bindings()
	if not check(anchor_bindings.ownerToGameplay and anchor_bindings.gameplayToNativeRoot and anchor_bindings.rootScript=="res://tests/native_script_floating_world.gd" and anchor_bindings.cameraInstance>0,"Actual Owner anchor callable binds Gameplay wrapper then current native world/camera entry; no injected anchor"):finish();return
	var before: Array=floating_owner.entries.keys();floating_owner.log_message.connect(observed_log)
	var chat_before: int=ui.chat.sequence
	baseline_feedback_rows=ui.feedback.floating.size()
	for row_value in ui.floating_rows:
		var label: Variant=row_value.get("label")
		if is_instance_valid(label):baseline_legacy.append(label.get_instance_id())
	for row_value in ui.feedback.floating:
		if row_value.get("objectId")==source.id:
			var plain:=str(row_value.get("rich",{}).get("text",""));baseline_feedback[plain]=int(baseline_feedback.get(plain,0))+1
	ui.chat.submit("-native-script-floating")
	var deadline:=Time.get_ticks_msec()+15000
	while Time.get_ticks_msec()<deadline and current():
		observe_entries(before)
		legacy_duplicate=legacy_duplicate or legacy_script_duplicate()
		if observed.size()==4 and observed.values().all(func(entry):return entry.activeSeen) and floating_owner.entries.keys().all(func(serial):return before.has(serial)) and logs.size()==2:break
		await client.process_frame
	if not check(current(),"Disclosure and connection remain current through all original received widgets"):finish();return
	check(observed.size()==4,"Four independently received93/94 events reach the real per-object queue")
	check(observed.values().all(func(entry):return entry.activeSeen and entry.duration==1.5),"Every queued event activates its own original1.5second native widget")
	check(observed.values().all(func(entry):return str(entry.get("viewScript","")).begins_with("res://systems/native_script_floating")),"Dedicated native source widgets prepare/layout each queued event in the headless test")
	check(observed.size()==4 and observed.values().all(func(entry):return entry.paintSamples.size()==2 and entry.paintSamples[0].frame!=entry.paintSamples[1].frame and entry.paintSamples[0].remaining>entry.paintSamples[1].remaining),"All four actual writer events publish two distinct real-frame scoped camera paints to visible native Canvas controls")
	check(actual_anchor_bindings()==anchor_bindings,"Production Gameplay/current native world/camera callable owners remain unchanged through paint observation")
	check(observed.values().filter(func(entry):return entry.type==93).size()==2 and observed.values().filter(func(entry):return entry.type==94).size()==2,"Observed owner entries preserve both original feedback types")
	check(logs.size()==2,"Only exact showChat1 emits an immediate native log row")
	check(logs.any(func(entry):return str(entry.get("text",""))=="NATIVE_SCRIPT94_ECHO") and not logs.any(func(entry):return str(entry.get("text",""))=="NATIVE_SCRIPT94_NO_ECHO"),"Literal94 echo0/1 remain independent from visible widgets")
	check(ui.chat.sequence>=chat_before+2,"Actual native chat receives the dedicated echo signal")
	check(not legacy_duplicate,"No additional legacy4.5second widget contains the received93/94 markers; unrelated combat floaties remain allowed")
	check(floating_owner.entries.keys().all(func(serial):return before.has(serial)),"All four independent native lifetimes complete without a stale queued event")
	finish()
