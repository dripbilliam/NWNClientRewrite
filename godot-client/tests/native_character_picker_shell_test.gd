extends SceneTree
const Shell=preload("res://systems/native_character_picker_shell.gd")
var checks:=0
var failures: Array=[]
var actions: Array=[]
var selections: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1280,800)
	var shell:=Shell.new(); root.add_child(shell)
	check(shell.built and shell.roster!=null and shell.preview_mount!=null and shell.play.disabled,"Complete picker shell builds synchronously before any frame, catalog, bitmap or preview exists")
	check(shell.get_children().all(func(node):return node is Control),"Immediate shell creates only native UI nodes with no asset or model service")
	shell.action_requested.connect(func(tag):actions.append(tag)); shell.character_selected.connect(func(key,activate):selections.append([key,activate]))
	var a:={"key":"server:a","name":"Ilivara Claddath","classes":"Wizard / Pale Master","source":"Server","summary":"Wizard17\nPale Master3"}
	var b:={"key":"local:b","name":"Nibs","classes":"Druid17","source":"Local"}
	var allowed:={"select":true,"play":true,"back":true,"create":true,"details":true,"server-info":true,"players":true}
	shell.present([1],[a,b],"server:a",allowed,"Owned localhost","Two characters received")
	check(shell.row_keys==["server:a","local:b"] and shell.title.text==a.name and shell.row_classes[a.key].text==a.classes and shell.row_names[a.key].text==a.name and shell.row_portraits[a.key].texture==null,"Actual provided roster identity, names, source and classes populate stable portrait rows before artwork")
	check(not shell.play.disabled and shell.portrait.texture==null,"A valid selection enables Play before any portrait or3D preview loads")
	shell.play.button_down.emit(); shell.play.pressed.emit(); check(actions==["play"],"Play action reaches its connection owner without waiting for a preview")
	shell.play.button_down.emit(); shell.present([2],[a,b],"server:a",allowed,"Another connection"); shell.play.pressed.emit()
	check(actions==["play"],"A press captured on a retired connection cannot submit a character")
	shell.play.button_down.emit(); shell.present([2],[a,b],"local:b",allowed,"Owned localhost"); shell.play.pressed.emit()
	check(actions==["play"],"Changing selection during a held Play press cannot enter another character")
	shell.rows[a.key].button_down.emit(); shell.rows[a.key].pressed.emit(); check(selections==[["server:a",false]],"Roster input emits the provided character key without inventing a new identity")
	var unavailable:=allowed.duplicate(); unavailable.play=false; unavailable.select=false
	shell.present([2],[a,b],"local:b",unavailable,"Owned localhost","Server is busy"); shell.play.button_down.emit(); shell.play.pressed.emit()
	check(shell.play.disabled and shell.rows[a.key].disabled and actions==["play"],"Authoritative unavailability disables selection and Play while feedback remains visible")
	shell.present([2],[],"local:b",allowed,"Owned localhost"); check(shell.play.disabled and shell.empty.visible,"An empty roster cannot retain a selectable retired character")
	await process_frame; await process_frame
	check(shell.preview_mount.get_global_rect().size.x>=200 and shell.stage.get_global_rect().size.y>=220,"Standard-window layout allocates a bounded independent character stage")
	if DisplayServer.get_name()!="headless":
		shell.present([3],[a,b],"server:a",allowed,"Owned local server","Character list received"); await process_frame; await process_frame; await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")==OK,"Native prototype screenshot saved for layout review with explicit sample records")
	var build_us: int=shell.built_us; shell.free(); await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"shell_build_us":build_us,"publicConnections":0,"prototype":true,"integrated":false,"preview3DImplemented":false,"fullUiParity":false,"scope":"Immediate native picker composition and real signal semantics with supplied test records. Full graphical/input/local-server integration and native3D preview remain unfinished."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
