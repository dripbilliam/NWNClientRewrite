extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Menu=preload("res://systems/native_main_menu.gd")
const Pregame=preload("res://systems/native_pregame_menu.gd")
class MockPage:
	extends Control
	var layout_ready:=true
	var buttons: Dictionary={}
	func art_ready() -> bool:return true
	func cohort_snapshot() -> Dictionary:return {"failures":[],"scope":"test"}
	func set_context(_scope: Array,_enabled: Dictionary,_colors: Dictionary={}) -> void:pass
	func dismiss() -> void:hide()
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func run() -> void:
	var install="C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall"
	var catalog=Catalog.new()
	check(catalog.mount_install(install),"Installed original catalog mounts")
	if not failures.is_empty():quit(1);return
	var menu=Menu.new();root.add_child(menu)
	menu.configure_menu_audio(catalog,"")
	for i in 300:
		if menu.menu_click_player.stream!=null:break
		await process_frame
	check(menu.menu_click_player.stream!=null,"Original gui_button sound decodes from installed resource")
	if menu.menu_click_player.stream!=null:check(menu.menu_click_player.stream.get_length()>0.05,"Original button cue has playable duration")
	var retired_owner=menu.menu_audio_assets
	menu.configure_menu_audio(catalog,"")
	var current_job: int=menu.menu_click_job
	menu.menu_audio_ready(current_job,{"error":"stale owner"},retired_owner)
	check(menu.menu_click_job==current_job and menu.menu_click_player.stream==null,"Retired asset completion cannot publish into reconfigured menu")
	for i in 300:
		if menu.menu_click_player.stream!=null:break
		await process_frame
	check(menu.menu_click_player.stream!=null,"Reconfigured menu restores original button sound")
	var profile=ProjectSettings.globalize_path("res://.cache/nwn81/sound-profile")
	DirAccess.make_dir_recursive_absolute(profile)
	var settings=FileAccess.open(profile.path_join("settings.tml"),FileAccess.WRITE)
	settings.store_string("[sound.music]\nvolume = 0.0\n[sound.effects]\nvolume = 0.0\n");settings.close()
	menu.menu_audio_profile=profile
	check(menu.menu_effect_volume()==0.0,"Effects mute is honored independently of music volume")
	menu.play_menu_click()
	check(not menu.menu_click_player.playing,"Muted button activation does not start playback")
	settings=FileAccess.open(profile.path_join("settings.tml"),FileAccess.WRITE)
	settings.store_string("[sound.effects]\nvolume = 0.25\n");settings.close()
	check(is_equal_approx(menu.menu_effect_volume(),0.25),"Effects volume refreshes after settings change")
	menu.play_menu_click()
	check(is_equal_approx(menu.menu_click_player.volume_linear,0.25),"Button player receives current effects gain")
	var pregame=Pregame.new();root.add_child(pregame)
	pregame.status=Label.new();pregame.add_child(pregame.status)
	pregame.main=MockPage.new();pregame.add_child(pregame.main)
	var clicks:=[0]
	pregame.button_sound_requested.connect(func():clicks[0]+=1)
	pregame.main_action("multibutton")
	check(clicks[0]==0,"Inactive pregame action makes no cue")
	pregame.wanted=true;pregame.page="main";pregame.set_button_audio_status(false)
	check(not pregame.main.visible and pregame.status.visible,"Cold visible menu waits for original button sound")
	pregame.main_action("multibutton")
	check(clicks[0]==0 and pregame.wanted,"Pending audio cannot accept a first action")
	pregame.set_button_audio_status(true)
	check(pregame.main.visible,"Ready sound reveals the first clickable menu")
	pregame.wanted=true;pregame.page="main";pregame.main_action("multibutton")
	check(clicks[0]==1 and not pregame.wanted,"Accepted pregame action makes exactly one cue")
	pregame.queue_free()
	menu.menu_click_player.stop()
	menu.menu_click_player.stream=null
	if is_instance_valid(menu.menu_audio_assets):menu.menu_audio_assets.close()
	menu.queue_free();await process_frame
	for i in 4:await process_frame
	quit(0 if failures.is_empty() else 1)
