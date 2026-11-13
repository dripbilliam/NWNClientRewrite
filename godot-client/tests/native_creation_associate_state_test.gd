extends SceneTree
const State=preload("res://systems/native_data/creation_associate_state.gd")
var failures: Array=[]
var checks:=0
class Text extends RefCounted:
	func raw(value: Dictionary) -> String:return "Active name "+str(int(value.strRef))
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> bool:
	checks+=1
	if not value:failures.append(message)
	return value
func table_for(rows: Array) -> Dictionary:
	var result:={"orderedRows":[]}
	for row in rows:
		var data: Dictionary={}
		if row.title!=null:data.STRREF=str(int(row.title))
		if row.base!=null:data.BASERESREF=str(row.base)
		result.orderedRows.append(data)
	return result
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var original: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle));var text:=Text.new()
	if not original is Dictionary or not original.get("rows") is Array:quit(2);return
	for at in original.rows.size():
		var row: Dictionary=original.rows[at];var input: Dictionary=row.input
		var model:=State.choices(table_for(input.rows),input.arcane,input.level,text)
		var expected: Array=row.entries.map(func(entry):return {"id":int(entry.id),"title":int(entry.title)})
		check(model.ready and model.entries.map(func(entry):return {"id":int(entry.id),"title":int(entry.title)})==expected,"Original physical associate loader rows "+str(at))
		check(model.kinds.table==str(row.loadCalls[0][1]).to_lower(),"Original exact Arcane table branch "+str(at))
		var state:=State.new();state.configure(model,0,"Owned name");state.select_index(int(row.selectedIndex));var preview:=state.preview()
		var calls: Array=row.selectionCalls.filter(func(call):return call[0]=="preview")
		check(calls.size()==1 and preview.ready and preview.resource==str(calls[0][1]) and preview.type==int(calls[0][2]) or calls.is_empty() and not preview.ready and not state.view().canAccept,"Original selected physical row/level UTC preview and OK gate "+str(at))
	var sparse:=table_for([{ "title":1,"base":"A"},{"title":null,"base":"B"},{"title":3,"base":"C"},{"title":4,"base":"D"}])
	var model:=State.choices(sparse,1,1,text);var state:=State.new();var view:=state.configure(model,2,"Owned")
	check(view.physicalId==3,"Original initial stored type selects a visible index, preserving sparse physical-row behavior")
	check(state.configure(model,3,"Owned").physicalId==0,"Original out-of-count stored index falls back to index0")
	check(state.configure(model,-1,"Owned").physicalId==0,"Original uninitialized type becomes0")
	check(not state.configure(model,-2,"Owned").ready,"Unsafe original negative tab dereference remains explicitly unavailable")
	view=state.configure(model,0,"");check(view.ready and view.canAccept and view.needsGeneratedName,"Empty name does not invent a selection failure or generated name")
	check(state.commit().get("needsGeneratedName",false),"Empty-name OK requires the actual active name generator")
	check(state.commit("Server generated")=={"ready":true,"field":"familiar","id":0,"name":"Server generated","code":0},"Supplied generated name commits exact physical type and familiar owner")
	state.set_name("  ");check(state.commit().name=="  ","Original name byte-length semantics preserve whitespace")
	var detached:=state.view();detached.entries[0].base="Caller mutation";check(state.preview().resource=="a01","Detached chooser views cannot mutate active preview identity")
	model=State.choices(sparse,2,100,text);state.configure(model,0,"Odd class");check(model.kinds.table=="hen_companion" and state.commit().field=="familiar" and state.preview().resource=="a100","Unusual raw Arcane preserves distinct original table/store predicates")
	check(not State.choices(null,1,1,text).ready and not State.choices({},1,1,text).ready,"Absent/unloaded tables stay unavailable")
	model=State.choices({"orderedRows":[]},1,1,text);view=state.configure(model,0,"Empty");check(view.ready and not view.canAccept and view.physicalId==null,"Loaded empty table has no invented physical choice")
	check(not State.choices(sparse,null,1,text).ready and not State.choices(sparse,1,256,text).ready and not State.choices(sparse,1,1,null).ready,"Unknown class/level/text inputs are explicit")
	check(not State.choices({"orderedRows":[{"STRREF":"0xwrong","BASERESREF":"A"}]},1,1,text).ready,"Unresolved original hexadecimal conversion does not invent a row")
	model=State.choices({"columns":["strref","STRREF","BASERESREF"],"orderedCells":[["1","9","FAMIL"]],"orderedRows":[{}]},1,1,text)
	check(model.ready and model.entries.size()==1 and model.entries[0].title==1,"Physical duplicate columns retain original first case-insensitive precedence")
	var many: Array=[]
	for id in 1024:many.append({"STRREF":str(id),"BASERESREF":"Associate"})
	var samples: Array=[]
	for turn in 8:
		var began:=Time.get_ticks_usec();var decoded:=State.choices({"orderedRows":many},1,1,text);samples.append((Time.get_ticks_usec()-began)/1000.0)
		check(decoded.ready and decoded.entries.size()==1024,"Large active associate-table decode "+str(turn))
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":original.rows.size(),"decode1024Ms":samples,"scope":"Pure native physical associate row/selection policy versus180 complete original loader/selection executions, active-table boundaries, sparse initial selection, exact name ownership and mutation isolation. No actual creator controls, name-generator implementation, draft/BIC/server/pixels or full panel acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
