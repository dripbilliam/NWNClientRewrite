extends SceneTree
# Actual default source chooser, received BIC tickets, real installed source
# assets/fonts and authored server acknowledgments. No network or GPU timing.
const Reader=preload("res://systems/native_character_preview.gd")
const Lobby=preload("res://systems/character_lobby.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const PRecord=preload("res://systems/native_data/pregame_record.gd")
const PSkills=preload("res://systems/native_data/pregame_skills.gd")
const PSpells=preload("res://systems/native_data/pregame_spells.gd")
var samples: Array=[]
var records: Array=[]
var packets: Array=[]
var output_path:=""
var surface: SubViewport
var ui
var native
var state: Dictionary={}
var checks:=0
var failures: Array=[]
var requests: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func _initialize() -> void:run.call_deferred()
func wait_until(predicate: Callable) -> bool:
	var deadline:=Time.get_ticks_msec()+10000
	while not predicate.call() and Time.get_ticks_msec()<deadline:await process_frame
	return predicate.call()
func input_down(key_value: String) -> int:
	var index: int=native.row_keys.find(key_value);var point: Vector2=native.rows[index].get_global_rect().get_center()
	var motion_event:=InputEventMouseMotion.new();motion_event.position=point;motion_event.global_position=point;surface.push_input(motion_event,true)
	var event:=InputEventMouseButton.new();event.position=point;event.global_position=point;event.pressed=true;event.button_index=MOUSE_BUTTON_LEFT;event.button_mask=MOUSE_BUTTON_MASK_LEFT
	var began:=Time.get_ticks_usec();surface.push_input(event,true);var elapsed:=Time.get_ticks_usec()-began
	event=InputEventMouseButton.new();event.position=point;event.global_position=point;event.pressed=false;event.button_index=MOUSE_BUTTON_LEFT;surface.push_input(event,true)
	return elapsed
func ready_for(key_value: String) -> bool:
	return ui.native_selection.is_empty() and ui.state.get("selected")==key_value and ui.native_preview.accepted.size()>1 and ui.native_preview.accepted[1]==key_value and native.record_projection.get("ready",false) and native.skill_projection.get("ready",false) and native.spell_projection.get("ready",false)
func select_record(index: int,round_index: int) -> void:
	var key_value: String="server:"+str(index);native.picker_diagnostic_spans.clear();ui.picker_diagnostic_spans.clear();native.projection_work.diagnostic_table_captures.clear()
	var count:=requests.size();var press_us:=input_down(key_value)
	check(requests.size()==count+1 and requests.back().kind=="lobby-choose" and requests.back().key==key_value,"Actual source row pointer sends the current exact selection nonce")
	var nonce: int=int(requests.back().requestId)
	state.selected=key_value;state.preview=packets[index];state.selectionAck={"key":key_value,"requestId":nonce}
	var began:=Time.get_ticks_usec();ui.apply_state({"connection":1,"state":state.duplicate(true)});var apply_us:=Time.get_ticks_usec()-began
	var ready_began:=Time.get_ticks_usec();check(await wait_until(func():return ready_for(key_value) or not ui.native_preview.error.is_empty()),"Actual ticket reader and record projections reach their current selected owner")
	var ready_us:=Time.get_ticks_usec()-ready_began
	check(ui.native_preview.error.is_empty() and ready_for(key_value),"No decoded/stale preview replaces the selected record")
	var work: Dictionary=native.projection_work.snapshot();var spans: Array=native.picker_diagnostic_spans.duplicate(true);var controller_spans: Array=ui.picker_diagnostic_spans.duplicate(true);var tables: Array=native.projection_work.diagnostic_table_captures.duplicate(true)
	began=Time.get_ticks_usec();native.sync();var repeated_us:=Time.get_ticks_usec()-began
	check(native.record_projection==PRecord.compute(records[index].recordSource,native.text_owner.tables),"Record equals existing canonical pregame projection")
	check(native.skill_projection==PSkills.compute(records[index].skillSource,native.text_owner.tables),"Skills equal existing canonical pregame projection")
	check(native.spell_projection==PSpells.compute(records[index].spellSource,native.text_owner.tables),"Spells equal existing canonical pregame projection")
	check(native.record_labels.armorclass.text==str(native.record_projection.armorClass) and native.record_labels.hitpoints.text==str(native.record_projection.currentHP)+"/"+str(native.record_projection.maximumHP),"Actual installed record Controls show the selected received values")
	check(not native.buttons.playbutton.disabled and requests.all(func(row):return row.kind!="lobby-play"),"Exact selection completion enables Play without submitting a character")
	samples.append({"round":round_index,"index":index,"cold":round_index==0 and index==1,"pointer_us":press_us,"apply_state_us":apply_us,"ready_schedule_us":ready_us,"repeat_sync_us":repeated_us,"worker":work,"chooser_spans":spans,"controller_spans":controller_spans,"table_captures":tables,"preview_worker":ui.native_preview.snapshot()})
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","fixture","install"]) or FileAccess.file_exists(args.report):quit(2);return
	output_path=args.report;root.size=Vector2i(1200,850);surface=SubViewport.new();surface.size=root.size;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;surface.gui_disable_input=false;surface.handle_input_locally=true;root.add_child(surface);surface.notify_mouse_entered()
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Read-only installed native layout/model/font assets")
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Actual installed base TLK")
	for filename in DirAccess.get_files_at(str(args.fixture).path_join("resources")):
		if filename.ends_with(".2da"):
			var bytes:=FileAccess.get_file_as_bytes(str(args.fixture).path_join("resources").path_join(filename));var parser:=preload("res://systems/native_data/two_da.gd").new();text.publish_table(filename.trim_suffix(".2da"),parser.parse(preload("res://systems/native_data/binary_data.gd").new(bytes).text(0,bytes.size())));check(parser.failure.is_empty(),"Captured active table parses "+filename)
	var directory:=str(args.fixture).path_join("bic");var choices: Array=[]
	for filename in DirAccess.get_files_at(directory):
		if not filename.ends_with(".bic"):continue
		var file:=directory.path_join(filename);var bytes:=FileAccess.get_file_as_bytes(file);var packet:={"format":"native-bic-file-v1","path":file,"bytes":bytes.size(),"sha256":FileAccess.get_sha256(file)};var reader:=Reader.ReadJob.new();reader.packet=packet;reader.run();check(reader.error.is_empty(),"Captured received BIC is decoded by the actual native reader")
		records.append(reader.value);packets.append(packet);choices.append({"key":"server:"+str(choices.size()),"source":"server","serverSource":17,"label":"Captured "+str(choices.size()),"classes":reader.value.get("classes",[])})
	check(records.size()==3,"Three distinct previously received server-vault entries are available offline")
	var painter:=Painter.new();surface.add_child(painter);painter.configure_source(catalog,"")
	ui=Lobby.new();surface.add_child(ui);ui.preferences.open_file("");ui.configure_preview(directory);ui.request.connect(func(message):requests.append(message.duplicate(true)));ui.configure_native(painter,text,catalog,"");native=ui.native_chooser
	check(await wait_until(func():return native.layout_ready or not native.failure.is_empty()),"Actual default source chooser layout prepares")
	check(native.failure.is_empty(),"Installed source geometry/attachment hooks are valid")
	if native.layout_ready and records.size()==3:
		state={"phase":"character-selection","connected":true,"canSelect":true,"selected":"server:0","choices":choices,"preview":null};ui.apply_state({"connection":1,"state":state.duplicate(true)});await process_frame;await process_frame
		for round_index in 2:
			for index in [1,2,0]:await select_record(index,round_index)
		var first_count:=requests.size();input_down("server:1");var first: Dictionary=requests.back().duplicate();input_down("server:2");var latest: Dictionary=requests.back().duplicate()
		state.selected="server:1";state.preview=packets[1];state.selectionAck={"key":"server:1","requestId":first.requestId};ui.apply_state({"connection":1,"state":state.duplicate(true)})
		check(ui.native_selection.key=="server:2" and native.buttons.playbutton.disabled,"An older acknowledgment cannot release the latest pending pointer selection")
		state.selected="server:2";state.preview=packets[2];state.selectionAck={"key":"server:2","requestId":latest.requestId};ui.apply_state({"connection":1,"state":state.duplicate(true)});check(await wait_until(func():return ready_for("server:2")),"Rapid supersession finally presents only its latest current record")
		check(requests.size()==first_count+2 and requests.all(func(row):return row.kind!="lobby-play"),"Rapid switching never submits Play")
	ui.close_native();check(native.closed and not native.projection_work.snapshot().running,"Retirement joins only the probe's own current projection worker");ui.free();painter.close();painter.free();text.close();await process_frame;surface.free();await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"gpuBenchmark":false,"liveClientTouched":false,"scope":"Actual default original-style picker pointer input, exact authored acknowledgments and previously received BIC byte tickets with installed native source models/fonts, three record projections and rapid supersession. CPU phases only; cached data and authored receive timing, no current-server/user-visible latency or rendered-pixel claim."}
	var output:=FileAccess.open(output_path,FileAccess.WRITE);output.store_string(JSON.stringify(result,"  "));output.close();quit(0 if result.success else 1)
