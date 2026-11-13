extends "res://tests/native_release_pregame_observation_test.gd"
# The inherited fourth assertion still fails/passes at its original instant.
# Only after that failure, delay teardown to observe real preparation for <=5s
# measured from the actual Internet tab intent. This cannot accept the baseline.
const OBSERVATION_CEILING_USEC: int=5000000
var configure_begin_usec: int=-1
var configure_end_usec: int=-1
var prepared_usec: int=-1
var ready_usec: int=-1
var visible_usec: int=-1
var failure_usec: int=-1
var completions: Array[Dictionary]=[]
var completion_overflow: bool=false
func source_prepared(painter,text,base_catalog,cache_path: String) -> void:
	configure_begin_usec=Time.get_ticks_usec()
	super.source_prepared(painter,text,base_catalog,cache_path)
	configure_end_usec=Time.get_ticks_usec()
	server_browser.native_browser.prepared.connect(observed_prepared)
	server_browser.native_browser.visibility_changed.connect(observed_visibility)
	server_browser.native_browser.assets.completed.connect(observed_completion)
func observed_prepared() -> void:
	prepared_usec=Time.get_ticks_usec()
	if ready_usec<0: ready_usec=prepared_usec
func observed_visibility() -> void:
	var browser=server_browser.native_browser
	if browser.visible and browser.is_visible_in_tree():
		var now: int=Time.get_ticks_usec()
		if visible_usec<0: visible_usec=now
		if browser.layout_ready and ready_usec<0: ready_usec=now
func observed_completion(_id: int,result: Dictionary) -> void:
	var now: int=Time.get_ticks_usec()
	var browser=server_browser.native_browser
	if not browser.failure.is_empty() and failure_usec<0: failure_usec=now
	if completions.size()>=64: completion_overflow=true; return
	var bytes: Variant=result.get("bytes")
	completions.append({"ticksUsec":now,"sinceInternetIntentMs":(now-internet_intent_usec)/1000.0 if internet_intent_usec>=0 else null,"resource":str(result.get("resource_name","")),"error":str(result.get("error","")).left(1024),"bytes":bytes.size() if bytes is PackedByteArray else null,"readMs":result.get("read_ms"),"workerMs":result.get("worker_ms"),"phases":result.get("phases",{}),"browserJobsRemaining":browser.jobs.size(),"browserModels":browser.models.size()})
func elapsed_ms(instant: int,origin: int) -> Variant:
	return (instant-origin)/1000.0 if instant>=0 and origin>=0 else null
func finish_case() -> void:
	var assertion_failed: bool=failures.has("Physical Internet action reaches native list using an authored received view")
	var drain_begin: int=Time.get_ticks_usec()
	var browser=server_browser.native_browser
	var observed_frames: int=0
	if assertion_failed and internet_intent_usec>=0:
		var deadline: int=internet_intent_usec+OBSERVATION_CEILING_USEC
		while Time.get_ticks_usec()<deadline and not (browser.layout_ready and browser.visible and browser.is_visible_in_tree()) and browser.failure.is_empty():
			await process_frame
			observed_frames+=1
		capture_observation("Separate bounded post-failure readiness observation",false)
	var now: int=Time.get_ticks_usec()
	var service=browser.assets
	var data: Dictionary={"sourceRevision":"19e4f9fb0bbb10d410b2f0aacab5f367a03d03cd10320aa3b0c1f3d1ea202d0d","baselineOriginallyFailed":assertion_failed,"baselineAccepted":false,"observationCeilingMs":OBSERVATION_CEILING_USEC/1000.0,"ceilingOrigin":"Actual Internet tab browser-input intent, not teardown start","configureBeginUsec":configure_begin_usec,"configureEndUsec":configure_end_usec,"internetIntentUsec":internet_intent_usec,"preparedUsec":prepared_usec,"layoutReadyObservedUsec":ready_usec,"visibleObservedUsec":visible_usec,"failureObservedUsec":failure_usec,"drainBeginUsec":drain_begin,"drainEndUsec":now,"configureToReadyMs":elapsed_ms(ready_usec,configure_begin_usec),"internetToReadyMs":elapsed_ms(ready_usec,internet_intent_usec),"internetToVisibleMs":elapsed_ms(visible_usec,internet_intent_usec),"internetToFailureMs":elapsed_ms(failure_usec,internet_intent_usec),"inputToDrainEndMs":elapsed_ms(now,internet_intent_usec),"postAssertionFrames":observed_frames,"layoutReady":browser.layout_ready,"visible":browser.visible,"visibleInTree":browser.is_visible_in_tree(),"browserFailure":browser.failure,"typeTableFailure":browser.type_table_failure,"pendingJobs":browser.jobs.size(),"models":browser.models.size(),"requestedModels":browser.requested.size(),"sources":browser.sources.size(),"assetsPending":service.pending.size(),"assetsRunning":service.running.size(),"assetFailure":service.failure,"completionOverflow":completion_overflow,"completions":completions,"scope":"Latency observation after original assertion; original inputs/waits/assertions preserved. No release, original pixels or responsiveness acceptance."}
	var file: FileAccess=FileAccess.open(str(args.report)+".readiness.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(data,"\t")+"\n")
		file.close()
	await super.finish_case()
