extends SceneTree
# Authored table replacements mounted over the actual install. No original
# table or proprietary asset is copied into this fixture directory.
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
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
	table(directory,"classes",["Label","Name","PlayerClass","SpellCaster","SpellTableColumn","SpellcastingAbil","MemorizesSpells","SpellbookRestricted","SkillPointBase","HitDie","Package","SkillsTable","FeatsTable","BonusFeatsTable","SpellGainTable","SpellKnownTable","AttackBonusTable","SavingThrowTable","StatGainTable","Int"],[{"Label":"ServerMystic","Name":16777216,"PlayerClass":1,"SpellCaster":1,"SpellTableColumn":"ServerLevel","SpellcastingAbil":"INT","MemorizesSpells":1,"SpellbookRestricted":1,"SkillPointBase":2,"HitDie":6,"Package":0,"SkillsTable":"auth_skill","FeatsTable":"auth_feat","BonusFeatsTable":"auth_bonus","SpellGainTable":"auth_gain","SpellKnownTable":"auth_known","AttackBonusTable":"auth_attack","SavingThrowTable":"auth_save","StatGainTable":"auth_stats","Int":18}])
	table(directory,"racialtypes",["Label","Name","PlayerRace","Appearance","AbilitiesPointBuyNumber","SkillPointModifierAbility","FirstLevelSkillPointsMultiplier","NumberNormalFeatsEveryNthLevel"],[{"Label":"AuthoredRace","Name":16777217,"PlayerRace":1,"Appearance":6,"AbilitiesPointBuyNumber":30,"SkillPointModifierAbility":"Int","FirstLevelSkillPointsMultiplier":4,"NumberNormalFeatsEveryNthLevel":1}])
	table(directory,"spells",["Label","Name","ServerLevel","UserType","Master","SubRadSpell1"],[{"Label":"ServerFamily","Name":16777217,"ServerLevel":1,"UserType":1,"Master":0,"SubRadSpell1":1},{"Label":"ServerChild","Name":16777217,"ServerLevel":1,"UserType":1,"Master":0},{"Label":"ServerLeaf","Name":16777217,"ServerLevel":1,"UserType":1},{"Label":"OtherClass","Name":16777217,"ServerLevel":255,"UserType":1}])
	table(directory,"feat",["Label","FEAT","AllClassesCanUse","MININT"],[{"Label":"ServerGrant","FEAT":16777217,"AllClassesCanUse":0},{"Label":"ServerRestricted","FEAT":16777217,"AllClassesCanUse":1,"MININT":18},{"Label":"ServerPick","FEAT":16777217,"AllClassesCanUse":1,"MININT":10},{"Label":"ServerBonus","FEAT":16777217,"AllClassesCanUse":0}])
	table(directory,"auth_feat",["FeatIndex","List","GrantedOnLevel"],[{"FeatIndex":0,"List":3,"GrantedOnLevel":1},{"FeatIndex":3,"List":2}])
	table(directory,"auth_skill",["SkillIndex","ClassSkill"],[{"SkillIndex":0,"ClassSkill":1}])
	table(directory,"auth_bonus",["Bonus"],[{"Bonus":1}]); table(directory,"auth_gain",["NumSpellLevels","SpellLevel0","SpellLevel1"],[{"NumSpellLevels":2,"SpellLevel0":0,"SpellLevel1":1}]); table(directory,"auth_known",["SpellLevel0","SpellLevel1"],[{"SpellLevel0":0,"SpellLevel1":1}])
	table(directory,"auth_attack",["BAB"],[{"BAB":0}]); table(directory,"auth_save",["FortSave"],[{"FortSave":0}]); table(directory,"auth_stats",["Int"],[{"Int":1}])
	table(directory,"packages",["Label","Name","ClassID","PlayerClass","Gold","SkillPref2DA","FeatPref2DA","SpellPref2DA"],[{"Label":"ServerPackage","Name":16777218,"ClassID":0,"PlayerClass":1,"Gold":77,"SkillPref2DA":"auth_pref_skill","FeatPref2DA":"auth_pref_feat","SpellPref2DA":"auth_pref_spell"}])
	table(directory,"auth_pref_skill",["SkillIndex"],[{"SkillIndex":0}]); table(directory,"auth_pref_feat",["FeatIndex"],[{"FeatIndex":3},{"FeatIndex":2}]); table(directory,"auth_pref_spell",["SpellIndex"],[{"SpellIndex":2}])
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original resources mount read-only"); check(catalog.mount_directory(directory,99999999),"Authored server override layer mounts above the install")
	var ui:=Gameplay.new(); root.add_child(ui); ui.configure(catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".layout.cfg",{"name":"authcustom","path":tlk(directory)})
	ui.creator.open(1); var deadline:=Time.get_ticks_msec()+90000
	while ui.creator.phase!="editing" and Time.get_ticks_msec()<deadline: await process_frame
	var r=ui.creator.rules
	var observed: Dictionary={}
	if check(ui.creator.phase=="editing","Creator loads the active replacement tables"):
		check(r.rows("classes").size()==1 and r.cls().Label=="ServerMystic","Class choices use the active table rather than stock IDs")
		check(ui.creator.title("classes",0)=="Server Mystic","Server custom TLK resolves character-choice names natively")
		check(r.spell_options(1)==[0,2] and not r.spell_options(1).has(1),"Custom spell column replaces stock lists and suppresses a family's child")
		check(r.granted_feats()==[0] and r.feat_slots()=={"normal":1,"bonus":1},"Active racial/class tables own granted and selectable feats")
		check(not r.feat_requirement(1,[0]).is_empty() and r.feat_allowed(3,"bonus") and not r.feat_allowed(3,"normal"),"Server feat prerequisites and bonus lists replace stock behavior")
		ui.creator.view.choose_recommended(); deadline=Time.get_ticks_msec()+30000
		while ui.creator.phase!="editing" and Time.get_ticks_msec()<deadline: await process_frame
		check(r.draft.known.get(1,[])==[2],"Recommendation follows the server package's spell preference resource")
		observed={"feats":r.draft.feats.duplicate(true),"abilities":r.abilities(),"slots":r.feat_slots(),"preferences":r.preference("FeatPref2DA","FeatIndex")}
		check(r.draft.feats.size()==2 and r.draft.feats[0].id==3 and r.draft.feats[1].id==2,"Recommendation fills server bonus and general feat slots from active preferences")
		check(r.draft.memorized.get(1,[]).has(2),"Preparation uses the recommended custom spell")
		r.tables.feat.orderedRows[2].MinFortSave="0"
		check(r.feat_requirement(2,[0]).contains("Fortitude"),"An explicit zero saving-throw requirement remains distinct from an absent cell")
		r.tables.packages={"orderedRows":[]}; r.draft.packageId=-1
		check(r.recommend().contains("No selectable starting package"),"Servers without a selectable package fail explicitly instead of loading a guessed default")
	ui.close(); ui.free(); await process_frame; await process_frame
	var next_catalog:=Catalog.new(); next_catalog.mount_install(args.install)
	var next_ui:=Gameplay.new(); root.add_child(next_ui); next_ui.configure(next_catalog,args.install,ProjectSettings.globalize_path("user://native-prepared-v2"),str(args.report)+".next-layout.cfg")
	next_ui.creator.open(2); deadline=Time.get_ticks_msec()+90000
	while next_ui.creator.phase!="editing" and Time.get_ticks_msec()<deadline: await process_frame
	check(next_ui.creator.phase=="editing" and next_ui.creator.rules.rows("classes").size()>11 and str(next_ui.creator.rules.row("spells",0).get("Label",""))!="ServerFamily","Replacing the connection's catalog restores its own class and spell tables")
	check(next_ui.text.custom.count==0,"The prior server's custom TLK does not leak into a new connection")
	next_ui.close(); next_ui.free(); await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observed":observed,"publicConnections":0,"scope":"Authored server overrides over original catalog; custom classes/spell column/feats/preferences/TLK are native"}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
