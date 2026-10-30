extends "res://systems/native_gold_transfer.gd"
# Same original INV_STACKSPLIT artwork/controls, with the item-split callback
# 9a6aa0 ->7c0050 instead of the private gold drag source.
var selection: Dictionary={}
func dialog_title() -> String:
	return owner_inventory.text_owner.raw({"strRef":int(entries.get("title",{}).get("caption",{}).get("Obj_StrRef",6616))})
func current_context() -> Array:
	var row: Dictionary=owner_inventory.valid_item(selection) if not selection.is_empty() else {}
	return [owner_inventory.generation,owner_inventory.area_id,owner_inventory.controlled_id,selection.get("viewId",-1),selection.get("entryId",-1),row.get("stack",0)]
func balance() -> int:
	var row: Dictionary=owner_inventory.valid_item(selection) if not selection.is_empty() else {}
	return mini(65535,int(row.get("stack",0)))
func open_item(value: Dictionary) -> void:
	if closed or not layout_ready: return
	cancel(); selection=value.duplicate(true)
	if balance()<=1: return
	context=current_context(); maximum=balance(); number.text="1"; modal.position=(get_viewport_rect().size-modal.size)*0.5; modal.show(); modal.move_to_front(); number.grab_focus(); number.select_all(); set_process(true); stats.opened+=1
func confirm() -> void:
	if closed or not is_instance_valid(modal) or not modal.visible: return
	var amount:=Amount.confirmed(number.text,maximum)
	if context!=current_context() or amount>balance(): stats.stale+=1; cancel(); return
	modal.hide(); repeat_step=0; repeat_button=null; repeat_elapsed=0; repeat_initial=true; number.release_focus(); set_process(false)
	if amount<=0: return
	var message: Dictionary=selection.duplicate(true); message.kind="inventory-action"; message.operation="split"; message.amount=amount; owner_inventory.input_request(message)
