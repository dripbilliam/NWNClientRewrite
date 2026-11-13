extends "res://native_session_world.gd"
# Actual entry/receive/connection gate; no base startup or transport. These
# adapters observe presentation calls only, not native browser input/pixels.
class BrowserAdapter extends Node:
	var wanted:=false
	var connection:=7
	var opens:=0
	var closes:=0
	func open_list()->void:opens+=1;wanted=true
	func close()->void:closes+=1;wanted=false
class LobbyAdapter extends Node:
	var panel: Control
	var applied: Array=[]
	var appearance_identity: Dictionary={}
	var native_closes:=0
	func _init()->void:panel=Control.new();add_child(panel)
	func apply_state(value: Dictionary)->void:applied.append(value.duplicate(true))
	func close_native()->void:native_closes+=1
class MenuAdapter extends Node:
	var observed: Array=[]
	var opens: Array=[]
	var dismisses:=0
	var detaches:=0
	func observe_lobby(state: Dictionary)->void:observed.append(state.duplicate(true))
	func open(playing: bool)->void:opens.append(playing)
	func dismiss()->void:dismisses+=1
	func detach_native()->void:detaches+=1

var failure_checks:=0
var failure_failures: Array=[]
var refusal_messages: Array=[]
var observed_sends: Array=[]
func _initialize()->void:call_deferred("run_failure_test")
func fail(reason: String)->void:refusal_messages.append(reason)
func send(value: Dictionary)->void:observed_sends.append(value.duplicate(true))
func failure_check(value: bool,description: String)->void:
	failure_checks+=1
	if not value:failure_failures.append(description);print("FAIL: ",description)
func state(overrides: Dictionary={})->Dictionary:
	var result: Dictionary={"phase":"menu","error":"Destination unavailable","connected":false,"busy":false}
	result.merge(overrides,true);return result
func publish(value: Dictionary,connection: int=7)->void:
	receive_profiled({"kind":"lobby","connection":connection,"state":value})
func reset_adapters()->void:
	server_browser.wanted=false;server_browser.opens=0;server_browser.closes=0
	character_lobby.panel.show();character_lobby.applied.clear();render_menu.observed.clear();render_menu.opens.clear()
	return_to_browser=false;return_to_main_menu=false;cancelled_connection=-1;session_connection=7;label.text="Pending destination"

func run_failure_test()->void:
	var output:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	label=Label.new();root.add_child(label)
	server_browser=BrowserAdapter.new();root.add_child(server_browser)
	character_lobby=LobbyAdapter.new();root.add_child(character_lobby)
	render_menu=MenuAdapter.new();root.add_child(render_menu)
	failure_check(native_clock_runtime==null and peer.get_status()==StreamPeerTCP.STATUS_NONE and not authenticated and args.is_empty() and ticket.is_empty(),"Actual SceneTree startup remains suppressed with no transport, clock, ticket or profile")
	reset_adapters();var actual_failure:=state()
	publish(actual_failure)
	failure_check(server_browser.opens==1 and server_browser.wanted and not return_to_browser,"Current idle disconnected menu error uses the existing browser route exactly once")
	failure_check(character_lobby.applied==[{"kind":"lobby","connection":7,"state":actual_failure}] and render_menu.observed==[actual_failure],"The real receive branch still delivers unchanged received state to both presentation owners")
	failure_check(not character_lobby.panel.visible and label.text.is_empty() and render_menu.opens.is_empty(),"Failure hides stale chooser and caption without opening Main Menu")
	publish(actual_failure)
	failure_check(server_browser.opens==1 and character_lobby.applied.size()==2 and render_menu.observed.size()==2,"Repeated unchanged failure cannot restart an already wanted browser")
	for definition in [
		{"name":"busy","fields":{"busy":true}},
		{"name":"connected","fields":{"connected":true}},
		{"name":"empty error","fields":{"error":""}},
		{"name":"non-String error","fields":{"error":9}},
		{"name":"missing error","erase":"error"},
		{"name":"missing connected","erase":"connected"},
		{"name":"missing busy","erase":"busy"},
		{"name":"non-Boolean connected","fields":{"connected":0}},
		{"name":"non-Boolean busy","fields":{"busy":0}},
		{"name":"ordinary playing","fields":{"phase":"playing"}},
	]:
		reset_adapters();var value: Dictionary=state(definition.get("fields",{}))
		if definition.has("erase"):value.erase(definition.erase)
		publish(value)
		failure_check(server_browser.opens==0 and not server_browser.wanted and not return_to_browser and render_menu.opens.is_empty(),"Excluded state leaves browser routing unchanged: "+definition.name)
		failure_check(character_lobby.applied.size()==1 and render_menu.observed.size()==1 and character_lobby.panel.visible,"Excluded state still follows normal lobby presentation: "+definition.name)
	reset_adapters();return_to_main_menu=true;return_to_browser=true;server_browser.wanted=true
	publish(state())
	failure_check(render_menu.opens==[false] and server_browser.opens==0 and server_browser.closes==1 and not server_browser.wanted,"Explicit Main Menu wins over received menu failure and closes the browser")
	failure_check(not return_to_main_menu and not return_to_browser and not character_lobby.panel.visible and label.text.is_empty(),"Main Menu precedence consumes both return flags")
	reset_adapters();return_to_main_menu=true
	publish(state({"busy":true}))
	failure_check(render_menu.opens.is_empty() and server_browser.opens==0 and return_to_main_menu and not return_to_browser,"Busy received failure cannot consume a pending explicit Main Menu return")
	reset_adapters();return_to_browser=true
	publish(state({"error":""}))
	failure_check(server_browser.opens==1 and not return_to_browser,"Existing explicit browser return still works on a clean menu state")
	reset_adapters();var stale_before: int=int(report.get("stale_session_messages",0))
	publish(state(),6)
	failure_check(int(report.get("stale_session_messages",0))==stale_before+1 and session_connection==7,"Existing accept_connection rejects an old connection before lobby dispatch")
	failure_check(character_lobby.applied.is_empty() and render_menu.observed.is_empty() and server_browser.opens==0 and character_lobby.panel.visible,"Old-connection failure cannot touch any current presentation owner")
	reset_adapters();publish(state({"phase":"closed","error":"","connected":true}))
	failure_check(server_browser.opens==1 and server_browser.wanted and cancelled_connection==7,"Existing closed phase retains its unconditional return-to-browser policy")
	failure_check(character_lobby.native_closes>0 and render_menu.detaches>0 and raw_world.is_empty() and accepted_raw_serial==-1,"Closed phase still invokes actual session reset before reopening browser")
	reset_adapters();var retired_applied: int=character_lobby.applied.size();stale_before=int(report.get("stale_session_messages",0))
	publish(state({"phase":"closed"}),6)
	failure_check(character_lobby.applied.size()==retired_applied and int(report.get("stale_session_messages",0))==stale_before+1 and server_browser.opens==0,"Retired closed phase cannot reset or reopen the current session")
	failure_check(refusal_messages.is_empty() and observed_sends.is_empty() and native_clock_runtime==null and peer.get_status()==StreamPeerTCP.STATUS_NONE,"Actual receive tests emit no refusals/transport messages and start no services")
	var result: Dictionary={"success":failure_failures.is_empty(),"checks":failure_checks,"failures":failure_failures,"sourceConnection":session_connection,"scope":"Actual startup-suppressed SessionWorld receive_profiled/accept_connection/lobby/reset route. Inert view adapters observe calls only; no real Browser rendering, pointer readiness, transport, server, install/profile/key/native build/GPU."}
	server_browser.free();character_lobby.free();render_menu.free();label.free()
	server_browser=null;character_lobby=null;render_menu=null;label=null;catalog=null;render_pool.clear()
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print("NATIVE_LOBBY_MENU_FAILURE ",failure_checks," checks, ",failure_failures.size()," failures")
	quit(0 if failure_failures.is_empty() else 1)
