extends SceneTree
const Plan=preload("res://systems/native_data/level_up_class_dependencies.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func run() -> void:
	var args: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		var pair:=argument.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var received:={"classes":[{"id":0,"level":3}]};var retained:=received.duplicate(true)
	var tables:={"classes":{"orderedRows":[{"StatGainTable":"oldgain","SkillsTable":"oldskills","FeatsTable":"oldfeats","AttackBonusTable":"oldbab","BonusFeatsTable":"unused_oldbonus","SpellCaster":"0","SpellGainTable":"unused_noncast"},{"StatGainTable":"newgain","SkillsTable":"newskills","FeatsTable":"newfeats","AttackBonusTable":"newbab","BonusFeatsTable":"newbonus","SpellCaster":"1","SpellGainTable":"newspgn","SpellKnownTable":"newspkn"}]}}
	for name in ["oldgain","oldskills","oldfeats","oldbab"]:tables[name]={"orderedRows":[]}
	var before:=tables.duplicate(true);var value:=Plan.compose(received,1,tables)
	check(not value.ready and value.pending and value.dependencies==["newgain","newskills","newfeats","newbab","newbonus","newspgn","newspkn"],"Appended class loads its exact active named dependencies before Skills")
	check(not value.required.has("unused_oldbonus") and not value.required.has("unused_noncast"),"No whole-world or irrelevant old-bonus/noncaster-spell preload")
	check(tables==before and received==retained,"Class preparation plan never changes raw tables or received class levels")
	for name in value.dependencies:tables[name]={"orderedRows":[]}
	value=Plan.compose(received,1,tables)
	check(value.ready and value.advanced.current==1 and value.advanced.classes[1].level==1 and value.advanced.level==4,"Parsed empty tables remain valid known resources and advanced class-slot context stays mode1")
	tables.newskills={};value=Plan.compose(received,1,tables)
	check(not value.ready and not value.get("pending",false) and value.failed=="newskills","Known failed critical table cannot masquerade as empty ready data")
	tables.newskills={"orderedRows":"bad"};check(not Plan.compose(received,1,tables).ready,"Malformed table shape remains explicit")
	tables.newskills={"orderedRows":[]};tables.classes.orderedRows[1].SpellCaster="****"
	check(not Plan.compose(received,1,tables).ready,"Missing class spell flag cannot become a guessed noncaster")
	tables.classes.orderedRows[1].SpellCaster="0";tables.erase("newspgn");tables.erase("newspkn");value=Plan.compose(received,1,tables)
	check(value.ready and not value.required.has("newspgn") and not value.required.has("newspkn"),"Active noncaster override retires unused spell-table requirements")
	tables.classes.orderedRows[1].StatGainTable="****";tables.erase("newgain");check(Plan.compose(received,1,tables).ready,"Explicit native empty optional class resource does not request row0 or a stock table")
	check(not Plan.compose(received,2,tables).ready,"Physical absent class ID cannot be prepared")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"serverConnections":0,"gpu":false,"runtimeIntegrated":false,"scope":"NEW mode1 class-selected dependency plan: advanced owned/new class resources, conditional caster/current-bonus dependencies, parsed empty vs failed/missing, exact IDs and borrowed-data isolation. No worker/control/server acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
