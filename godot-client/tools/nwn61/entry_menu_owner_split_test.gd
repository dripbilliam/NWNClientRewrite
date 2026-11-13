extends SceneTree
const Video=preload("res://systems/native_video_options.gd")
const Keys=preload("res://systems/native_key_settings.gd")
const Menu=preload("res://systems/native_main_menu.gd")
class FakeCatalog extends RefCounted:
	var failure:="fixture-missing"
	func fork():return self
	func get_resource(_name: String,_type: int) -> PackedByteArray:return PackedByteArray()
class FakeVideoSettings extends Node:
	signal changed
class FakeBindings extends Node:
	signal changed
	signal edited
	signal cancel_requested
	func retire() -> void:pass
var checks:=0
var failures: Array=[]
var output:=""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
	call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func snapshot(owner) -> Dictionary:
	return {"jobs":owner.jobs.duplicate(),"requested":owner.requested.duplicate(),"path":owner.layout_path if owner.get_script()==Video else owner.storage,"asset_workers":owner.assets.maximum_workers,"asset_cache":owner.assets.cache_directory}
func exercise(script: Script,service: Node,expected_phases: Array,expected_jobs: Array) -> Dictionary:
	var catalog:=FakeCatalog.new();var painter:=Node.new();var text_owner:=Node.new();var path:="user://nwn61-missing-layout.cfg"
	var original=script.new();root.add_child(original)
	original.configure(painter,text_owner,catalog,"",service,path)
	var synchronous:=snapshot(original)
	check(synchronous.jobs.values()==expected_jobs,"synchronous request order "+script.resource_path)
	original.close();original.free()
	var staged=script.new();root.add_child(staged)
	var state: Dictionary=staged.begin_entry_configuration(painter,text_owner,catalog,"",service,path)
	var phases: Array=[];var costs: Array=[];var result: Dictionary={}
	for _step in expected_phases.size():
		phases.append(staged.entry_configuration_phase(state))
		var before:=Time.get_ticks_usec();result=staged.entry_configuration_step(state);costs.append(Time.get_ticks_usec()-before)
		if result.get("done",false):break
	check(result.get("done",false) and result.get("accepted",false),"staged owner completes "+script.resource_path)
	check(phases==expected_phases,"original setup phase order "+script.resource_path)
	check(snapshot(staged)==synchronous,"staged and synchronous request/state parity "+script.resource_path)
	check(not staged.entry_configuration_step(state).get("accepted",false),"completed owner token rejected "+script.resource_path)
	staged.finish_entry_configuration()
	check(not staged.layout_ready,"missing fixture assets do not publish a premature page "+script.resource_path)
	var receipt:={"phases":phases,"step_us":costs,"total_us":costs.reduce(func(sum,value):return sum+value,0),"maximum_unit_us":costs.max(),"requests":synchronous.jobs.values(),"scope":"Small headless fake-catalog setup only; times are diagnostic and not FPS or original-asset costs."}
	staged.close();staged.free()
	var cancelled=script.new();root.add_child(cancelled)
	state=cancelled.begin_entry_configuration(painter,text_owner,catalog,"",service,path)
	cancelled.entry_configuration_step(state);cancelled.entry_configuration_step(state)
	cancelled.close()
	check(not cancelled.entry_configuration_step(state).get("accepted",false),"closed owner rejects partial entry token "+script.resource_path)
	cancelled.free();painter.free();text_owner.free()
	return receipt
func run() -> void:
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var menu_script: Script=Menu
	check(menu_script.can_instantiate(),"current staged main-menu source compiles with both owner APIs")
	var video_settings:=FakeVideoSettings.new();root.add_child(video_settings)
	var bindings:=FakeBindings.new();root.add_child(bindings)
	var video:=exercise(Video,video_settings,["initialize","asset_service","layout_request","scrollbar_request","scroll_up_request","scroll_down_request","signals","complete"],["@layout","scrollbar_simple","pb_scrl_up","pb_scrl_down"])
	var keys:=exercise(Keys,bindings,["initialize","asset_service","panel_request","page_request","button_request","scrollbar_request","scroll_up_request","scroll_down_request","signals","complete"],["@options_key_pnl","@options_key_page","ctl_opt_btn_key","scrollbar_simple","pb_scrl_up","pb_scrl_down"])
	var menu:=Menu.new();root.add_child(menu)
	menu.window_settings=video_settings;menu.key_bindings=bindings;menu.layout_path=""
	var painter:=Node.new();var text_owner:=Node.new();var catalog:=FakeCatalog.new()
	var state: Dictionary=menu.begin_native_configuration(painter,text_owner,catalog,"",[1,2,3,4]);state.phase=13
	var menu_phases: Array=[];var menu_result: Dictionary={}
	for _step in 28:
		menu_phases.append(menu.native_configuration_phase(state))
		menu_result=menu.native_configuration_step(state)
		if menu_result.get("done",false):break
	check(menu_result.get("done",false) and menu_result.get("accepted",false),"main menu entry continuation reaches completion")
	check(menu_phases.has("video:layout_request") and menu_phases.has("keys:page_request") and menu_phases.has("video:complete") and menu_phases.has("keys:complete"),"nested owner units are separately attributed")
	check(is_instance_valid(menu.video_owner) and is_instance_valid(menu.key_owner) and menu.video_owner.prepared.is_connected(menu.update_native) and menu.key_owner.prepared.is_connected(menu.update_native),"child owner publication signals bind after setup")
	check(menu.video_owner.jobs.values()==video.requests and menu.key_owner.jobs.values()==keys.requests,"main menu sends the same ordered video/key requests")
	check(not menu.native_configuration_step(state).get("accepted",false),"completed main-menu token is rejected")
	menu.free();painter.free();text_owner.free()
	menu=Menu.new();root.add_child(menu);menu.window_settings=video_settings;menu.layout_path=""
	painter=Node.new();text_owner=Node.new();catalog=FakeCatalog.new()
	state=menu.begin_native_configuration(painter,text_owner,catalog,"",[5,6,7,8]);state.phase=13
	menu.native_configuration_step(state);menu.native_configuration_step(state);menu.native_configuration_step(state)
	var retiring_video=menu.video_owner;var before_epoch: int=retiring_video.assets.epoch
	menu.cancel_native_configuration(state)
	check(state.cancelled and not menu.native_configuration_step(state).get("accepted",false),"main-menu cancellation revokes the partial owner token")
	check(retiring_video.assets.epoch>before_epoch,"main-menu cancellation retires the partial owner's queued assets")
	menu.free();painter.free();text_owner.free()
	video_settings.free();bindings.free()
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"video":video,"keys":keys,"menu_phases":menu_phases,"source_sha256":{"menu":FileAccess.get_sha256(ProjectSettings.globalize_path("res://systems/native_main_menu.gd")),"video":FileAccess.get_sha256(ProjectSettings.globalize_path("res://systems/native_video_options.gd")),"keys":FileAccess.get_sha256(ProjectSettings.globalize_path("res://systems/native_key_settings.gd"))}},"  ")+"\n");file.close()
	quit(0 if failures.is_empty() else 1)
