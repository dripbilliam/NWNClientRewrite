extends SceneTree
const Lobby=preload("res://systems/character_lobby.gd")
class TextOwner extends RefCounted:
	func raw(value: Dictionary) -> String: return "Localized server refusal" if int(value.get("strRef",0))==10500 else ""
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	var ui:=Lobby.new();root.add_child(ui);await process_frame;var text:=TextOwner.new()
	ui.state={"error":"Fallback server rejection","characterRejection":{"strRef":10500}}
	check(ui.failure_text(text)=="Localized server refusal","Server refusal resolves its raw TLK reference through the native text owner")
	ui.state=JSON.parse_string(JSON.stringify(ui.state));check(ui.failure_text(text)=="Localized server refusal","JSON numeric references retain localized rejection text")
	check(ui.failure_text()=="Fallback server rejection","Unavailable native text retains the explicit refusal fallback")
	ui.state.characterRejection={"strRef":99};check(ui.failure_text(text)=="Fallback server rejection","Missing localized text does not hide the refusal")
	ui.state.characterRejection={"strRef":"invalid"};check(ui.failure_text(text)=="Fallback server rejection","Malformed rejection metadata cannot invoke the native text lookup")
	ui.state={"error":""};check(ui.failure_text(text).is_empty(),"A fresh authoritative selection clears the old rejection")
	ui.close_native();ui.free();await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures}));file.close();quit(0 if failures.is_empty() else 1)
