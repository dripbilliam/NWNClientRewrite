extends "res://tests/native_creation_school_binding_test.gd"
const SpellValidation=preload("res://systems/native_data/creation_spells_validation.gd")
func press_only(button: Button) -> void:
	var point:=button.get_global_transform_with_canvas()*(button.size*.5)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;surface.push_input(motion,true);await process_frame
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true;event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.position=point;event.global_position=point;surface.push_input(event,true);await process_frame
func spell_rules(creator,ui) -> void:
	school_rules(creator,ui)
	creator.rules.tables.classes=coherent_row(creator.rules.tables.classes,0,{"SkipSpellSelection":"0","PlayerClass":"1","SpellTableColumn":"SERVER_CAST","SpellKnownTable":"****"})
	creator.rules.tables.spells={"orderedRows":[]}
	for id in 5:
		creator.rules.tables.spells.orderedRows.append({"Name":str(40000+id),"SpellDesc":str(41000+id),"School":["D","A","C","****","I"][id],"SERVER_CAST":str([0,1,1,255,1][id]),"UserType":"0" if id==0 else "1","Master":"3" if id==0 else "-1","IconResRef":"ips_clightw"})
		ui.text.overrides[40000+id]="Server spell "+str(id);ui.text.overrides[41000+id]="Server spell help "+str(id)
	creator.rules.tables.spellschools.orderedRows[1].Opposition="2"
	creator.rules.tables.packages={"orderedRows":[{"ClassID":"0","PlayerClass":"1","Name":"0","School":"1","SpellPref2DA":"fixture_sprefs"}]}
	creator.rules.draft.firstName="SpellFixture";creator.rules.draft.lastName="Native"
	# Complete unrelated ability allocation through the actual existing rules;
	# keep INT14 so the native spell budget/source fixture stays meaningful.
	for turn in 100:
		if creator.rules.point_balance()<=0:break
		var advanced:=false
		for ability in ["Str","Dex","Wis","Cha","Con"]:
			var prior: int=creator.rules.draft.abilities[ability];creator.rules.change_ability(creator.rules.ABILITIES.find(ability),1)
			if int(creator.rules.draft.abilities[ability])!=prior:advanced=true;break
		if not advanced:break
	var portraits: Array=creator.rules.portraits();var voices: Array=creator.rules.voices()
	if not portraits.is_empty():creator.rules.draft.portrait=str(portraits[0])
	if not voices.is_empty():creator.rules.draft.soundset=int(voices[0])
	ui.text.revision+=1;creator.render()
func release_now(button: Button) -> void:
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;event.position=button.get_global_transform_with_canvas()*(button.size*.5);event.global_position=event.position;surface.push_input(event,true)
func enter_spells(creator) -> bool:
	if not await enter_school(creator):return false
	await click(creator.source_frontend.school.buttons.abjuration);await click(creator.source_frontend.school.buttons.okbutton)
	return await wait_for(func():return creator.phase=="editing" and creator.source_frontend.child=="package-spells" and creator.source_frontend.spells.layout_ready and creator.source_frontend.spells.model.get("ready",false),10)
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var fixture_dir:=str(args.report)+".resources";DirAccess.make_dir_recursive_absolute(fixture_dir)
	for name in ["fixture_sprefs","fixture_cancel"]:
		var file:=FileAccess.open(fixture_dir.path_join(name+".2da"),FileAccess.WRITE);file.store_string("2DA V2.0\nSpellIndex\n0 4\n1 1\n");file.close()
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface);surface.notify_mouse_entered()
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install) and active.mount_directory(fixture_dir,100000001),"Original catalogs mount read-only with separately authored preference resources")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var captions=preload("res://systems/native_data/talk_text.gd").new();captions.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,captions,base,"");creator.open(401)
	var samples: Array=[];var worker_ran:=false;var bytes_size:=0
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.school.layout_ready,50),"Actual creator and original source workers prepare",creator.resource_errors):
		spell_rules(creator,ui);var front=creator.source_frontend;var pane=front.spells;var identity: Array=creator.summary_identity();front.begin(identity,{"classBase":0},creator.rules.rows("classes"))
		check(creator.rules.point_balance()==0,"Unrelated ability allocation completes through actual active rules")
		if check(await enter_spells(creator),"Physical Package→Skills→Feats→School reaches native Spells with its real draft owner"):
			check(creator.source_post.stage==3 and creator.rules.draft.school==1 and creator.rules.creation_spell_slots[1]==2 and creator.source_spells.state.source.gain[1]==3,"Class-dependent transfer retains old-school cached slots separately from current-school spell gain")
			check(creator.rules.draft.known[0]==[0] and pane.model.available.map(func(entry):return int(entry.id))==[1,4] and pane.remaining.text=="5","Native draft learns all cantrips regardless of UserType/Master and filters active opposition")
			pane.buttons["available:0:info"].show();await click(pane.buttons["available:0:info"])
			if check(await wait_for(func():return pane.info_popup.layout_ready or not pane.info_popup.failure.is_empty(),10) and pane.info_popup.layout_ready,"Original spell information leaf prepares"):
				check(pane.modal_active and not pane.info_popup.modal_owner_ticket.is_empty() and pane.info_popup.description.get_parsed_text()=="Server spell help 1","Actual creator factory registers the distinct information owner and active spell text")
				await click(pane.info_popup.buttons.closebutton);check(not pane.modal_active and pane.info_popup.modal_owner_ticket.is_empty(),"Physical information Close retires its exact native owner")
			pane.capture("available:0:arrow");var old_ticket: Array=front.ticket.duplicate();ui.text.overrides[40001]="Renamed spell";ui.text.revision+=1;creator.refresh_source();pane.invoke("available:0:arrow")
			check(front.ticket!=old_ticket and creator.rules.draft.known[1].is_empty() and pane.model.available[0].name=="Renamed spell","Text reticket refreshes active names while rejecting held input without granting another budget")
			for turn in 8:
				var began:=Time.get_ticks_usec();pane.capture("available:0:arrow");pane.invoke("available:0:arrow");var added: bool=creator.rules.draft.known[1]==[1];pane.capture("known:0:arrow");pane.invoke("known:0:arrow");samples.append((Time.get_ticks_usec()-began)/1000.0)
				check(added and creator.rules.draft.known[1].is_empty() and creator.source_spells.state.remaining==5,"Actual controller add/remove changes then restores the owned draft "+str(turn))
			check(samples.max()<50.0,"Warm real controller handler pairs avoid an obnoxious synchronous stall: "+str(samples))
			# Configure legitimately prefetched this table. Evict only the
			# authored fixture's publication/request entry to exercise the real
			# asynchronous reload path, without a fake completion callback.
			creator.rules.tables.erase("fixture_sprefs");creator.requested.erase("table:fixture_sprefs");creator.source_spells.read(creator.rules,ui.text,identity)
			await press_only(pane.buttons.recommendbutton);release_now(pane.buttons.recommendbutton)
			check(pane.busy and creator.phase=="spells-preparing" and creator.rules.draft.known[1].is_empty(),"Physical Recommended resets native choices before asynchronous active-resource preparation")
			check(await wait_for(func():return creator.phase=="editing" and not pane.busy and creator.rules.draft.known.get(1,[])==[4,1],10),"Actual asset service reads the authored Package preference resource and commits its original order")
			check(creator.rules.tables.has("fixture_sprefs") and pane.remaining.text=="3" and not pane.buttons.okbutton.disabled,"Exhausted available choices permit native OK with spare budget")
			await click(pane.buttons.okbutton)
			check(front.child.is_empty() and front.main.visible and front.flow.completed.packages and creator.source_post.stage==0 and creator.rules.draft.memorized[1]==[4,1],"Original8011 callback commits preparations and finishes the configured parent sequence")
			check(SpellValidation.verify(creator.rules,ui.text,creator.rules.creation_spell_selection).valid,"Real controller choices pass final source transcript validation")
			creator.rules.tables.packages=creator.rules.tables.packages.duplicate(true);creator.rules.tables.packages.orderedRows[0].SpellPref2DA="fixture_cancel";creator.render()
			if check(await enter_spells(creator),"The actual Package chain can reopen a fresh native spell transaction"):
				creator.rules.tables.erase("fixture_cancel");creator.requested.erase("table:fixture_cancel");creator.source_spells.read(creator.rules,ui.text,identity)
				await press_only(pane.buttons.recommendbutton);release_now(pane.buttons.recommendbutton)
				check(pane.busy and creator.phase=="spells-preparing" and not pane.buttons.cancelbutton.disabled,"Pending recommendation keeps actual Cancel available")
				await key(KEY_ESCAPE);check(front.child.is_empty() and not front.flow.completed.packages and creator.rules.draft.known.is_empty() and not creator.rules.draft.has("sourceSpellChoices"),"Escape during preparation resets derived choices and retires the scoped transaction")
				await wait_for(func():return creator.jobs.is_empty() and creator.resource_queue.is_empty(),10);check(front.child.is_empty() and creator.phase=="editing","Late preparation completion cannot reopen or mutate the retired spell transaction")
			creator.rules.tables.packages=creator.rules.tables.packages.duplicate(true);creator.rules.tables.packages.orderedRows[0].SpellPref2DA="fixture_sprefs";creator.render()
			if check(await enter_spells(creator),"Native spell transaction can reopen after cancellation"):
				await click(pane.buttons.recommendbutton);await click(pane.buttons.okbutton)
				var errors: Array=creator.rules.errors();check(errors.is_empty(),"Completed native draft passes the real save validation",errors)
				if errors.is_empty():
					creator.phase="preparing";creator.begin_build();worker_ran=true
					check(await wait_for(func():return creator.build_task<0 and creator.phase in ["waiting","editing"],20),"Actual BIC worker completes with detached spell text and copied cached slot/transcript owners")
					var submissions: Array=sent.filter(func(message):return message.get("kind","")=="native-creation-submit")
					check(creator.phase=="waiting" and submissions.size()==1,"The real save worker produces exactly one owned submit intent",creator.status)
					if submissions.size()==1:
						var bytes:=Marshalls.base64_to_raw(str(submissions[0].data));bytes_size=bytes.size();var parser=preload("res://systems/native_data/gff_document.gd").new();var document:=parser.parse(bytes,"BIC ")
						check(parser.failure.is_empty(),"Actual worker output parses as original BIC")
						if parser.failure.is_empty():
							var cls: Dictionary=document.root.ClassList[0]
							check(cls.KnownList0.map(func(row):return int(row.Spell))==[0] and cls.KnownList1.map(func(row):return int(row.Spell))==[4,1],"BIC preserves physical cantrip/known-spell order rather than generic family filtering")
							check(cls.MemorizedList0.map(func(row):return int(row.Ready))==[1,0,0] and cls.MemorizedList1.map(func(row):return int(row.Ready))==[1,1,0] and cls.MemorizedList1.map(func(row):return int(row.Spell))==[4,1,65535],"BIC preserves earlier cached slot counts, prepares actual selected spells and writes unused slots unready")
							var output:=FileAccess.open(str(args.report)+".bic",FileAccess.WRITE);output.store_buffer(bytes);output.close()
	ui.close();ui.free();painter.free();surface.queue_free();await frames(6)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"handlerPairMs":samples,"workerRan":worker_ran,"bicBytes":bytes_size,"scope":"Actual native Gameplay/creator/frontend Package-Skills-Feats-School-Spells controls, active custom2DA/TLK and native asynchronous preference resource, transcript/slot commits, info owner, cancellation/stale completion and real BIC worker/submit intent with parsed known/memorized bytes. Controlled artwork/fonts; custom data is authored and not sent to a server. No original pixels, actual server upload/admission, spontaneous encoder or full remaining creator/level-up parity.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
