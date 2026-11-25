extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Menu=preload("res://systems/native_main_menu.gd")
const Pregame=preload("res://systems/native_pregame_menu.gd")
const Frame=preload("res://systems/native_entry_menu_frame.gd")
const Splash=preload("res://systems/native_startup_splash.gd")
class MockPage:
	extends Control
	var layout_ready:=true
	var buttons: Dictionary={}
	func art_ready() -> bool:return true
	func cohort_snapshot() -> Dictionary:return {"ready":layout_ready,"failures":[],"scope":"test"}
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
	var profile=ProjectSettings.globalize_path("user://nwn81-menu-audio-test")
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
	check(clicks[0]==0 and not pregame.wanted,"The release action does not replay the press cue")
	var page:=Frame.new();root.add_child(page);page.layout_ready=true;page.scope=["test"]
	var button:=Button.new();page.add_child(button);page.buttons["multibutton"]=button
	button.button_down.connect(page.button_down.bind("multibutton"))
	button.pressed.connect(page.invoke.bind("multibutton"))
	page.button_sound_requested.connect(func():clicks[0]+=1)
	var actions:=[0]
	page.action_requested.connect(func(_tag):actions[0]+=1)
	button.button_down.emit()
	check(clicks[0]==1 and actions[0]==0,"An accepted press plays the cue before releasing the action")
	button.pressed.emit()
	check(clicks[0]==1 and actions[0]==1,"Release dispatches one action while keeping one sound")
	button.disabled=true;button.button_down.emit();button.pressed.emit()
	check(clicks[0]==1 and actions[0]==1,"Disabled controls cannot play or run the action")
	button.disabled=false;button.button_down.emit();page.revision+=1;button.pressed.emit()
	check(clicks[0]==2 and actions[0]==1,"Scope retirement rejects a stale release without replaying its cue")
	page.queue_free()
	check(Splash.enabled(profile),"Omitted splash setting uses the original schema default")
	settings=FileAccess.open(profile.path_join("settings.tml"),FileAccess.WRITE)
	settings.store_string("[graphics.intro.splash]\n enabled = false # skip the legal panel\n");settings.close()
	check(not Splash.enabled(profile),"Explicit original splash setting can skip the legal panel")
	var splash:=Splash.new();root.add_child(splash);splash.artwork=TextureRect.new();splash.add_child(splash.artwork)
	splash.artwork.texture=ImageTexture.create_from_image(Image.create_empty(1,1,false,Image.FORMAT_RGBA8))
	splash.open_once();splash.set_process(false);splash._process(0.0)
	check(splash.visible and splash.covers_menu() and is_zero_approx(splash.artwork.modulate.a),"Legal art begins with the stock fade-in")
	splash._process(0.6);splash._process(4.9)
	check(splash.covers_menu() and is_equal_approx(splash.artwork.modulate.a,1.0),"Legal art holds at full opacity before menu admission")
	splash._process(0.2)
	check(splash.visible and not splash.covers_menu() and splash.artwork.modulate.a<1.0,"The main menu can open underneath the fade-out")
	splash._process(1.6);splash.open_once()
	check(not splash.visible and not splash.covers_menu(),"The completed startup splash does not replay on a return to menu")
	splash.queue_free()
	pregame.queue_free()
	menu.menu_click_player.stop()
	menu.menu_click_player.stream=null
	if is_instance_valid(menu.menu_audio_assets):menu.menu_audio_assets.close()
	menu.queue_free();await process_frame
	for i in 4:await process_frame
	quit(0 if failures.is_empty() else 1)
