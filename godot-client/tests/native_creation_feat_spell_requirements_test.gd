extends SceneTree
const Spells=preload("res://systems/native_data/creation_feat_spell_rules.gd")
const Requirements=preload("res://systems/native_data/creation_feat_requirements.gd")
const SHA="6197ca5bb2e6937d941d536d68fcd6aa79a12fb86190a128dabb7eb57de32f46"
const ORIGINAL="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String,details: Variant=null) -> void:
	checks+=1
	if not value:failures.append({"label":label,"details":details})
func normalize(source: Dictionary) -> Dictionary:
	var result: Dictionary=source.duplicate(true)
	for cls in result.classes:
		var gains: Array=[]
		# The original corpus installs this same decoded gain on every
		# physical class level; normalize it to the adapter's per-class sum.
		for value in cls.spell.statGain:gains.append(Spells.signed8(int(value)*(int(cls.level)&255)))
		cls.spell.abilityGain=gains
	return result
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	check(FileAccess.get_sha256(args.oracle)==SHA,"Original positive spell-prerequisite corpus remains immutable")
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(evidence.target==ORIGINAL and evidence.rows.size()==288 and evidence.procedures.size()==16 and evidence.procedures.has("0x140299e70") and evidence.procedures.has("0x140299e40"),"Complete original prerequisite/known/gain/race/class helpers identify the corpus")
	for observed in evidence.rows:
		var before:=JSON.stringify(observed);var source:=normalize(observed.case);var level:=int(source.feat.MINSPELLLVL)&255;var spell:=Spells.nonmemorizing(source,level)
		check(spell.ready and spell.allowed==observed.accepted,"Native non-memorizing capacity matches original positive MINSPELL execution",{"source":source,"actual":spell,"expected":observed.accepted})
		source.spellLevels={};source.spellLevels[level]=spell.allowed;var full:=Requirements.evaluate(source,source.feat)
		check(full.ready and full.allowed==observed.accepted,"Published original spell capacity composes with the full decoded prerequisite core",full)
		check(JSON.stringify(observed)==before,"Native spell prerequisite projection leaves the original instruction corpus unchanged")
	var source:=normalize(evidence.rows[1].case)
	source.baseAbilities=[];check(not Spells.nonmemorizing(source,1).ready,"Unavailable native base abilities remain pending")
	source=normalize(evidence.rows[1].case);source.classes[0].spell.SpellCaster=1;source.classes[0].spell.MemorizesSpells=1;check(not Spells.nonmemorizing(source,1).ready,"A memorizing class is delegated rather than treated as non-memorizing")
	source=normalize(evidence.rows[1].case);source.classes[0].spell.SpellCaster=1;source.classes[0].spell.erase("abilityGain");check(not Spells.nonmemorizing(source,1).ready,"Unpublished per-class ability gains cannot become guessed spell eligibility")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"graphical":false,"scope":"288 complete original positive MINSPELL executions for non-memorizing classes at physical levels1..40 and decoded valid cached rules/stats, with no substituted reached helper. Constant original per-level stat fixtures normalize to per-class cumulative gains. Active-table adapter, memorizing branch, source draft/server/pixels remain open."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
