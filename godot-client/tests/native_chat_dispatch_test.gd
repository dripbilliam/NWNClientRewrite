extends SceneTree
const Prompt=preload("res://systems/native_data/chat_prompt.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func calls(message: Dictionary) -> Array:
	if message.has("error_ref"): return [{"kind":"feedback","code":106}]
	if message.is_empty(): return []
	if message.get("kind","")=="native-chat-party": return [{"kind":"party","target":int(message.targetId),"command":6 if message.operation=="accept" else 4}]
	if message.get("kind","")!="chat": return [{"unexpected":message}]
	var row:={"kind":{1:"talk",2:"shout",3:"whisper",6:"party",14:"dm"}.get(int(message.channel),"tell-id"),"text":message.text}
	if int(message.channel)==4:
		if message.has("recipient"): row.kind="tell-name"; row.recipient=message.recipient
		else: row.playerId=int(message.playerId)
	return [row]
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(original.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and original.cases.size()==260,"Executed original dispatcher observations belong to the pinned binary and complete fixture")
	var players: Array=[[7,{"name":"Player Account","objectId":77,"character":{"id":88,"firstName":{"text":"Two"},"lastName":{"text":"Words"}}}],[8,{"name":"Other Account","objectId":78,"character":{"id":89,"firstName":{"text":"Ada"}}}]]
	for row in original.cases:
		if row.value=="/d unavailable": continue # Privileged/local console remains unported.
		var result:=Prompt.dispatch(str(row.value),int(row.mode),players)
		var expected: Array=row.calls.duplicate(true)
		for call in expected:
			for field in ["playerId","target","command","code"]:
				if call.has(field): call[field]=int(call[field])
		check(calls(result)==expected,"Original dispatch mode%d %s"%[int(row.mode),str(row.value)])
	var text:=Talk.new(); text.overrides={600001:"Server",600002:"Character"}; var custom: Array=[[9,{"name":"Custom Account","character":{"id":90,"firstName":{"strRef":600001},"lastName":{"strRef":600002}}}]]
	check(Prompt.dispatch('/t "Server Character" hello',2,custom,text).get("playerId")==9,"Character lookup resolves active server TLK names natively")
	check(Prompt.dispatch('/t "Server Character" hello',2,custom).has("error_ref"),"Missing text provider cannot substitute a built-in class or guessed character name")
	check(Prompt.dispatch('hello\rsecond\nthird',2,players).text=="hello" and Prompt.dispatch('hello\nsecond\rthird',2,players).text=="hello","Original prompt truncates CR/LF before dispatch")
	check(Prompt.dispatch('##local',2,players).has("error") and Prompt.dispatch('/d local',2,players).has("error"),"Unported console paths stay local and never become chat")
	text.close()
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"oracle_cases":260,"compared_cases":255,"deferred_cases":5,"graphical":false,"publicConnections":0,"scope":"Original executed87b590 dispatch, string slicing and roster lookup decisions across five modes. Sender/network/feedback/privilege boundaries are captured; local/DM console and authoritative server outcomes remain open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
