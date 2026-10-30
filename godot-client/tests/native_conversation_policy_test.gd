extends SceneTree
const Plan=preload("res://systems/native_data/conversation_layout.gd")
const Conversation=preload("res://systems/server_conversation.gd")
var checks:=0
var failures: Array=[]
var requests: Array=[]
var mismatches: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func original_float(actual: float,expected: float,scale: float=1) -> bool:
	# The JSON reader rounds binary64 decimal tails. Compare the original
	# binary32 values in model units, without accepting a one-float32-ULP drift.
	return Plan.M.f(actual*scale)==Plan.M.f(expected*scale)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var path:=ProjectSettings.globalize_path("res://../backups/animations/native-conversation-policy-observations-v1.json"); var input:=FileAccess.open(path,FileAccess.READ); var oracle: Dictionary=JSON.parse_string(input.get_as_text()); input.close()
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.flows.size()==378 and oracle.selections.size()==160,"Original conversation sizing and callback observations identify the verified native executable")
	for row in oracle.flows:
		var actual:=Plan.flow(float(row.input.entry),float(row.input.reply),float(row.input.clearance)); var expected: Dictionary=row.output
		var equal: bool=actual.error.is_empty() and actual.entry_scroll==expected.entryScroll and actual.reply_scroll==expected.replyScroll and original_float(actual.reply_top,expected.replyTop,0.01) and original_float(actual.height,expected.height,0.01) and original_float(actual.logical_height,expected.logicalHeight,0.01) and original_float(actual.time,expected.time)
		if mismatches.size()<3 and not equal: mismatches.append({"input":row.input,"actual":actual,"expected":expected})
		check(equal,"Unchanged original float32 sizing matches entry%s/reply%s/clearance%s"%[row.input.entry,row.input.reply,row.input.clearance])
	var view:=Conversation.new(); root.add_child(view); view.setup(""); view.request.connect(func(message):requests.append(message.duplicate(true)))
	for row in oracle.selections:
		requests.clear(); var choices: Array=[]
		for index in int(row.count): choices.append({"id":100+index,"rich":{"text":"Choice"},"available":(int(row.mask)&(1<<index))==0})
		view.present({"kind":"dialog-entry","rich":{"text":"Entry"}})
		view.present({"kind":"dialog-replies","entryId":4294967294,"localEnd":bool(row.terminal),"replies":choices}); view.pending=bool(row.blocked)
		if int(row.choice)<0: view.choose(4294967295,true)
		else: view.choose(100+int(row.choice))
		var equal:=false
		if row.callback==null: equal=requests.is_empty() and view.opened
		elif int(row.callback)==-2: equal=requests.is_empty() and not view.opened
		else: equal=requests.size()==1 and view.opened and view.pending and requests[0]=={"kind":"reply","entryId":4294967294,"replyId":4294967295 if int(row.callback)<0 else 100+int(row.callback),"abort":int(row.callback)<0}
		check(equal,"Original reply selection matches count%d/blocked%d/terminal%d/mask%d/choice%d"%[row.count,row.blocked,row.terminal,row.mask,row.choice])
	view.free(); await process_frame; await process_frame
	for value in [Vector3(-1,1,1),Vector3(1,-1,1),Vector3(INF,1,1),Vector3(1,NAN,1),Vector3(1,1,INF)]: check(not Plan.flow(value.x,value.y,value.z).error.is_empty(),"Malformed text dimensions cannot schedule native GUI animation work")
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"mismatches":mismatches,"oracleSha256":FileAccess.get_sha256(path),"publicConnections":0,"fullConversationParity":false,"scope":"378 unchanged original float32 sizing paths and160 original callback selection paths compared with native Godot policy. Typography, graphical comparison and full conversation variants remain separately open."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
