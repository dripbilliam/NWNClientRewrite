extends SceneTree
const HitDie=preload("res://systems/native_data/level_up_hit_die.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	if not oracle is Dictionary or oracle.get("binarySha256")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" or oracle.get("rows",[]).size()!=192:quit(2);return
	for index in oracle.rows.size():
		var row: Dictionary=oracle.rows[index];var c: Dictionary=row.case;var result:=HitDie.roll_byte(int(c.die),int(c.total),int(c.threshold),int(c.forceMaximum)!=0,int(c.seed))
		check(result.ready!=row.undefinedDivision,"Original signed division defined/undefined boundary "+str(index))
		if not row.undefinedDivision:check(int(result.value)==int(row.value),"Original raw BYTE die roll/maximum override "+str(index))
		check(int(result.randomCalls)==int(row.randomCalls) and int(result.seedAfter)==int(row.seedAfter),"Original random-state advance/order including forced maximum "+str(index))
	var tables:={"classes":{"orderedRows":[{"HitDie":"10"}]},"ruleset":{"orderedRows":[]}}
	var source:={"ready":true,"source":{"current":0,"classes":[{"id":0,"level":3}],"owned":[],"selected":[]}}
	var before:=source.duplicate(true);var maximum:=HitDie.compose(source,tables,{})
	check(maximum.ready and maximum.hitDie==10 and maximum.randomCalls==0,"Active die and default MIN_LEVEL_FOR_MAX_HP use maximum without inventing application/RNG context")
	source.source.classes[0].level=4
	check(not HitDie.compose(source,tables,{}).ready,"A required unbound application/random owner remains pending")
	var rolled:=HitDie.compose(source,tables,{"forceMaximum":false,"randomSeed":1})
	check(rolled.ready and rolled.hitDie>=5 and rolled.hitDie<=10 and rolled.randomCalls==1 and not rolled.serverAcknowledged,"Owned original CRT state produces a mode1 roll, not a server ACK")
	tables.ruleset={"orderedRows":[{"Label":"MIN_LEVEL_FOR_MAX_HP","Value":"8"}]};check(HitDie.compose(source,tables,{}).hitDie==10,"Active custom rules own the maximum-die level boundary")
	check(before.source.classes[0].level==3 and source.source.owned.is_empty(),"Numeric finalizer never mutates received/private class or feat arrays")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":192,"scope":"Unchanged original hit-die arithmetic/CRT-state differential plus active-rule numeric finalizer; no actual application-field producer, summary text/body, runtime entry or server acceptance."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
