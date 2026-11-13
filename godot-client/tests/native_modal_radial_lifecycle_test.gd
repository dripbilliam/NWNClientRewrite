extends SceneTree
const Order=preload("res://systems/native_data/modal_order.gd")
const Wheel=preload("res://systems/server_radial.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Gameplay=preload("res://systems/native_gameplay_ui.gd")
const ItemContext=preload("res://systems/native_item_context.gd")
class InventoryBoundary extends Node:
	var item_context
	var unrelated_gold:={"untouched":true}
	func close() -> void:
		if is_instance_valid(item_context): item_context.close()
class ChatBoundary extends Node:
	var context
	var history:=["retained message"]
	func close() -> void:
		if is_instance_valid(context): context.reset()
class DialogBoundary extends Node:
	var clears:=0
	func clear() -> void: clears+=1
	func close() -> void: pass
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func open(wheel) -> void: wheel.open_at(Vector2(400,300),42,Vector3.ZERO,false)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	root.size=Vector2i(1024,768)
	var ui:=Gameplay.new(); root.add_child(ui); ui.set_process(false); ui.set_process_input(false); ui.set_process_unhandled_key_input(false); ui.modal_order=Order.new()
	var desktop:=Desktop.new(); ui.add_child(desktop); desktop.set_process(false); desktop.set_process_unhandled_key_input(false); desktop.owner_ui=ui; ui.desktop=desktop
	desktop.radial=Wheel.new(); desktop.add_child(desktop.radial); desktop.shortcut_dialogs=DialogBoundary.new(); desktop.add_child(desktop.shortcut_dialogs)
	var inventory:=InventoryBoundary.new(); ui.add_child(inventory); ui.inventory=inventory; inventory.item_context=ItemContext.new(); inventory.add_child(inventory.item_context); inventory.item_context.set_process(false); inventory.item_context.wheel=Wheel.new(); inventory.item_context.add_child(inventory.item_context.wheel)
	var chat:=ChatBoundary.new(); ui.add_child(chat); ui.chat_skin=chat; chat.context=Wheel.new(); chat.add_child(chat.context)
	ui.bind_modal_radials()
	open(desktop.radial)
	check(ui.modal_order.snapshot().records.size()==1 and not ui.modal_order.deactivate_for_panel(16).deactivationRequested and desktop.radial.active,"Real wheel activation registers a lease while unavailable default coverage preserves current behavior")
	var first: Dictionary=desktop.radial.modal_owner_ticket.duplicate(true); var lifetime: int=desktop.radial.request_id
	ui.bind_modal_radials(); check(desktop.radial.modal_owner_ticket==first,"Actual configuration binding is idempotent and cannot reorder existing live owners")
	desktop.radial.register_modal_owner(); check(desktop.radial.modal_owner_ticket==first and ui.modal_order.snapshot().records.size()==1,"Repeated current activation does not duplicate a real wheel lease")
	ui.modal_order.set_membership_coverage(true) # Explicit authored complete fixture graph only.
	var other:=Node.new(); ui.add_child(other); var other_ticket: Dictionary=ui.modal_order.activate(other,"other",1)
	check(not ui.modal_order.deactivate_for_panel(22).deactivationRequested and desktop.radial.active,"A higher authored non-radial modal blocks server radial-close without layer inference")
	desktop.radial.register_modal_owner(); check(ui.modal_order.top().ticket==first,"Explicit activation promotes a lower live wheel with the same request lifetime")
	desktop.radial_stack=[{"retain":1}]; desktop.radial_entries={1:{"retain":1}}; desktop.pending_shortcuts={1:{"retain":1}}; desktop.shortcut_context={"retain":1}; desktop.target={"keep_target":true}
	check(ui.modal_order.deactivate_for_panel(16).deactivationRequested and not desktop.radial.active and desktop.radial.request_id>lifetime,"Original-style top deactivation retires the actual Desktop wheel exactly once")
	check(desktop.radial_stack.is_empty() and desktop.radial_entries.is_empty() and desktop.pending_shortcuts.is_empty() and desktop.shortcut_context.is_empty(),"Desktop retirement clears only its wheel-owned stacks/entries/pending shortcut context")
	check(desktop.target=={"keep_target":true} and desktop.shortcut_dialogs.clears==0 and ui.modal_order.top().ticket==other_ticket,"Target cursor, lower shortcut dialogs and unrelated modal owner remain untouched")
	check(not desktop.retire_current_radial(lifetime) and not ui.modal_order.retire(first),"Old request/ticket cannot close or remove a later owner")
	open(desktop.radial); var world_ticket: Dictionary=desktop.radial.modal_owner_ticket.duplicate(true)
	inventory.item_context.selection={"entryId":1}; inventory.item_context.lifetime=[1,55,42]; inventory.item_context.history=[{"kind":"root"}]; inventory.item_context.entries={1:{"keep":1}}; inventory.item_context.quickbar_owned=true
	open(inventory.item_context.wheel); var old_item: int=inventory.item_context.wheel.request_id
	check(ui.modal_order.deactivate_for_panel(21).deactivationRequested and not inventory.item_context.wheel.active and desktop.radial.active,"Only selected top item wheel is cancelled while another authored lower wheel remains")
	check(inventory.item_context.selection.is_empty() and inventory.item_context.history.is_empty() and inventory.item_context.entries.is_empty() and not inventory.item_context.quickbar_owned and inventory.unrelated_gold=={"untouched":true},"Actual item cancel retires its selection/trade/quickbar lifetimes without touching a lower gold owner")
	open(chat.context)
	check(ui.modal_order.deactivate_for_panel(18).deactivationRequested and not chat.context.active and desktop.radial.active and chat.history==["retained message"],"Chat wheel retirement resets only its real radial widget, preserving chat history and lower world owner")
	open(inventory.item_context.wheel)
	check(not ui.retire_item_radial(old_item) and inventory.item_context.wheel.active,"Stale item request cannot cancel a reopened item wheel")
	inventory.item_context.wheel.reset(); check(ui.modal_order.top().ticket==world_ticket,"Normal reset retires exactly its own current lease")
	open(chat.context); check(ui.modal_order.snapshot().records.size()==3,"A reopened chat widget owns its new current modal lease")
	chat.context.free(); check(ui.modal_order.snapshot().records.size()==2,"Exiting real radial owner retires its lease without scanning/closing other owners")
	desktop.closed=true; check(not desktop.retire_current_radial(desktop.radial.request_id) and desktop.radial.active,"Closed Desktop rejects late modal retirement"); desktop.closed=false
	ui.close(); check(not ui.modal_order.top().available and ui.modal_order.snapshot().records.is_empty() and not ui.retire_item_radial(old_item),"UI close invalidates the registry before owner teardown and rejects late callbacks")
	ui.free(); await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"servers":0,"scope":"Actual ServerRadial open/reset/exit and Desktop/GameUi/item cancel owner callbacks; explicit authored complete modal graph, fake inventory/chat setup boundaries. Production coverage stays unavailable and no53/2 close is enabled. No original pixels/server/full modal-membership claim."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("MODAL_RADIAL_LIFECYCLE_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
