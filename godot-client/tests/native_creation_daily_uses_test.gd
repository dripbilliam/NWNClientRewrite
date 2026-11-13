extends SceneTree
const Builder=preload("res://systems/native_data/creation_bic.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Parser=preload("res://systems/native_data/gff_document.gd")
class OwnedRules extends "res://systems/native_data/creation_rules.gd":
	# This fixture isolates serialized file shape, not selection admission.
	func errors() -> Array:return []
	func spell_slots(level: int) -> int:return 2 if level==0 else 1 if level==1 else 0
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["install","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Actual catalog and UTI loader remain in the generic serialization path")
	var rules:=OwnedRules.new();rules.catalog=catalog
	rules.tables={"classes":{"orderedRows":[{"HitDie":"8","SpellCaster":"1","MemorizesSpells":"0"}]},"racialtypes":{"orderedRows":[{"Appearance":"0"}]},"packages":{"orderedRows":[{"Gold":"3"}]},"chargenclothes":{"orderedRows":[{"ItemResRef":"nw_cloth002"}]}}
	rules.draft={"classId":0,"raceId":0,"packageId":0,"gender":0,"feats":[],"skills":{},"known":{0:[1,2],1:[3]},"memorized":{},"domains":[],"school":0,"firstName":"Native","lastName":"Generic","biography":"","subrace":"","deity":"","age":18,"phenotype":0,"head":1,"clothes":0,"skin":0,"hair":0,"tattoo1":0,"tattoo2":0,"portrait":"po_hu_m_01","soundset":0,"familiar":-1,"familiarName":"","companion":-1,"companionName":"","goodEvil":50,"lawChaos":50,"abilities":{"Str":10,"Dex":10,"Con":10,"Int":10,"Wis":10,"Cha":10}}
	rules.creation_skill_points=0;rules.skill_points_snapshot={}
	var builder:=Builder.new();var parser:=Parser.new();var document:=parser.parse(builder.build(rules),"BIC ")
	check(builder.failure.is_empty() and parser.failure.is_empty(),"Real generic Builder writes and reparses a complete authored BIC")
	if not document.is_empty():
		var cls: Dictionary=document.root.ClassList[0]
		check(cls.SpellsPerDayList.size()==10 and cls.SpellsPerDayList[0].NumSpellsLeft==2 and cls.SpellsPerDayList[1].NumSpellsLeft==1,"Generic non-source spontaneous draft retains its existing daily-use list")
		check(cls.KnownList0.map(func(row):return int(row.Spell))==[1,2] and cls.KnownList1[0].Spell==3,"Daily-use gating does not change known spell serialization")
		rules.draft.sourceSpellChoices=true;var source_document:=parser.parse(builder.build(rules),"BIC ")
		check(builder.failure.is_empty() and parser.failure.is_empty() and not source_document.root.ClassList[0].has("SpellsPerDayList"),"Existing manual source spell receipt still omits the legacy uses list")
		check(source_document.root.ClassList[0].KnownList0==cls.KnownList0 and source_document.root.ClassList[0].KnownList1==cls.KnownList1,"Known lists remain byte-field-equivalent across the unchanged manual receipt gate")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Real Builder/GFF/installed UTI serialization of authored generic and manual source daily-use shape. Automatic accepted source-tail exclusion is separately asserted by the full cached Recommended source-control test; no rules admission/server claim."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
