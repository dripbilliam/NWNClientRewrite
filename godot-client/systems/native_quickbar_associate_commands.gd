extends RefCounted
# Native quickslot-only associate Commands. World9914b0 passes mode0 and
# deliberately differs from quickslot9ac860's mode1; this adapter does not
# extend the normal world Commands menu.
const Model=preload("res://systems/native_data/quickbar_associate_commands.gd")
const Identity=preload("res://systems/native_data/player_identity.gd")
static func object_valid(value: Variant) -> bool:
	return typeof(value)==TYPE_OBJECT and is_instance_valid(value)
static func normal_player(owner) -> bool:
	if not object_valid(owner) or owner.closed:return false
	var permission:=Identity.permission(owner.state.get("gameMasterPermission"))
	return permission.available and not permission.permission
static func query(owner) -> Dictionary:
	if not normal_player(owner):return Model.unavailable("Normal-player party context is unavailable.",["normal-player.permission"])
	var revision: Variant=owner.state.get("partyListRevision")
	return Model.snapshot(owner.actor(),owner.state.get("party"),owner.objects,Model.integer(revision,9007199254740991) and revision>0)
static func member_lifetime(owner,id: int) -> Variant:
	var value: Variant=owner.objects.get(id)
	if not value is Dictionary or value.get("id")!=id or value.get("objectType")!=5 or value.get("replicationRemoved")==true or value.get("destroyed")==true:return null
	var lifetime: Variant=value.get("clientKnownLifetime")
	return int(lifetime) if Model.integer(lifetime,9007199254740991) and lifetime>0 else null
static func actor_scope(owner) -> Dictionary:
	if not normal_player(owner) or not object_valid(owner.radial) or not owner.radial.active or owner.shortcut_context.is_empty() or not owner.pending_shortcuts.has("index"):return {}
	if not owner.shortcut_scope_valid(owner.shortcut_context):return {}
	var lifetime: Variant=owner.world_member_lifetime(owner.actor_id)
	if lifetime==null:return {}
	return {"owner":owner.get_instance_id(),"request":owner.radial.request_id,"origin":owner.shortcut_context.duplicate(true),"actorLifetime":lifetime}
static func member_scope(owner,origin: Dictionary,value: Dictionary) -> Dictionary:
	var index:=int(value.partyIndex);var id:=int(value.objectId)
	var lifetime: Variant=member_lifetime(owner,id)
	if origin.is_empty() or index<0 or index>32767 or lifetime==null or id==Model.INVALID:return {}
	return origin.merged({"objectId":id,"partyIndex":index,"memberLifetime":lifetime},true)
static func valid(owner,scope: Dictionary) -> bool:
	if not normal_player(owner) or not object_valid(owner.radial) or not owner.radial.active:return false
	if scope.is_empty() or scope.get("owner")!=owner.get_instance_id() or scope.get("request")!=owner.radial.request_id or not scope.get("origin") is Dictionary:return false
	if not owner.shortcut_scope_valid(scope.origin) or owner.world_member_lifetime(owner.actor_id)!=scope.get("actorLifetime"):return false
	if not scope.has("objectId"):return true
	var id:=int(scope.objectId)
	if member_lifetime(owner,id)!=scope.get("memberLifetime"):return false
	return Model.child(query(owner),id,int(scope.partyIndex)).ready
static func entry_valid(owner,entry: Dictionary) -> bool:
	return not entry.has("associateScope") or entry.associateScope is Dictionary and valid(owner,entry.associateScope)
static func render(owner,plans: Array,origin: Dictionary) -> Array:
	if not object_valid(owner.owner_ui) or not object_valid(owner.owner_ui.text):return []
	var result: Array=[]
	for plan in plans:
		if plan.kind=="more":
			result.append(owner.entry(int(plan.slot),owner.owner_ui.text.raw({"strRef":int(plan.titleRef)}),"branch",str(plan.icon),{"disabled":origin.is_empty(),"associateScope":origin.duplicate(true),"menu":{"kind":"quickbar-associates-more","offset":int(plan.offset),"title":owner.owner_ui.text.raw({"strRef":int(plan.titleRef)}),"center":str(plan.icon),"associateScope":origin.duplicate(true)}}))
		elif plan.kind=="associate":
			var scope:=member_scope(owner,origin,plan)
			var label: String=owner.owner_ui.text.name(plan.name,int(plan.objectId))
			result.append(owner.entry(int(plan.slot),label,"branch",str(plan.icon),{"disabled":scope.is_empty(),"associateScope":scope,"menu":{"kind":"quickbar-associate-member","title":label,"center":str(plan.icon),"objectId":int(plan.objectId),"partyIndex":int(plan.partyIndex),"associateScope":scope.duplicate(true)}}))
		else:
			var scope:=member_scope(owner,origin,plan)
			result.append(owner.entry(int(plan.slot),owner.owner_ui.text.raw({"strRef":int(plan.titleRef)}),"power",str(plan.icon),{"disabled":scope.is_empty() or not plan.indexAvailable or not plan.targetAvailable,"associateScope":scope,"binding":{"type":39,"intParam":int(plan.command),"associateType":1,"associateId":int(plan.objectId)}}))
	return result
static func entries(owner,menu: Dictionary) -> Array:
	var context:=query(owner)
	if not context.ready:return []
	var kind:=str(menu.get("kind",""));var origin:=actor_scope(owner)
	if kind=="quickbar-commands":return render(owner,Model.root(context).entries,origin)
	var captured: Variant=menu.get("associateScope")
	if not captured is Dictionary or not valid(owner,captured):return []
	if kind=="quickbar-associates-more":return render(owner,Model.page(context,int(menu.get("offset",-1))).entries,captured)
	if kind=="quickbar-associate-member":return render(owner,Model.child(context,int(menu.get("objectId",Model.INVALID)),int(menu.get("partyIndex",-1))).entries,captured)
	return []
