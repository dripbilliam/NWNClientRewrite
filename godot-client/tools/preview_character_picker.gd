extends SceneTree
# Offline original BIC preview: no credentials, sockets or world admission.
const Shell=preload("res://systems/native_character_picker_shell.gd")
const Stage=preload("res://systems/native_character_stage.gd")
const Loader=preload("res://systems/native_data/session_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Gff=preload("res://systems/native_data/gff_document.gd")
const Metadata=preload("res://systems/native_data/local_character_metadata.gd")
const Visual=preload("res://systems/native_data/bic_visual.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var shell
var character_stage
var loader
var assets
var art
var text=preload("res://systems/native_data/talk_text.gd").new()
var rules=preload("res://systems/native_data/game_ui_rules.gd").new()
var install:=""
var cache:=""
var selected:=""
var sources: Dictionary={}
var task:=-1
var result: Array=[]
var gate:=Mutex.new()
var jobs: Dictionary={}
var closed:=false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.title="NWN · Offline character picker preview"; root.size=Vector2i(1280,800); auto_accept_quit=false; root.close_requested.connect(shutdown)
	var area:=DisplayServer.screen_get_usable_rect(root.current_screen); root.position=area.position+(area.size-root.size)/2; root.window_input.connect(activate_from_click)
	shell=Shell.new(); root.add_child(shell); shell.present(["offline"],[],"",{"back":true},"Offline preview","Reading original installed characters…")
	character_stage=Stage.new(); shell.preview_mount.add_child(character_stage); character_stage.changed.connect(stage_changed)
	shell.character_selected.connect(func(key,_activate):selected=key; refresh()); shell.action_requested.connect(func(tag):
		if tag=="back": shutdown())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--install="): install=arg.substr(10)
	if install.is_empty(): shell.status.text="Specify an original installation to load character models."; return
	cache=ProjectSettings.globalize_path("user://native-prepared-v2"); var directory:=install.path_join("data/lcv")
	task=WorkerThreadPool.add_task(func():
		var rows: Array=[]
		for name in ["wizard.bic","druid.bic","fighter.bic"]:
			var bytes:=FileAccess.get_file_as_bytes(directory.path_join(name)); var parser:=Gff.new(); var document:=parser.parse(bytes,"BIC ")
			if not parser.failure.is_empty(): continue
			rows.append({"key":name,"metadata":Metadata.project(document),"visual":Visual.source(document),"sha256":Cache.digest(bytes)})
		gate.lock(); result=rows; gate.unlock(),false,"Read original picker characters")
	loader=Loader.new(); root.add_child(loader); loader.completed.connect(catalog_ready); loader.start({"install":install})
	process_frame.connect(tick); print("PICKER_PREVIEW_SHELL_READY screen=",root.current_screen," unfocusable=",root.unfocusable)
func catalog_ready(_serial: int,catalog: RefCounted,error: String,_stats: Dictionary) -> void:
	if closed: return
	if not error.is_empty(): shell.status.text=error; return
	text.base.open_file(install.path_join("lang/en/data/dialog.tlk")); rules.text=text
	assets=Assets.new(); root.add_child(assets); assets.configure(catalog); assets.cache_directory=cache; assets.completed.connect(table_ready)
	for name in ["classes","portraits"]: jobs[assets.request(name,2017,"2da")]=name
	art=preload("res://systems/native_ui_art.gd").new(); root.add_child(art); art.configure(catalog,cache)
	character_stage.configure(catalog,cache); refresh()
func table_ready(id: int,value: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id)
	if str(value.get("error","")).is_empty(): text.publish_table(name,value.value)
	refresh()
func tick() -> void:
	if closed or task<0 or not WorkerThreadPool.is_task_completed(task): return
	WorkerThreadPool.wait_for_task_completion(task); task=-1; gate.lock(); var rows:=result; result=[]; gate.unlock()
	for row in rows: sources[row.key]=row
	if not rows.is_empty(): selected=str(rows[0].key)
	refresh()
func refresh() -> void:
	if closed: return
	var characters: Array=[]
	for key in sources:
		var data: Dictionary=sources[key].metadata; var parts: Array=[]
		for entry in data.classes:
			var name:=rules.title("classes",int(entry.id)) if is_instance_valid(assets) else ""
			parts.append((name if not name.is_empty() else "Class "+str(int(entry.id)))+" "+str(int(entry.level)))
		var first: Dictionary=preload("res://systems/native_data/character_preview.gd").localized(data.firstName,0,0); var last: Dictionary=preload("res://systems/native_data/character_preview.gd").localized(data.lastName,0,0)
		characters.append({"key":key,"name":text.name({"firstName":first,"lastName":last},-1),"classes":" / ".join(parts),"source":"Installed","summary":"\n".join(parts)+"\n\nOriginal installed character · offline preview"})
	shell.present(["offline"],characters,selected,{"select":true,"back":true},"Offline character preview","Original BICs · no server connection")
	if is_instance_valid(art):
		for key in sources: art.bind_portrait(shell.row_portraits[key],rules.portrait({"replicated":sources[key].metadata},1))
	if not sources.has(selected) or not is_instance_valid(character_stage.asset_service): return
	var chosen: Dictionary=sources[selected]; character_stage.observe(["offline",selected,chosen.sha256],chosen.visual)
	if is_instance_valid(art): art.bind_portrait(shell.portrait,rules.portrait({"replicated":chosen.metadata},4))
func stage_changed(state: Dictionary) -> void:
	shell.stage_status.text="Drag to rotate · Wheel to zoom" if state.phase=="ready" else str(state.get("message","Preparing appearance…")); shell.portrait.visible=state.phase!="ready"
func activate_from_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: root.window_input.disconnect(activate_from_click); root.unfocusable=false; root.grab_focus()
func shutdown() -> void:
	if closed: return
	closed=true
	if task>=0: WorkerThreadPool.wait_for_task_completion(task); task=-1
	if is_instance_valid(character_stage): character_stage.close()
	if is_instance_valid(assets): assets.close()
	if is_instance_valid(art): art.close()
	if is_instance_valid(loader): loader.close()
	text.close(); quit()
