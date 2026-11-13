extends "res://tests/native_pregame_flow_test.gd"
# Functional parity setup contract only. Preserve the original15s ceiling,
# subsequent waits, all physical inputs and the unchanged visibility assertion.
# Cold Internet-open responsiveness is measured by a separate rejected-baseline
# observation; waiting here cannot accept or erase that latency finding.
var initial_browser_gate_used: bool=false
func await_flow(predicate: Callable,milliseconds: int=15000) -> bool:
	if initial_browser_gate_used: return await super.await_flow(predicate,milliseconds)
	initial_browser_gate_used=true
	var started: int=Time.get_ticks_usec()
	var accepted: bool=await super.await_flow(func():
		return predicate.call() and is_instance_valid(server_browser.native_browser) and server_browser.native_browser.layout_ready and server_browser.native_browser.failure.is_empty()
	,milliseconds)
	var browser=server_browser.native_browser
	var data: Dictionary={"accepted":accepted,"initialGateCeilingMs":milliseconds,"elapsedMs":(Time.get_ticks_usec()-started)/1000.0,"browserLayoutReady":browser.layout_ready,"browserFailure":browser.failure,"pendingJobs":browser.jobs.size(),"models":browser.models.size(),"sources":browser.sources.size(),"originalInputsChanged":false,"subsequentWaitsChanged":false,"visibilityAssertionChanged":false,"coldResponsivenessAccepted":false,"scope":"New initial preparation gate for fixed-source functional engine parity only"}
	var file: FileAccess=FileAccess.open(str(args.report)+".initial-ready.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(data,"\t")+"\n")
		file.close()
	return accepted
