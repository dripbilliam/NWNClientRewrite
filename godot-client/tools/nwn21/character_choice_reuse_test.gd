extends SceneTree
const Lobby=preload("res://systems/character_lobby.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok: failures.append(label)
func _initialize()->void: call_deferred("run")
func run()->void:
	var ui:=Lobby.new();root.add_child(ui)
	var rows: Array=[{"key":"server:a","label":"Ada"},{"key":"server:b","label":"Bela"}]
	var state: Dictionary={"phase":"character-selection","selected":"server:a","choices":rows}
	ui.apply_state({"connection":1,"state":state})
	check(ui.keys==["server:a","server:b"] and ui.choices.item_count==2,"Initial rows and keys")
	ui.choices.set_item_metadata(0,"reuse-marker")
	var updated: Dictionary=state.duplicate(true);updated.resourceProgress={"phase":"server-manifest","completed":0,"total":0}
	ui.apply_state({"connection":1,"state":updated})
	check(ui.choices.get_item_metadata(0)=="reuse-marker","Unchanged rows survive a state update")
	ui.choices.select(1)
	ui.apply_state({"connection":1,"state":updated})
	check(ui.choices.get_selected_items().size()==1 and ui.choices.get_selected_items()[0]==0,"Server selection remains authoritative")
	updated.selected="server:b";ui.apply_state({"connection":1,"state":updated})
	check(ui.choices.get_selected_items().size()==1 and ui.choices.get_selected_items()[0]==1 and ui.choices.get_item_metadata(0)=="reuse-marker","Selection changes reuse rows")
	updated.selected="missing";ui.apply_state({"connection":1,"state":updated})
	check(ui.choices.get_selected_items().is_empty(),"Absent selection clears the list highlight")
	updated.choices=[{"key":"server:a","label":"Ada revised"},{"key":"server:b","label":"Bela"}]
	ui.apply_state({"connection":1,"state":updated})
	check(ui.choices.get_item_text(0)=="Ada revised" and ui.choices.get_item_metadata(0)==null,"Changed content rebuilds rows")
	ui.free()
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Character-list row reuse and authoritative selection; no latency or live-server claim."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.substr(9),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
