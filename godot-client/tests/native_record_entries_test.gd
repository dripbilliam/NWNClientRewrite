extends SceneTree
const Entries=preload("res://systems/native_data/character_record_entries.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""; var fixture:=""
	var order_fixture:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--fixture="): fixture=arg.substr(10)
		if arg.begins_with("--order-fixture="): order_fixture=arg.substr(16)
	if output.is_empty() or fixture.is_empty() or order_fixture.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(str(original.target)=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Feat admission oracle pins the original client binary")
	for row in original.rows:
		var before: Dictionary=row.case.duplicate(true); var successors: Dictionary=row.case.successors
		var result:=Entries.feat_admission(row.case.main,row.case.bonus,func(id):return successors.get(str(int(id))))
		check(result.ids==row.selected.map(func(id):return int(id)) and result.errors.is_empty() and row.case==before,"Complete original feat admission matches main/bonus/successor case "+str(row.case.main)+"/"+str(row.case.bonus))
	var cycle:=Entries.feat_admission([1,2],[],func(id):return 2 if int(id)==1 else 1)
	check(cycle.ids.is_empty() and not cycle.errors.is_empty(),"Malformed successor cycles retire safely with diagnostics instead of hanging the UI")
	var text:=Text.new(); var rules:=Rules.new(); rules.text=text
	text.tables={"feat":{"orderedRows":[{"FEAT":"0","Label":"Old","SUCCESSOR":"1"},{"FEAT":"1","Label":"New","SUCCESSOR":"-1"},{"FEAT":"****","Label":"Disabled row","SUCCESSOR":"-1"}]}}
	var actor:={"playerState":{"feats":[0,1,2],"bonusFeats":[1]},"inventoryStats":{"fields118":[0,1],"fields128":[]}}
	var before:=actor.duplicate(true); var projected:=rules.record_entries(actor,2)
	check(projected.size()==1 and projected[0].id==1 and projected[0].binding.intParam==1,"Native record uses current authoritative feat lists and owned active-table successors")
	check(rules.feats(actor)==[0,1,2] and actor==before,"Character-sheet admission never rewrites gameplay feat ownership or received lists")
	actor.inventoryStats.fields118=[0]; actor.inventoryStats.fields128=[1]; projected=rules.record_entries(actor,2)
	check(projected.size()==2 and projected[0].id==1 and projected[1].id==1 and projected[0].entryId!=projected[1].entryId,"Native bonus-list duplicate semantics retain separate private UI entries")
	actor.inventoryStats.fields118=[2]; actor.inventoryStats.fields128=[]
	check(rules.record_entries(actor,2).is_empty(),"An inactive FEAT cell is not exposed as a fabricated character-sheet row")
	text.tables.feat.orderedRows[0].SUCCESSOR="2"; text.tables.feat.orderedRows[2].FEAT="2"; actor.inventoryStats.fields118=[0,2]
	check(rules.record_entries(actor,2)[0].id==2,"Server-specific active feat definitions govern successor display without a stock list")
	var order: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(order_fixture)); var writer:=preload("res://systems/native_data/gff_writer.gd").new()
	check(order.target==original.target,"Label comparator oracle uses the same pinned binary")
	for row in order.rows: check(Entries.compare(PackedByteArray(row.firstBytes),PackedByteArray(row.secondBytes))==int(row.result),"Original default-locale comparator matches "+JSON.stringify([row.first,row.second]))
	check(writer.text("Évasion")==PackedByteArray([201,118,97,115,105,111,110]),"Native label ordering encodes the source CP1252 bytes before comparison")
	var sorted_rows:=Entries.ordered([{"name":"Skill 2","tag":0},{"name":"Skill 10","tag":1},{"name":"same","tag":2},{"name":"SAME","tag":3}])
	check(sorted_rows.map(func(row):return int(row.tag))==[3,2,1,0],"Original lower-bound insertion preserves lexical numeric order and inserts equal labels before older rows")
	text.close()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalRows":original.rows.size(),"orderRows":order.rows.size(),"fixtureSha256":FileAccess.get_sha256(fixture),"orderFixtureSha256":FileAccess.get_sha256(order_fixture),"publicConnections":0,"scope":"Complete original feat-admission and default-locale comparator instruction oracles, active FEAT/SUCCESSOR rows, lower-bound insertion and private entries. Alternate runtime locales and complete row-state parity remain open."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
