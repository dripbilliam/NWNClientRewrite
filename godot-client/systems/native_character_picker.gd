extends Control
# Native production picker. Existing lobby owns identity, acknowledgements and
# requests. The optional actor never controls whether Play is available.
const Shell=preload("res://systems/native_character_picker_shell.gd")
const Stage=preload("res://systems/native_character_stage.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
var controller
var shell
var return_button: Button
var text=preload("res://systems/native_data/talk_text.gd").new()
var base_text
var rules=preload("res://systems/native_data/game_ui_rules.gd").new()
var catalog
var cache_path:=""
var assets
var art
var stage
var jobs: Dictionary={}
var row_keys: Array=[]
var show_pregenerated:=false
var details_page:=-1
var last_text_revision:=-1
var portrait_identity:=""
var stage_cached:=false
var closed:=false
func configure(owner) -> void:
	controller=owner; show_pregenerated=owner.preferences.show_pregenerated
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_IGNORE
	shell=Shell.new(); add_child(shell); shell.character_selected.connect(func(key,activate):controller.choose_native(key,activate)); shell.action_requested.connect(action)
	shell.pregenerated_changed.connect(func(on):show_pregenerated=on; sync())
	return_button=shell.button(self,"Back to characters","roster"); return_button.position=Vector2(24,24); return_button.size=Vector2(220,42); return_button.hide()
	rules.text=text; hide()
func configure_base(_painter,source_text,_catalog,_path: String) -> void:
	base_text=source_text
	if catalog==null: text=source_text; rules.text=text; sync()
func configure_source(source_text,source,path: String) -> void:
	if catalog==source: return
	var requested_page:=details_page; clear_source(false); details_page=requested_page; catalog=source; text=source_text; rules.text=text; cache_path=path
	assets=Assets.new(); add_child(assets); assets.configure(source); assets.cache_directory=path; assets.maximum_workers=1; assets.high_priority=true; assets.completed.connect(table_ready)
	for name in ["pregen","classes","portraits"]: jobs[assets.request(name,2017,"2da")]=name
	art=preload("res://systems/native_ui_art.gd").new(); add_child(art); art.configure(source,path); sync()
func table_ready(id: int,value: Dictionary) -> void:
	if closed or not jobs.has(id): return
	var name: String=jobs[id]; jobs.erase(id); text.publish_table(name,value.value if str(value.get("error","")).is_empty() else {"error":str(value.error),"orderedRows":[]}); sync()
func _process(_delta: float) -> void:
	if closed or not is_visible_in_tree(): return
	if text.revision!=last_text_revision: sync()
func available_rows() -> Array:
	var result: Array=[]
	for data in controller.catalog_choices(text):
		if data.get("source")!="server" and (catalog==null or not text.tables.has("pregen")): continue
		if not show_pregenerated and data.get("pregenerated",false): continue
		result.append(data)
	result.sort_custom(func(a,b):return str(a.get("label","")).nocasecmp_to(str(b.get("label","")))<0); return result
func sync() -> void:
	if closed or not is_instance_valid(controller): return
	var state: Dictionary=controller.state; var active: bool=str(state.get("phase","")) in ["character-selection","character-rejected"] and not state.get("creating",false) and controller.panel.visible
	visible=active
	if not active:
		if is_instance_valid(stage): stage.observe([],{},false)
		return
	last_text_revision=text.revision; var choices:=available_rows(); var items: Array=[]; var key:=str(state.get("selected","") if state.get("selected")!=null else ""); row_keys=choices.map(func(row):return str(row.key))
	for data in choices:
		var parts: Array=[]
		for entry in data.get("classes",[]): parts.append(rules.title("classes",int(entry.id))+" "+str(int(entry.level)))
		items.append({"key":str(data.key),"name":str(data.get("label","")),"classes":" / ".join(parts),"source":"Server" if data.get("source")=="server" else "Local","summary":"\n".join(parts)})
	var ready: bool=controller.can_select(); var legacy_ready: bool=is_instance_valid(controller.native_chooser) and controller.native_chooser.layout_ready
	var capabilities:={"select":ready,"play":ready and controller.native_selection.is_empty(),"back":state.get("connected",false) and not state.get("busy",false),"create":state.get("canCreate",false),"delete":controller.delete_reason().is_empty(),"customize":false,"details":ready and key!="","server-info":state.get("canLobbyPages",false),"players":state.get("canLobbyPages",false),"roster":true}
	var endpoint: Variant=state.get("endpoint"); var server_name: String="%s:%s"%[endpoint.host,int(endpoint.port)] if endpoint is Dictionary else "Multiplayer"
	var feedback:=str(state.get("error",""))
	if feedback.is_empty(): feedback=controller.local_notice
	if not controller.delete_lease.is_empty(): feedback="Refreshing local characters…" if controller.delete_lease.get("refreshing",false) else "Confirm whether to delete the selected local character."
	if feedback.is_empty(): feedback="Preparing character data…" if not ready else "Choose a character to enter the world"
	if details_page>=0 and not legacy_ready: feedback="Preparing character details…"
	var pending_key: String=str(controller.native_selection.key) if controller.native_selection.get("connection")==controller.connection else ""
	shell.present([controller.connection],items,key,capabilities,server_name,feedback,pending_key); shell.pregen.set_pressed_no_signal(show_pregenerated); shell.pregen.disabled=not ready
	shell.buttons.delete.tooltip_text=controller.delete_reason(); shell.buttons.customize.tooltip_text="Server-vault characters cannot be customized here." if controller.selected_local_row().get("source")=="server" else "Local character customization is not migrated yet."
	if is_instance_valid(art):
		for row in choices: art.bind_portrait(shell.row_portraits[str(row.key)],rules.portrait({"replicated":row},1))
	if legacy_ready: controller.native_chooser.show_pregenerated=show_pregenerated
	var showing_details: bool=details_page>=0 and legacy_ready; shell.visible=not showing_details; return_button.visible=showing_details
	if showing_details:
		controller.native_chooser.automatic_selection={}
		if controller.native_chooser.page_index!=details_page: controller.native_chooser.select_page(details_page)
		if is_instance_valid(stage): stage.observe([],{},false)
	else: sync_preview(key,choices)
	if ready and controller.post_delete_index<0 and not row_keys.is_empty() and not row_keys.has(key) and controller.native_selection.is_empty(): controller.choose_native(str(row_keys[0]))
func sync_preview(key: String,choices: Array) -> void:
	var identity:=str([controller.connection,key])
	if identity!=portrait_identity: portrait_identity=identity; shell.portrait.texture=null
	var row: Dictionary={}
	for entry in choices:
		if str(entry.key)==key: row=entry; break
	var value: Variant=controller.record_preview(); var preview: Dictionary=value if value is Dictionary else {}
	if is_instance_valid(art) and not row.is_empty(): art.bind_portrait(shell.portrait,rules.portrait({"replicated":preview if preview.has("portrait") or preview.has("portraitRef") else row},4))
	var packet: Variant=controller.state.get("preview")
	var source: Dictionary=preview.get("visualSource",{}); var signature:=str(packet.get("sha256","")) if packet is Dictionary else ""
	stage_cached=false
	if not source.get("equipmentComplete",false):
		var cached: Dictionary=controller.appearance_cache.read_seen(controller.appearance_cache.identity(controller.state))
		if not cached.is_empty(): source=cached.source; signature="last-seen:"+str(cached.digest); stage_cached=true
	if key.is_empty() or source.is_empty():
		if is_instance_valid(stage): stage.observe([],{},false)
		shell.portrait.show(); shell.stage_status.text="Waiting for the selected character's preview…" if not key.is_empty() else "Select a character to see their appearance"; return
	if catalog==null: return
	if not is_instance_valid(stage):
		stage=Stage.new(); shell.preview_mount.add_child(stage); stage.changed.connect(stage_changed); stage.configure(catalog,cache_path)
	stage.observe([controller.connection,key,signature],source)
func stage_changed(value: Dictionary) -> void:
	shell.stage_status.text=("Last seen appearance · " if stage_cached else "")+"Drag to rotate · Wheel to zoom" if value.phase=="ready" else ("Preparing last seen appearance…" if stage_cached and value.phase=="preparing" else str(value.get("message",""))); shell.portrait.visible=value.phase!="ready"
func action(tag: String) -> void:
	if not visible: return
	match tag:
		"play": controller._play()
		"back": controller._send({"kind":"lobby-disconnect","saveCharacter":false})
		"create": controller.create_button.pressed.emit()
		"delete": controller.begin_delete()
		"details","server-info","players":
			details_page={"details":0,"server-info":1,"players":2}[tag]
			if is_instance_valid(controller.native_chooser): controller.native_chooser.automatic_selection={}
			controller.sync_native()
		"roster": details_page=-1; controller.sync_native()
func clear_source(persist: bool=true) -> void:
	if persist: controller.preferences.save(show_pregenerated)
	if is_instance_valid(stage): stage.close(); stage.queue_free()
	stage=null
	for owner in [assets,art]:
		if is_instance_valid(owner): owner.close(); owner.queue_free()
	assets=null; art=null; catalog=null; jobs.clear(); details_page=-1
	if base_text!=null: text=base_text; rules.text=text
func close() -> void:
	if closed: return
	clear_source(); closed=true; hide()
