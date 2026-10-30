extends SceneTree
const State=preload("res://systems/native_data/journal_state.gd")
const Notes=preload("res://systems/native_data/journal_notes.gd")
const Date=preload("res://systems/native_data/journal_date.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle_path:=ProjectSettings.globalize_path("res://../backups/animations/native-journal-date-observations-v1.json"); var file:=FileAccess.open(oracle_path,FileAccess.READ); var oracle: Dictionary=JSON.parse_string(file.get_as_text()); file.close()
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.rows.size()==160,"Date oracle identifies unchanged original calendar and formatter instructions")
	for row in oracle.rows:
		var actual:=Date.parts(int(row.date),int(row.time),int(row.minutesPerHour)); var expected: Dictionary=row.output.parts; var equal: bool=actual.error.is_empty()
		for key in expected: equal=equal and int(actual.get(key,-1))==int(expected[key])
		check(equal and Date.format(int(row.date),int(row.time),int(row.minutesPerHour),"Day","Month")==row.output.text,"Original journal timestamp matches day%s/ticks%s/hour%s"%[row.date,row.time,row.minutesPerHour])
	check(not Date.parts(0,0,0).error.is_empty() and Date.format(0,0,256,"Day","Month").is_empty(),"Invalid zero hour byte cannot trigger division by zero")
	var text:=Talk.new(); var model:=State.new(); model.reset("character-one")
	var raw:={"entries":[["a",{"tag":"a","title":{"text":"Alpha"},"description":{"text":"One"},"completed":false,"isQuest":true,"date":1,"time":0,"priority":3}],["b",{"tag":"b","title":{"text":"Beta"},"description":{"text":"Two"},"completed":false,"isQuest":false,"date":2,"time":0,"priority":1}]]}; var before:=raw.duplicate(true)
	check(model.observe(raw) and model.records.size()==2 and model.lists[0]==["a","b"] and model.lists[1].is_empty(),"Received completion determines native active/completed lists")
	check(model.records.a.unread and not model.records.b.unread and model.rows(0,text,-1,7200000).size()==2,"Historical isQuest transport flag controls unread attention rather than a Notes category")
	var revision: int=model.revision; check(not model.observe(raw) and revision==model.revision,"An unchanged received journal never rebuilds local record state")
	check(model.expand("a") and model.records.a.expanded and not model.records.a.unread and raw==before,"Opening an entry changes only local read/expansion state")
	raw.entries.reverse(); check(not model.observe(raw) and model.lists[0]==["a","b"],"Snapshot map iteration changes cannot reorder the original insertion identity list")
	for entry in raw.entries:
		if entry[0]=="a": entry[1].description={"text":"New server text"}; entry[1].date=3
	check(model.observe(raw) and model.records.a.expanded and model.records.a.unread,"Received changed text retains expansion and restores source attention state")
	for entry in raw.entries:
		if entry[0]=="a": entry[1].completed=true
	check(model.observe(raw) and model.lists[0]==["b"] and model.lists[1]==["a"] and model.rows(1,text,-1,7200000)[0].description.text=="New server text","Server completion moves a stable tag into the completed identity list")
	check(model.sort_by(0,2) and not model.sort_by(0,2) and not model.sort_by(2,0),"Sort state is separate for both quest pages and rejects invalid changes")
	raw.entries=raw.entries.filter(func(entry):return entry[0]!="a"); check(model.observe(raw) and not model.records.has("a") and model.lists[1].is_empty(),"Server removal retires local state for that tag")
	model.reset("character-one"); check(model.records.size()==1,"Same character context preserves received identity state"); model.reset("character-two"); check(model.records.is_empty() and model.modes==[0,0],"A different character clears previous journal presentation state")
	var notes:=Notes.new(); var directory:=output+".notes"; notes.configure(directory); notes.select("one"); notes.edit("First note\nSecond line"); check(notes.flush() and notes.drafts.is_empty() and notes.writes==1,"Native notes publish a complete character file")
	notes.edit("Replaced text"); check(notes.flush() and notes.writes==2,"Atomic native notes publication replaces the previous file")
	var loaded:=Notes.new(); loaded.configure(directory); loaded.select("one"); check(loaded.value=="Replaced text","Fresh notes ownership reads the complete replacement text")
	notes.select("two"); check(notes.value.is_empty(),"Different character notes are isolated"); notes.edit("Other character"); notes.select("one"); check(notes.value=="Replaced text" and notes.drafts.is_empty(),"Changing identity flushes the old character without losing either file")
	notes.configure(""); notes.edit("Retained unsaved edit"); check(not notes.flush() and not notes.failure.is_empty() and notes.drafts.size()==1,"A failed notes write retains its draft and reports failure")
	notes.select("two"); notes.edit("Other retained edit"); check(notes.drafts.size()==2,"Changing character after failed storage preserves both drafts")
	notes.configure(directory); check(notes.flush() and notes.drafts.is_empty() and notes.failure.is_empty(),"Available storage can publish all retained drafts without a fabricated prior success")
	loaded=Notes.new(); loaded.configure(directory); loaded.select("one"); check(loaded.value=="Retained unsaved edit","Recovered first-character draft is readable"); loaded.select("two"); check(loaded.value=="Other retained edit","Recovered second-character draft stays separate")
	text.close(); var output_file:=FileAccess.open(output,FileAccess.WRITE); output_file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracleSha256":FileAccess.get_sha256(oracle_path),"fullJournalParity":false,"publicConnections":0,"scope":"160 unchanged original timestamp observations, received journal identity/read/expansion/sort lifecycle and isolated native note persistence/refusal recovery only. Full original-client UI/role parity remains open."},"  ")+"\n"); output_file.close(); quit(0 if failures.is_empty() else 1)
