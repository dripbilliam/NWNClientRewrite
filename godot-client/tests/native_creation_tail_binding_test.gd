extends "res://tests/native_creation_spells_binding_test.gd"
const TailWriter=preload("res://systems/native_data/creation_tail_bic.gd")
func click_tail(button: Button) -> void:
	if not check(is_instance_valid(button) and button.is_visible_in_tree(),"Actual source tail button is visible"):return
	await click(button)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var fixture_dir:=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(fixture_dir)
	var file:=FileAccess.open(fixture_dir.path_join("fixture_sprefs.2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nSpellIndex\n0 4\n1 1\n");file.close()
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install) and active.mount_directory(fixture_dir,100000001),"Installed catalogs and authored preference data mount")
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(701)
	var bytes_size:=0;var model: Dictionary={};var preview_signature:="";var timings: Array=[];var worker: Dictionary={};var preview_admission: Dictionary={};var retirement: Dictionary={};var rapid_usec:=0
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.tail.appearance.layout_ready and creator.tail.information.layout_ready,50),"Actual creator and original Appearance/Info source panes prepare",creator.resource_errors):
		spell_rules(creator,ui);creator.rules.tables.packages=coherent_row(creator.rules.tables.packages,0,{"SoundSet":"0"})
		var installed_voice: Dictionary=creator.rules.row("soundset",int(creator.rules.draft.soundset));var voice_resource: String=str(creator.rules.cell(installed_voice,"RESREF",""))
		creator.rules.tables.soundset={"columns":["RESREF","TYPE","GENDER","STRREF"],"orderedRows":[{"RESREF":voice_resource,"TYPE":"2","GENDER":str(creator.rules.draft.gender),"STRREF":"60000"}]};ui.text.overrides[60000]="Active TYPE2 voice";ui.text.revision+=1
		creator.rules.draft.firstName="";creator.rules.draft.lastName="";creator.render()
		var front=creator.source_frontend;var tail=creator.tail;var pane=tail.appearance;var info=tail.information;var identity: Array=creator.summary_identity()
		check(creator.source_entered==identity and front.wanted and front.main.visible,"Ordinary creator.open automatically entered CG_MAIN without a manual frontend.begin")
		if check(await enter_spells(creator),"Actual Package→Skills→Feats→School→Spells chain reaches Customize prerequisite"):
			await click(front.spells.buttons.recommendbutton);await click(front.spells.buttons.okbutton)
			check(front.child.is_empty() and front.flow.enabled.customize,"Native Package sequence enables Customize")
			var prior:=JSON.stringify(creator.rules.draft);await click(front.main.buttons.customizebutton)
			if check(await wait_for(func():return tail.stage=="appearance" or not tail.failure.is_empty(),15) and tail.stage=="appearance","Physical Customize opens accepted active-data Appearance provider",tail.failure):
				worker={"thread":tail.prepared.workerThread,"resourceIndexMs":tail.prepared.resourceIndexMs,"modelResourceCount":tail.prepared.modelResourceCount}
				check(int(worker.thread)!=OS.get_main_thread_id(),"Actual active resource index/provider ran on its private worker")
				check(not creator.source_fallback and not creator.view.wanted and pane.wanted and front.owns(tail.ticket),"Source pane owns one real parent ticket without generic wizard fallback")
				check(creator.preview.view.surface.get_parent()==pane.preview_slot and creator.preview.view.active,"Native source preview attaches only the existing viewport surface")
				check(JSON.stringify(creator.rules.draft)==prior,"Opening typed resource preparation does not mutate committed draft")
				var initial: Dictionary=pane.state.snapshot();var old_ticket: Array=tail.ticket.duplicate()
				await click_tail(pane.buttons.head_right)
				check(JSON.stringify(creator.rules.draft)==prior and pane.state.value.head!=initial.head,"Physical Head changes private extended-WORD value before acceptance")
				await click_tail(pane.buttons.tattoo_right)
				check(pane.state.value.skinParts[7]==2 and pane.state.value.skinParts.size()==19,"Physical tattoo updates raw skin separately from actual outfit")
				var rapid_began:=Time.get_ticks_usec()
				for request_index in 12:
					pane.state.step("head",1);pane.refresh();pane.preview_changed.emit(pane.state.snapshot(),tail.ticket.duplicate())
				rapid_usec=Time.get_ticks_usec()-rapid_began
				var snapshot: Dictionary=pane.state.snapshot();model=preload("res://systems/native_creation_preview.gd").source_object(int(creator.rules.draft.raceId),int(tail.prepared.provenance.appearanceId),snapshot.merged({"gender":int(creator.rules.draft.gender)}),tail.prepared.loads[snapshot.clothingResRef].document)
				check(model.appearance.bodyParts[7].value==2 and model.appearance.equipment[0].item.parts==snapshot.bodyParts and model.appearance.equipment[0].item.colors==snapshot.materialColors,"Native preview uses all actual19 garment parts/six materials and separate rawskin")
				check(await wait_for(func():return creator.preview.diagnostics.has("ready"),15) and creator.preview.diagnostics.get("ready",false),"Actual source native Stream admits installed model/mesh resources",creator.preview.diagnostics)
				check(int(creator.preview.diagnostics.object.appearance.head)==int(snapshot.head) and creator.preview.retirement_stats.maximumRetired==1 and creator.preview.retirement_stats.maximumPending==1 and creator.preview.retirement_stats.coalesced>0,"Actual rapid native preview callbacks admit only latest shape under bounded retirement")
				preview_admission=creator.preview.diagnostics.duplicate(true)
				preview_signature=creator.preview.signature
				await click_tail(pane.buttons.okbutton)
				check(tail.stage=="information" and info.wanted and tail.ticket==old_ticket and front.child=="customizebutton" and not front.main.visible,"Appearance8002 transfers directly to Info retaining the parent ticket")
				check(not creator.preview.view.active and creator.preview.stream==null,"Transfer clears current native model immediately")
				check(await wait_for(func():return creator.preview.retiring.is_empty() and creator.preview.view.surface.get_parent()==creator.view.appearance_preview,3),"Transfer restores surface only after owned retired workers drain")
				check(creator.rules.draft.sourceTailAppearance.value.skinParts[7]==2 and not creator.rules.draft.has("sourceTailChoices"),"Accepted Appearance commits exact rawskin but completion awaits Info")
				if check(await wait_for(func():return info.random_ready or not tail.names.failure.is_empty(),10) and info.random_ready,"Actual scoped installed LTR/name resources prepare",tail.names.failure):
					check(await wait_for(func():return info.pending_random<0 and not str(info.state.fields.firstName).is_empty(),10),"Native auto Random publishes actual worker-generated names")
				info.edits.firstnameedit.text="  éCreator ";info.edits.firstnameedit.text_changed.emit(info.edits.firstnameedit.text);info.edits.lastnameedit.text=" Last ";info.edits.lastnameedit.text_changed.emit(info.edits.lastnameedit.text)
				info.edits.ageedit.text="-7";info.edits.ageedit.text_changed.emit("-7");info.biography.text=" Biography é ";info.biography.text_changed.emit()
				await click_tail(info.buttons.deitybutton)
				check(info.deity.wanted,"Physical Deity opens original nested edit owner")
				info.deity.edit.text=" deity ";await click(info.deity.buttons.okbutton)
				check(info.state.fields.deity==" deity ","Original nested edit preserves private deity whitespace")
				var selected: int=int(info.state.selected);info.voice_requested.emit(selected,str(info.state.voices[info.state.by_id[selected]].resRef),17,tail.ticket)
				check(creator.voice.last.code==17 and creator.voice.last.voice==selected,"Info owns exact explicit sample without internal double cycling")
				await click_tail(info.buttons.okbutton)
				check(front.child.is_empty() and front.main.visible and front.flow.completed.customize and front.flow.enabled.play and creator.rules.draft.sourceTailChoices,"Info8007 commits and completes Customize→Main source navigation")
				check(front.main.summary_view.labels.title.text.ends_with("  éCreator   Last ") and front.summary_model.labels.title.text==front.main.summary_view.labels.title.text and front.summary_model.portrait==str(creator.rules.draft.portrait)+"l","Info8007 refreshes actual CG_MAIN name and current portrait projection")
				check(creator.rules.draft.firstName=="  éCreator " and creator.rules.draft.age==-7 and creator.rules.draft.biography==" Biography é " and creator.rules.draft.deity==" deity ","Accepted Info fields retain source whitespace/signed age")
				check(creator.rules.draft.soundset==0 and info.state.voices[0].resRef==voice_resource.left(16).to_lower() and creator.rules.voices().is_empty(),"Actual active-provider TYPE2 physical voice is admitted by source Info independently of legacy TYPE0 filter",{"selected":creator.rules.draft.soundset,"source":voice_resource,"published":info.state.voices,"legacy":creator.rules.voices()})
				var errors: Array=preload("res://systems/native_data/creation_bic.gd").validation_errors(creator.rules);check(errors.is_empty(),"Actual builder validates source-tail limits plus all unrelated rules",errors)
				var builder=preload("res://systems/native_data/creation_bic.gd")
				for field in ["head","soundset","firstName"]:
					var prior_value: Variant=creator.rules.draft[field];creator.rules.draft[field]=str(prior_value)+"x" if field=="firstName" else int(prior_value)+1
					check(not builder.tail_patch(creator.rules.draft).ready,"Changed accepted tail value rejects: "+field);creator.rules.draft[field]=prior_value
				var package_id: int=int(creator.rules.draft.packageId);creator.rules.draft.packageId=package_id+1
				check(not builder.tail_patch(creator.rules.draft).ready,"Source tail from another package context is rejected");creator.rules.draft.packageId=package_id
				var old_skills: Dictionary=creator.rules.draft.skills.duplicate(true);creator.rules.draft.skills[0]=999
				check(builder.tail_patch(creator.rules.draft).ready and builder.validation_errors(creator.rules).has("Invalid skill ranks."),"Tail profile preserves unrelated actual skill rejection");creator.rules.draft.skills=old_skills
				var old_feats: Array=creator.rules.draft.feats.duplicate(true);creator.rules.draft.feats.append({"id":65535,"kind":"normal"})
				check(builder.tail_patch(creator.rules.draft).ready and not builder.validation_errors(creator.rules).is_empty(),"Tail profile preserves unrelated actual feat rejection");creator.rules.draft.feats=old_feats
				var old_classes: Dictionary=creator.rules.tables.classes;creator.rules.tables.classes=coherent_row(old_classes,0,{"PlayerClass":"0"})
				check(builder.tail_patch(creator.rules.draft).ready and not builder.validation_errors(creator.rules).is_empty(),"Tail profile preserves unrelated actual class rejection");creator.rules.tables.classes=old_classes
				creator.rules.draft.erase("sourceTailChoices")
				check(builder.validation_errors(creator.rules).has("Enter a valid age."),"Generic draft retains original positive-age validation");creator.rules.draft.sourceTailChoices=true
				if errors.is_empty():
					await click(front.main.buttons.playbutton)
					check(await wait_for(func():return creator.build_task<0 and creator.phase in ["waiting","editing"],20),"Actual native BIC worker finishes source tail",creator.status)
					var submissions: Array=sent.filter(func(message):return message.get("kind")=="native-creation-submit")
					check(submissions.size()==1 and creator.phase=="waiting","Physical Play emits one scoped completed BIC intent")
					if submissions.size()==1:
						var bytes:=Marshalls.base64_to_raw(submissions[0].data);bytes_size=bytes.size();var parser=preload("res://systems/native_data/gff_document.gd").new();var doc:=parser.parse(bytes,"BIC ")
						check(parser.failure.is_empty() and doc.root.FirstName.entries[0].text=="  éCreator " and doc.root.Age==-7 and doc.root.Deity==" deity ","Actual generated BIC preserves accepted source Info")
						check(doc.root.xBodyPart_Torso==2 and doc.field_types[0].xAppearance_Head==2 and doc.root.Equip_ItemList[0].keys()==["EquippedRes"] and int(doc.struct_types[1])>=0,"Actual BIC writes typed rawskin/extended head and reference-only equipped outfit")
						file=FileAccess.open(str(args.report)+".bic",FileAccess.WRITE);file.store_buffer(bytes);file.close()
					creator.phase="editing";creator.status=""
				# Cancel/stale/reentry after full transaction, without any login.
				var committed: Dictionary=creator.rules.draft.duplicate(true);front.flow.enabled.customize=true;creator.render();await click(front.main.buttons.customizebutton)
				check(await wait_for(func():return tail.stage=="appearance",15),"Source Customize reopens after completed tail")
				await click_tail(pane.buttons.head_right);await click_tail(pane.buttons.cancelbutton)
				check(front.child.is_empty() and creator.rules.draft==committed,"Appearance Cancel discards private edits and returns Main")
				await click(front.main.buttons.customizebutton);await wait_for(func():return tail.stage=="appearance",15);await click_tail(pane.buttons.okbutton)
				var names_before: Array=[creator.rules.draft.firstName,creator.rules.draft.lastName];var old_info: Array=tail.ticket.duplicate();info.edits.firstnameedit.text="Uncommitted";info.edits.firstnameedit.text_changed.emit("Uncommitted");await click_tail(info.buttons.cancelbutton)
				check(front.child.is_empty() and [creator.rules.draft.firstName,creator.rules.draft.lastName]==names_before and not creator.voice.audio.player.playing,"Info Cancel discards private name edits and stops source audio")
				committed=creator.rules.draft.duplicate(true);tail.names_ready(999,{"ready":true,"firstName":"Late","lastName":"Reply","scope":old_info})
				check(creator.rules.draft==committed,"Retired name result cannot alter the accepted draft")
				await click(front.main.buttons.customizebutton);var retired: Array=tail.ticket.duplicate();front.retire_child();front.refresh();tail.appearance_result(true,snapshot,retired);await frames(3)
				check(creator.rules.draft==committed and tail.ticket.is_empty() and creator.preview.stream==null,"Retired parent callback and late resource completion cannot write/reopen")
				creator.rules.draft.sourceTailAppearance.mode=1
				check(not builder.tail_patch(creator.rules.draft).ready,"Existing-character mode cannot opt into the first-level BIC patch");creator.rules.draft.sourceTailAppearance.mode=0
				var before_mode: Dictionary=creator.rules.draft.duplicate(true);front.context.customizeMode=1;front.open_child("appearance");await frames(3)
				check(creator.phase=="closed" and creator.rules.draft==before_mode and tail.ticket.is_empty() and tail.failure=="Existing-character customization is unavailable.","Existing-vault Customize stays explicitly unsupported without any first-level draft save")
	timings=creator.tail.callback_timings.duplicate(true);retirement=creator.preview.retirement_stats.duplicate(true);ui.close();ui.free();painter.free();surface.queue_free();await frames(8)
	file=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"bicBytes":bytes_size,"previewObject":model,"previewAdmission":preview_admission,"previewSignature":preview_signature,"callbackTimings":timings,"previewRetirement":retirement,"rapidPreviewUsec":rapid_usec,"providerWorker":worker,"scope":"Actual runtime Gameplay/Creator/Frontend Customize source Appearance→Info→Main, real active data/UTI/palette/name workers, physical controls, exact scoped audio sample, private/stale/cancel and actual worker-generated parsed BIC. Controlled source artwork/fonts and headless 3D; no rendered pixel/audio playback/server upload/client restart claim."},"  "));file.close();quit(0 if failures.is_empty() else 1)
