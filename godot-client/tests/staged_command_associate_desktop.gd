extends "res://systems/native_game_desktop.gd"
# Test-only adapter showing the exact proposed Desktop boundary; never imported
# by the production scene. Existing wheel, quickbar, assignment and use stay real.
const Staged=preload("res://systems/native_data/staged_command_associates.gd")
var command_party: Array=[]
var command_revision: Variant=null
var command_snapshot: Dictionary={}
var command_scope: Dictionary={}
func capture_commands() -> Dictionary:
	return Staged.capture(command_party,command_revision,actor_id,func(id):return objects.get(id),func(object,id):return owner_ui.text.name(object.get("replicated",{}).get("name"),id))
func scope_commands() -> Dictionary:
	return {"generation":generation,"area":area_id,"actor":actor_id,"actorLifetime":actor().get("clientKnownLifetime")}
func ability_entries(menu: Dictionary) -> Array:
	if menu.get("kind")!="quickbar-commands":return super.ability_entries(menu)
	command_snapshot=capture_commands();command_scope=scope_commands()
	return decorate_commands(Staged.materialize(command_snapshot,Staged.root_plan(command_snapshot,1)))
func decorate_commands(rows: Array) -> Array:
	var result: Array=[]
	for source in rows:
		var value: Dictionary=source.duplicate(true);value.label=str(value.label) if value.label!=null else owner_ui.text.raw({"strRef":int(value.labelRef)})
		value.action="power";value.canDrag=value.has("binding");value.submenu=value.has("children")
		if value.has("children"):value.children=decorate_commands(value.children)
		result.append(value)
	return result
func radial_select(message: Dictionary) -> void:
	if radial.active and int(message.get("requestId",-1))==radial.request_id and int(message.get("menuId",-1))==radial.menu_id and not shortcut_context.is_empty() and not command_scope.is_empty() and radial_entries.has(int(message.get("slot",-1))):
		if command_scope!=scope_commands() or not Staged.integer(command_scope.actorLifetime) or int(command_scope.actorLifetime)<=0 or not Staged.selection_valid(command_snapshot,capture_commands(),radial_entries[int(message.slot)]):
			retire_shortcut_context();return
	super.radial_select(message)
	if not radial.active:command_scope.clear();command_snapshot.clear()
func retire_shortcut_context(reset_wheel: bool=true) -> void:
	command_scope.clear();command_snapshot.clear();super.retire_shortcut_context(reset_wheel)
