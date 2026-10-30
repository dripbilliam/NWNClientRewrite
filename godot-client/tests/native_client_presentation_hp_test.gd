extends "res://tests/native_particle_schedule_test.gd"
const HP=preload("res://systems/native_data/client_presentation_hp.gd")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:="res://../backups/animations/native-client-presentation-hp-observations-v1.json"
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(oracle.target==BINARY_SHA and oracle.rows.size()==192,"Pinned original constructor observations")
	for row in oracle.rows:
		var c: Dictionary=row.case; var rules: Array=[]
		for key in c:
			if str(key).begins_with("CHARGEN_"): rules.append({"Label":key,"Value":str(int(c[key]))})
		var races: Array=[{},{},{},{},{},{},{"ConAdjust":str(int(c.raceCon))}]
		var tables:={"ruleset":{"orderedRows":rules},"racialtypes":{"orderedRows":races},"classes":{"orderedRows":[{},{},{},{},{"StatGainTable":"CUSTOM_GAIN"}]},"custom_gain":{"orderedRows":[{"Con":str(int(c.classCon))}]}}
		var original:=HP.constructor(tables)
		check(same(original,row.constructed).is_empty(),"Original constructor "+JSON.stringify(c))
		var actor:={"replicated":{"stats":{"classes":[{"id":3,"level":15}]}}}; var before:=actor.duplicate(true)
		check(HP.stored(actor,"maximum",original)==int(row.afterClassUpdate.maximum) and HP.stored(actor,"current",original)==int(row.afterClassUpdate.current),"Partial class update preserves original presentation HP")
		check(actor==before,"Private constructor projection never invents authoritative HP")
		actor.replicated.hitPoints={"base":47,"temporary":2,"current":31,"maximum":99}
		check(HP.stored(actor,"maximum",original)==int(row.afterDisclosedFields.maximum) and HP.stored(actor,"current",original)==int(row.afterDisclosedFields.current),"Received shorts override private constructor state")
	check(HP.constructor({})=={"base":0,"temporary":0,"current":1,"maximum":1},"Stock ruleset constructor HP")
	check(HP.constructor({"ruleset":{"orderedRows":[{"Label":"CHARGEN_ABILITY_MODIFIER_INCREMENT","Value":"0"}]}}).is_empty(),"Invalid original integer division is diagnosed")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"evidenceSha256":FileAccess.get_sha256(path),"scope":"192 original private constructor cases, class-only update retention and received HP replacement. No inference of undisclosed server health or live combat outcome."},"\t")); file.close()
	print("NATIVE_CLIENT_PRESENTATION_HP ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
