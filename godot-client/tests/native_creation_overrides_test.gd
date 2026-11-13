extends SceneTree
# Authored table replacements mounted over the actual install. No original
# table or proprietary asset is copied into this fixture directory.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Doubles=preload("res://tests/native_portrait_chooser_test.gd")
var failures: Array=[]
var checks:=0
func check(value: bool,label: String) -> bool:
	checks+=1
	if not value: failures.append(label)
	return value
func _initialize() -> void: call_deferred("run")
func table(directory: String,name: String,columns: Array,rows: Array) -> void:
	var text:="2DA V2.0\n\n"+" ".join(columns)+"\n"
	for index in rows.size():
		var cells: Array=[str(index)]
		for column in columns: cells.append(str(rows[index].get(column,"****")))
		text+=" ".join(cells)+"\n"
	var file:=FileAccess.open(directory.path_join(name+".2da"),FileAccess.WRITE); file.store_string(text)
func tlk(directory: String) -> String:
	var strings: Array=["Server Mystic","Server choice","Server package"]; var bytes:=PackedByteArray(); bytes.resize(20+40*strings.size()); bytes.encode_u32(8,0); bytes.encode_u32(12,strings.size()); bytes.encode_u32(16,bytes.size())
	for index in 8: bytes[index]="TLK V3.0".unicode_at(index)
	var offset:=0
	for index in strings.size():
		var text: PackedByteArray=str(strings[index]).to_ascii_buffer(); bytes.encode_u32(20+index*40,1); bytes.encode_u32(20+index*40+28,offset); bytes.encode_u32(20+index*40+32,text.size()); bytes.append_array(text); offset+=text.size()
	var path:=directory.path_join("authcustom.tlk"); var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); return path
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("install") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var directory: String=str(args.report)+".overrides"; DirAccess.make_dir_recursive_absolute(directory)
	table(directory,"classes",["Label","Name","PlayerClass","SpellCaster","SpellTableColumn","SpellcastingAbil","MemorizesSpells","SpellbookRestricted","SkillPointBase","HitDie","Package","SkillsTable","FeatsTable","BonusFeatsTable","SpellGainTable","SpellKnownTable","AttackBonusTable","SavingThrowTable","StatGainTable","Str","Dex","Con","Int","Wis","Cha","AlignRestrict","AlignRstrctType","InvertRestrict"],[{"Label":"ServerMystic","Name":16777216,"PlayerClass":1,"SpellCaster":1,"SpellTableColumn":"ServerLevel","SpellcastingAbil":"INT","MemorizesSpells":1,"SpellbookRestricted":1,"SkillPointBase":2,"HitDie":6,"Package":0,"SkillsTable":"auth_skill","FeatsTable":"auth_feat","BonusFeatsTable":"auth_bonus","SpellGainTable":"auth_gain","SpellKnownTable":"auth_known","AttackBonusTable":"auth_attack","SavingThrowTable":"auth_save","StatGainTable":"auth_stats","Str":10,"Dex":12,"Con":14,"Int":18,"Wis":9,"Cha":11,"AlignRestrict":21,"AlignRstrctType":3,"InvertRestrict":0}])
	table(directory,"ruleset",["Label","Value"],[{"Label":"CHARGEN_ABILITY_COST_INCREMENT2","Value":9},{"Label":"CHARGEN_ABILITY_COST_INCREMENT3","Value":12},{"Label":"CHARGEN_ABILITY_COST_INCREMENT4","Value":16}])
	table(directory,"racialtypes",["Label","Name","PlayerRace","Appearance","AbilitiesPointBuyNumber","SkillPointModifierAbility","FirstLevelSkillPointsMultiplier","NumberNormalFeatsEveryNthLevel"],[{"Label":"AuthoredRace","Name":16777217,"PlayerRace":1,"Appearance":6,"AbilitiesPointBuyNumber":30,"SkillPointModifierAbility":"Int","FirstLevelSkillPointsMultiplier":4,"NumberNormalFeatsEveryNthLevel":1}])
	table(directory,"spells",["Label","Name","ServerLevel","UserType","Master","SubRadSpell1"],[{"Label":"ServerFamily","Name":16777217,"ServerLevel":1,"UserType":1,"Master":0,"SubRadSpell1":1},{"Label":"ServerChild","Name":16777217,"ServerLevel":1,"UserType":1,"Master":0},{"Label":"ServerLeaf","Name":16777217,"ServerLevel":1,"UserType":1},{"Label":"OtherClass","Name":16777217,"ServerLevel":255,"UserType":1}])
	table(directory,"feat",["Label","FEAT","AllClassesCanUse","MININT"],[{"Label":"ServerGrant","FEAT":16777217,"AllClassesCanUse":0},{"Label":"ServerRestricted","FEAT":16777217,"AllClassesCanUse":1,"MININT":18},{"Label":"ServerPick","FEAT":16777217,"AllClassesCanUse":1,"MININT":10},{"Label":"ServerBonus","FEAT":16777217,"AllClassesCanUse":0}])
	table(directory,"auth_feat",["FeatIndex","List","GrantedOnLevel"],[{"FeatIndex":0,"List":3,"GrantedOnLevel":1},{"FeatIndex":3,"List":2}])
	table(directory,"auth_skill",["SkillIndex","ClassSkill"],[{"SkillIndex":0,"ClassSkill":1}])
	table(directory,"skills",["Name","Description","KeyAbility","Untrained","AllClassesCanUse","HideFromLevelUp"],[{"Name":16777217,"Description":16777218,"KeyAbility":"INT","Untrained":1,"AllClassesCanUse":0},{"Name":16777218,"Description":16777217,"KeyAbility":"DEX","Untrained":1,"AllClassesCanUse":1},{"Name":16777217,"Description":16777218,"KeyAbility":"STR","Untrained":0,"AllClassesCanUse":0},{"Name":16777217,"KeyAbility":"INT","Untrained":1,"AllClassesCanUse":1,"HideFromLevelUp":1}])
	table(directory,"auth_bonus",["Bonus"],[{"Bonus":1}]); table(directory,"auth_gain",["NumSpellLevels","SpellLevel0","SpellLevel1"],[{"NumSpellLevels":2,"SpellLevel0":0,"SpellLevel1":1}]); table(directory,"auth_known",["SpellLevel0","SpellLevel1"],[{"SpellLevel0":0,"SpellLevel1":1}])
	table(directory,"auth_attack",["BAB"],[{"BAB":0}]); table(directory,"auth_save",["FortSave"],[{"FortSave":0}]); table(directory,"auth_stats",["Int"],[{"Int":1}])
	table(directory,"packages",["Label","Name","ClassID","PlayerClass","Gold","SkillPref2DA","FeatPref2DA","SpellPref2DA"],[{"Label":"ServerPackage","Name":16777218,"ClassID":0,"PlayerClass":1,"Gold":77,"SkillPref2DA":"auth_pref_skill","FeatPref2DA":"auth_pref_feat","SpellPref2DA":"auth_pref_spell"}])
	table(directory,"auth_pref_skill",["SkillIndex"],[{"SkillIndex":0}]); table(directory,"auth_pref_feat",["FeatIndex"],[{"FeatIndex":3},{"FeatIndex":2}]); table(directory,"auth_pref_spell",["SpellIndex"],[{"SpellIndex":2}])
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original resources mount read-only"); check(catalog.mount_directory(directory,99999999),"Authored server override layer mounts above the install")
	var ui:=Gameplay.new(); root.add_child(ui); ui.configure(catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg",{"name":"authcustom","path":tlk(directory)})
	var base:=Catalog.new();base.mount_install(args.install)
	var text=preload("res://systems/native_data/talk_text.gd").new();text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk"))
	var painter:=Painter.new();var art:=Doubles.HeadlessArt.new();var fonts:=Doubles.HeadlessFonts.new();painter.art=art;painter.fonts=fonts;painter.add_child(art);painter.add_child(fonts);art.loaded.connect(painter.art_loaded);root.add_child(painter);ui.creator.configure_source(painter,text,base,"")
	ui.creator.open(1); var deadline:=Time.get_ticks_msec()+90000
	while ui.creator.phase!="editing" and Time.get_ticks_msec()<deadline: await process_frame
	var r=ui.creator.rules
	var observed: Dictionary={}
	if check(ui.creator.phase=="editing","Creator loads the active replacement tables"):
		var front=ui.creator.source_frontend;deadline=Time.get_ticks_msec()+30000
		while not front.class_chooser.layout_ready and Time.get_ticks_msec()<deadline:await process_frame
		if check(front.class_chooser.layout_ready,"Original Class frame prepares independently of server table overrides"):
			front.begin(ui.creator.summary_identity(),{"classBase":int(r.draft.classId)},r.rows("classes"));front.flow.enabled["class"]=true;front.refresh();front.main.buttons.classbutton.button_down.emit();front.main.buttons.classbutton.pressed.emit()
			var page=front.class_chooser
			check(page.assets.catalog==base and page.data_text==ui.text and page.row_buttons.size()==1 and page.row_buttons[0].get_child(0).text=="Server Mystic" and page.title.text==text.raw({"strRef":61920}),"Original artwork/base title and actual mounted server class/custom TLK coexist in the same Class control")
			page.buttons.recommendbutton.button_down.emit();page.buttons.recommendbutton.pressed.emit();check(page.state.selected_class()==-1 and page.buttons.okbutton.disabled,"Original physical-row4 recommendation does not invent Fighter in a one-class server ruleset")
			page.row_buttons[0].button_down.emit();page.row_buttons[0].pressed.emit();page.buttons.okbutton.button_down.emit();page.buttons.okbutton.pressed.emit()
			check(front.flow.completed["class"] and int(r.draft.classId)==0 and int(r.creation_base_hp)==6 and int(r.draft.abilities.Int)==10 and int(r.creation_class_points)==28,"Actual source Class OK uses mounted custom hit die, spell ability, first-level stat gain and point pool")
			deadline=Time.get_ticks_msec()+30000
			while not front.alignment.layout_ready and Time.get_ticks_msec()<deadline:await process_frame
			if check(front.alignment.layout_ready,"Original Alignment frame prepares for mounted custom class rules"):
				front.main.buttons.alignbutton.button_down.emit();front.main.buttons.alignbutton.pressed.emit();var alignment=front.alignment
				check(alignment.assets.catalog==base and alignment.data_text==ui.text and alignment.state.enabled==[true,false,false,false,false,false,false,false,false],"Source Alignment availability comes from actual mounted server class restriction columns")
				alignment.buttons.recommendbutton.button_down.emit();alignment.buttons.recommendbutton.pressed.emit()
				check(alignment.state.selected==7 and alignment.buttons.cnbutton.disabled and alignment.buttons.cnbutton.button_pressed,"Original class0 recommendation retains disabled CN under a server-only-LG restriction")
				alignment.buttons.lgbutton.button_down.emit();alignment.buttons.lgbutton.pressed.emit();alignment.buttons.okbutton.button_down.emit();alignment.buttons.okbutton.pressed.emit()
				check(front.flow.completed.align and front.flow.enabled.abilities and int(r.draft.goodEvil)==85 and int(r.draft.lawChaos)==85 and r.alignment_allowed(r.cls(),85,85),"Actual source Alignment commits legal server-data axes and original parent progression")
				deadline=Time.get_ticks_msec()+30000
				while not front.attributes.layout_ready and Time.get_ticks_msec()<deadline:await process_frame
				if check(front.attributes.layout_ready,"Original Attributes frame prepares for mounted server allocation rules"):
					front.main.buttons.abilitiesbutton.button_down.emit();front.main.buttons.abilitiesbutton.pressed.emit();var attributes=front.attributes
					check(attributes.assets.catalog==base and attributes.data_text==ui.text and attributes.model.points==28 and attributes.model.gains[3]==1,"Source Attributes uses the mounted server class gain, remaining pool and active text")
					for index in 2:attributes.buttons.strupbutton.button_down.emit();attributes.buttons.strupbutton.button_up.emit();attributes.buttons.strupbutton.pressed.emit()
					check(int(r.draft.abilities.Str)==10 and r.point_balance()==25 and attributes.cost.text=="2","Actual source arrows spend1 then2 at the mounted ruleset's custom threshold9")
					for index in 2:attributes.buttons.strdownbutton.button_down.emit();attributes.buttons.strdownbutton.button_up.emit();attributes.buttons.strdownbutton.pressed.emit()
					check(int(r.draft.abilities.Str)==8 and r.point_balance()==28,"Decreasing refunds the same active server costs")
					attributes.buttons.recommendbutton.button_down.emit();attributes.buttons.recommendbutton.pressed.emit()
					check(r.draft.abilities=={"Str":10,"Dex":12,"Con":14,"Int":18,"Wis":9,"Cha":11} and r.point_balance()==0 and attributes.model.scores[3]==19,"Source Recommended copies all six mounted class scores and displays the separate server gain")
					attributes.buttons.okbutton.button_down.emit();attributes.buttons.okbutton.pressed.emit()
					check(front.flow.completed.abilities and front.flow.enabled.packages,"Mounted server allocation commits through actual source OK and parent8003")
					front.main.buttons.classbutton.button_down.emit();front.main.buttons.classbutton.pressed.emit();page.buttons.okbutton.button_down.emit();page.buttons.okbutton.pressed.emit()
					check(int(r.draft.abilities.Int)==10 and r.point_balance()==28 and not front.flow.completed.abilities,"Accepting the same source Class resets the previous server allocation and later completion")
			front.dismiss();ui.creator.stage_source();ui.creator.refresh_source()
		check(r.rows("classes").size()==1 and r.cls().Label=="ServerMystic","Class choices use the active table rather than stock IDs")
		check(ui.creator.title("classes",0)=="Server Mystic","Server custom TLK resolves character-choice names natively")
		check(r.spell_options(1)==[0,2] and not r.spell_options(1).has(1),"Custom spell column replaces stock lists and suppresses a family's child")
		check(r.granted_feats()==[0] and r.feat_slots()=={"normal":1,"bonus":1},"Active racial/class tables own granted and selectable feats")
		check(not r.feat_requirement(1,[0]).is_empty() and r.feat_allowed(3,"bonus") and not r.feat_allowed(3,"normal"),"Server feat prerequisites and bonus lists replace stock behavior")
		var package_front=ui.creator.source_frontend;r.recommend_abilities();ui.creator.refresh_source();package_front.begin(ui.creator.summary_identity(),{"classBase":0},r.rows("classes"));package_front.flow.enabled.packages=true;package_front.refresh()
		deadline=Time.get_ticks_msec()+30000
		while not package_front.packages.layout_ready and Time.get_ticks_msec()<deadline:await process_frame
		if check(package_front.packages.layout_ready,"Original Package controls prepare independently of mounted server data"):
			package_front.main.buttons.packagesbutton.button_down.emit();package_front.main.buttons.packagesbutton.pressed.emit();var page=package_front.packages
			check(page.row_buttons.size()==1 and page.row_buttons[0].get_child(0).text=="Server package" and page.assets.catalog==base and page.data_text==ui.text,"Actual source Package list and custom TLK use the mounted server table")
			var before: Dictionary=r.draft.abilities.duplicate();page.buttons.okbutton.button_down.emit();page.buttons.okbutton.pressed.emit();deadline=Time.get_ticks_msec()+30000
			while (ui.creator.phase!="editing" or not package_front.child.is_empty()) and Time.get_ticks_msec()<deadline:await process_frame
			check(package_front.flow.completed.packages and r.draft.abilities==before and int(r.draft.packageGold)==77 and r.draft.skills=={0:4},"Source Package commits custom gold and listed skill preference without changing abilities or filling unlisted skills")
			check(r.draft.feats==[{"id":3,"kind":"bonus"},{"id":2,"kind":"normal"}] and r.draft.known.get(1,[])==[2] and r.draft.memorized.get(1,[])==[2],"Actual source automatic choices follow the custom feat/spell resources")
			package_front.main.buttons.packagesbutton.button_down.emit();package_front.main.buttons.packagesbutton.pressed.emit();page.buttons.configurepckg.button_down.emit();page.buttons.configurepckg.pressed.emit();deadline=Time.get_ticks_msec()+30000
			while (ui.creator.phase!="editing" or not package_front.skills.wanted or not package_front.skills.layout_ready) and Time.get_ticks_msec()<deadline:await process_frame
			if check(package_front.skills.wanted and package_front.skills.layout_ready,"Mounted server Configure opens the bound original Skills view"):
				var skills=package_front.skills;var points: int=r.skill_balance();var hidden:=true;var disabled:=false
				for index in skills.model.entries.size():
					var entry: Dictionary=skills.model.entries[index];hidden=hidden and int(entry.id)!=3
					if int(entry.id)==2:disabled=skills.row_buttons[index].disabled
				check(skills.row_buttons.size()==3 and hidden and disabled and skills.model.entries.any(func(entry):return entry.name=="Server choice "+ui.text.raw({"strRef":52951})),"Original skill controls follow mounted custom names, physical IDs, hidden rows and class availability")
				for id in [0,1]:skills.buttons["up:"+str(id)].button_down.emit();skills.buttons["up:"+str(id)].button_up.emit();skills.buttons["up:"+str(id)].pressed.emit()
				check(r.draft.skills=={0:1,1:1} and r.skill_balance()==points-3 and skills.cost.text=="2" and skills.help.title.text=="Server package" and int(skills.model.details[1].modifier)==1,"Actual source arrows and help use server class/cross costs, custom TLK and KeyAbility")
				skills.buttons.cancelbutton.button_down.emit();skills.buttons.cancelbutton.pressed.emit();check(r.draft.skills.is_empty() and not package_front.flow.completed.packages,"Mounted server Skills Cancel resets the actual draft and original parent")
		package_front.dismiss();ui.creator.stage_source();ui.creator.refresh_source()
		ui.creator.view.choose_recommended(); deadline=Time.get_ticks_msec()+30000
		while ui.creator.phase!="editing" and Time.get_ticks_msec()<deadline: await process_frame
		check(r.draft.known.get(1,[])==[2],"Recommendation follows the server package's spell preference resource")
		observed={"feats":r.draft.feats.duplicate(true),"abilities":r.abilities(),"slots":r.feat_slots(),"preferences":r.preference("FeatPref2DA","FeatIndex")}
		check(r.draft.feats.size()==2 and r.draft.feats[0].id==3 and r.draft.feats[1].id==2,"Recommendation fills server bonus and general feat slots from active preferences")
		check(r.draft.memorized.get(1,[]).has(2),"Preparation uses the recommended custom spell")
		r.draft.abilities.Con=8;r.tables.feat.orderedRows[2].MinFortSave="0"
		check(r.feat_requirement(2,[0]).contains("Fortitude"),"An explicit zero saving-throw requirement remains distinct from an absent cell")
		r.tables.packages={"orderedRows":[]}; r.draft.packageId=-1
		check(r.recommend().contains("No selectable starting package"),"Servers without a selectable package fail explicitly instead of loading a guessed default")
	ui.close(); ui.free();painter.free(); await process_frame; await process_frame
	var next_catalog:=Catalog.new(); next_catalog.mount_install(args.install)
	var next_ui:=Gameplay.new(); root.add_child(next_ui); next_ui.configure(next_catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".next-layout.cfg")
	next_ui.creator.open(2); deadline=Time.get_ticks_msec()+90000
	while next_ui.creator.phase!="editing" and Time.get_ticks_msec()<deadline: await process_frame
	check(next_ui.creator.phase=="editing" and next_ui.creator.rules.rows("classes").size()>11 and str(next_ui.creator.rules.row("spells",0).get("Label",""))!="ServerFamily","Replacing the connection's catalog restores its own class and spell tables")
	check(next_ui.text.custom.count==0,"The prior server's custom TLK does not leak into a new connection")
	next_ui.close(); next_ui.free(); await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observed":observed,"publicConnections":0,"scope":"Authored server overrides over original catalog; custom classes/spell column/feats/preferences/TLK are native"}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
