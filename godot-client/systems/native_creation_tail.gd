extends Node
# Own the first-level source Appearance -> Character Information transaction.
# The frontend's one current child ticket remains live through both panes.
const Provider=preload("res://systems/native_data/creation_tail_provider.gd")
const TailBic=preload("res://systems/native_data/creation_tail_bic.gd")
const Snapshot=preload("res://systems/native_data/creation_tail_snapshot.gd")
const PaletteTexture=preload("res://systems/native_data/gui_palette_texture.gd")
class Preparation extends RefCounted:
	var catalog
	var tables: Dictionary={}
	var selection: Dictionary={}
	var result: Dictionary={}
	func run() -> void:
		var index_began:=Time.get_ticks_usec();var names: Array=catalog.resource_names(2002);var index_ms: float=(Time.get_ticks_usec()-index_began)/1000.0;var loads: Dictionary={};var palettes: Dictionary={};var palette_hashes: Dictionary={}
		var candidates:=Provider.clothing_candidates(tables.get("chargenclothes",{}),selection)
		if not candidates.ready:result=candidates;return
		for candidate in candidates.candidates:
			var name: String=candidate.resRef
			if name.is_empty() or loads.has(name):continue
			if not catalog.has_resource(name,2025):loads[name]={"status":"absent"};continue
			var bytes: PackedByteArray=catalog.get_resource(name,2025);var parser=preload("res://systems/native_data/gff_document.gd").new();var document:=parser.parse(bytes,"UTI ")
			loads[name]={"status":"ready" if catalog.failure.is_empty() and parser.failure.is_empty() else "decode-failed","document":document,"sha256":preload("res://systems/native_data/prepared_cache.gd").digest(bytes)}
		for name in Provider.PALETTES.values():
			if palettes.has(name):continue
			var bytes: PackedByteArray=catalog.get_resource(name,3);var parser=preload("res://systems/native_data/texture_data.gd").new();palettes[name]=parser.parse(bytes,3) if catalog.failure.is_empty() else {};palette_hashes[name]=preload("res://systems/native_data/prepared_cache.gd").digest(bytes)
		result=Provider.appearance(tables,selection,names,loads,palettes)
		if result.ready:
			var palette_rows:=PaletteTexture.rows(palettes,palette_hashes)
			result.context.paletteRows=palette_rows.rows if palette_rows.ready else {};result.context.paletteSourceHashes=palette_rows.sources if palette_rows.ready else {}
			if not palette_rows.ready:result.context.paletteRowsUnavailable=str(palette_rows.reason)
			result.loads=loads;result.workerThread=OS.get_thread_caller_id();result.resourceIndexMs=index_ms;result.modelResourceCount=names.size()
var creator
var front
var appearance
var information
var names
var identity: Array=[]
var ticket: Array=[]
var source_signature: Array=[]
var text_revision:=-1
var stage:=""
var generation:=0
var task:=-1
var work
var work_generation:=-1
var preparation_queued:=false
var prepared: Dictionary={}
var name_jobs: Dictionary={}
var original_parent
var original_index:=-1
var restore_pending:=false
var attach_pending: Dictionary={}
var failure:=""
var closed:=false
var status_label: Label
var callback_timings: Array=[]
func measured(event: String,began: int) -> void:
	callback_timings.append({"event":event,"usec":Time.get_ticks_usec()-began})
	if callback_timings.size()>64:callback_timings.pop_front()
func configure(owner,painter,text,base_catalog,cache_path: String) -> void:
	creator=owner;front=owner.source_frontend
	appearance=preload("res://systems/native_appearance_chooser.gd").new();front.surface.add_child(appearance);appearance.configure(painter,text,base_catalog,cache_path);appearance.prepared.connect(place);appearance.finished.connect(appearance_result);appearance.preview_attached.connect(attach_preview);appearance.preview_changed.connect(preview_changed);appearance.start()
	information=preload("res://systems/native_character_info_chooser.gd").new();front.surface.add_child(information);information.configure(painter,text,base_catalog,cache_path);information.prepared.connect(place);information.finished.connect(information_result);information.voice_requested.connect(voice_requested);information.random_requested.connect(random_requested);information.start()
	names=preload("res://systems/native_character_names.gd").new();add_child(names);names.prepared.connect(names_prepared);names.names_ready.connect(names_ready)
	creator.preview.retirement_drained.connect(preview_drained)
	front.get_viewport().size_changed.connect(place)
func signature() -> Array:
	var d: Dictionary=creator.rules.draft
	return [d.get("raceId"),d.get("gender"),d.get("classId"),d.get("lawChaos"),d.get("goodEvil"),d.get("packageId")]
func parent_current() -> bool:
	return not closed and not creator.dead and creator.phase=="editing" and creator.summary_identity()==identity and front.owns(ticket)
func current() -> bool:return parent_current() and signature()==source_signature and int(creator.ui.text.revision)==text_revision
func open(value_ticket: Array) -> void:
	var began:=Time.get_ticks_usec();open_transaction(value_ticket);measured("open",began)
func open_transaction(value_ticket: Array) -> void:
	retire()
	if closed or not front.owns(value_ticket) or creator.phase!="editing":return
	if int(front.context.get("customizeMode",0))!=0:
		failure="Existing-character customization is unavailable.";front.accept_child(value_ticket,2);return
	identity=creator.summary_identity();ticket=value_ticket.duplicate();source_signature=signature();text_revision=int(creator.ui.text.revision);stage="preparing";failure=""
	appearance.set_context({},ticket);appearance.open();place()
	if task>=0:preparation_queued=true;return
	start_preparation()
func start_preparation() -> void:
	var d: Dictionary=creator.rules.draft;work=Preparation.new();work.catalog=creator.ui.catalog.fork()
	work.tables=Snapshot.capture(creator.rules.tables,int(d.raceId))
	work.selection={"mode":0,"classes":[int(d.classId)],"raceId":int(d.raceId),"gender":int(d.gender),"lawChaos":int(d.lawChaos),"goodEvil":int(d.goodEvil),"phenotype":255,"head":int(d.head),"skin":int(d.skin),"hair":int(d.hair),"tattoo1":int(d.tattoo1),"tattoo2":int(d.tattoo2)}
	work_generation=generation;task=WorkerThreadPool.add_task(work.run,false,"Native creation tail resources")
func _process(_delta: float) -> void:
	if restore_pending and creator.preview.retiring.is_empty():restore_surface()
	if not ticket.is_empty() and not current():
		var old:=ticket.duplicate();var accepted:=parent_current();retire()
		if accepted:front.accept_child(old,2)
	# A prior name worker can finish draining after the new resources signal.
	# Observe only this pending owned job, so readiness cannot be lost on reopen.
	if stage=="information" and current() and not information.random_ready and names.available(ticket):information.set_random_ready(true,ticket)
	if task<0 or not WorkerThreadPool.is_task_completed(task):return
	WorkerThreadPool.wait_for_task_completion(task);task=-1;var result: Dictionary=work.result;work=null
	if preparation_queued:
		preparation_queued=false
		if current():start_preparation()
		return
	if not current() or work_generation!=generation:return
	if not result.get("ready",false):failure=str(result.get("reason","Native appearance is unavailable."));show_status();return
	prepared=result;stage="appearance";appearance.set_context(prepared.context,ticket);appearance.open();place()
func place() -> void:
	if closed or not is_instance_valid(front):return
	var extent: Vector2=front.get_viewport().get_visible_rect().size
	for pane in [appearance,information]:
		if pane.size.x<=0 or pane.size.y<=0:continue
		var factor:=minf(1,minf(extent.x/pane.size.x,extent.y/pane.size.y));pane.scale=Vector2.ONE*factor;pane.position=(extent-pane.size*factor)*.5
	show_status()
func show_status() -> void:
	if not is_instance_valid(appearance.preview_slot):return
	if appearance.buttons.has("okbutton"):appearance.buttons.okbutton.disabled=stage!="appearance"
	if not is_instance_valid(status_label):
		status_label=Label.new();appearance.preview_slot.add_child(status_label);status_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;status_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;status_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);appearance.frame.font_style(status_label,{"AurString_Font":"fnt_dialog14x14"})
	status_label.text=failure if not failure.is_empty() else "Preparing appearance…" if stage=="preparing" else ""
	status_label.visible=not status_label.text.is_empty() and stage in ["preparing","appearance"]
func attach_preview(slot: Control,value_ticket: Array) -> void:
	if not current() or ticket!=value_ticket or stage!="appearance":return
	var preview=creator.preview;var view=preview.view;preview.stop()
	if not is_instance_valid(original_parent):original_parent=view.surface.get_parent();original_index=view.surface.get_index()
	restore_pending=false;view.active=true
	if view.surface.get_parent()!=slot and not preview.retiring.is_empty():attach_pending={"slot":weakref(slot),"ticket":ticket.duplicate()};return
	attach_surface(slot)
func attach_surface(slot: Control) -> void:
	var view=creator.preview.view;attach_pending={}
	if view.surface.get_parent()!=slot:view.surface.reparent(slot,false)
	view.surface.custom_minimum_size=Vector2.ZERO;view.surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);view.active=true
func preview_drained() -> void:
	if not ticket.is_empty() and not current():retire();return
	if not attach_pending.is_empty():
		var slot=attach_pending.slot.get_ref()
		if current() and attach_pending.ticket==ticket and is_instance_valid(slot):attach_surface(slot)
		else:attach_pending={};creator.preview.stop();creator.preview.view.active=false
	if restore_pending:restore_surface()
func preview_changed(value: Dictionary,value_ticket: Array) -> void:
	var began:=Time.get_ticks_usec();apply_preview(value,value_ticket);measured("preview-request",began)
func apply_preview(value: Dictionary,value_ticket: Array) -> void:
	if not current() or ticket!=value_ticket or stage!="appearance":return
	var choice:=outfit(value)
	if choice.is_empty():return
	var document: Dictionary=prepared.loads.get(str(choice.resRef),{}).get("document",{})
	var verified:=TailBic.private_outfit(document,value,choice)
	if not verified.ready:failure=verified.reason;return
	var data:=value.duplicate(true);data.gender=int(creator.rules.draft.gender)
	creator.preview.refresh_source(int(creator.rules.draft.raceId),int(prepared.provenance.appearanceId),data,document,ticket)
func outfit(value: Dictionary) -> Dictionary:
	for choice in prepared.get("context",{}).get("clothing",[]):
		if int(choice.id)==int(value.get("clothes",-1)) and choice.resRef==value.get("clothingResRef"):return choice
	return {}
func release_preview() -> void:
	if not is_instance_valid(creator) or not is_instance_valid(creator.preview):return
	creator.preview.stop();creator.preview.view.active=false;restore_pending=true
	attach_pending={}
	if creator.preview.retiring.is_empty():restore_surface()
func restore_surface() -> void:
	var view=creator.preview.view
	if is_instance_valid(original_parent) and view.surface.get_parent()!=original_parent:
		view.surface.reparent(original_parent,false);original_parent.move_child(view.surface,mini(original_index,original_parent.get_child_count()-1));view.surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);view.surface.custom_minimum_size=Vector2(280,360)
	original_parent=null;original_index=-1;restore_pending=false
func appearance_result(accepted: bool,value: Dictionary,value_ticket: Array) -> void:
	var began:=Time.get_ticks_usec();apply_appearance(accepted,value,value_ticket);measured("appearance-accept" if accepted else "appearance-cancel",began)
func apply_appearance(accepted: bool,value: Dictionary,value_ticket: Array) -> void:
	if not current() or ticket!=value_ticket:return
	if not accepted:finish(2);return
	if stage!="appearance":appearance.open();return
	if value!=appearance.state.snapshot():failure="The current appearance selection has changed.";appearance.open();show_status();return
	var choice:=outfit(value);var patch:=TailBic.first_level(int(prepared.provenance.appearanceId),value,choice)
	if not patch.ready:failure=patch.reason;appearance.open();show_status();return
	var d: Dictionary=creator.rules.draft
	for field in ["head","phenotype","clothes","skin","hair","tattoo1","tattoo2"]:d[field]=value[field]
	d.sourceTailAppearance={"mode":0,"appearanceId":int(prepared.provenance.appearanceId),"value":value.duplicate(true),"choice":choice.duplicate(true),"signature":source_signature.duplicate()}
	release_preview();stage="information"
	var model:=Provider.character_info(creator.rules.tables,d,creator.ui.text)
	if not model.ready:failure=model.reason;stage="appearance";appearance.open();show_status();return
	information.set_context(model.context,ticket);information.open();place()
	names.configure(creator.ui.catalog,ticket,model.context.namePlan)
func voice_requested(id: int,resref: String,sample: int,value_ticket: Array) -> void:
	if current() and ticket==value_ticket and stage=="information" and information.state.by_id.has(id) and information.state.voices[int(information.state.by_id[id])].resRef==resref:creator.voice.play_sample(id,resref,sample)
func random_requested(id: int,value_ticket: Array) -> void:
	if not current() or ticket!=value_ticket or stage!="information" or information.pending_random!=id:return
	var request: int=names.request_names(ticket)
	if request<0:information.generation_failed(id,ticket);return
	name_jobs[request]={"viewId":id,"ticket":ticket.duplicate(),"generation":generation}
func names_prepared(value_ticket: Array) -> void:
	if current() and ticket==value_ticket and stage=="information":information.set_random_ready(names.available(ticket),ticket)
func names_ready(id: int,result: Dictionary) -> void:
	var request: Dictionary=name_jobs.get(id,{});name_jobs.erase(id)
	if request.is_empty() or not current() or request.ticket!=ticket or int(request.generation)!=generation or stage!="information":return
	if result.get("ready",false):information.generated_names(int(request.viewId),str(result.firstName),str(result.lastName),ticket)
	else:information.generation_failed(int(request.viewId),ticket)
func information_result(accepted: bool,value: Dictionary,value_ticket: Array) -> void:
	var began:=Time.get_ticks_usec();apply_information(accepted,value,value_ticket);measured("information-accept" if accepted else "information-cancel",began)
func apply_information(accepted: bool,value: Dictionary,value_ticket: Array) -> void:
	if not current() or ticket!=value_ticket or stage!="information":return
	if not accepted:finish(2);return
	var actual: Dictionary=information.state.result()
	if not actual.get("available",false) or actual.get("value")!=value:failure="The current character information has changed.";information.open();return
	var patch:=TailBic.information(value)
	if not patch.ready:failure=patch.reason;information.open();return
	var d: Dictionary=creator.rules.draft
	for field in ["firstName","lastName","age","deity","soundset"]:d[field]=value[field]
	d.biography=value.description;d.sourceTailInformation=value.duplicate(true);d.sourceTailChoices=true
	finish(0x8007)
func finish(code: int) -> void:
	var old:=ticket.duplicate();retire();front.accept_child(old,code)
func retire() -> void:
	generation+=1;ticket=[];identity=[];stage="";prepared={};name_jobs.clear();preparation_queued=false
	if is_instance_valid(appearance):appearance.dismiss()
	if is_instance_valid(information):information.dismiss()
	if is_instance_valid(creator):release_preview();creator.voice.reset()
func close() -> void:
	if closed:return
	retire();closed=true
	creator.preview.drain_retired(true);restore_surface()
	if task>=0:WorkerThreadPool.wait_for_task_completion(task);task=-1
	if is_instance_valid(names):names.close()
	if is_instance_valid(appearance):appearance.close()
	if is_instance_valid(information):information.close()
func _exit_tree() -> void:close()
