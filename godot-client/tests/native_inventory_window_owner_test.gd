extends SceneTree
const OwnerPolicy=preload("res://systems/native_data/inventory_window_owner.gd")
const PC:=2147483650
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func normalized(value: Variant) -> Variant:return JSON.parse_string(JSON.stringify(value))
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var output:="";var oracle_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.trim_prefix("--report=")
		if arg.begins_with("--oracle="):oracle_path=arg.trim_prefix("--oracle=")
	if output.is_empty() or oracle_path.is_empty() or FileAccess.file_exists(output):quit(2);return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.get("target","")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.cases.size()==96 and oracle.windows.size()==384,"Original executable and complete receiver/window corpora are pinned")
	for row in oracle.cases:
		var c: Dictionary=row.case;var objects: Dictionary={}
		if c.present:objects[int(c.ownerId)]={"objectType":5,"replicationRemoved":int(c.removed)!=0}
		var model:=OwnerPolicy.select(int(c.ownerId),PC,objects,bool(c.guiAvailable),bool(c.guiAvailable));var events: Array=[]
		if not model.reply.is_empty():events.append({"kind":"statusRequest","open":0,"ownerId":model.reply.ownerId})
		elif model.available:events.append({"kind":"window","alternate":model.role=="alternate","open":int(c.open),"notify":0,"ownerId":int(c.ownerId)})
		var expected: Array=[]
		for call in row.calls:
			if call.kind in ["statusRequest","window"]:expected.append(call)
		check(normalized(events)==expected,"Original receiver selection/availability/reply: "+str(c))
	for row in oracle.windows:
		var c: Dictionary=row.case;var state:={"active":int(c.active)==1,"displayedOwner":c.displayedOwner,"containerMode":c.containerMode,"containerId":2147483655,"containerField":99,"attached":c.attached}
		var result:=OwnerPolicy.transition(state,int(c.open)!=0,int(c.ownerId),PC,int(c.notify)!=0,bool(c.messageOwner))
		var expected:={"active":int(row.active)==1,"displayedOwner":row.displayedOwner,"containerMode":row.containerMode,"containerId":row.containerId,"containerField":row.containerField}
		var actual:={}
		for field in expected:actual[field]=result.state[field]
		check(result.ready and normalized(actual)==expected and normalized(result.events)==row.calls,"Original owner/active/container/request effects: "+str(c))
	var complete:={"active":true,"displayedOwner":PC,"containerMode":1,"containerId":2147483655,"containerField":99,"attached":true}
	for field in complete:
		var pending:=complete.duplicate(true);pending.erase(field)
		check(not OwnerPolicy.transition(pending,true,PC,PC).ready,"Missing private GUI dependency stays pending: "+field)
	for field in complete:
		var pending:=complete.duplicate(true);pending[field]=null
		check(not OwnerPolicy.transition(pending,false,PC,PC).ready,"Unresolved private GUI dependency cannot clear a window: "+field)
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Original96 protocol receiver +384 open/close body cases with captured GUI/transport boundaries; pure native owner policy only. Actual decoder/session/UI integration, alternate item actions and original-server outcome remain open."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
