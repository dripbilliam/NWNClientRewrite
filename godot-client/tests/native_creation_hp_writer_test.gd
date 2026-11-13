extends SceneTree
const Builder=preload("res://systems/native_data/creation_bic.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
const Parser=preload("res://systems/native_data/gff_document.gd")
const SHA="0650c6924fe381bf544872f596a1905238964f2a0b6a2b901a1600fa6f803601"
class RulesData extends RefCounted:
	var draft: Dictionary={}
	var tables: Dictionary={}
	var creation_base_hp: Variant=null
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
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==SHA,"Executed original Class/CON cache corpus remains pinned")
	var corpus: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	var negative_con:=false;var special_grant:=false;var states:=0
	for row in corpus.rows:
		var rules:=RulesData.new();rules.tables=row.case.tables.duplicate(true)
		var sequence: Array=[row.initial]
		for step in row.results:sequence.append(step.state)
		for state in sequence:
			states+=1;rules.creation_base_hp=int(state.baseHP)
			rules.draft={"classId":int(state.classId),"raceId":0,"abilities":state.abilities.duplicate(true),"feats":row.case.source.primaryFeats+row.case.source.bonusFeats}
			var before:=JSON.stringify(rules.draft);var patch:=Builder.source_hp_fields(rules)
			var expected: Dictionary={"HitPoints":int(state.baseHP),"MaxHitPoints":int(state.maximumHP),"PregameCurrent":int(state.currentHP),"CurrentHitPoints":int(state.baseHP)+int(state.currentHP)-int(state.maximumHP)}
			var parser:=Parser.new();var writer:=Writer.new();var parsed:=parser.parse(writer.write("BIC ",Writer.record(patch.get("fields",{}))),"BIC ")
			check(patch.ready and writer.failure.is_empty() and parser.failure.is_empty() and parsed.root==expected,"Parsed four HP fields match original cached values and807950 writer formula: "+str(states))
			check(expected.keys().all(func(key):return parsed.field_types[0].get(key)==3) and JSON.stringify(rules.draft)==before,"All four fields retain original SHORT type without changing the private draft: "+str(states))
			# Feats OK appends IDs, while the maximum getter reads the cached short.
			rules.draft.feats.append(40)
			check(Builder.source_hp_fields(rules)==patch,"Selecting Toughness cannot invent a second pregame HP recalculation: "+str(states))
			negative_con=negative_con or int(state.maximumHP)<int(state.baseHP)
			special_grant=special_grant or int(state.classId)==37 and int(state.baseHP) in [6,8,10,12]
	check(negative_con and special_grant,"Corpus covers negative CON and granted class37 hit-die caches")
	var rules:=RulesData.new();rules.tables=corpus.rows[0].case.tables;rules.draft={"classId":0,"raceId":0,"abilities":{}}
	check(not Builder.source_hp_fields(rules).ready,"Missing committed cache cannot fall back to class HitDie")
	rules.creation_base_hp=8;rules.tables={}
	check(not Builder.source_hp_fields(rules).ready,"Missing active vital resources remain unavailable")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"states":states,"scope":"Executed original first-level cache corpus plus807950 typed HP serialization; server normalization is a separate live acceptance boundary."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
