extends SceneTree
const Runtime=preload("res://systems/native_client_clock_runtime.gd")
const Source=preload("res://systems/native_data/native_clock_source.gd")
const WorldClock=preload("res://systems/native_data/world_timer.gd")
const SpeechAnchor=preload("res://systems/native_data/overhead_speech_anchor.gd")
const Scope=preload("res://systems/native_data/overhead_speech_scope.gd")
const INVALID:=0x7f000000
class DeltaTarget extends Node:
	var gui_delta_reader:=Callable()
class TextRows extends RefCounted:
	var objects: Dictionary={}
class UiHolder extends Control:
	var text:=TextRows.new()
	var area_id:=INVALID
	var overhead:=DeltaTarget.new()
	var script_floating:=DeltaTarget.new()
	var overhead_popup_registry:=DeltaTarget.new()
	var script_floating_object_delta_query:=Callable()
	func _init()->void:
		add_child(overhead);add_child(script_floating);add_child(overhead_popup_registry)
	func release_readers()->void:
		overhead.gui_delta_reader=Callable();script_floating.gui_delta_reader=Callable();overhead_popup_registry.gui_delta_reader=Callable();script_floating_object_delta_query=Callable()
class ClientHolder extends RefCounted:
	var args: Dictionary={"native-overhead-clocks":"true"}
	var report: Dictionary={}
	var gameplay_ui: UiHolder
	var epoch:=0
	var accepted_connection: int=-1
	func native_text_connection()->Variant:return accepted_connection if accepted_connection>=0 else null
var checks:=0
var failures: Array=[]
var batch_results: Array=[]
var cold_snapshots:=0
var report_path:=""
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
static func body(source: String,name: String)->String:
	var at:=source.find("func "+name+"(")
	if at<0:return ""
	var end:=source.find("\nfunc ",at+1)
	return source.substr(at,end-at if end>=0 else -1)
func hot_source_guards()->void:
	var source:=FileAccess.get_file_as_string("res://systems/native_client_clock_runtime.gd")
	for method in ["prefix","receive","post_receive","bind_text_consumers","gui_delta","object_delta","set_scope"]:
		var code:=body(source,method)
		check(not code.is_empty() and not code.contains("state_view("),"hot-method-no-full-state-copy-"+method)
	check(body(source,"set_scope").contains("if next==current_scope:return") and body(source,"set_scope").contains("area_transfer_references"),"thin-enumeration-only-on-scope-change")
	check(not source.contains("Time.get_ticks"),"runtime-does-not-substitute-process-relative-ticks")
func disabled_paths()->void:
	check(not ClassDB.class_exists(Source.NATIVE_CLASS) and not GDExtensionManager.is_extension_loaded(Source.DESCRIPTOR),"clock-extension-not-auto-loaded")
	var client:=ClientHolder.new();client.args={}
	var runtime:=Runtime.new();runtime.configure(client)
	check(not runtime.enabled and not runtime.ready and runtime.services==null,"runtime-default-disabled-no-service")
	runtime.close();runtime=null;client=null
	client=ClientHolder.new();client.args={"native-overhead-clocks":"true","offline-replay":"true"}
	runtime=Runtime.new();runtime.configure(client)
	check(not runtime.enabled and not runtime.ready and runtime.services==null,"offline-replay-cannot-activate-real-clock")
	runtime.close();runtime=null;client=null
	check(not ClassDB.class_exists(Source.NATIVE_CLASS),"disabled-paths-never-load-library")
func publish(ui: UiHolder,anchor: Dictionary)->void:
	ui.text.objects[int(anchor.row.id)]=anchor.row.duplicate(true)
static func query_inputs(anchor: Dictionary)->Dictionary:
	var received: Dictionary=anchor.context
	var context:=Scope.context(received.get("connection"),received.get("generation"),received.get("areaId"))
	var where: Array=[]
	if context.ready:where=[context.connection,context.generation,context.areaId]
	return {"identity":SpeechAnchor.witness(anchor.row),"where":where}
func current_query(runtime,anchor: Variant)->Variant:
	if not anchor is Dictionary:return null
	var projected:=query_inputs(anchor)
	return runtime.object_delta(int(anchor.row.id),projected.identity,projected.where)
func bound_readers(ui: UiHolder,runtime)->void:
	for target in [ui.overhead,ui.script_floating,ui.overhead_popup_registry]:
		check(target.gui_delta_reader.is_valid() and target.gui_delta_reader.get_object()==runtime and target.gui_delta_reader.get_method()==&"gui_delta","actual-runtime-gui-callable-bound")
	check(ui.script_floating_object_delta_query.is_valid() and ui.script_floating_object_delta_query.get_object()==runtime and ui.script_floating_object_delta_query.get_method()==&"object_delta","actual-runtime-object-callable-bound")
func _initialize()->void:run.call_deferred()
func run()->void:
	var fixture_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
		elif arg.begins_with("--fixture="):fixture_path=arg.trim_prefix("--fixture=")
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(fixture is Dictionary and fixture.get("source")=="native-clock-runtime-fixture-v1","actual-pipeline-fixture-readable")
	if not fixture is Dictionary:finish({});return
	check(fixture.checks.batchCount==17 and fixture.checks.frameCount==15 and fixture.provenance.actualSessionWorldBridge and fixture.provenance.actualRawCombatAndDisclosureOwners and fixture.provenance.actualNativePauseWriterDecoder,"fixture-pipeline-authority-and-counts")
	check(fixture.provenance.authoredServerDTOs and not fixture.provenance.originalServer and not fixture.provenance.network and not fixture.provenance.rendererPreparation,"authored-fixture-not-original-server-or-renderer-evidence")
	check(fixture.provenance.sourcePinsBefore==fixture.provenance.sourcePinsAfter and fixture.checks.sourcePinsUnchanged,"node-pipeline-source-pins-stable")
	hot_source_guards();disabled_paths()
	var ui:=UiHolder.new();root.add_child(ui)
	var client:=ClientHolder.new();client.gameplay_ui=ui
	var runtime:=Runtime.new();runtime.configure(client)
	check(runtime.enabled and runtime.ready and runtime.source.library_ready,"actual-runtime-configures-reviewed-private-dll")
	check(GDExtensionManager.is_extension_loaded(Source.DESCRIPTOR) and ClassDB.class_exists(Source.NATIVE_CLASS) and FileAccess.get_sha256(Source.LIBRARY)==Source.LIBRARY_SHA256,"actual-reviewed-extension-loaded-explicitly")
	if not runtime.ready:
		ui.release_readers();runtime.close();ui.free();finish({"ready":false});return
	check(runtime.source.samples==3,"one-process-three-absolute-constructor-samples")
	var initial_services=runtime.services
	var captured: Dictionary={};var retained_anchor: Dictionary={};var previous_frame: int=-1
	var old_area_scope: Array=[];var frame_count:=0
	for batch in fixture.batches:
		await process_frame
		var frame: int=Engine.get_process_frames();frame_count+=1
		check(previous_frame<0 or frame==previous_frame+1,"one-actual-engine-frame-per-batch-"+batch.label);previous_frame=frame
		var samples_before: int=runtime.source.samples
		runtime.prefix(frame)
		check(runtime.source.samples==samples_before+3,"one-three-timer-prefix-"+batch.label)
		if batch.expected.get("runtimeCleanupBefore",false):
			var same_samples: int=runtime.source.samples
			runtime.cleanup_connection();ui.text.objects.clear()
			check(runtime.connection==-1 and runtime.services==initial_services and runtime.source.samples==same_samples,"reconnect-cleans-reference-owner-not-process-timers")
		client.accepted_connection=int(batch.connection);client.epoch=int(batch.generation);ui.area_id=int(batch.areaId)
		var protocol_before: int=runtime.diagnostics.protocolFrames
		for message in batch.frames:runtime.receive(message.duplicate(true))
		check(runtime.diagnostics.protocolFrames==protocol_before+batch.frames.size(),"exact-fixture-frame-ingress-"+batch.label)
		check(runtime.source.samples==samples_before+3 and runtime.services==initial_services,"receive-does-not-reconstruct-or-resample-"+batch.label)
		if batch.label=="freshA":
			captured=batch.capturedAnchor.duplicate(true)
			var proof: Dictionary=runtime.state_view(true);cold_snapshots+=1
			check(runtime.current_scope==[int(batch.connection),0,INVALID] and batch.frames[0].scope.areaId==INVALID,"actual-known-prearea-scope-not-null-sentinel-invention")
			check(proof.services.objects.bindingCount==1 and ui.text.objects.is_empty() and not batch.rawAvailable,"physical-birth-precedes-raw-and-model-readiness")
			check(captured.row.nativeClockOwner.physicalToken==batch.frames[0].event.physicalToken and batch.frames[0].event.constructionCertified and not batch.frames[0].event.ownerAbsentCertified,"exact-private-construction-token-not-display-lifetime")
		if batch.label=="repeatedA":check(batch.frames[0].event.physicalToken==captured.row.nativeClockOwner.physicalToken and not batch.frames[0].event.constructionCertified,"retained-a-no-new-birth")
		if batch.label=="areaTransfer":old_area_scope=query_inputs(retained_anchor).where
		if batch.label=="removal" or batch.label=="ambiguousA":
			check(not retained_anchor.is_empty() and current_query(runtime,retained_anchor)==null,"private-retirement-rejects-old-published-row-before-raw-update-"+batch.label)
		if batch.rawAvailable and batch.anchor is Dictionary:publish(ui,batch.anchor)
		if batch.get("otherAnchor") is Dictionary:publish(ui,batch.otherAnchor)
		runtime.post_receive()
		check(runtime.source.samples==samples_before+3,"post-and-bind-do-not-sample-"+batch.label)
		bound_readers(ui,runtime)
		var gui: Dictionary=runtime.gui_delta()
		if batch.label=="unsupportedPause":
			check(not gui.get("ready",false) and current_query(runtime,batch.anchor)==null,"unsupported-native-pause-is-unavailable-no-nominal-fallback")
			check(not ui.overhead.gui_delta_reader.call().get("ready",false) and not ui.script_floating.gui_delta_reader.call().get("ready",false) and not ui.overhead_popup_registry.gui_delta_reader.call().get("ready",false),"all-three-bound-targets-see-explicit-unavailable")
		else:check(gui.get("ready",false) and gui.get("seconds") is float and is_finite(gui.seconds),"actual-t2-gui-difference-"+batch.label)
		var delta: Variant=current_query(runtime,batch.get("anchor"))
		var expected_current: bool=batch.rawAvailable and batch.anchor is Dictionary and batch.anchor.currentAnchor and batch.anchor.row.nativeClockOwner.get("physicalCurrent")==true and batch.anchor.row.nativeClockOwner.get("physicalToken") is String and batch.label!="unsupportedPause"
		check(delta is int and delta>=0 if expected_current else delta==null,"actual-row-witness-and-physical-query-"+batch.label)
		if batch.label=="delayedRaw":
			check(batch.anchor.row==captured.row and ui.text.objects[int(fixture.ids.actor)]==captured.row,"delayed-received-row-published-unchanged")
			var original_anchor: Dictionary=batch.anchor.duplicate(true);var projected:=query_inputs(batch.anchor)
			check(projected.identity.size()==3 and projected.where.size()==3,"actual-owner-projection-has-three-word-shapes")
			for index in 3:
				check(typeof(projected.identity[index])==TYPE_INT and typeof(projected.where[index])==TYPE_INT and projected.identity[index]==batch.anchor.witness[index] and projected.where[index]==batch.anchor.where[index],"actual-owner-projects-json-numbers-without-changing-values")
			check(batch.anchor==original_anchor,"owner-projection-does-not-mutate-received-fixture")
			check(runtime.object_delta(int(fixture.ids.actor),batch.anchor.witness,batch.anchor.where)==null,"raw-json-arrays-are-not-owned-native-query-shapes")
			var full: Dictionary=runtime.state_view(true);cold_snapshots+=1
			var private_delta: Dictionary=runtime.services.object_delta_for_physical(int(fixture.ids.actor),batch.anchor.row.nativeClockOwner.physicalToken,projected.where,frame)
			var previous: Dictionary=full.services.objects.frame.prior
			check(private_delta.ready and private_delta.basisKind=="previous-ai" and private_delta.basis.frame==previous.frame and previous.frame==frame-1 and private_delta.previousPair==previous.world,"late-first-query-uses-previous-completed-ai-not-birth-or-ui-publish")
			var difference:=WorldClock.subtract_world_times(private_delta.currentPair,previous.world,full.services.objects.frame.dayLength)
			check(difference.outputsDefined and delta==difference.time,"actual-counter-derived-lazy-remainder-no-authored-frame-delta")
		if batch.label=="unknownOther":
			check(gui.ready and delta is int and current_query(runtime,batch.otherAnchor)==null,"unknown-other-physical-owner-does-not-disable-t2-or-actor")
		if batch.label=="areaTransfer":
			var projected:=query_inputs(batch.anchor)
			check(runtime.current_scope==projected.where and old_area_scope!=projected.where and runtime.object_delta(int(fixture.ids.actor),projected.identity,old_area_scope)==null,"area-transfer-preserves-owner-rejects-old-scope")
		if batch.label=="ambiguousA":check(batch.anchor.currentAnchor and batch.anchor.row.nativeClockOwner.physicalToken==null and delta==null,"new-disclosure-witness-cannot-certify-ambiguous-physical-owner")
		if batch.label=="reconnectFreshA":check(batch.anchor.row.nativeClockOwner.epoch!=captured.row.nativeClockOwner.epoch and batch.anchor.row.nativeClockOwner.physicalToken!=captured.row.nativeClockOwner.physicalToken and current_query(runtime,captured)==null,"new-registry-epoch-physical-token-rejects-old-callback")
		if batch.label=="staleOldCallback":check(batch.frames.is_empty() and runtime.diagnostics.protocolFrames==protocol_before and gui.ready and delta is int,"actual-bridge-old-session-callback-produces-no-ingress")
		if expected_current:retained_anchor=batch.anchor.duplicate(true)
		batch_results.append({"label":batch.label,"frame":frame,"connection":runtime.connection,"scope":runtime.current_scope.duplicate(),"protocolFrames":batch.frames.size(),"rawPublished":batch.rawAvailable,"guiReady":gui.get("ready",false),"objectReady":delta is int,"absoluteSamples":runtime.source.samples})
	check(frame_count==17 and runtime.diagnostics.protocolFrames==15,"all-actual-batches-and-frames-consumed")
	check(cold_snapshots==2,"only-two-explicit-cold-full-state-diagnostics")
	# Passive holders model their own teardown contract, not actual GUI pixels.
	ui.release_readers()
	var weak_runtime: WeakRef=weakref(runtime)
	runtime.close()
	var closed_report: Dictionary=client.report.native_clock_runtime.duplicate(true)
	check(closed_report.processRelease.ready and closed_report.finalServices.clockHistoryComplete==false and not closed_report.ready,"close-releases-unsupported-clock-owner-without-history-repair")
	runtime=null;client.gameplay_ui=null;client=null;ui.free()
	await process_frame
	check(weak_runtime.get_ref()==null,"close-breaks-acceptedLifecycle-and-pause-callback-cycles")
	finish(closed_report)
func finish(diagnostics: Dictionary)->void:
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"batches":batch_results,"coldFullSnapshots":cold_snapshots,"runtime":diagnostics,"scope":"Actual Runtime/Services and explicitly loaded reviewed private Win32 direct-Real DLL with exact actual Session/World/Bridge/Raw/Disclosure fixture output. Server DTOs authored, not original capture. GUI targets are passive holders; no renderer/model/pose injection, actual GUI owner execution, pixels, live server or native cached-thread equivalence. Unsupported transition close is covered; actual partial Pause cleanup remains the separate Services165 proof."}
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"batches":batch_results.size()}));quit(0 if failures.is_empty() else 1)
