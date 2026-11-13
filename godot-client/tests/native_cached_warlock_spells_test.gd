extends SceneTree
const Rules=preload("res://systems/native_data/creation_rules.gd")
const Snapshot=preload("res://systems/native_data/creation_spells_snapshot.gd")
const State=preload("res://systems/native_data/creation_spells_state.gd")
const Parser=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["fixture","report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var diagnostic: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(str(args.fixture).path_join("diagnostic.json")))
	check(diagnostic.success and diagnostic.manifest=="7e0898127f44bd44f13bdab852ae85bb9badfd6b","Offline SHA-verified cached Arelith manifest fixture")
	var rules:=Rules.new();var text:=Talk.new();var parser:=Parser.new()
	for resource in diagnostic.resources:
		var path:=str(args.fixture).path_join(str(resource.file))
		check(FileAccess.get_sha256(path)==str(resource.sha256),"Exact selected cached bytes "+str(resource.name))
		if int(resource.type)==2017:
			var bytes:=FileAccess.get_file_as_bytes(path);rules.tables[str(resource.name)]=parser.parse(Binary.new(bytes).text(0,bytes.size()))
			check(parser.failure.is_empty(),"Actual native 2DA parse "+str(resource.name))
		elif int(resource.type)==2018:check(text.custom.open_file(path),"Actual selected cached Arelith custom TLK")
	check(text.base.open_file(str(args.install).path_join("lang/en/data/dialog.tlk")),"Installed base TLK fallback")
	var cls: Dictionary=rules.tables.classes.orderedRows[92]
	check(str(cls.Label)=="Warlock" and text.raw({"strRef":int(cls.Name)})=="Warlock","Physical class92 and actual active TLK name agree")
	rules.draft={"classId":92,"raceId":6,"abilities":{"Str":10,"Dex":14,"Con":14,"Int":14,"Wis":8,"Cha":16},"school":0,"known":{}}
	var before:=JSON.stringify(rules.draft);var result:=Snapshot.compose(rules,text)
	check(result.ready,"Actual production first-level Snapshot accepts cached Warlock data: "+str(result.get("reason","")))
	var observations: Array=[]
	if result.ready:
		var state:=State.new();check(state.configure(result.source).ready,"Actual production State accepts the active Snapshot")
		var view:=state.view()
		check(result.classId==92 and result.source.classLevel==1,"First-level scope is explicit; no level-up adapter is inferred")
		check(not result.source.memorizes and not result.source.learnScroll,"Warlock uses the actual spontaneous/non-scroll flags")
		check(result.source.capacity==[0,0,0,0,0,0,0,0,0,0],"Actual zero level-one capacity is retained")
		check(view.tabs==[false,false,false,false,false,false,false,false,false,false],"All ten disabled tabs match cached first-level getters")
		check(view.remaining==0 and view.canAccept,"Empty first-level selection is complete and accepts, rather than a stalled required choice")
		check(view.available.size()==10 and view.available.all(func(row):return row.enabled==false),"Ten valid level-zero definitions remain disabled because remaining capacity is zero")
		check(not view.cannotLearn and not view.empty,"At CHA16, the budget gate is distinct from the primary-ability gate or missing spell definitions")
		check(not state.add(int(view.available[0].id)) and state.can_accept(),"Disabled rows cannot consume nonexistent capacity or block completion")
		check(not state.select_level(1) and state.selected_level==0,"A physically disabled level remains nonselectable")
		observations.append({"cha":16,"tabs":view.tabs,"remaining":view.remaining,"canAccept":view.canAccept,"cannotLearn":view.cannotLearn,"available":view.available.map(func(row):return {"id":row.id,"enabled":row.enabled,"name":row.name,"icon":row.icon})})
		for cha in [8,11,18]:
			rules.draft.abilities.Cha=cha;var next:=Snapshot.compose(rules,text);var private_state:=State.new()
			check(next.ready and private_state.configure(next.source).ready,"Actual Snapshot/State remains ready for explicit CHA "+str(cha))
			var current:=private_state.view()
			check(current.canAccept and current.remaining==0 and current.tabs==view.tabs,"Ability changes do not invent first-level known capacity "+str(cha))
			observations.append({"cha":cha,"tabs":current.tabs,"remaining":current.remaining,"canAccept":current.canAccept,"cannotLearn":current.cannotLearn,"availableEnabled":current.available.map(func(row):return row.enabled)})
		rules.draft.abilities.Cha=16
		check(JSON.stringify(rules.draft)==before,"Snapshot and State do not mutate the draft")
	text.close()
	var output:={"success":failures.is_empty(),"checks":checks,"failures":failures,"manifest":diagnostic.manifest,"classId":92,"snapshotReady":bool(result.ready),"snapshotReason":str(result.get("reason","")),"observations":observations,"scope":"Actual production first-level Snapshot and State composed from SHA-verified cached Arelith classes/spells/gain/known/race/ruleset/custom TLK. Explicit draft abilities, no live server, rendering or claim that this is the exact unpersisted user-run descriptor. Level2 table data is evidence only, not a level-up adapter acceptance.","publicConnections":0,"nativeBuilds":0,"gpu":false}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(output,"  "));file.close();quit(0 if failures.is_empty() else 1)
