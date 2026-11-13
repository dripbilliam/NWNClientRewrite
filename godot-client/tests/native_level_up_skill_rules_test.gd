extends "res://tests/native_creation_overrides_test.gd"
# Uses real mounted/parsed resources and production creation/level controllers.
# Only the level-begin snapshot and protocol command sink are supplied here.
const TwoDa=preload("res://systems/native_data/two_da.gd")
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Game=preload("res://systems/native_data/game_ui_rules.gd")
const SkillRules=preload("res://systems/native_data/creation_skill_rules.gd")
const Level=preload("res://systems/native_level_up.gd")
const Wizard=preload("res://systems/server_level_up.gd")
var observations: Array=[]
class Desktop:
	extends RefCounted
	var owner_ui: Dictionary={}
	var rules
	var sent: Array=[]
	func class_tables_ready(_id: int) -> bool:return true # All fixture dependencies are mounted and parsed below.
	func command(value: Dictionary) -> void:sent.append(value.duplicate(true))
func oracle(path: String) -> void:
	check(FileAccess.get_sha256(path)=="ca7d734843053e460f2bdff7c4199121c11885fd8e69ce06c08a7ad0d996aee6","Post-first-level original instruction observations are pinned")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(corpus.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and corpus.rows.size()==144,"The144 post-first-level cases identify the unchanged original binary")
	for row in corpus.rows:
		var c: Dictionary=row.case;var tables: Dictionary=c.vital.tables.duplicate(true);var level:=int(c.vital.source.level)
		tables.classes.orderedRows[0].SkillPointBase=str(int(c.classPoints));tables.classes.orderedRows[0].SkillsTable="test_skill_rules";tables.test_skill_rules={"orderedRows":c.classSkills.duplicate(true)};tables.skills={"orderedRows":[]}
		for data in c.skills:tables.skills.orderedRows.append({"AllClassesCanUse":str(int(data.AllClassesCanUse))})
		var race: Dictionary=tables.racialtypes.orderedRows[0];race.SkillPointModifierAbility=SkillRules.KEYS[int(c.ability)] if int(c.ability)<6 else "None";race.ExtraSkillPointsPerLevel=str(int(c.extra));race.FirstLevelSkillPointsMultiplier=str(int(c.multiplier))
		check(SkillRules.budget(tables,0,0,row.scores,int(c.vital.source.dexterityAdjustment),int(c.unspent),level)==int(row.budget),"Active rule budget, carried point WORD and new total level match original instructions")
		var ranks: Array=row.initial.ranks.map(func(value):return int(value));var points:=int(row.initial.points)
		for step in row.results:
			if step.operation.kind=="recommend":
				for id in c.preferences:
					while true:
						var result:=SkillRules.move(tables,0,int(id),int(ranks[int(id)]),points,0,1,level)
						if not result.changed:break
						ranks[int(id)]=result.rank;points=result.points
			else:
				var id:=int(step.operation.id);var result:=SkillRules.move(tables,0,id,int(ranks[id]),points,int(step.operation.get("baseline",0)),1 if step.operation.kind=="up" else -1,level);ranks[id]=result.rank;points=result.points
			check(ranks==step.state.ranks.map(func(value):return int(value)) and points==int(step.state.points),"Original post-first-level rank/cap/cost/point results match shared native rules")
func fixture(directory: String,variant: int) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	table(directory,"classes",["Label","Name","PlayerClass","SkillPointBase","SkillsTable","StatGainTable","HitDie","Str","Dex","Con","Int","Wis","Cha"],[{"Label":"ServerMystic","Name":16777216,"PlayerClass":1,"SkillPointBase":5,"SkillsTable":"sv_skills","StatGainTable":"sv_gain","HitDie":6,"Str":10,"Dex":12,"Con":14,"Int":18,"Wis":16,"Cha":8}])
	table(directory,"racialtypes",["Label","PlayerRace","SkillPointModifierAbility","ExtraSkillPointsPerLevel","FirstLevelSkillPointsMultiplier","WisAdjust","NumberNormalFeatsEveryNthLevel"],[{"Label":"ServerRace","PlayerRace":1,"SkillPointModifierAbility":"Wis" if variant==0 else "None","ExtraSkillPointsPerLevel":2,"FirstLevelSkillPointsMultiplier":3,"WisAdjust":2,"NumberNormalFeatsEveryNthLevel":0}])
	table(directory,"ruleset",["Label","Value"],[{"Label":"CHARGEN_ABILITY_NEUTRAL_VALUE","Value":12},{"Label":"CHARGEN_ABILITY_MODIFIER_INCREMENT","Value":3},{"Label":"CHARGEN_SKILL_MAX_LEVEL_1_BONUS","Value":7 if variant==0 else 1}])
	table(directory,"skills",["Name","KeyAbility","Untrained","AllClassesCanUse"],[{"Name":16777217,"KeyAbility":"WIS","Untrained":1,"AllClassesCanUse":1},{"Name":16777218,"KeyAbility":"INT","Untrained":1,"AllClassesCanUse":1},{"Name":16777217,"KeyAbility":"STR","Untrained":0,"AllClassesCanUse":0}])
	table(directory,"sv_skills",["SkillIndex","ClassSkill"],[{"SkillIndex":0,"ClassSkill":1 if variant==0 else 0},{"SkillIndex":0,"ClassSkill":0 if variant==0 else 1}])
	table(directory,"sv_gain",["Wis"],[{"Wis":1}])
	# Empty server feat/spell lists are valid and must not resurrect stock rows.
	table(directory,"feat",["FEAT"],[]);table(directory,"spells",["Name"],[])
func read_tables(catalog,fixture_dependencies: bool=true) -> Dictionary:
	var result: Dictionary={};var parser:=TwoDa.new()
	var names: Array=["classes","racialtypes","ruleset","skills","feat","spells"]
	if fixture_dependencies:names.append_array(["sv_skills","sv_gain"])
	for name in names:
		result[name]=parser.parse(catalog.get_resource(name,2017).get_string_from_ascii());check(parser.failure.is_empty(),"Native parser reads resolved "+name)
	return result
func plus(view) -> int:
	for item in view.state.items:
		if item.get("tag","")=="skill-plus":return int(item.controlId)
	return -1
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	oracle(args.oracle)
	var base:=Catalog.new();check(base.mount_install(args.install),"Read-only base resources mount")
	var stock:=base.get_resource("classes",2017);var surface:=SubViewport.new();surface.size=Vector2i(1440,960);surface.disable_3d=true;surface.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(surface)
	var text=preload("res://systems/native_data/talk_text.gd").new();check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Base text opens independently")
	var game:=Game.new();game.text=text;var desktop:=Desktop.new();desktop.rules=game;desktop.owner_ui={"text":text};var level:=Level.new();var view:=Wizard.new();view.setup(str(args.report)+".layout.cfg");surface.add_child(view);level.configure(desktop,view);view.request.connect(level.input)
	var creation:=Rules.new()
	for variant in 2:
		var directory:=str(args.report)+".server-"+str(variant);fixture(directory,variant);var catalog:=base.fork();check(catalog.mount_directory(directory,99999999),"A distinct server override catalog mounts above base")
		text.tables=read_tables(catalog);check(text.custom.open_file(tlk(directory)),"Server custom TLK opens");creation.tables=text.tables;creation.catalog=catalog;creation.initialize();creation.draft.abilities={"Str":10,"Dex":12,"Con":14,"Int":18,"Wis":16,"Cha":8}
		check(creation.reset_source_choices() and creation.skill_balance()==(27 if variant==0 else 21),"Real creation draft budget uses server race ability, class points, gain, ruleset and multiplier")
		check(creation.change_skill(0,1) and creation.skill_balance()==(26 if variant==0 else 19),"Real creation allocator uses the first matching server class-skill row")
		view.open();level.begin({"snapshot":{"classes":[{"id":0,"level":2}],"baseAbilities":[10,12,14,18,16,8],"race":0,"skills":[1,0,0],"feats":[],"spellbooks":{},"fieldDC6":4,"fieldE34":255,"fieldE48":"","fieldE30":255,"fieldE38":""},"available":[true],"token":7+variant})
		check(level.budget()==(13 if variant==0 else 11) and level.balance()==level.budget(),"Production level-up uses active server modifier arithmetic and carries existing skill points without first-level multiplication")
		var observation:={"variant":variant,"budget":level.budget(),"rules":[level.skill_rule(0),level.skill_rule(1),level.skill_rule(2)],"tables":text.tables.ruleset};observations.append(observation)
		check(level.skill_rule(0).maximum==(10 if variant==0 else 2) and level.skill_rule(0).cost==(1 if variant==0 else 2) and level.skill_rule(1).maximum==(5 if variant==0 else 2) and not level.skill_rule(2).allowed,"Production level-up uses active server caps, class/cross costs and usability")
		view.navigate(2);var id:=plus(view)
		if check(id>=0 and not view.controls[id].disabled,"Active server skill rows expose actual native increment controls"):
			check(view.state.items.any(func(item):return item.get("tag","")=="skill" and str(item.label).begins_with("Server choice")),"Level-up row names use the server custom TLK")
			view.controls[id].pressed.emit();check(int(level.draft.skills[0])==1 and level.balance()==(12 if variant==0 else 9),"Actual level-up button updates the draft with server-defined cost")
			while int(level.snapshot.skills[0])+int(level.draft.skills[0])<int(level.skill_rule(0).maximum) and level.balance()>=int(level.skill_rule(0).cost):
				id=plus(view);view.controls[id].pressed.emit()
			check(int(level.snapshot.skills[0])+int(level.draft.skills[0])==int(level.skill_rule(0).maximum) and view.controls[plus(view)].disabled,"Actual level-up control stops at the server-defined rank cap")
			observation.after={"rank":int(level.snapshot.skills[0])+int(level.draft.skills[0]),"maximum":level.skill_rule(0).maximum,"points":level.balance(),"disabled":view.controls[plus(view)].disabled}
		level.submitting=true;level.render();check(view.controls.values().all(func(control):return not control is BaseButton or control.disabled),"Submission keeps every level-up button disabled even when its row is otherwise available")
		level.submitting=false;level.render()
		view.close_level_up();check(level.snapshot.is_empty() and level.draft.is_empty() and not view.wanted,"Cancel retires the server-specific level draft")
	check(base.get_resource("classes",2017)==stock and creation.rows("classes").size()==1 and text.tables.spells.orderedRows.is_empty(),"Server rule replacement leaves the base catalog intact and does not resurrect stock rows")
	creation.tables=read_tables(base,false);text.tables=creation.tables;check(creation.rows("classes").size()>11 and creation.rows("skills").size()>3,"Restoring the base catalog restores its own class and skill lists")
	view.free();surface.free();await process_frame;await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"publicConnections":0,"graphical":false,"scope":"Original144 post-first-level skill allocator cases plus two mounted native 2DA/TLK catalogs, real creation draft and native level-up controls. Snapshot/protocol sink are fixtures; full original level-up lifecycle, pixels and authoritative admission remain separate."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
