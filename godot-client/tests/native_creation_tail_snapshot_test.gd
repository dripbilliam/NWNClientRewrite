extends SceneTree
const Snapshot=preload("res://systems/native_data/creation_tail_snapshot.gd")
const Provider=preload("res://systems/native_data/creation_tail_provider.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<20:failures.append(label)
func fixture() -> Dictionary:
	var races: Array=[];races.resize(12)
	var appearances: Array=[];appearances.resize(32)
	for index in races.size():races[index]={"Appearance":"0"}
	for index in appearances.size():appearances[index]={"MODELTYPE":"F","RACE":"wrong"}
	races[3]={"Appearance":"9","appearance":"8"};appearances[7]={"MODELTYPE":"F","modeltype":"S","RACE":"wrong","nested":{"values":[1,2]},"packed":PackedByteArray([4,5])}
	var racial_cells: Array=[];racial_cells.resize(4)
	for index in racial_cells.size():racial_cells[index]=[]
	racial_cells[3]=["7","9"]
	var cells: Array=[];cells.resize(8)
	for index in cells.size():cells[index]=[]
	cells[7]=["P","F","h"]
	return {"racialtypes":{"columns":["appearance","Appearance"],"defaultValue":"11","orderedRows":races,"orderedCells":racial_cells},"appearance":{"columns":["modeltype","MODELTYPE","RACE"],"defaultValue":"P","orderedRows":appearances,"orderedCells":cells},"gender":{"columns":["gender","GENDER"],"defaultValue":"x","orderedRows":[{"GENDER":"bad"},{"GENDER":"bad"}],"orderedCells":[["m","f"],["f","m"]]},"chargenclothes":{"columns":["ClassRestrict","RaceRestrict","GenderRestrict","AlignmentRestrict","ItemResRef","ITEMRESREF"],"defaultValue":"ignored","orderedRows":[{"ItemResRef":"wrong"},{"ItemResRef":"wrong"}],"orderedCells":[["****","****","****","****","outfit_a","wrong"],["****","****","****","****","outfit_b","wrong"]]},"ruleset":{"columns":["Label","Value"],"defaultValue":"missing","orderedRows":[{"label":"CHARGEN_ENABLED_PHENOTYPES","Label":"ignored","Value":"4"},{"Label":"CHARGEN_ENABLED_PHENOTYPES","Value":"****"},{"Label":"CHARGEN_ENABLED_PHENOTYPES","Value":"5"}],"orderedCells":[["ignored","0"]]}}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","install"]) or FileAccess.file_exists(args.report):quit(2);return
	var models: Array=["pmh0_head001","pmh0_head300","pfh0_head001","pfh0_head300"]
	var document:={"type":"UTI ","version":"V3.2","root":{},"field_types":{0:{}}};var loads:={"outfit_a":{"status":"ready","document":document},"outfit_b":{"status":"ready","document":document}}
	var palettes: Dictionary={}
	for name in Provider.PALETTES.values():palettes[name]={"format":"rgba8","width":256,"height":176}
	for variant in 12:
		for gender in [0,1]:
			var tables:=fixture()
			match variant:
				1:tables.appearance.orderedCells[7][0]="F"
				2:tables.appearance.orderedCells[7]=[]
				3:tables.appearance.erase("orderedCells")
				4:tables.appearance.columns=["other","RACE"]
				5:tables.erase("appearance")
				6:tables.racialtypes.erase("orderedRows")
				7:tables.racialtypes.orderedRows=[]
				8:tables.racialtypes.orderedCells[3][0]="0xQ"
				9:tables._native_resolved_ruleset={"CHARGEN_ENABLED_PHENOTYPES":6}
				10:tables.gender.erase("columns");tables.gender.erase("orderedCells")
				11:tables.appearance.orderedCells[7]=["p"]
			var selection:={"mode":0,"classes":[4],"raceId":3,"gender":gender,"lawChaos":50,"goodEvil":50,"phenotype":255,"head":300,"skin":1,"hair":2,"tattoo1":3,"tattoo2":4}
			var original:=Provider.appearance(tables,selection,models,loads,palettes);var captured:=Snapshot.capture(tables,3);var projected:=Provider.appearance(captured,selection,models,loads,palettes)
			check(original==projected,"Whole provider output equals full graph for metadata/default/case/nonP variant"+str(variant)+" gender"+str(gender))
			for name in ["racialtypes","appearance","gender","chargenclothes","ruleset"]:
				check(tables.has(name)==captured.has(name),"Table absence retained: "+name)
				if not tables.has(name):continue
				check(tables[name].has("orderedRows")==captured[name].has("orderedRows"),"Unknown rows distinguished from known-empty: "+name)
				check(tables[name].get("orderedRows",[]).size()==captured[name].get("orderedRows",[]).size() and tables[name].get("orderedCells",[]).size()==captured[name].get("orderedCells",[]).size(),"Physical row/cell lengths retained: "+name)
				check(tables[name].get("columns")==captured[name].get("columns") and tables[name].get("defaultValue")==captured[name].get("defaultValue"),"Header/default exact presence and value: "+name)
				for id in [-1,tables[name].get("orderedRows",[]).size()]:
					for key in ["Appearance","MODELTYPE","GENDER","ItemResRef","missing"]:check(Tables.cell(tables[name],id,key)==Tables.cell(captured[name],id,key),"Out-of-range/native default getter contract")
	var input:=fixture();var captured:=Snapshot.capture(input,3)
	input.appearance.orderedRows[7].nested.values[0]=99;input.appearance.orderedRows[7].packed[0]=99;input.appearance.orderedCells[7][0]="S";input.appearance.columns[0]="changed";input.ruleset.orderedRows[2].Value="0"
	check(captured.appearance.orderedRows[7].nested.values==[1,2] and captured.appearance.orderedRows[7].packed==PackedByteArray([4,5]) and captured.appearance.orderedCells[7][0]=="P" and captured.appearance.columns[0]=="modeltype" and captured.ruleset.orderedRows[2].Value=="5","Selected nested/packed/header/physical/ruleset mutation isolation")
	check(captured.appearance.orderedRows[6].is_empty() and captured.appearance.orderedRows.size()==32,"Only unaddressable appearance rows are omitted without reindexing")
	var catalog:=Catalog.new();check(catalog.mount_install(args.install),"Read-only installed catalog mounts")
	var actual: Dictionary={}
	for name in ["racialtypes","appearance","gender","chargenclothes","ruleset"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2017);var parser=preload("res://systems/native_data/two_da.gd").new();actual[name]=parser.parse(preload("res://systems/native_data/binary_data.gd").new(bytes).text(0,bytes.size()));check(catalog.failure.is_empty() and parser.failure.is_empty(),"Actual native table parses: "+name)
	var start:=Time.get_ticks_usec();var detached:=actual.duplicate(true);var full_us:=Time.get_ticks_usec()-start
	start=Time.get_ticks_usec();var snapshot:=Snapshot.capture(actual,0);var snapshot_us:=Time.get_ticks_usec()-start
	for key in ["Appearance","appearance","missing"]:check(Tables.cell(actual.racialtypes,0,key)==Tables.cell(snapshot.racialtypes,0,key),"Actual physical race getter agrees")
	var appearance:=Tables.integer(actual.racialtypes,0,"Appearance")
	if appearance.ready and appearance.ok:
		for key in ["MODELTYPE","modeltype","RACE","missing"]:check(Tables.cell(actual.appearance,int(appearance.value)&65535,key)==Tables.cell(snapshot.appearance,int(appearance.value)&65535,key),"Actual physical appearance getter agrees")
	check(not detached.is_empty(),"Baseline deep graph retained for descriptive CPU observation")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"fullDetachUsec":full_us,"projectedDetachUsec":snapshot_us,"appearanceRows":actual.appearance.orderedRows.size(),"scope":"Exact full-provider output and native metadata/default/physical/case/getter equivalence for the consumed row closure, mutation isolation and actual installed data. Descriptive CPU only; no GPU/server/user-process action."},"  "));file.close();quit(0 if failures.is_empty() else 1)
func _initialize() -> void:run.call_deferred()
