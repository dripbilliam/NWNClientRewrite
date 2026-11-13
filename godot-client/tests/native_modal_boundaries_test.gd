extends SceneTree
const Order=preload("res://systems/native_data/modal_order.gd")
const Surfaces=preload("res://systems/native_modal_surfaces.gd")
const Lease=preload("res://systems/native_data/modal_lease.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var order:=Order.new();var surfaces:=Surfaces.new();root.add_child(surfaces);surfaces.configure(order)
	var lower:=CanvasLayer.new();lower.layer=100;root.add_child(lower)
	var upper:=CanvasLayer.new();upper.layer=30;root.add_child(upper)
	var a:=Control.new();lower.add_child(a);var b:=Control.new();upper.add_child(b)
	var one:=Lease.new();one.configure(a,order,surfaces,lower);one.bind_input(a)
	var two:=Lease.new();two.configure(b,order,surfaces,upper);two.bind_input(b)
	check(one.recursive_input,"Installed Godot exposes exact recursive mouse/focus admission without child scans")
	one.activate([1]);var a_ticket:=one.ticket.duplicate(true)
	check(order.admits(a_ticket) and lower.layer==Surfaces.BASE,"An explicit active lease drives its render rank")
	two.activate([1]);var b_ticket:=two.ticket.duplicate(true)
	check(not one.admits() and two.admits() and upper.layer>lower.layer,"Logical top independently drives input and cross-layer presentation")
	check(int(a.get("mouse_behavior_recursive"))==1 and int(a.get("focus_behavior_recursive"))==1,"Lower registered Control rejects descendant mouse/focus input without disabling world owners")
	check(not order.deactivate_for_panel(16).deactivationRequested,"New owner bindings do not silently enable global coverage")
	one.activate([1]);check(one.ticket==a_ticket and lower.layer>upper.layer and order.snapshot().records.size()==2,"Promotion retains lifetime and moves exact explicit group")
	var unknown:=Node.new();root.add_child(unknown);var unknown_ticket:=order.activate(unknown,"other",1)
	check(not surfaces.snapshot().available and lower.layer==100 and upper.layer==30,"Unmapped live owner suspends all rank projection and restores original layers")
	order.retire(unknown_ticket);unknown.free()
	check(surfaces.snapshot().available and lower.layer>upper.layer,"Exact retirement resumes projection from the live logical order")
	var detached:=surfaces.snapshot();detached.available=false
	check(surfaces.snapshot().available,"Surface diagnostics are detached")
	var callbacks: Array=[]
	order.with_callback(a_ticket,func():
		callbacks.append(order.callback_owner(a_ticket))
		two.activate([1])
		order.with_callback(two.ticket,func():callbacks.append(order.callback_owner(two.ticket) and not order.callback_owner(a_ticket)))
		callbacks.append(order.callback_owner(a_ticket)))
	check(callbacks==[true,true,true] and not order.callback_owner(a_ticket),"Nested synchronous callback owners restore precisely and never remain latched")
	two.retire();one.retire()
	check(lower.layer==100 and upper.layer==30 and int(a.get("mouse_behavior_recursive"))==one.mouse_mode,"Retirement restores presentation and recursive input state")
	var resetter:=Node.new();root.add_child(resetter);var incoming:=Node.new();root.add_child(incoming)
	order.activate(resetter,"other",1,[],Callable(),func(_ticket):order.reset())
	var rejected:=order.activate(incoming,"other",1)
	check(not rejected.has("registry") and order.snapshot().records.is_empty(),"Reset during a previous-top callback cannot append a captured old-epoch owner")
	var replaced:=Node.new();root.add_child(replaced);var retire_incoming:=Node.new();root.add_child(retire_incoming)
	order.activate(replaced,"other",1,[],Callable(),func(_ticket):
		order.retire(order.snapshot().records.back().ticket)
		order.activate(retire_incoming,"other",2))
	var old:=order.activate(retire_incoming,"other",1)
	check(not old.has("registry") and order.snapshot().records.back().ticket.lifetime==2,"Reentrant incoming lifetime replacement survives the outer activation")
	order.reset();order.with_callback(a_ticket,func():callbacks.append(false))
	check(callbacks.size()==3,"Stale callback ticket cannot invoke a menu action")
	one.close();two.close();surfaces.close();order.close();a.free();b.free();lower.free();upper.free();resetter.free();incoming.free();replaced.free();retire_incoming.free();surfaces.queue_free()
	await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"servers":0,"scope":"Current modal lease/order/surface policy, actual recursive native Control admission, reentrancy and explicit rank restoration. Authored owners only; no full membership,53/2 enablement, original pixels or live client claim."}
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  ")+"\n");file.close();print("MODAL_BOUNDARIES_RESULT ",JSON.stringify(result));quit(0 if result.success else 1)
