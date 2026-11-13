extends SceneTree
# Prepared native test. Run only in a later authorized free-PC check window.
const Entry=preload("res://native_session_world.gd")
class MenuSpy extends "res://systems/native_main_menu.gd":
	var updates:=0
	var dismissals:=0
	func _ready() -> void:pass
	func dismiss() -> void:dismissals+=1
	func update_native() -> void:updates+=1
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.substr(9)
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var menu:=MenuSpy.new();var scope:=[1,2,3,4]
	check(Entry.refresh_entry_menu_scope(menu,scope) and menu.updates==1 and menu.dismissals==1,"First scope uses actual menu setter")
	check(not Entry.refresh_entry_menu_scope(menu,scope.duplicate()) and menu.updates==1 and menu.dismissals==1,"Equal detached scope does not rebuild context")
	scope[0]=9
	check(menu.native_scope==[1,2,3,4],"Actual setter retains a detached owner scope")
	for component in 4:
		var changed: Array=menu.native_scope.duplicate();changed[component]+=1
		var previous:=menu.updates
		check(Entry.refresh_entry_menu_scope(menu,changed) and menu.native_scope==changed and menu.updates==previous+1,"Changed scope coordinate refreshes: "+str(component))
	var same: Array=menu.native_scope.duplicate();var before:=menu.updates
	menu.observe_lobby({"connected":true,"phase":"playing"})
	check(menu.updates==before+1 and menu.native_scope==same,"Actual lobby notification still refreshes an unchanged scope")
	check(not Entry.refresh_entry_menu_scope(menu,same) and menu.updates==before+1,"Subsequent same-scope commit does not erase independent refresh")
	menu.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Actual entry helper and native menu setter/lobby refresh contract, no world, connection or performance measurement"}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close();print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
