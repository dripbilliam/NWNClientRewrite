extends "res://tests/native_creation_gender_test.gd"
const PointsOracle=preload("res://tests/native_creation_ability_points_test.gd")
const AbilityRules=preload("res://systems/native_data/creation_ability_rules.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	PointsOracle.verify_oracle(args.oracle,check)
	surface=SubViewport.new();surface.size=Vector2i(1600,1000);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var base:=Catalog.new();var active:=Catalog.new();check(base.mount_install(args.install) and active.mount_install(args.install),"Independent pregame and active rules catalogs mount")
	check(preload("res://systems/native_data/prepared_cache.gd").digest(base.get_resource("cg_attributes",2047))=="5b73d80375d34ad2d2b95a247e5b7c1494b66b7c0f977e7d247157be169b2eac","Pinned original Attributes GUI")
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);surface.add_child(painter)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Original captions load independently")
	var ui:=Gameplay.new();surface.add_child(ui);ui.configure(active,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg");ui.request.connect(func(message):sent.append(message.duplicate(true)))
	var creator=ui.creator;creator.configure_source(painter,text,base,"");creator.open(161)
	if check(await wait_for(func():return creator.phase=="editing" and creator.source_frontend.main.layout_ready and creator.source_frontend.attributes.layout_ready,100),"Real draft and original Attributes controls prepare",creator.source_frontend.attributes.failure):
		var front=creator.source_frontend;var pane=front.attributes;var scope: Array=creator.summary_identity()
		front.begin(scope,{"classBase":int(creator.rules.draft.classId)},creator.rules.rows("classes"));front.flow.enabled.abilities=true;front.refresh();await frames();await click(front.main.buttons.abilitiesbutton)
		check(pane.wanted and pane.assets.catalog==base and pane.data_text==ui.text and pane.values.size()==6 and pane.buttons.size()==21,"Actual source parent opens original numeric/help/arrow controls with active data")
		check(pane.help.current.slice(1)==[261,457] and pane.cost.text.is_empty() and pane.buttons.okbutton.disabled and pane.points.text==str(creator.rules.point_balance()),"Original initial general help, blank cost and remaining-point OK availability")
		var initial:=int(creator.rules.draft.abilities.Str);var pool: int=creator.rules.point_balance();creator.rules.draft.domains=[1,2];creator.rules.draft.skills={0:1}
		await click(pane.buttons.strupbutton)
		check(int(creator.rules.draft.abilities.Str)==initial+1 and creator.rules.point_balance()==pool-1 and pane.help_index==0 and pane.cost.text=="1","Physical arrow down applies exactly one native draft increment without a second release action")
		check(pane.values[0].text==str(int(creator.rules.abilities().Str))+" (-1)" and pane.help.body.get_parsed_text().contains("Base Ability Score: "+str(initial+1)),"Original score/modifier and detailed base/race/class/final help are displayed")
		await click(pane.buttons.cancelbutton)
		check(front.child.is_empty() and int(creator.rules.draft.abilities.Str)==initial+1 and creator.rules.point_balance()==pool-1 and not front.flow.completed.abilities and creator.rules.draft.domains==[1,2] and creator.rules.draft.skills=={0:1},"Original Cancel preserves live allocation edits and does not accept/reset the parent")
		await click(front.main.buttons.abilitiesbutton);await click(pane.buttons.strdownbutton)
		check(int(creator.rules.draft.abilities.Str)==initial and creator.rules.point_balance()==pool,"Physical decrease refunds the cost of the resulting raw score")
		await click(pane.buttons.strlabel);var before_help: String=pane.help.body.get_parsed_text();var before_cost: String=pane.cost.text;await click(pane.buttons.recommendbutton)
		check(creator.rules.point_balance()==0 and creator.rules.draft.abilities==AbilityRules.recommended(creator.rules.tables,creator.rules.cls()) and not pane.buttons.okbutton.disabled,"Source Recommended copies active class recommendations and sets the actual remaining BYTE to0")
		check(pane.help.body.get_parsed_text()==before_help and pane.cost.text==before_cost,"Original Recommended refreshes numeric labels without silently rebuilding the selected help/cost text")
		front.flow.enabled.packages=true;creator.rules.skill_summary_mask=7;await click(pane.buttons.okbutton)
		check(front.flow.completed.abilities and front.flow.enabled.packages and creator.rules.draft.domains.is_empty() and creator.rules.draft.skills.is_empty() and creator.rules.skill_summary_mask==0,"Abilities8003 performs original conditional parent reset and enables Package")
		# Native timer semantics: immediate action, strict500ms first delay and
		#50ms period, at most one callback per GUI tick, no release action.
		creator.rules.draft.abilities.Str=8;creator.rules.record_ability_points(10);creator.refresh_source();await click(front.main.buttons.abilitiesbutton)
		var button: Button=pane.buttons.strupbutton;var point:=button.get_global_rect().get_center();var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.global_position=point;event.pressed=true;surface.push_input(event,true);pane.set_process(false)
		check(int(creator.rules.draft.abilities.Str)==9 and pane.repeat_clock.active,"Actual timer button acts immediately on physical press")
		pane.advance_repeat(500000);check(int(creator.rules.draft.abilities.Str)==9,"Native timer threshold is strict, not greater-or-equal")
		pane.advance_repeat(1);check(int(creator.rules.draft.abilities.Str)==10,"First repeat follows the original half-second delay")
		pane.advance_repeat(50000);check(int(creator.rules.draft.abilities.Str)==10,"Periodic threshold is also strict")
		pane.advance_repeat(1);check(int(creator.rules.draft.abilities.Str)==11,"Held arrow repeats after original50ms period")
		event.pressed=false;surface.push_input(event,true);await frames();check(not pane.repeat_clock.active and int(creator.rules.draft.abilities.Str)==11,"Release retires repeat without applying a duplicate increment")
		await key(KEY_ESCAPE);check(front.child.is_empty() and int(creator.rules.draft.abilities.Str)==11,"Escape preserves live edits like original Cancel")
		# Active server gains can initialize raw primary below the base minimum.
		var custom: Dictionary=creator.rules.tables.classes.duplicate(true);var id:=int(creator.rules.draft.classId);custom.orderedRows[id].SpellCaster="1";custom.orderedRows[id].SpellcastingAbil="STR";custom.orderedRows[id].StatGainTable="server_ability_gains";custom.orderedRows[id].Str="17";creator.rules.tables.classes=custom;creator.rules.tables.server_ability_gains={"orderedRows":[{"Str":"4"}]};creator.rules.commit_class(id);creator.refresh_source()
		check(int(creator.rules.draft.abilities.Str)==7 and creator.rules.point_balance()==31,"Original Class cache supports raw primary7 plus server gain4 and31 remaining points")
		await click(front.main.buttons.abilitiesbutton);await click(pane.buttons.strdownbutton)
		check(int(creator.rules.draft.abilities.Str)==7 and creator.rules.point_balance()==31 and pane.help.body.get_parsed_text().contains("Class: 4"),"Primary minimum uses effective score and detailed help exposes server class gain")
		await click(pane.buttons.strupbutton);check(int(creator.rules.draft.abilities.Str)==8 and creator.rules.point_balance()==30,"Native increment spends1 even when starting below the usual base minimum")
		await click(pane.title);check(pane.help_index==6 and pane.help_prefix.is_empty() and pane.cost.text=="0","Original title restores general help and cost0")
		var old_ticket: Array=front.ticket.duplicate();pane.capture("strupbutton");ui.text.revision+=1;creator.refresh_source();pane.invoke("strupbutton")
		check(front.ticket!=old_ticket and int(creator.rules.draft.abilities.Str)==8 and pane.repeat_tag.is_empty(),"Active text replacement retires held allocation and repeat scope")
		surface.size=Vector2i(512,400);await frames();front.place();await click(pane.buttons.strupbutton);check(pane.scale.x<1 and int(creator.rules.draft.abilities.Str)==9,"Scaled original arrow controls keep pointer alignment")
		var retiring:=func(_operation,_index,_identity):front.dismiss();return {"ready":true}
		front.bind_attributes(scope,front.attributes_context,true,ui.text,retiring,creator.commit_source_attributes);await click(pane.buttons.strupbutton);check(not front.wanted and int(creator.rules.draft.abilities.Str)==9,"Reentrant draft retirement prevents a late ability result or repeat")
		creator.cancel();creator.open(162);await wait_for(func():return creator.phase=="editing",100);front.attributes_result(true,old_ticket)
		check(creator.summary_identity()!=scope and creator.edit_source_attributes("up",0,scope).is_empty() and creator.commit_source_attributes(scope).is_empty(),"Old mutation/acceptance callbacks cannot affect a replacement draft")
	check(not sent.any(func(message):return message.kind=="native-creation-submit"),"Inspection does not fabricate character upload or server acceptance")
	ui.close();ui.free();painter.free();surface.queue_free();await frames(5)
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"sourceArtworkDouble":true,"scope":"Original1344 ability transitions plus real source Attributes numeric/help/arrow/hold/recommendation/Cancel/Escape/OK, actual draft mutation, active custom gains, conditional parent reset, scaling and stale/reentrant retirement. Original pixels/full formatted-help instruction proof, full source creator and level-up remain open."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
