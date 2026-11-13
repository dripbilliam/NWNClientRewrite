extends SceneTree
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Identity=preload("res://systems/native_data/player_identity.gd")
class View extends RefCounted:
	func reset()->void:pass
	func sync()->void:pass
	func set_world(_epoch,_area,_controlled,_objects,_inventory={})->void:pass
	func update_world(_epoch,_area,_controlled,_objects,_removed,_inventory={})->void:pass
class Desktop extends RefCounted:
	var state:Dictionary={}
	var objects:Dictionary={}
	var scope:Array=[]
	func set_world(epoch,area,controlled,raw,header)->void:scope=[epoch,area,controlled];state=header;objects=raw
var checks:=0
var failures:Array=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label)
func _initialize()->void:
	var output:="";var fixture:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--fixture="):fixture=arg.trim_prefix("--fixture=")
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var ui:=Gameplay.new();ui.desktop=Desktop.new();ui.inventory=View.new();ui.barter=View.new();ui.conversation=View.new();ui.examine=View.new();ui.examine_skin=View.new()
	var actor:={"id":99,"objectType":5};var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	for stage in data.stages:
		var source:Dictionary=stage.header;var header:={"area":{"id":10},"module":{"name":"Authored current"},"ui":source};var expected:Dictionary=stage.expected
		ui.set_world(1,10,99,[actor],{},header)
		check(ui.desktop.state.gameMasterPermission==source.gameMasterPermission and ui.desktop.state.playerRosterKnown==source.playerRosterKnown,"Actual full Gameplay header preserves exact owners "+str(stage.label))
		check(Identity.normal_context(ui.desktop.state,stage.target).available==expected.normalAdmission,"Actual full Gameplay forwarding retains typed admission "+str(stage.label))
		ui.update_world(1,10,99,[],[],{},header)
		check(ui.desktop.state.gameMasterPermission==source.gameMasterPermission and ui.desktop.state.playerRosterKnown==source.playerRosterKnown,"Actual delta Gameplay header preserves exact owners "+str(stage.label))
		check(ui.desktop.state.players==source.players and ui.desktop.scope==[1,10,99] and ui.desktop.objects.has(99),"Existing roster/object/scope owners survive forwarding "+str(stage.label))
	ui.set_world(1,10,99,[actor],{},{});check(ui.desktop.state.gameMasterPermission==null and ui.desktop.state.playerRosterKnown==null and not Identity.normal_context(ui.desktop.state,100).available,"Absent full owners remain unavailable, never permission0/known empty")
	ui.update_world(1,10,99,[],[],{},{});check(ui.desktop.state.gameMasterPermission==null and ui.desktop.state.playerRosterKnown==null,"Absent delta owners are not inherited or defaulted")
	ui.closed=true;ui.free()
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual Gameplay.set_world/update_world and real typed identity policy over19 Session/World/host headers. Only downstream views are inert; no server/renderer/pixels outcome."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
