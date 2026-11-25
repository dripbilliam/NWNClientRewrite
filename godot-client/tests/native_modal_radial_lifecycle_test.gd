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
	check(not desktop.radial.active and desktop.radial.modal_owner_ticket.is_empty() and desktop.radial.request_id==lifetime+1,"External modal activation retires the exact previous Desktop wheel")
	check(not ui.modal_order.deactivate_for_panel(22).deactivationRequested and ui.modal_order.top().ticket==other_ticket and ui.modal_order.snapshot().records.size()==1,"A server radial-close leaves the higher non-radial owner intact")
	open(desktop.radial)
	var current_lifetime: int=desktop.radial.request_id
	var current_ticket: Dictionary=desktop.radial.modal_owner_ticket.duplicate(true)
	check(desktop.radial.active and current_lifetime>lifetime and ui.modal_order.top().ticket==current_ticket,"A reopened Desktop wheel owns a fresh request and top lease")
	check(not desktop.retire_current_radial(lifetime) and not ui.modal_order.retire(first) and desktop.radial.active and ui.modal_order.top().ticket==current_ticket,"Retired Desktop request and ticket cannot close a reopened wheel")
	desktop.radial_stack=[{"retain":1}]; desktop.radial_entries={1:{"retain":1}}; desktop.pending_shortcuts={1:{"retain":1}}; desktop.shortcut_context={"retain":1}; desktop.target={"keep_target":true}
	var desktop_close: Dictionary=ui.modal_order.deactivate_for_panel(16)
	check(desktop_close.deactivationRequested and desktop_close.ticket==current_ticket and not desktop.radial.active and desktop.radial.request_id==current_lifetime+1,"Original-style top deactivation retires the fresh Desktop wheel exactly once")
	check(desktop.radial_stack.is_empty() and desktop.radial_entries.is_empty() and desktop.pending_shortcuts.is_empty() and desktop.shortcut_context.is_empty(),"Desktop retirement clears only its wheel-owned stacks/entries/pending shortcut context")
	check(desktop.target=={"keep_target":true} and desktop.shortcut_dialogs.clears==0 and ui.modal_order.top().ticket==other_ticket,"Target cursor, lower shortcut dialogs and unrelated modal owner remain untouched")
	open(desktop.radial)
	var world_ticket: Dictionary=desktop.radial.modal_owner_ticket.duplicate(true)
	inventory.item_context.selection={"entryId":1}; inventory.item_context.lifetime=[1,55,42]; inventory.item_context.history=[{"kind":"root"}]; inventory.item_context.entries={1:{"keep":1}}; inventory.item_context.quickbar_owned=true
	open(inventory.item_context.wheel)
	var item_ticket: Dictionary=inventory.item_context.wheel.modal_owner_ticket.duplicate(true)
	var old_item: int=inventory.item_context.wheel.request_id
	check(not desktop.radial.active and not ui.modal_order.retire(world_ticket) and inventory.item_context.wheel.active and ui.modal_order.top().ticket==item_ticket,"External item activation retires the previous Desktop wheel and owns admission")
	open(chat.context)
	var chat_ticket: Dictionary=chat.context.modal_owner_ticket.duplicate(true)
	check(not inventory.item_context.wheel.active and not ui.modal_order.retire(item_ticket) and chat.context.active and ui.modal_order.top().ticket==chat_ticket,"External chat activation retires the previous item wheel and owns admission")
	check(inventory.item_context.selection.is_empty() and inventory.item_context.history.is_empty() and inventory.item_context.entries.is_empty() and not inventory.item_context.quickbar_owned and inventory.unrelated_gold=={"untouched":true},"Actual item cancellation retires its selection and quickbar ownership while preserving gold")
	var chat_close: Dictionary=ui.modal_order.deactivate_for_panel(18)
	check(chat_close.deactivationRequested and chat_close.ticket==chat_ticket and not chat.context.active and chat.history==["retained message"] and ui.modal_order.top().ticket==other_ticket,"Chat deactivation retires only its wheel and preserves chat history and the unrelated owner")
	open(inventory.item_context.wheel)
	var reopened_item_ticket: Dictionary=inventory.item_context.wheel.modal_owner_ticket.duplicate(true)
	check(not ui.retire_item_radial(old_item) and not ui.modal_order.retire(item_ticket) and inventory.item_context.wheel.active and ui.modal_order.top().ticket==reopened_item_ticket,"Stale item request and ticket cannot cancel a reopened item wheel")
	var item_close: Dictionary=ui.modal_order.deactivate_for_panel(21)
	check(item_close.deactivationRequested and item_close.ticket==reopened_item_ticket and not inventory.item_context.wheel.active and ui.modal_order.top().ticket==other_ticket,"Server close cancels the exact reopened item wheel and preserves the unrelated owner")
	open(inventory.item_context.wheel)
	var reset_ticket: Dictionary=inventory.item_context.wheel.modal_owner_ticket.duplicate(true)
	inventory.item_context.wheel.reset()
	check(not ui.modal_order.retire(reset_ticket) and ui.modal_order.top().ticket==other_ticket,"Normal reset retires exactly its own current lease")
	open(chat.context)
	var exit_ticket: Dictionary=chat.context.modal_owner_ticket.duplicate(true)
	check(exit_ticket!=chat_ticket and ui.modal_order.top().ticket==exit_ticket and ui.modal_order.snapshot().records.size()==2,"A reopened chat widget owns a fresh current modal lease")
	chat.context.free()
	check(not ui.modal_order.retire(exit_ticket) and ui.modal_order.top().ticket==other_ticket and ui.modal_order.snapshot().records.size()==1,"Exiting the active chat wheel retires its exact lease and preserves the unrelated owner")
	open(desktop.radial)
	var closed_lifetime: int=desktop.radial.request_id
	var closed_ticket: Dictionary=desktop.radial.modal_owner_ticket.duplicate(true)
	desktop.closed=true
	check(not desktop.retire_current_radial(closed_lifetime) and desktop.radial.active and ui.modal_order.top().ticket==closed_ticket,"Closed Desktop rejects retirement of the exact live wheel")
	desktop.closed=false
	ui.close(); check(not ui.modal_order.top().available and ui.modal_order.snapshot().records.is_empty() and not ui.retire_item_radial(old_item),"UI close invalidates the registry before owner teardown and rejects late callbacks")
	ui.free(); await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"servers":0,"scope":"Actual ServerRadial open/reset/exit and Desktop/GameUi/item cancel owner callbacks; explicit authored complete modal graph, fake inventory/chat setup boundaries. Production coverage stays unavailable and no53/2 close is enabled. No original pixels/server/full modal-membership claim."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); print("MODAL_RADIAL_LIFECYCLE_RESULT ",JSON.stringify(result)); quit(0 if result.success else 1)
