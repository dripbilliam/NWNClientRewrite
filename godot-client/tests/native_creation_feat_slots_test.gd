extends SceneTree
const Slots=preload("res://systems/native_data/creation_feat_slots.gd")
const Rules=preload("res://systems/native_data/creation_rules.gd")
const LevelUp=preload("res://systems/native_level_up.gd")
const TwoDA=preload("res://systems/native_data/two_da.gd")
const ORIGINAL="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
const SHA="5842d021351c5a7c4b9cce7786f6b484892ef4ef3728b95023e4f62c395c7534"
var checks:=0
var failures: Array=[]
func _init() -> void:run.call_deferred()
func check(value: bool,label: String,details: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"details":details})
func fixture(source: Dictionary) -> Dictionary:
	var races: Array=[];races.resize(int(source.raceId)+1);races.fill({})
	races[int(source.raceId)]={"NormalFeatEveryNthLevel":source.period,"NumberNormalFeatsEveryNthLevel":source.number,"ExtraFeatsAtFirstLevel":source.extra}
	var classes: Array=[];var result: Dictionary={"racialtypes":{"columns":["NormalFeatEveryNthLevel","NumberNormalFeatsEveryNthLevel","ExtraFeatsAtFirstLevel"],"orderedRows":races}}
	for entry in source.levels:
		while classes.size()<=int(entry.classId):classes.append({})
		var name:="server_bonus_"+str(int(entry.classId));classes[int(entry.classId)]={"BonusFeatsTable":name}
		var bonuses: Array=[]
		for value in source.classBonus[str(int(entry.classId))]:bonuses.append({"Bonus":value})
		result[name]={"columns":["Bonus"],"orderedRows":bonuses}
	result.classes={"columns":["BonusFeatsTable"],"orderedRows":classes};return result
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==SHA,"Original feat-slot corpus is immutable")
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(evidence.target==ORIGINAL and evidence.rows.size()==288 and evidence.procedures==["0x1407ec290","0x1407f5d70","0x1407f10a0","0x1402997d0"],"All four complete original functions execute without substituted boundaries")
	for observed in evidence.rows:
		var before:=JSON.stringify(observed);var source: Dictionary=observed.case;var selected: Dictionary=source.levels[int(source.current)];var total:=0
		for entry in source.levels:total+=int(entry.level)&255
		var expected:={"normal":int(observed.normal),"bonus":int(observed.bonus)}
		check(Slots.count(int(source.period),int(source.number),int(source.extra),total,int(selected.level),source.classBonus[str(int(selected.classId))])==expected,"Decoded byte counters match the original machine instructions",source)
		var tables:=fixture(source)
		check(Slots.calculate(tables,int(source.raceId),int(selected.classId),total,int(selected.level))==expected,"Active physical race/class/bonus tables feed the same original counters",source)
		if int(selected.level)>0:
			var level_up:=LevelUp.new();level_up.desktop={"owner_ui":{"text":{"tables":tables}}};level_up.draft={"classId":int(selected.classId)}
			var classes: Array=source.levels.duplicate(true)
			classes[int(source.current)].level=int(selected.level)-1
			level_up.snapshot={"race":int(source.raceId),"classes":classes.map(func(entry):return {"id":int(entry.classId),"level":int(entry.level)})}
			check(level_up.feat_slots()==expected,"Actual level-up owner uses new total level and selected class level",source)
		if total==1 and int(selected.level)==1:
			var creation:=Rules.new();creation.tables=tables;creation.draft={"raceId":int(source.raceId),"classId":int(selected.classId)}
			check(creation.feat_slots()==expected,"Actual creation owner uses the shared original first-level counters",source)
		check(JSON.stringify(observed)==before,"Projection does not mutate the independent original corpus")
	var parser:=TwoDA.new()
	var custom:={"racialtypes":parser.parse_reference("2DA V2.0\nNormalFeatEveryNthLevel NumberNormalFeatsEveryNthLevel ExtraFeatsAtFirstLevel\n901 -3 256 255\n"),"classes":parser.parse_reference("2DA V2.0\nBonusFeatsTable\n17 server_bonus\n"),"server_bonus":parser.parse_reference("2DA V2.0\nDEFAULT: 2\nBonus\n900 257\n901 ****\n")}
	check(Slots.calculate(custom,0,0,1,1)=={"normal":255,"bonus":1},"Parsed server values and physical rows own first-level counts despite arbitrary 2DA row labels")
	check(Slots.calculate(custom,0,0,3,2)=={"normal":0,"bonus":0},"Negative server period, wrapped count and explicit blank bonus preserve original widths")
	check(Slots.calculate(custom,0,0,6,3)=={"normal":0,"bonus":2},"Missing physical bonus row uses the table's numeric default")
	check(Slots.calculate(custom,0,0,6,61).bonus==0,"Original class bonus getter stops after physical level60")
	var old_races: Array=[];old_races.resize(7);old_races.fill({});custom.racialtypes={"columns":[],"orderedRows":old_races}
	check(Slots.calculate(custom,6,0,1,1).normal==2 and Slots.calculate(custom,0,0,1,1).normal==1,"Absent legacy columns use only the original loader's format defaults")
	custom.racialtypes=parser.parse_reference("2DA V2.0\nNormalFeatEveryNthLevel NumberNormalFeatsEveryNthLevel ExtraFeatsAtFirstLevel\n0 **** **** ****\n")
	check(Slots.calculate(custom,0,0,1,1).normal==0,"Present blank server columns do not fall back to stock race counts")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"288 complete original feat-slot executions, active table projection, real creation/level-up call sites and authored physical 2DA defaults. Does not accept feat prerequisites, source Feats UI, full creator/level-up, pixels or server outcomes."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
