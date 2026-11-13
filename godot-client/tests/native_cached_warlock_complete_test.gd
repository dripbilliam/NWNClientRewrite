extends "res://tests/native_cached_warlock_creation_test.gd"
# Real cached-data continuation. All inputs use shipping owners; the terminal
# submit intent is captured by the fixture's signal sink, never by a Session.
class ResourceReads extends RefCounted:
	var mutex:=Mutex.new()
	var values:Dictionary={}
	var overflow:=false
	func record(name:String,type:int,bytes:PackedByteArray,error:String)->void:
		var key:=name.to_lower()+":"+str(type)
		mutex.lock()
		if not values.has(key) and values.size()>=2048:overflow=true;mutex.unlock();return
		var prior:Dictionary=values.get(key,{"name":name.to_lower(),"type":type,"reads":0})
		prior.reads+=1;prior.bytes=bytes.size();prior.error=error
		if error.is_empty():prior.sha256=preload("res://systems/native_data/prepared_cache.gd").digest(bytes)
		values[key]=prior;mutex.unlock()
	func snapshot()->Array:
		mutex.lock();var result:Array=values.values().duplicate(true);mutex.unlock();return result
var resource_reads:=ResourceReads.new()
var local_build_count:=0
func verify_selected_bic(document:Dictionary,_creator)->void:
	check(document.root.FeatList.any(func(row):return int(row.Feat)==2300),"Parsed actual BIC retains physically selected custom Warlock Pact2300")
func configure_fixture_catalog(catalog)->void:catalog.recording=resource_reads
func fixture_scope()->String:return "Offline cached Arelith first-level Warlock through shipping physical controls, real Familiar UTC/name workers, active-data Appearance/Info, private native BIC worker and parsed local submit intent. No authored rules, injected post states, NetworkSession, key, GPU/pixel or server-admission claim."
func before_fixture_close(creator)->void:
	observations.resourceReads=resource_reads.snapshot()
	observations.privateCaptureGaps=observations.resourceReads.filter(func(row):return row.error=="Native NWSync resource is not cached")
	observations.associateWorkers={"templates":creator.associate_templates.keys(),"nameFailure":creator.associate_names.failure,"nameDiagnostics":creator.associate_names.diagnostics,"namePending":creator.associate_name_jobs.size()}
	observations.tailWorkers={"stage":creator.tail.stage,"failure":creator.tail.failure,"nameFailure":creator.tail.names.failure,"nameDiagnostics":creator.tail.names.diagnostics}
	check(not resource_reads.overflow,"Bounded resource-read evidence did not overflow")
	check(observations.privateCaptureGaps.is_empty(),"Every requested selected-manifest body was present in the private fixture",observations.privateCaptureGaps)
func verify_fixture_transport()->void:
	var submissions:Array=sent.filter(func(message):return message.get("kind")=="native-creation-submit")
	check(submissions.size()==local_build_count and local_build_count==1,"One native BIC intent was intercepted locally without a Session",submissions.size())
func finish_associate(creator,_ui)->bool:
	var pane=creator.source_frontend.associate
	if not check(not pane.rows.is_empty() and pane.rows[0].index==0,"Actual first visible Familiar row maps an active physical choice"):return false
	if not await input(pane.rows[0].button,"Select actual mapped Familiar"):return false
	var selected_id:int=int(pane.state.selected_id());var mapped:Dictionary=pane.state.preview()
	if not check(mapped.get("ready",false),"Actual source Familiar preview maps selected physical row and class level",mapped):return false
	var resource:String=str(mapped.resource)
	var ready:bool=await wait_for(func():return (creator.associate_templates.has(resource) and not pane.summary_identity.is_empty() and not pane.generating and not pane.state.current_name.is_empty()) or not creator.associate_names.failure.is_empty() or not creator.resource_errors.is_empty(),12)
	observations.familiarAccepted={"physicalId":selected_id,"resource":resource,"name":pane.state.current_name,"generating":pane.generating,"previewIdentity":pane.summary_identity,"nameFailure":creator.associate_names.failure,"resourceErrors":creator.resource_errors.duplicate(true),"nameDiagnostics":creator.associate_names.diagnostics.duplicate(true)}
	if not check(ready and creator.associate_templates.has(resource) and not pane.summary_identity.is_empty() and not pane.generating and not pane.state.current_name.is_empty(),"Actual mapped Familiar UTC/preview and real native name worker complete",observations.familiarAccepted):return false
	if not await input(pane.buttons.okbutton,"Accept actual Familiar and generated name"):return false
	if not check(await wait_source(creator,[""]),"Actual Familiar callback completes the original post flow",trace):return false
	return check(int(creator.rules.draft.familiar)==selected_id and not str(creator.rules.draft.familiarName).is_empty() and creator.source_frontend.flow.enabled.customize,"Original Familiar commit preserves physical ID/name and enables Customize")
func enter_text(edit:LineEdit,value:String)->void:
	await click(edit);edit.select_all()
	for index in value.length():
		var event:=InputEventKey.new();event.pressed=true;event.unicode=value.unicode_at(index);surface.push_input(event,true)
	await frames()
func path(creator,ui)->bool:
	if not await super.path(creator,ui):return false
	var front=creator.source_frontend;var tail=creator.tail
	if not await input(front.main.buttons.customizebutton,"Customize cached active character"):return false
	var appearance_ready:bool=await wait_for(func():return tail.stage=="appearance" or not tail.failure.is_empty(),15)
	observations.appearancePreparation={"stage":tail.stage,"failure":tail.failure,"resourceErrors":creator.resource_errors.duplicate(true)}
	if not check(appearance_ready and tail.stage=="appearance" and tail.appearance.layout_ready,"Actual active clothing/head/palette worker opens source Appearance",observations.appearancePreparation):return false
	var pane=tail.appearance
	for tag in ["head_right","clothes_right"]:
		if not pane.buttons[tag].disabled and not await input(pane.buttons[tag],"Actual Appearance "+tag):return false
	observations.appearance=pane.state.snapshot()
	if not await input(pane.buttons.okbutton,"Appearance OK"):return false
	if not check(await wait_for(func():return tail.stage=="information" and tail.information.layout_ready,8),"Actual Appearance8002 transfers to Information without replacing parent scope",tail.failure):return false
	var info=tail.information
	var initial_voice:Dictionary=preload("res://systems/native_data/creation_feat_tables.gd").integer(creator.rules.tables.packages,int(creator.rules.draft.packageId),"SoundSet")
	observations.initialVoice={"read":initial_voice,"selectedPhysicalId":info.state.selected,"firstAdmittedPhysicalId":info.state.voices[0].id if not info.state.voices.is_empty() else null}
	if not check(initial_voice.get("ready",false) and not initial_voice.get("ok",true) and int(initial_voice.value)==0 and not info.state.voices.is_empty() and info.state.selected==info.state.voices[0].id,"Original failed Soundset INT output0 maps visible index0 to the actual admitted physical voice",observations.initialVoice):return false
	var names_ready:bool=await wait_for(func():return (info.random_ready and info.pending_random<0 and not str(info.state.fields.firstName).is_empty()) or not tail.names.failure.is_empty(),12)
	observations.characterNames={"ready":info.random_ready,"pending":info.pending_random,"first":info.state.fields.get("firstName"),"last":info.state.fields.get("lastName"),"failure":tail.names.failure,"diagnostics":tail.names.diagnostics.duplicate(true)}
	if not check(names_ready and info.random_ready and info.pending_random<0 and not str(info.state.fields.firstName).is_empty(),"Real active racial name routes and scoped native name worker complete",observations.characterNames):return false
	await enter_text(info.edits.firstnameedit,"CachedWarlock");await enter_text(info.edits.lastnameedit,"Offline")
	if not check(info.state.fields.firstName=="CachedWarlock" and info.state.fields.lastName=="Offline","Physical Information keyboard input changes private current names"):return false
	observations.information={"fields":info.state.fields.duplicate(true),"voiceId":info.state.selected,"voiceEntries":info.state.voices.size()}
	if not await input(info.buttons.okbutton,"Information OK"):return false
	if not check(front.child.is_empty() and front.main.visible and front.flow.completed.customize and front.flow.enabled.play and creator.rules.draft.get("sourceTailChoices",false),"Info8007 commits actual tail and returns to playable source Main"):return false
	var builder=preload("res://systems/native_data/creation_bic.gd");var errors:Array=builder.validation_errors(creator.rules)
	observations.validationErrors=errors
	if not check(errors.is_empty(),"Actual cached custom-class draft passes all native BIC validation",errors):return false
	if not await input(front.main.buttons.playbutton,"Build native cached Warlock BIC locally"):return false
	if not check(await wait_for(func():return creator.build_task<0 and creator.phase in ["waiting","editing"],20),"Actual native BIC worker completes without a Session",creator.status):return false
	var submissions:Array=sent.filter(func(message):return message.get("kind")=="native-creation-submit")
	if not check(submissions.size()==1 and creator.phase=="waiting","Physical source Play emits exactly one captured local BIC intent",creator.status):return false
	local_build_count=1
	var bytes:=Marshalls.base64_to_raw(submissions[0].data);var parser=preload("res://systems/native_data/gff_document.gd").new();var document:Dictionary=parser.parse(bytes,"BIC ")
	if not check(parser.failure.is_empty() and document.root.ClassList[0].Class==92 and document.root.Race==6 and document.root.FirstName.entries[0].text=="CachedWarlock" and document.root.LastName.entries[0].text=="Offline","Parsed actual BIC preserves active class/race and physical Info names",parser.failure):return false
	check(not document.root.ClassList[0].has("SpellsPerDayList"),"Original first-level807950 BIC omits daily-use list for manual and automatic source paths")
	verify_selected_bic(document,creator)
	observations.bic={"bytes":bytes.size(),"class":document.root.ClassList[0],"race":document.root.Race,"familiar":document.root.get("FamiliarType"),"name":document.root.FirstName,"outfit":document.root.get("Equip_ItemList"),"head":document.root.get("xAppearance_Head"),"featCount":document.root.FeatList.size()}
	var args:Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	var file:=FileAccess.open(str(args.report)+".bic",FileAccess.WRITE);file.store_buffer(bytes);file.close()
	return failures.is_empty()
