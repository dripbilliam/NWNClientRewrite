extends SceneTree
const Title=preload("res://systems/native_data/level_up_title.gd")
const Module=preload("res://systems/native_data/level_up_module_context.gd")
class Text extends RefCounted:
	func raw(value: Dictionary) -> String:return {100:"Custom caster",101:"Server class",0:"",4294967295:"Last physical name"}.get(int(value.strRef),"Unknown")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var text:=Text.new();var tables:={"classes":{"orderedRows":[{"Name":"100"},{"Name":"101"},{"Name":"-1"}]}}
	var rows: Array=[]
	for first in ["","First"," Leading ","Äther"]:
		for last in ["","Last"," Trailing "]:
			for override in ["","Override"," "]:
				rows.append({"first":first,"last":last,"override":override})
	for parts in rows:
		var expected: String=parts.override if not parts.override.is_empty() else parts.first+" "+parts.last if not parts.first.is_empty() and not parts.last.is_empty() else parts.first+parts.last
		var result:=Title.compose(parts,[{"id":0,"level":3},{"id":1,"level":1}],"Source Skills",tables,text)
		check(result.ready and result.name==expected and result.classes=="Custom caster (3) Server class (1)" and result.text==(expected+"   " if not expected.is_empty() else "")+"Custom caster (3) Server class (1)        Source Skills","Exact original name precedence/whitespace and title separators "+str(parts))
	var parts:={"first":"Private","last":"Clone","override":""};var before:=parts.duplicate(true);var data:=tables.duplicate(true)
	var private_classes: Array=[]
	for id in 8:private_classes.append({"id":id%2,"level":255 if id==7 else 1,"receivedColoredLevel":true})
	var result:=Title.compose(parts,private_classes,"",tables,text)
	check(result.ready and result.text.ends_with("Server class (255)        ") and not result.text.contains("<c"),"Eight private class BYTE levels preserve order and constructor flags rather than copying received level colors")
	check(Title.compose(parts,[{"id":2,"level":1}],"Source",tables,text).classes=="Last physical name (1)","Active signed Name STRREF is stored as original DWORD")
	for malformed in [null,{}, {"first":"A","last":"B"},{"first":"A","last":"B","override":false},{"first":"A"+String.chr(0),"last":"B","override":""}]:check(not Title.compose(malformed,[{"id":0,"level":1}],"Source",tables,text).ready,"Unavailable private name stays pending: "+str(malformed))
	for malformed in [null,[],[{}],[{"id":-1,"level":1}],[{"id":3,"level":1}],[{"id":0,"level":0}],[{"id":0,"level":256}],range(9).map(func(_at):return {"id":0,"level":1})]:check(not Title.compose(parts,malformed,"Source",tables,text).ready,"Unavailable private class summary stays pending: "+str(malformed))
	for malformed in [null,1,"Line1\nLine2","Line1\rLine2"]:check(not Title.compose(parts,[{"id":0,"level":1}],malformed,tables,text).ready,"A full/wrapped caption is never substituted for the actual first line")
	var missing:={"classes":{"orderedRows":[{}]}};check(not Title.compose(parts,[{"id":0,"level":1}],"Source",missing,text).ready,"Unknown active class Name does not become a stock choice")
	check(parts==before and tables==data,"Formatting never mutates private context or shared server tables")
	for force in [false,true]:
		for hidden in [false,true]:
			var module:={"serverFlags":{"field158":force,"field164":hidden}};var original:=module.duplicate(true)
			check(Module.compose(module)=={"forceMaximum":force,"hideHitPointGain":hidden} and module==original,"Exact received LoadModule BOOLs own independent die/text flags")
	for unknown in [null,{}, {"serverFlags":null},{"serverFlags":{"field158":0,"field164":"false"}}]:check(Module.compose(unknown)=={"forceMaximum":null,"hideHitPointGain":null},"Missing/malformed received BOOLs remain explicitly unknown")
	check(Module.compose({"serverFlags":{"field158":false}})=={"forceMaximum":false,"hideHitPointGain":null},"Known false does not collapse into unavailable or invent the other flag")
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"runtimeIntegrated":false,"scope":"Staged text formatting from complete original9cda40/7f3f00/7f1230 and strict existing received module BOOL mapping. Caller supplies exact private resolved name/class/first-line context; no producer/view/pixel/server acceptance."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
