extends SceneTree
const Values=preload("res://systems/native_data/character_record_values.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""; var fixture:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--fixture="): fixture=arg.substr(10)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or fixture.is_empty() or install.is_empty() or FileAccess.file_exists(output): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(str(original.target)=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Ability oracle pins the same original client binary")
	for row in original.rows:
		var entries: Array=[]
		for key in row.rules: entries.append({"Label":key,"Value":str(row.rules[key])})
		check(Values.modifier(int(row.score),{"ruleset":{"orderedRows":entries}})==int(row.modifier),"Original instruction result matches score/rules "+str(row.score)+"/"+str(row.rules))
	var tables:={"ruleset":{"orderedRows":[{"Label":"CHARGEN_ABILITY_NEUTRAL_VALUE","Value":"12"},{"Label":"CHARGEN_ABILITY_NEUTRAL_VALUE","Value":"****"},{"Label":"CHARGEN_ABILITY_NEUTRAL_VALUE","Value":" 10suffix"},{"Label":"chargen_ability_neutral_value","Value":"255"}]}}
	check(Values.modifier(9,tables)==-1,"Ruleset uses last nonempty exact-case label and original atoi prefix semantics")
	check(Values.modifier(15,{"ruleset":{"orderedRows":[{"Label":"CHARGEN_ABILITY_MODIFIER_INCREMENT","Value":"0x2"}]}})==null,"Malformed zero-divisor rules display unknown rather than crashing the UI")
	var rows:=Values.abilities([18,12,9,11,255,0],[4,2,-3,0,255,1],-2,{})
	check(rows[0].modifier==4 and rows[0].modifierAdjustment==2 and rows[0].adjustment==4,"Received positive score adjustment compares effective and unadjusted native modifiers")
	check(rows[1].modifier==-1 and rows[1].modifierAdjustment==-1,"Received Dexterity modifier cache participates in effective value and comparison color")
	check(rows[2].modifier==-1 and rows[2].modifierAdjustment==-2 and rows[2].adjustment==-3,"Negative received adjustment preserves signed score/modifier presentation")
	check(rows[4].adjustment==-1 and rows[4].modifier==122 and rows[4].modifierAdjustment==127,"Signed-byte baseline score arithmetic wraps before the original modifier lookup")
	check(Values.abilities([],[],0,{}).all(func(row):return row.score==null and row.modifier==null),"Undisclosed ability values remain unavailable")
	check(Values.tone(1)==Color8(32,255,32) and Values.tone(-1)==Color8(255,1,1) and Values.tone(0)==Color.WHITE,"Ability presentation uses original raw color-token RGB values")
	var text:=Text.new(); check(text.base.open_file(install.path_join("lang/en/data/dialog.tlk")),"Original TLK opens read-only for record labels")
	var rules:=Rules.new(); rules.text=text
	var actor:={"id":42,"replicated":{"name":{"text":"Values fixture"},"hitPoints":{"current":7,"maximum":15,"fieldE8":2}},"inventoryStats":{"fields70":[18,12,9,11,255,0],"fields7d":[4,2,-3,0,255,1],"fields76":[14,10,12,11,0,255,-2],"field98":4,"field9a":5,"field99":6,"field9b":-1,"combatInformation":{"field5":10,"field6":15,"field7":3}}}
	text.objects={42:actor}; var before:=actor.duplicate(true); var record:=rules.record(actor,"values")
	check(record.abilities[1].modifier==-1 and record.abilities[1].modifierAdjustment==-1,"Actual native record path reads Dexterity from the seventh fields76 cache byte")
	check(record.labels.experience==text.raw({"strRef":314}) and record.labels.nextLevel==text.raw({"strRef":315}) and record.abilities[0].label==text.raw({"strRef":135}),"Record and ability labels resolve the original active TLK references")
	check(record.details[0].label==text.raw({"strRef":317}) and record.details[0].value==4 and record.details[1].value==5 and record.details[2].value==6,"Original Fortitude/Reflex/Will field ordering and localized captions are retained")
	check(record.details[3].value==null and record.details[5].value=="15%" and record.details[6].value=="-3","Undisclosed BAB sentinel and native arcane-failure/armor-penalty formatting reach the record model")
	check(actor==before,"Record presentation does not mutate received ability/combat fields")
	text.close()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalRows":original.rows.size(),"fixtureSha256":FileAccess.get_sha256(fixture),"publicConnections":0,"scope":"Original machine-instruction ability arithmetic oracle, wire-cache signed-byte display projection, exact token colors and active TLK labels. Full record content/disclosure and UI parity remain open."},"\t")); file.close(); quit(0 if failures.is_empty() else 1)
