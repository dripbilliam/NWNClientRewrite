extends SceneTree
# Real original-style chooser owners with local copies of authorized pregame
# replies. Headless CPU responsiveness only, no server connection or GPU claim.
const Lobby=preload("res://systems/character_lobby.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Preview=preload("res://systems/native_character_preview.gd")
var result:={"success":false,"publicConnections":0,"gpuBenchmark":false,"selections":[],"failures":[]}
var args: Dictionary={}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or not args.has("fixture") or FileAccess.file_exists(args.report): quit(2); return
	root.size=Vector2i(1200,850)
	var surface:=SubViewport.new(); surface.size=root.size; root.add_child(surface)
	var catalog:=Catalog.new(); catalog.mount_install(args.install)
	var text=preload("res://systems/native_data/talk_text.gd").new(); text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var resources:=str(args.fixture).path_join("resources")
	for file in DirAccess.get_files_at(resources):
		if file.ends_with(".2da"):
			var bytes:=FileAccess.get_file_as_bytes(resources.path_join(file)); var parser:=preload("res://systems/native_data/two_da.gd").new()
			text.publish_table(file.trim_suffix(".2da"),parser.parse(preload("res://systems/native_data/binary_data.gd").new(bytes).text(0,bytes.size())))
	var painter:=Painter.new(); surface.add_child(painter); painter.configure_source(catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var ui:=Lobby.new(); surface.add_child(ui); ui.configure_native(painter,text,catalog,ProjectSettings.globalize_path("user://native-prepared-v2"))
	var chooser=ui.native_chooser; var end:=Time.get_ticks_msec()+45000
	while not chooser.layout_ready and chooser.failure.is_empty() and Time.get_ticks_msec()<end: await process_frame
	if not chooser.layout_ready: result.failures.append("Original chooser failed to prepare: "+chooser.failure)
	else:
		var values: Array=[]; var choices: Array=[]; var directory:=str(args.fixture).path_join("bic")
		for file in DirAccess.get_files_at(directory):
			if not file.ends_with(".bic"): continue
			var bytes:=FileAccess.get_file_as_bytes(directory.path_join(file)); var job:=Preview.ReadJob.new(); job.packet={"path":directory.path_join(file),"bytes":bytes.size(),"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes)}; job.run(); values.append(job.value)
			choices.append({"key":"server:"+str(values.size()),"source":"server","serverSource":17,"label":"Captured character "+str(values.size()),"classes":job.value.get("classes",[])})
		ui.request.connect(func(_message):pass)
		for round_index in 4:
			for index in values.size():
				var state:={"phase":"character-selection","connected":true,"canSelect":true,"selected":choices[index].key,"choices":choices,"preview":values[index]}
				var began:=Time.get_ticks_usec(); ui.apply_state({"connection":1,"state":state}); var apply_ms:=(Time.get_ticks_usec()-began)/1000.0
				var ready_began:=Time.get_ticks_usec(); var deadline:=Time.get_ticks_msec()+10000
				while not (chooser.record_projection.get("ready",false) and chooser.skill_projection.get("ready",false) and chooser.spell_projection.get("ready",false)) and Time.get_ticks_msec()<deadline: await process_frame
				var ready_ms:=(Time.get_ticks_usec()-ready_began)/1000.0
				began=Time.get_ticks_usec(); chooser.sync(); var repeat_ms:=(Time.get_ticks_usec()-began)/1000.0
				result.selections.append({"round":round_index,"index":index,"apply_ms":apply_ms,"repeat_ms":repeat_ms,"async_ready_ms":ready_ms,"worker":chooser.projection_work.snapshot(),"record_ready":chooser.record_projection.get("ready",false),"skills_ready":chooser.skill_projection.get("ready",false),"spells_ready":chooser.spell_projection.get("ready",false)})
				if args.get("verify","")=="true":
					for pair in [["record",preload("res://systems/native_data/pregame_record.gd"),"recordSource",chooser.record_projection],["skills",preload("res://systems/native_data/pregame_skills.gd"),"skillSource",chooser.skill_projection],["spells",preload("res://systems/native_data/pregame_spells.gd"),"spellSource",chooser.spell_projection]]:
						if pair[3]!=pair[1].compute(values[index][pair[2]],text.tables): result.failures.append("Worker differs from source-faithful fallback: "+str(pair[0])+" selection "+str(index))
				await process_frame
	result.row_count=chooser.rows.size(); ui.close_native(); ui.free(); painter.close(); painter.free(); text.close(); await process_frame; await process_frame
	result.success=result.failures.is_empty(); var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if result.success else 1)
