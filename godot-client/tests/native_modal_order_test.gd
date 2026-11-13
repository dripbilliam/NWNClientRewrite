extends SceneTree
const Order=preload("res://systems/native_data/modal_order.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func run() -> void:
	var output:=""; var oracle_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--oracle="): oracle_path=arg.substr(9)
	if output.is_empty() or oracle_path.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.success and oracle.checks==480 and oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Pinned unchanged original topmodal480 corpus identifies authority and captured-helper boundary")
	for row in oracle.rows:
		var order:=Order.new(); order.set_membership_coverage(true); var owners: Array=[]; var closed: Array=[]
		for index in row.modalTypes.size():
			var owner:=Node.new(); owners.append(owner)
			order.activate(owner,"unknown" if row.modalTypes[index]==null else str(row.modalTypes[index]),1,[],func(ticket):closed.append(ticket.owner))
		var result:=order.deactivate_for_panel(int(row.panel))
		check(result.deactivationRequested==row.closeTop and closed.size()==int(row.deactivateCalls) and (closed.is_empty() or closed[0]==owners.back().get_instance_id()),"Original last-modal-only close case%s"%checks)
		order.close()
		for owner in owners: owner.free()
	var order:=Order.new(); var a:=Node.new(); var b:=Node.new(); var closed: Array=[]; var displaced: Array=[]
	var one:=order.activate(a,"Rmnu",1,[1,55,42],func(ticket):closed.append(ticket),func(ticket):displaced.append(ticket))
	check(not order.deactivate_for_panel(16).deactivationRequested and closed.is_empty(),"Registry is optional/unavailable until explicit owner coverage is established")
	order.set_membership_coverage(true)
	var two:=order.activate(b,"other",1,[1,55,42]); check(displaced.size()==1 and order.top().ticket==two,"New modal supersedes only prior top at its explicit activation boundary")
	check(order.activate(b,"other",1,[1,55,42])==two and displaced.size()==1,"Already-top activation is an idempotent no-op")
	check(order.activate(a,"Rmnu",1,[1,55,42])==one and order.top().ticket==one and order.snapshot().records.size()==2,"Existing lower owner promotes with the same lifetime ticket, without duplication")
	var detached:=order.snapshot(); detached.records[1].ticket.scope.clear(); var top:=order.top(); top.ticket.owner=0
	check(order.top().ticket==one,"Snapshots and top tickets are detached recursively")
	check(not order.retire({}) and not order.retire(one.merged({"lifetime":0},true)),"Missing/malformed private retirement cannot remove a live owner")
	check(order.deactivate_for_panel(22).deactivationRequested and closed.size()==1 and order.top().ticket==two,"A disable22 closes only promoted Rmnu and leaves the lower modal")
	check(not order.retire(one),"A consumed old modal ticket cannot retire another owner")
	order.retire(two); var next:=order.activate(a,"Rmnu",2,[1,55,42],func(_ticket):order.activate(a,"Rmnu",3,[1,55,42],func(ticket):closed.append(ticket)))
	check(order.deactivate_for_panel(17).deactivationRequested and order.top().ticket.lifetime==3 and not order.retire(next),"Reentrant same-owner reopen survives stale completion")
	var old: Dictionary=order.top().ticket; order.reset(); order.set_membership_coverage(true); var replacement:=order.activate(a,"Rmnu",1,[2,56,42],func(ticket):closed.append(ticket))
	check(old.epoch!=replacement.epoch and not order.retire(old),"Reset/reconnect epoch retires old references even when owner and lifetime are reused")
	a.free(); check(not order.deactivate_for_panel(18).deactivationRequested and order.top().reason=="owner_unavailable","Unretired destroyed top never exposes a lower owner")
	order.close(); check(not order.top().available and order.snapshot().records.is_empty(),"Connection close invalidates tickets and queued ownership immediately")
	b.free()
	var limited:=Order.new(); limited.set_membership_coverage(true); var retained: Array=[]
	for index in Order.LIMIT+1:
		var owner:=Node.new(); retained.append(owner); limited.activate(owner,"other",1)
	check(limited.snapshot().records.size()==Order.LIMIT and not limited.top().available,"Capacity stays bounded and reports unavailable ownership rather than a guessed top")
	limited.close()
	for owner in retained: owner.free()
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Unintegrated private registry versus original480 last-only decision corpus plus promotion/lifetime/detachment/coverage/reentrancy/capacity. Authored owner Nodes, no actual UI modal activation, server or pixels.","gpu":false,"servers":0}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("NATIVE_MODAL_ORDER_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
