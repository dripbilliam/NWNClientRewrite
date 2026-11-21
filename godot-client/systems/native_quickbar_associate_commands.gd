extends RefCounted
# Native quickslot-only associate Commands. World9914b0 passes mode0 and
# deliberately differs from quickslot9ac860's mode1; this adapter does not
# extend the normal world Commands menu.
const Model=preload("res://systems/native_data/quickbar_associate_commands.gd")
const Identity=preload("res://systems/native_data/player_identity.gd")
const INVALID=Model.INVALID
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
	if scope.has("choiceTarget"):
		var choice_id:=int(scope.choiceTarget)
		if member_lifetime(owner,choice_id)!=scope.get("choiceLifetime"):return false
		var object: Dictionary=owner.objects.get(choice_id,{})
		var type:=int(scope.get("choiceType",0))
		if type==3 and choice_id==int(owner.actor().get("familiarId",INVALID)) and int(object.get("objectType",0))==5 and not bool(object.get("replicationRemoved",false)):return true
		return int(object.get("objectType",0))==5 and not bool(object.get("replicationRemoved",false)) and int(object.get("replicated",{}).get("master",INVALID))==owner.actor_id and int(object.get("replicated",{}).get("field908",0))==type
	if not scope.has("objectId"):return true
	var id:=int(scope.objectId)
	if member_lifetime(owner,id)!=scope.get("memberLifetime"):return false
	return Model.child(query(owner),id,int(scope.partyIndex)).ready
static func entry_valid(owner,entry: Dictionary) -> bool:
	return not entry.has("associateScope") or entry.associateScope is Dictionary and valid(owner,entry.associateScope)
static func shortcut(button: Dictionary,actor: Dictionary) -> Variant:
	if int(button.get("type",0))!=39:return null
	var associate_type:=int(button.get("associateType",0))
	var target_id: Variant=button.get("associateId") if associate_type==1 else actor.get("companionId",INVALID) if associate_type==2 else actor.get("familiarId",INVALID) if associate_type==3 else null
	if target_id==null:return null
	var command:=int(button.get("intParam",0))&65535
	return {"targetId":target_id,"command":command-65536 if command&32768 else command}
static func source_choices(owner) -> Array:
	# Old networkAssociateShortcutChoices: the five quick chats are supplied
	# by QuickbarRadial.commands; retain every remaining choice in source order.
	var actor: Dictionary=owner.actor()
	var result: Array=[]
	var familiar_id:=int(actor.get("familiarId",INVALID))
	var familiar: Dictionary=owner.objects.get(familiar_id,{})
	if int(familiar.get("objectType",0))==5 and not bool(familiar.get("replicationRemoved",false)):
		result.append({"label":"Possess Familiar","icon":"IFE_POSSESS","binding":{"type":38},"targetId":familiar_id,"associateType":3})
	var targets: Array=[]
	for member in owner.state.get("party",[]):
		var id:=int(member.get("id",INVALID)) if member is Dictionary else int(member)
		var object: Dictionary=owner.objects.get(id,{})
		var replicated: Dictionary=object.get("replicated",{})
		if int(object.get("objectType",0))==5 and not bool(object.get("replicationRemoved",false)) and int(replicated.get("field908",0))==1 and int(replicated.get("master",INVALID))==int(actor.get("id",INVALID)):
			targets.append(object)
	for object in owner.objects.values():
		if not object is Dictionary:continue
		if int(object.get("replicated",{}).get("field908",0)) in [2,3]:targets.append(object)
	for target in targets:
		var replicated: Dictionary=target.get("replicated",{})
		var type:=int(replicated.get("field908",0))
		if int(target.get("objectType",0))!=5 or bool(target.get("replicationRemoved",false)) or int(replicated.get("master",INVALID))!=int(actor.get("id",INVALID)):continue
		var commands: Array=[-9] if type==2 else [-8] if type==3 else [-18,-19,-20] if type==1 else []
		for command in commands:
			var names: Array={-8:["Unsummon","IFE_NOFAMILIAR"],-9:["Unsummon","IFE_NOFAMILIAR"],-18:["Unlock","IR_UNLOCK"],-19:["Inventory","IR_INVENTORY"],-20:["Disarm trap","IR_HAND_TRAP"]}[command]
			var name: Variant=replicated.get("name")
			var text_name:=str(name.get("text","")) if name is Dictionary else ""
			result.append({"label":str(names[0])+(" : "+text_name if not text_name.is_empty() else ""),"icon":str(names[1]),"binding":{"type":39,"intParam":command,"associateType":1,"associateId":int(target.get("id",INVALID))},"targetId":int(target.get("id",INVALID)),"associateType":type})
	return result
static func choice_scope(owner,origin: Dictionary,choice: Dictionary) -> Dictionary:
	var target_id:=int(choice.get("targetId",INVALID))
	var lifetime: Variant=member_lifetime(owner,target_id)
	if origin.is_empty():return {}
	return origin.merged({"choiceTarget":target_id,"choiceType":int(choice.get("associateType",0)),"choiceLifetime":lifetime},true)
static func source_page(owner,origin: Dictionary,offset: int) -> Array:
	var choices:=source_choices(owner)
	if origin.is_empty() or offset<0 or offset>=choices.size():return []
	var result: Array=[]
	for index in range(offset,mini(offset+7,choices.size())):
		var choice: Dictionary=choices[index]
		var scope:=choice_scope(owner,origin,choice)
		result.append(owner.entry(index-offset,str(choice.label),"power",str(choice.icon),{"binding":choice.binding,"disabled":scope.is_empty(),"associateScope":scope}))
	if offset+7<choices.size():
		result.append(owner.entry(7,"More","branch","IR_GUARD",{"associateScope":origin.duplicate(true),"menu":{"kind":"quickbar-associate-choices-page","offset":offset+7,"title":"More","center":"IR_GUARD","associateScope":origin.duplicate(true)}}))
	return result
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
	var kind:=str(menu.get("kind",""))
	if kind=="quickbar-commands":
		var root_scope:=actor_scope(owner)
		if source_choices(owner).is_empty():return []
		return [owner.entry(0,"Associates","branch","IR_COMMAND",{"disabled":root_scope.is_empty(),"associateScope":root_scope.duplicate(true),"menu":{"kind":"quickbar-associate-choices-page","offset":0,"title":"Associates","center":"IR_COMMAND","associateScope":root_scope.duplicate(true)}})]
	if kind=="quickbar-associate-choices-page":
		var page_scope: Variant=menu.get("associateScope")
		if not page_scope is Dictionary or not valid(owner,page_scope):return []
		return source_page(owner,page_scope,int(menu.get("offset",-1)))
	var context:=query(owner)
	if not context.ready:return []
	var origin:=actor_scope(owner)
	var captured: Variant=menu.get("associateScope")
	if not captured is Dictionary or not valid(owner,captured):return []
	if kind=="quickbar-associates-more":return render(owner,Model.page(context,int(menu.get("offset",-1))).entries,captured)
	if kind=="quickbar-associate-member":return render(owner,Model.child(context,int(menu.get("objectId",Model.INVALID)),int(menu.get("partyIndex",-1))).entries,captured)
	return []
