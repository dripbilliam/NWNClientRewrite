extends RefCounted
# Existing owners call this BEFORE altering the original draw state. A weak
# endpoint avoids a dependency on an experimental renderer or ownership cycle.
const OWNER:="native_static_draw_owner"
static func withdraw(owner: Object,reason: String) -> void:
	if not is_instance_valid(owner) or not owner.has_meta(OWNER):return
	var endpoint: Variant=owner.get_meta(OWNER,null)
	if not endpoint is WeakRef:return
	var helper: Variant=endpoint.get_ref()
	if is_instance_valid(helper) and helper.has_method("withdraw_draw_owner"):helper.withdraw_draw_owner(owner,reason)
