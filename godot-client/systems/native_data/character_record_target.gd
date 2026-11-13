extends RefCounted
# Private displayed-character lifetime. No second entity store or mutable live
# data view leaves this helper. Production Desktop binding is a separate hook.
const Base=preload("res://systems/native_data/creature_radial.gd")
const Identity=preload("res://systems/native_data/player_identity.gd")
static func lifetime(objects:Dictionary,id:int,area:int) -> Variant:
	var value:Variant=objects.get(id)
	if not value is Dictionary or value.get("id")!=id or value.get("objectType")!=5 or value.get("areaId")!=area or value.get("replicationRemoved")==true or value.get("destroyed")==true:return null
	var token:Variant=value.get("clientKnownLifetime")
	return int(token) if Base.integer(token,9007199254740991) and token>0 else null
static func capture(owner_id:int,generation:int,area:int,actor_id:int,target_id:int,objects:Dictionary) -> Dictionary:
	if generation<0 or not Base.integer(area,4294967295) or area==Base.INVALID or not Base.integer(actor_id,4294967295) or actor_id==Base.INVALID or not Base.integer(target_id,4294967295) or target_id==Base.INVALID or target_id==actor_id:return {}
	var actor_lifetime:Variant=lifetime(objects,actor_id,area);var target_lifetime:Variant=lifetime(objects,target_id,area)
	if actor_lifetime==null or target_lifetime==null:return {}
	return {"owner":owner_id,"generation":generation,"area":area,"actor":actor_id,"target":target_id,"actorLifetime":actor_lifetime,"targetLifetime":target_lifetime}
static func valid(value:Dictionary,owner_id:int,generation:int,area:int,actor_id:int,objects:Dictionary) -> bool:
	if value.is_empty() or value.get("owner")!=owner_id or value.get("generation")!=generation or value.get("area")!=area or value.get("actor")!=actor_id or not Base.integer(value.get("target"),4294967295) or value.target==actor_id:return false
	var actor_lifetime:Variant=lifetime(objects,actor_id,area);var target_lifetime:Variant=lifetime(objects,int(value.target),area)
	return actor_lifetime!=null and target_lifetime!=null and actor_lifetime==value.get("actorLifetime") and target_lifetime==value.get("targetLifetime")
static func admission(actor_id:int,target_id:int,objects:Dictionary,header:Dictionary) -> Dictionary:
	var missing:Array=[];var role:=Identity.permission(header.get("gameMasterPermission"))
	if not role.available:missing.append("connection.permission")
	elif role.permission:missing.append("normal-associate-record.permission")
	var actor:Variant=objects.get(actor_id)
	if not actor is Dictionary or actor.get("id")!=actor_id or actor.get("objectType")!=5 or actor.get("replicationRemoved")==true or actor.get("destroyed")==true:missing.append("controlled.creature")
	var target:Variant=objects.get(target_id)
	if not target is Dictionary or target.get("id")!=target_id or target.get("objectType")!=5:missing.append("displayed.creature")
	var source:Variant=target.get("replicated") if target is Dictionary else null
	if not source is Dictionary:missing.append("displayed.replicated")
	else:
		if not Base.integer(source.get("master"),4294967295):missing.append("displayed.replicated.master")
		elif int(source.master)!=actor_id:missing.append("displayed.current-controlled-master")
		if not Base.integer(source.get("field908"),65535):missing.append("displayed.replicated.field908")
		elif int(source.field908) not in [1,2,3,4]:missing.append("displayed.record-associate-type")
	return {"available":missing.is_empty() and target_id!=actor_id,"missing":missing}
static func request_scope(value:Dictionary) -> Dictionary:
	if not Base.integer(value.get("target"),4294967295) or not Base.integer(value.get("actorLifetime"),9007199254740991) or not Base.integer(value.get("targetLifetime"),9007199254740991) or value.actorLifetime<1 or value.targetLifetime<1:return {}
	return {"targetId":int(value.target),"recordActorLifetime":int(value.actorLifetime),"recordTargetLifetime":int(value.targetLifetime)}
