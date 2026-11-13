extends SceneTree
const Pregame=preload("res://systems/native_pregame_menu.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var output:=""
	var install:=""
	var graphical:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		elif arg.begins_with("--install="): install=arg.substr(10)
		elif arg=="--graphical": graphical=true
	if output.is_empty() or FileAccess.file_exists(output) or not install.is_absolute_path(): quit(2); return
	if graphical:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		var primary:=DisplayServer.get_primary_screen()
		for screen in DisplayServer.get_screen_count():
			if screen!=primary:
				root.current_screen=screen
				root.position=DisplayServer.screen_get_position(screen)+Vector2i(80,80)
				break
		root.size=Vector2i(1000,760)
	var menu:=Pregame.new(); root.add_child(menu)
	menu.configure({"install":install,"modsDirectory":"","disabledMods":[]},ProjectSettings.globalize_path("user://native-prepared-v2"),"",null)
	menu.open()
	var samples: Array=[]
	var last_state:=""
	var deadline:=Time.get_ticks_msec()+12000
	var first_art_ready_before_cohort:=false
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if not menu.failure.is_empty(): break
		if not is_instance_valid(menu.options): continue
		var cohort: Dictionary=menu.options.cohort_snapshot()
		if menu.options.art_ready() and not cohort.ready: first_art_ready_before_cohort=true
		var state:=str(cohort.sealed)+":"+str(cohort.models_ready)+":"+str(cohort.images_ready)+":"+str(cohort.fonts_ready)+":"+str(cohort.failures)
		if state!=last_state and (samples.size()<7 or cohort.ready or not cohort.failures.is_empty()):
			last_state=state; samples.append({"elapsed_ms":12000-(deadline-Time.get_ticks_msec()),"cohort":cohort})
		if cohort.ready or not cohort.failures.is_empty(): break
	var ready: bool=is_instance_valid(menu.options) and bool(menu.options.cohort_snapshot().ready)
	var untagged: Array=[]
	if ready:
		for owner in [menu.options.stage,menu.options.confirmation]:
			for label in owner.find_children("*","Label",true,false):
				if not label.text.is_empty() and str(label.get_meta("native_font_resource","")).is_empty(): untagged.append(str(label.name))
		menu.main_action("optionsbutton")
		for index in 4: await process_frame
	var visible: bool=ready and menu.page=="options" and menu.options.visible and menu.options.art_ready()
	var reopened:=false
	if visible:
		menu.dismiss(); menu.open(); menu.main_action("optionsbutton")
		for index in 4: await process_frame
		reopened=menu.options.cohort_snapshot().ready and menu.options.visible
	var result: Dictionary={"success":ready and untagged.is_empty() and visible and reopened and (not graphical or root.get_flag(Window.FLAG_NO_FOCUS) and root.current_screen!=DisplayServer.get_primary_screen()),"cohort":menu.options.cohort_snapshot() if is_instance_valid(menu.options) else {},"samples":samples,"first_art_ready_before_cohort":first_art_ready_before_cohort,"visible":visible,"reopened":reopened,"untagged_nonempty_labels":untagged,"menu_failure":menu.failure,"page_failure":menu.options.failure if is_instance_valid(menu.options) else "No options page","elapsed_ms":12000-(deadline-Time.get_ticks_msec()),"graphical":graphical,"no_focus":root.get_flag(Window.FLAG_NO_FOCUS) if graphical else true,"secondary":root.current_screen!=DisplayServer.get_primary_screen() if graphical else true}
	menu.close()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close()
	quit(0 if result.success else 1)
