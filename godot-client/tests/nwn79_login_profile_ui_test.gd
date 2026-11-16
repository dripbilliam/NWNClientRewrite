extends SceneTree
const LoginPanel=preload("res://systems/native_login_profiles.gd")
const Controller=preload("res://systems/native_data/godot_login_profile_controller.gd")
const KEY="ABCDE-FGHIJ-KLMNO-PQRST-UVWXY-12345-67890"
var panel
var controller
var directory: String

func _initialize()->void:
	call_deferred("run_check")

func run_check()->void:
	directory=ProjectSettings.globalize_path("res://.cache/nwn79/test-login-ui-"+str(Time.get_ticks_usec()))
	controller=Controller.new()
	panel=LoginPanel.new();root.add_child(panel)
	panel.setup(directory.path_join("layout.cfg"))
	if not controller.open(directory,"",3,func(message: Dictionary):panel.receive(message),func()->bool:return false,func(_status: Dictionary):pass):fail("protected store");return
	panel.request.connect(controller.handle)
	panel.open("Druid",3)
	if not check(panel.visible and panel.view_id>0 and panel.rows.is_empty(),"fresh panel"):return
	panel.new_draft()
	panel.profile_label.text="Main"
	panel.player_name.text="Druid"
	panel.cd_key.text=KEY
	panel.save()
	if not check(panel.rows.size()==1 and panel.selected_id!=null and panel.cd_key.text.is_empty() and controller.status().hasSavedCdKey,"saved profile shown without key"):return
	panel.close_panel()
	panel.open("",3)
	if not check(panel.rows.size()==1 and panel.player_name.text=="Druid","profile reopened"):return
	panel.close_panel();controller.close()
	panel.queue_free()
	DirAccess.remove_absolute(directory.path_join("client-settings.json"))
	DirAccess.remove_absolute(directory)
	print("NWN79 Godot login profile UI PASS")
	quit(0)

func check(ok: bool,stage: String)->bool:
	if not ok:fail(stage)
	return ok

func fail(stage: String)->void:
	printerr("NWN79 Godot login profile UI failed: "+stage)
	if controller!=null:controller.close()
	quit(1)
