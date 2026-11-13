extends RefCounted
# Detached plans for9945d0/98f7d0/992240. Party positions are the raw received
# native card order, never the displayed/reordered Godot portrait list.
const INVALID:=0x7f000000
const MORE_REF:=83611
const ACTIONS:=[[1,"IR_INVENTORY",3731,-19],[0,"IR_HAND_TRAP",1482,-20],[7,"IR_UNLOCK",1467,-18]]
static func integer(value: Variant,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=maximum
static func unavailable(reason: String,missing: Array=[]) -> Dictionary:
	return {"ready":false,"reason":reason,"missing":missing,"associates":[],"entries":[]}
static func snapshot(controlled: Dictionary,members: Variant,objects: Dictionary,party_received: bool) -> Dictionary:
	if not party_received:return unavailable("The received party order is unavailable.",["partyListRevision"])
	if not members is Array:return unavailable("The received party order is unavailable.",["party"])
	if controlled.get("objectType")!=5 or not integer(controlled.get("id"),4294967295) or int(controlled.id)==INVALID:return unavailable("The controlled creature is unavailable.",["controlled"])
	var result: Array=[];var missing: Array=[];var first: Dictionary={}
	for index in members.size():
		var member: Variant=members[index]
		var raw_id: Variant=member.get("id") if member is Dictionary else member
		if not integer(raw_id,4294967295):return unavailable("A received party ID is malformed.",["party[%d].id"%index])
		var id:=int(raw_id)
		if not first.has(id):first[id]=index
		# Original queries resolve every current party card through AppManager.
		# Missing/deleted objects are skipped; no proxy or visual is constructed.
		var object: Variant=objects.get(id)
		if not object is Dictionary or object.get("objectType")!=5 or object.get("replicationRemoved",false):continue
		var received: Dictionary=object.get("replicated",{})
		if not integer(received.get("field908"),65535):missing.append("party[%d].associateType"%index);continue
		if int(received.field908)!=1:continue
		if not integer(received.get("master"),4294967295):missing.append("party[%d].master"%index);continue
		if int(received.master)!=int(controlled.id):continue
		var name: Variant=received.get("name")
		if name is Dictionary or name is Array:name=name.duplicate(true)
		elif not name is String:name=null
		result.append({"objectId":id,"partyIndex":int(first[id]),"name":name})
	if not missing.is_empty():return unavailable("Received associate ownership is incomplete.",missing)
	return {"ready":true,"associates":result,"entries":[],"invalidPartyIndex":int(first.get(INVALID,-1)),"missing":[],"reason":""}
static func branch(slot: int,value: Dictionary) -> Dictionary:
	return {"kind":"associate","slot":slot,"icon":"IR_GUARD","objectId":int(value.objectId),"partyIndex":int(value.partyIndex),"name":value.name.duplicate(true) if value.name is Dictionary or value.name is Array else value.name}
static func more(offset: int) -> Dictionary:
	return {"kind":"more","slot":7,"icon":"IR_GUARD","titleRef":MORE_REF,"offset":offset}
static func action_rows(value: Dictionary) -> Array:
	var result: Array=[]
	for action in ACTIONS:
		result.append({"kind":"action","slot":int(action[0]),"icon":str(action[1]),"titleRef":int(action[2]),"command":int(action[3]),"objectId":int(value.objectId),"partyIndex":int(value.partyIndex),"indexAvailable":int(value.partyIndex)>=0 and int(value.partyIndex)<=32767,"targetAvailable":int(value.objectId)!=INVALID})
	return result
static func root(context: Dictionary) -> Dictionary:
	if not context.get("ready",false):return unavailable(str(context.get("reason","Received associate context is unavailable.")),context.get("missing",[]).duplicate())
	var values: Array=context.associates;var entries: Array=[]
	if values.size()==1:entries=action_rows(values[0])
	elif values.is_empty() and int(context.get("invalidPartyIndex",-1))>=0:
		# First() returns INVALID, and native IndexOf still finds a sentinel card.
		# Preserve its visible plan while marking the invalid action unavailable.
		entries=action_rows({"objectId":INVALID,"partyIndex":int(context.invalidPartyIndex)})
	elif values.size()>=2:
		entries=[branch(0,values[0]),branch(1,values[1])]
		# Original deliberately creates an empty More branch for exactly two.
		entries.append(branch(7,values[2]) if values.size()==3 else more(2))
	return {"ready":true,"entries":entries,"missing":[],"reason":""}
static func page(context: Dictionary,offset: int) -> Dictionary:
	if not context.get("ready",false):return unavailable(str(context.get("reason","Received associate context is unavailable.")),context.get("missing",[]).duplicate())
	var values: Array=context.associates
	if offset<0 or offset>values.size():return unavailable("The associate page cursor is retired.")
	var remaining:=values.size()-offset;var entries: Array=[]
	var count:=mini(8,remaining) if remaining<9 else 7
	for index in count:entries.append(branch(index,values[offset+index]))
	if remaining>=9:entries.append(more(offset+7))
	return {"ready":true,"entries":entries,"missing":[],"reason":""}
static func child(context: Dictionary,object_id: int,party_index: int) -> Dictionary:
	if not context.get("ready",false):return unavailable(str(context.get("reason","Received associate context is unavailable.")))
	for value in context.associates:
		if int(value.objectId)==object_id and int(value.partyIndex)==party_index:return {"ready":true,"entries":action_rows(value),"missing":[],"reason":""}
	return unavailable("The originating party member is retired.")
