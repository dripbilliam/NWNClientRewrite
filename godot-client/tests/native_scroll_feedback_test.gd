extends SceneTree
const Feedback=preload("res://systems/native_data/combat_feedback.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Ui=preload("res://systems/native_gameplay_ui.gd")
class ChatSink extends RefCounted:
	var rows: Array=[]
	func append_message(row: Dictionary) -> void: rows.append(row)
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var source:=ProjectSettings.globalize_path("res://").path_join("../backups/animations/native-scroll-feedback-observations-v1.json").simplify_path()
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
	check(evidence.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Oracle executes the pinned original client")
	var text:=Text.new(); var formatter:=Feedback.new(); formatter.text=text
	for row in evidence.cases:
		var code:=int(row.type); var id:=int(row.spellId); var refs: Array=[]; var sounds: Array=[]
		for call in row.calls:
			if call[0] in ["tlk","parse"]: refs.append(int(call[1]))
			if call[0]=="sound": sounds.append(call[1])
		check(refs.size()==1 and row.outputs.size()==1,"Original branch has one message "+str(code))
		text.custom_tokens={0:"old0",99:"unrelated"}; text.overrides.clear(); text.tables={"spells":{"orderedRows":[]}}
		if not row.missingSpell and id>=0:
			var spells: Array=text.tables.spells.orderedRows; spells.resize(id+1)
			for index in spells.size(): spells[index]={"Name":"9000"}
			text.overrides[9000]=str(row.spellName)
		for ref in refs: text.overrides[ref]="T"+str(ref)
		if code==222: text.overrides[53307]="Learned [<CUSTOM0>]"
		var before:=text.custom_tokens.duplicate(); var rows:=formatter.format({"kind":"combat-feedback","type":code,"data":{"integers":{"0":id,"9":code}},"color":""})
		var expected: String="Learned ["+str(row.tokens["0"])+"]" if code==222 else "T"+str(refs[0])
		# A negative spell ID is unavailable in the native table; the oracle's
		# captured lookup can independently return a spell to probe token copying.
		if code==222 and id<0 and not row.missingSpell: expected="Learned []"
		check(rows.size()==1 and rows[0].text==expected,"Received scroll result matches original TLK/token path "+str(code))
		check(formatter.sounds==sounds,"Received result retains original GUI sound "+str(code))
		check(text.custom_tokens==before,"Message token scope preserves server custom tokens "+str(code))
		check(rows[0].rich.spans.any(func(span):return span.color=="#ffff01"),"Original default feedback tint "+str(code))
	var before_sounds:=formatter.sounds.duplicate()
	formatter.format({"kind":"combat-feedback","type":262,"data":{}})
	check(not before_sounds.is_empty() and formatter.sounds.is_empty(),"Next message cannot replay a previous learning sound")
	check(formatter.diagnostics==["Unsupported feedback branch 262"],"Only the deliberately unsupported branch is diagnosed")
	var ui:=Ui.new(); root.add_child(ui); ui.text=text; ui.feedback.text=text; ui.chat=ChatSink.new(); var sounds: Array=[]
	ui.gui_sound_requested.connect(func(resource):sounds.append(resource))
	text.tables={"spells":{"orderedRows":[{"Name":"9000"}]}}; text.overrides={9000:"Active server spell",53307:"Learned [<CUSTOM0>]",53309:"Refused non-scroll"}
	ui.present({"kind":"combat-feedback","type":222,"data":{"integers":{"0":0}}})
	check(ui.chat.rows.size()==1 and ui.chat.rows[0].text=="Learned [Active server spell]" and sounds==["gui_learnspell"],"Actual native gameplay UI forwards success text and exactly one sound cue")
	ui.present({"kind":"combat-feedback","type":78,"data":{}})
	check(ui.chat.rows.size()==2 and ui.chat.rows[1].text=="Refused non-scroll" and sounds==["gui_learnspell","gui_failspell"],"Actual native gameplay UI forwards refusal instead of fabricating a successful inventory outcome")
	ui.present({"kind":"combat-feedback","type":262,"data":{}})
	check(ui.chat.rows.size()==2 and sounds.size()==2,"Unsupported next feedback does not replay prior text or audio")
	ui.queue_free(); await process_frame
	text.close()
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalCases":evidence.cases.size(),"publicConnections":0,"scope":"Original-code scroll feedback selection/token/sound plans. Audio playback and authoritative successful learning are separate checks; full UI parity remains incomplete."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
