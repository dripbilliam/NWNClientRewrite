extends SceneTree
const Builder=preload("res://systems/native_data/creation_bic.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Parser=preload("res://systems/native_data/gff_document.gd")
class RulesData extends RefCounted:
	var draft: Dictionary={"classId":0,"familiar":2,"familiarName":"Actual familiar","companion":3,"companionName":"Actual companion"}
	var tables: Dictionary={}
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func model(minimum: Variant,arcane: Variant) -> RefCounted:
	var rules:=RulesData.new();rules.tables={"classes":{"columns":["MinAssociateLevel","Arcane"],"orderedRows":[{"MinAssociateLevel":str(minimum),"Arcane":str(arcane)}],"orderedCells":[[str(minimum),str(arcane)]],"defaultValue":"****"}};return rules
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	for row in [[255,0,[]],[0,1,[]],[1,1,["FamiliarType","FamiliarName"]],[1,0,["CompanionType","CompanionName"]],[257,-2,["FamiliarType","FamiliarName"]]]:
		var rules=model(row[0],row[1]);var before: Dictionary=rules.draft.duplicate(true);var value:=Builder.source_pet_fields(rules)
		check(value.ready and value.fields.keys()==row[2],"Original807950 class minimum/kind controls exact emitted field pair "+str(row[0])+"/"+str(row[1]))
		var writer:=Writer.new();var bytes:=writer.write("BIC ",Writer.record(value.fields));var parser:=Parser.new();var document:=parser.parse(bytes,"BIC ")
		check(writer.failure.is_empty() and parser.failure.is_empty() and rules.draft==before,"Typed write/read leaves the private source draft unchanged")
		if not row[2].is_empty():check(document.field_types[0][row[2][0]]==5 and document.field_types[0][row[2][1]]==10,"Actual parsed pet fields retain WriteFieldINT and CExoString types")
	var unset=model(1,1);unset.draft.familiar=-1;unset.draft.familiarName="";var patch:=Builder.source_pet_fields(unset);var writer:=Writer.new();var parser:=Parser.new();var document:=parser.parse(writer.write("BIC ",Writer.record(patch.fields)),"BIC ")
	check(patch.ready and document.root.FamiliarType==-1 and document.root.FamiliarName=="" and not document.root.has("CompanionType"),"Native unset signed type/name is preserved without inventing the unused companion")
	check(not Builder.source_pet_fields(model("****",0)).ready,"Unknown reached minimum remains unavailable")
	check(not Builder.source_pet_fields(model(1,"****")).ready,"Unknown reached kind remains unavailable")
	check(Builder.source_pet_fields(model(255,"****")).ready,"Unreached kind is not a dependency for a class without an associate")
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Original807950 conditional first-level associate field shape/type, parsed native BIC and unavailable dependency guards; no server admission."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
