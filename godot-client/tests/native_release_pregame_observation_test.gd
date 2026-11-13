extends "res://tests/native_pregame_flow_test.gd"
# Observation only: every original assertion, input, wait and teardown is inherited.
var internet_intent_usec: int=-1
var observation_events: Array[Dictionary]=[]
func send(value: Dictionary) -> void:
	if value.get("kind")=="browser-input" and value.get("operation")=="tab" and value.get("tab")=="Internet": internet_intent_usec=Time.get_ticks_usec()
	super.send(value)
func sizes(owner: Object,names: Array) -> Dictionary:
	var available: Dictionary={}
	for entry in owner.get_property_list(): available[str(entry.name)]=true
	var result: Dictionary={}
	for name in names:
		if not available.has(name): continue
		var value: Variant=owner.get(name)
		if value is Dictionary or value is Array or value is PackedStringArray: result[name]=value.size()
		elif value is String or value is bool or value is int: result[name]=value
	return result
func capture_observation(description: String,accepted: bool) -> void:
	var now: int=Time.get_ticks_usec()
	var browser=server_browser.native_browser
	var service=browser.assets
	var pending_results: int=0
	service.mutex.lock(); pending_results=service.results.size(); service.mutex.unlock()
	var event: Dictionary={"description":description,"assertionAccepted":accepted,"ticksUsec":now,"internetIntentUsec":internet_intent_usec,"sinceInternetIntentMs":(now-internet_intent_usec)/1000.0 if internet_intent_usec>=0 else null,"wanted":server_browser.wanted,"entryContext":server_browser.entry_context,"entryStage":server_browser.entry_stage,"profileFirst":server_browser.profile_first,"stateTab":server_browser.state.get("tab"),"sourceBrowser":{"layoutReady":browser.layout_ready,"visible":browser.visible,"visibleInTree":browser.is_visible_in_tree(),"failure":browser.failure,"typeTableFailure":browser.type_table_failure,"closed":browser.closed,"pendingJobs":browser.jobs.size(),"pendingNames":browser.jobs.values(),"sources":browser.sources.size(),"models":browser.models.size(),"requestedModels":browser.requested.size()},"assets":{"pending":service.pending.size(),"running":service.running.size(),"results":pending_results,"failure":service.failure,"closed":service.closed,"maximumWorkers":service.maximum_workers},"entryMenu":{"visible":server_browser.entry_menu.visible,"layoutReady":server_browser.entry_menu.layout_ready,"artReady":server_browser.entry_menu.art_ready(),"failure":server_browser.entry_menu.failure},"lobbyPanelVisible":character_lobby.panel.visible,"prototypePanelVisible":server_browser.panel.visible,"frameArt":sizes(browser.frame.art,["waiting","pending","failed","cache"]),"frameFonts":sizes(browser.frame.fonts,["waiting","pending","failed","cache"])}
	observation_events.append(event)
	var file: FileAccess=FileAccess.open(str(args.report)+".observation.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify({"events":observation_events,"sourceRevision":"19e4f9fb0bbb10d410b2f0aacab5f367a03d03cd10320aa3b0c1f3d1ea202d0d","assertionsChanged":false,"waitsChanged":false,"inputChanged":false,"scope":"Observation of inherited unchanged editor baseline, not release/functional acceptance"},"\t")+"\n")
		file.close()
func check(ok: bool,description: String) -> bool:
	if description in ["Actual PRE_MAIN, Multiplayer, browser and character chooser prepare without any connection","Physical Internet action reaches native list using an authored received view"]: capture_observation(description,ok)
	return super.check(ok,description)
