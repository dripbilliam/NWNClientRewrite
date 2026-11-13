extends SceneTree
signal resume_case
var failures: Array=[]
var checks: int=0
var records: Array=[]
var observations: Array=[]
var enabled: bool=false
var report: String=""
var worker_data: Dictionary={}
class Reentrant:
	extends Node
	var target: Object
	var callback_rows: Array=[]
	func _notification(what: int) -> void:
		if what==1234:
			callback_rows.append(ClassDB.class_call_static("NwnFrameProbe","script_context"))
			target.inner(51)
			callback_rows.append(ClassDB.class_call_static("NwnFrameProbe","script_context"))

func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report=arg.substr(9)
		if arg=="--script-owner-trace=on": enabled=true
	_run.call_deferred()

func inner(value: int) -> int:
	records.append({"phase":"inner","expected":"inner","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	return value*3

func outer() -> int:
	records.append({"phase":"outer-before","expected":"outer","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	var result: int=inner(7)
	records.append({"phase":"outer-after","expected":"outer","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	return result

func recurse(depth: int) -> int:
	records.append({"phase":"recurse-"+str(depth),"expected":"recurse","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	if depth==0: return 1
	var value: int=recurse(depth-1)+1
	records.append({"phase":"recurse-return-"+str(depth),"expected":"recurse","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	return value

func await_case() -> void:
	records.append({"phase":"await-before","expected":"await_case","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	await resume_case
	records.append({"phase":"await-after","expected":"await_case","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	inner(17)

func needed(value: int) -> int:
	return value

func invalid_get() -> Variant:
	var nothing: Variant=null
	return nothing.unavailable_field

func _worker() -> void:
	worker_data=ClassDB.class_call_static("NwnFrameProbe","script_context")

func _run() -> void:
	check(outer()==21,"nested return")
	check(recurse(12)==13,"recursive return")
	await_case()
	records.append({"phase":"await-suspended","expected":"_run","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	resume_case.emit()
	records.append({"phase":"await-resumed-caller","expected":"_run","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	var node:=Reentrant.new()
	node.target=self
	node.notification(1234)
	for row in node.callback_rows: records.append({"phase":"reentrant-native-callback","expected":"_notification","snapshot":row})
	node.free()
	records.append({"phase":"reentrant-return","expected":"_run","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	# The first call reaches VM's early argument-error return. The second reaches
	# the runtime opcode failure path. Both are deliberately paired in controls.
	Callable(self,"needed").call()
	records.append({"phase":"argument-error-return","expected":"_run","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	invalid_get()
	records.append({"phase":"opcode-error-return","expected":"_run","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	var detached: Thread=Thread.new()
	check(detached.start(_worker)==OK,"worker start")
	detached.wait_to_finish()
	check(not bool(worker_data.get("available",true)),"worker snapshot refused")
	records.append({"phase":"worker-return","expected":"_run","snapshot":ClassDB.class_call_static("NwnFrameProbe","script_context")})
	# Transient scripts have distinct IDs and copied source/function strings remain
	# available after both instance and GDScript resources are released.
	var transient_ids: Array=[]
	for i in range(12):
		var script:=GDScript.new()
		script.source_code="extends RefCounted\nfunc transient_"+str(i)+"():\n\treturn ClassDB.class_call_static(\"NwnFrameProbe\",\"script_context\")\n"
		check(script.reload()==OK,"transient compile "+str(i))
		var instance: RefCounted=script.new()
		var snapshot: Dictionary=instance.call("transient_"+str(i))
		records.append({"phase":"transient-"+str(i),"expected":"transient_"+str(i),"snapshot":snapshot})
		transient_ids.append(int(snapshot.get("active_id",0)))
		instance=null
		script=null
	var final: Dictionary=ClassDB.class_call_static("NwnFrameProbe","script_context")
	var seen: Dictionary={}
	for item in records:
		var snapshot: Dictionary=item.snapshot
		check(bool(snapshot.get("available",false)),"main snapshot available "+item.phase)
		check(bool(snapshot.get("enabled",false))==enabled,"flag "+item.phase)
		var id: int=int(snapshot.get("active_id",0))
		var found: String=""
		for row in snapshot.get("rows",[]):
			if int(row.id)==id: found=str(row.function)
		if enabled:
			check(id>0 and id<4294967295,"mapped main ID "+item.phase)
			check(found==str(item.expected),"owner "+item.phase+" found="+found)
			if seen.has(item.expected): check(int(seen[item.expected])==id,"immutable repeated ID "+item.phase)
			seen[item.expected]=id
		else:
			check(id==0,"disabled ID zero "+item.phase)
			check(int(snapshot.get("registered",-1))==0,"disabled no registration "+item.phase)
		observations.append({"phase":item.phase,"owner":str(item.expected),"pass":not enabled or found==str(item.expected)})
	if enabled:
		check(int(final.get("overflow_functions",-1))==0,"no exhausted registry")
		check(int(final.get("active_id_bytes",0))==4,"four-byte schema")
		check(str(final.get("active_id_address_hex","")).begins_with("0x"),"read-only address exposed")
		check(int(final.get("main_native_thread_id",0))>0,"native main TID")
		var known: Dictionary={}
		for row in final.get("rows",[]): known[int(row.id)]=str(row.function)
		for i in range(12): check(str(known.get(transient_ids[i],""))=="transient_"+str(i),"destroyed function names retained "+str(i))
	var output: Dictionary={"version":1,"success":failures.is_empty(),"enabled":enabled,"checks":checks,"failures":failures,"observations":observations,"final":final,"worker":worker_data,"scope":"Actual GDScript nested/recursive/await/error/reentrant/native callback/transient lifetime/worker differential; diagnostic correctness only, no FPS claim."}
	var file:=FileAccess.open(report,FileAccess.WRITE)
	if file==null: printerr("Unable to write fixture report");quit(3);return
	file.store_string(JSON.stringify(output,"\t"));file.close()
	quit(0 if failures.is_empty() else 2)
