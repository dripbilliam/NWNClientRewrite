extends "res://tools/preview_character_picker.gd"
# Exercise the actual interactive prototype, not a second UI implementation.
var report_path:=""
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func wait_for(predicate: Callable) -> bool:
	var end:=Time.get_ticks_msec()+60000
	while not predicate.call() and Time.get_ticks_msec()<end: await process_frame
	return predicate.call()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path=arg.substr(9)
	if report_path.is_empty() or FileAccess.file_exists(report_path): quit(2); return
	super.run()
	check(shell.built and sources.is_empty() and not character_stage.actor_ready,"Actual prototype shell exists before BIC/catalog/model work completes")
	check(await wait_for(func():return character_stage.state.phase in ["ready","unavailable"]),"The actual picker prototype reaches a model terminal state")
	check(sources.size()==3 and shell.rows.size()==3 and character_stage.actor_ready,"Actual installed BIC names and a real native model populate the same initial shell")
	check(shell.play.disabled and not shell.buttons.back.disabled,"Offline preview cannot fabricate server admission or enable Enter World")
	check(shell.title.text!="Ilivara Claddath" and shell.title.text==text.name({"firstName":preload("res://systems/native_data/character_preview.gd").localized(sources[selected].metadata.firstName,0,0),"lastName":preload("res://systems/native_data/character_preview.gd").localized(sources[selected].metadata.lastName,0,0)},-1),"Sample labels were replaced by the actual original character name")
	var first: String=selected; var another: String="fighter.bic" if first!="fighter.bic" else "druid.bic"
	var button: Button=shell.rows[another]; var point:=button.get_global_rect().get_center(); var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; root.push_input(motion,true); await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.pressed=pressed; event.button_index=MOUSE_BUTTON_LEFT; root.push_input(event,true); await process_frame
	check(selected==another and character_stage.wanted[1]==another,"Actual roster pointer input selects the correct BIC/model identity")
	check(await wait_for(func():return character_stage.actor_ready and character_stage.state.identity[1]==another),"Changing roster entries installs the newly selected original character")
	check(shell.stage_status.text.contains("Drag to rotate") and not shell.portrait.visible,"Ready model replaces the portrait fallback and exposes preview controls")
	if DisplayServer.get_name()!="headless":
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(report_path.trim_suffix(".json")+".png")==OK,"Actual integrated offline picker/model screenshot captured")
	var model: Dictionary=character_stage.stream.snapshot(); var build_us: int=shell.built_us
	character_stage.close(); check(character_stage.closed and not is_instance_valid(character_stage.stream),"The actual preview owner retires the selected actor on close")
	var file:=FileAccess.open(report_path,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"model":model,"shell_build_us":build_us,"publicConnections":0,"offlinePrototype":true,"livePickerIntegrated":false,"fullUiParity":false,"scope":"Actual offline prototype with original BICs, native model preparation, real pointer selection, portrait fallback and cleanup. Online-vault appearance completeness and production picker integration remain unaccepted."},"  ")+"\n"); file.close()
	shutdown()
