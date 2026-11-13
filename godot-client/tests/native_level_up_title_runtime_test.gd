extends "res://tests/native_level_up_rule_runtime_test.gd"
# Same actual Runtime/SourceOwner Class→Skills→Associate→Summary flow. This
# companion upgrades only the fixture font provider and supplies a disclosed
# controlled actor to the production reader seam; no snapshot/name injection.
const OriginalFonts=preload("res://systems/native_bitmap_fonts.gd")
const TitleInk=preload("res://tests/native_font_ink_probe.gd")
var title_actor: Dictionary={"id":42,"areaId":7,"objectType":5,"nativeLifetime":71,"clientKnownLifetime":73,"replicationRemoved":false,"replicated":{"name":{"firstName":{"text":"Shand"},"lastName":{"text":"Carna"}}}}
var title_cases: Array=[]
var first_title_ticket: Array=[]
var title_unknown: bool=OS.get_cmdline_user_args().has("--title-unknown=true")
var fonts_upgraded:=false
func check(value: bool,label: String) -> void:
	super.check(value,label)
	if not runtime_mode:return
	if label=="Actual runtime editor sends only the existing typed begin intent":
		if title_unknown:title_actor.replicated.erase("name")
		runtime_owner.source_runtime.current_actor_reader=func():return title_actor
		var previous=painter.fonts;previous.close();painter.remove_child(previous);previous.free()
		painter.fonts=OriginalFonts.new();painter.add_child(painter.fonts);painter.fonts.configure(catalog,"")
		# The inherited fixture configured Frontend with its original font double
		# before this upgrade. Connect the same production completion callback.
		painter.fonts.loaded.connect(front.source_title_font_loaded);fonts_upgraded=true
	elif label=="Actual begin result enters source controls while retaining the authoritative transaction gate":
		super.check(runtime_owner.source_runtime.source_title_context.identity==flow_identity,"Actual source begin captures a detached title identity without changing the snapshot")
		super.check(front.source_title_binding.identity.is_empty(),"Original Class is excluded from the six title-prefix callers")
	elif label=="Actual runtime sends one scoped proposal and typed Cancel without fabricating server acceptance":
		super.check(runtime_owner.source_runtime.source_title_context.identity.is_empty() and front.source_title_binding.identity.is_empty(),"Actual typed Cancel retires private title strings and the active view binding")
func wait_for(predicate: Callable) -> bool:
	if not await super.wait_for(predicate):return false
	if not fonts_upgraded:return true
	var deadline:=Time.get_ticks_msec()+15000
	while not painter.fonts.pending.is_empty() and Time.get_ticks_msec()<deadline:await process_frame
	return painter.fonts.pending.is_empty() and painter.fonts.failed.is_empty()
func inspect_current_title(stage: String,full_name: String) -> void:
	var runtime=runtime_owner.source_runtime;var pane=front.panes[stage];var binding=front.source_title_binding
	var valid: bool=binding.current(front.ticket) and binding.target!=null and is_instance_valid(binding.target.get_ref())
	super.check(valid,"Actual prepared/font callback owns current "+stage+" title")
	if not valid:return
	var label: Label=binding.target.get_ref();var entry: Dictionary=pane.plan.entries.title;var caption: String=pane.caption(entry)
	var expected: String=caption if title_unknown else full_name+"   Druid (3)        "+caption
	super.check(label.text==expected,"Actual Runtime→Frontend "+stage+" caption uses private name and advanced physical class order/level")
	super.check(label.get_theme_font("font") is FontFile and str(label.get_meta("native_font_applied","")).to_lower().begins_with("fnt_"),"Actual "+stage+" title uses installed FontFile/atlas rather than the inherited font double")
	var ink:=TitleInk.glyph_ink(label);super.check(ink.present and Rect2(Vector2.ZERO,pane.size).grow(1).encloses(ink.rect),"Actual integrated "+stage+" installed-font title ink stays within native frame")
	var payload: Dictionary=runtime.source_title_payload(front.ticket)
	super.check(payload.ready!=title_unknown and not runtime.source_title_payload(front.ticket+[1]).ready,"Unknown required names and stale frontend tickets cannot borrow another title context")
	title_cases.append(TitleInk.packed({"stage":stage,"ticket":front.ticket.duplicate(),"text":label.text,"expected":expected,"ink":ink,"entry":entry}))
func gate(value: bool,label: String) -> bool:
	var accepted: bool=super.gate(value,label)
	if not accepted or not runtime_mode:return accepted
	if label=="Class3 uses actual mode1 Skills without first-level allocation":
		inspect_current_title("skills","Shand Carna");first_title_ticket=front.ticket.duplicate()
		if not title_unknown:title_actor.replicated.name.firstName.text="Changed"
	elif label=="Original class-level3 continuation enters actual Associate controls":inspect_current_title("associate","Shand Carna")
	elif label=="Actual Associate OK commits and enters original Summary":
		super.check(front.source_title_binding.identity.is_empty(),"Original Summary keeps its unclaimed caption without a level-up prefix")
	elif label=="New token opens current Skills without reusing the retired publication":
		inspect_current_title("skills","Changed Carna")
		var before: String=front.source_title_binding.target.get_ref().text if front.source_title_binding.target!=null else ""
		front.refresh_source_title(first_title_ticket)
		super.check(front.source_title_binding.target!=null and front.source_title_binding.target.get_ref().text==before,"Old prepared/font callback cannot relabel a newly begun transaction")
	return accepted
func run() -> void:
	await super.run()
	var report:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):report=argument.trim_prefix("--report=")
	if report.is_empty() or not FileAccess.file_exists(report):return
	var result: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report));result.titleCases=title_cases;result.titleUnknown=title_unknown;result.actualInstalledTitleFonts=true
	result.scope+=" Runtime source-title capture/projection, actual installed-font Skills/Associate titles, private name freeze, new-token refresh, excluded Class/Summary, unknown names without blocking advancement, and stale font callback retirement. Actor name disclosure is authored at the production reader seam; no wire/server/pixel acceptance."
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
