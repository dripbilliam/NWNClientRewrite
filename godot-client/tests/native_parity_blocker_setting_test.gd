extends SceneTree
# SOURCE ONLY. No server/world/native library/GPU; do not execute before approval.
const Settings=preload("res://systems/native_render_settings.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func run() -> void:
	var directory:=OS.get_environment("NWN_PARITY_UI_TEST_DIR")
	if directory.is_empty():directory="user://"
	var file:=directory.path_join("native-parity-blocker-test-"+str(Time.get_ticks_usec())+".cfg")
	var owner:=Settings.new();root.add_child(owner);owner.setup(file,"")
	check(not owner.show_blockers_enabled and not owner.show_blockers_toggle.button_pressed,"Blocker diagnostics default off")
	var seen: Array=[];owner.show_blockers_changed.connect(func(on):seen.append(on))
	owner.show_blockers_toggle.button_pressed=true
	var config:=ConfigFile.new();config.load(file)
	check(owner.show_blockers_enabled and config.get_value("rendering","show_blockers")==true and seen==[true],"Toggle persists and emits cold ownership signal")
	owner.free()
	var reloaded:=Settings.new();root.add_child(reloaded);reloaded.setup(file,"")
	check(reloaded.show_blockers_enabled and reloaded.show_blockers_toggle.button_pressed,"Saved diagnostic preference reloads")
	reloaded.free();config.set_value("rendering","show_blockers","false");config.save(file)
	var malformed:=Settings.new();root.add_child(malformed);malformed.setup(file,"")
	check(not malformed.show_blockers_enabled,"Wrong-typed value cannot enable diagnostic rendering")
	malformed.free();DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	print("NATIVE_PARITY_BLOCKER_SETTING ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
