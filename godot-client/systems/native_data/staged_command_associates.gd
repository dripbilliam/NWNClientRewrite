extends RefCounted
# STAGED ONLY. Native9945d0(mode1)/992240/98f7d0, not a production import.
# The caller supplies the canonical party and lookup at an explicit menu boundary.
# Keep only scalar query results; never duplicate the entity store.
const INVALID=2130706432
const SAFE=9007199254740991
const BASE=[[5,"IR_GUARD",1474,9],[4,"IR_STANDGROUND",1477,10],[3,"IR_FOLLOW",682,22],[2,"IR_ATTACKNEAREST",5345,0],[6,"IR_HEALME",1483,4]]
const DIRECT=[[1,"IR_INVENTORY",3731,-19],[0,"IR_HAND_TRAP",1482,-20],[7,"IR_UNLOCK",1467,-18]]
static func integer(value: Variant,maximum: int=SAFE) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=maximum
static func capture(party: Variant,revision: Variant,actor_id: Variant,lookup: Callable,name_of: Callable) -> Dictionary:
	var result:={"known":false,"actorId":actor_id,"revision":revision,"rawIds":[],"associates":[]}
	if not party is Array or not integer(revision) or not integer(actor_id,4294967295) or not lookup.is_valid():return result
	for member in party:
		if not member is Dictionary or not integer(member.get("id"),4294967295):return result
		var id:=int(member.id);result.rawIds.append(id)
		var object: Variant=lookup.call(id)
		# Null is an explicit canonical lookup miss, not an assumed missing flag.
		if object==null:continue
		if not object is Dictionary or not integer(object.get("objectType"),255):return result
		if int(object.objectType)!=5 or object.get("replicationRemoved",false):continue
		var fields: Variant=object.get("replicated")
		if not fields is Dictionary or not integer(fields.get("field908"),65535) or not integer(fields.get("master"),4294967295):return result
		if int(fields.field908)!=1 or int(fields.master)!=int(actor_id):continue
		var label: Variant=name_of.call(object,id) if name_of.is_valid() else null
		result.associates.append({"id":id,"name":label,"lifetime":object.get("clientKnownLifetime")})
	result.known=true;return result
static func row(slot: int,icon: String,ref: Variant,callback: String,argument: int,label: Variant=null) -> Dictionary:
	return {"slot":slot,"icon":icon,"labelRef":ref,"label":label,"callback":callback,"low32":argument&4294967295,"disabled":false}
static func base() -> Array:
	var rows: Array=[]
	for source in BASE:
		var value:=row(int(source[0]),source[1],int(source[2]),"0x140998100",int(source[3]));value.binding={"type":42,"intParam":int(source[3])};rows.append(value)
	return rows
static func direct(index: int) -> Array:
	var rows: Array=[]
	for source in DIRECT:rows.append(row(int(source[0]),source[1],int(source[2]),"0x140995f10",((index&65535)<<16)|(int(source[3])&65535)))
	return rows
static func named(snapshot: Dictionary,associate: Dictionary,slot: int) -> Dictionary:
	var index: int=snapshot.rawIds.find(associate.id)
	return row(slot,"IR_GUARD",null,"0x14098f7d0",index,associate.name)
static func more() -> Dictionary:return row(7,"IR_GUARD",83611,"0x140992240",0)
static func root_plan(snapshot: Dictionary,mode: int,dm_executable: Variant=null) -> Dictionary:
	var result:={"rows":base(),"cursor":0,"available":false}
	# Executable identity is deliberately distinct from received DM permission.
	if mode==0 and (not dm_executable is bool or not dm_executable):return result
	if mode not in [0,1] or not snapshot.get("known",false):return result
	var associates: Array=snapshot.associates;result.available=true
	if associates.size()<2:
		var id: int=int(associates[0].id) if not associates.is_empty() else INVALID
		var index: int=snapshot.rawIds.find(id)
		if index>=0:result.rows.append_array(direct(index))
		result.cursor=associates.size();return result
	for index in 2:
		if not associates[index].name is String:result.available=false;result.rows=base();return result
		result.rows.append(named(snapshot,associates[index],index))
	result.cursor=2
	if associates.size()==3:
		if not associates[2].name is String:result.available=false;result.rows=base();return result
		result.rows.append(named(snapshot,associates[2],7));result.cursor=3
	else:result.rows.append(more()) # Includes the original empty More for count2.
	return result
static func more_plan(snapshot: Dictionary,cursor: int) -> Dictionary:
	var rows: Array=[];var associates: Array=snapshot.get("associates",[])
	if not snapshot.get("known",false) or cursor<0 or cursor>associates.size():return {"rows":rows,"cursor":cursor}
	var count:=mini(8,associates.size()-cursor)
	if associates.size()-cursor>8:count=7
	for slot in count:
		if not associates[cursor+slot].name is String:return {"rows":[],"cursor":cursor}
		rows.append(named(snapshot,associates[cursor+slot],slot))
	cursor+=count
	if cursor<associates.size():rows.append(more())
	return {"rows":rows,"cursor":cursor}
static func callback_binding(snapshot: Dictionary,argument: int) -> Dictionary:
	var index: int=(argument>>16)&65535
	if index&32768:index-=65536
	var command: int=argument&65535
	if command&32768:command-=65536
	var id: int=int(snapshot.actorId) if index==-1 else int(snapshot.rawIds[index]) if index>=0 and index<snapshot.rawIds.size() else INVALID
	return {"type":39,"intParam":command,"associateType":1,"associateId":id}
static func materialize(snapshot: Dictionary,plan: Dictionary) -> Array:
	var result: Array=[]
	for source in plan.rows:
		var value: Dictionary=source.duplicate(true)
		match str(value.callback):
			"0x140995f10":
				value.binding=callback_binding(snapshot,int(value.low32))
				var target: Variant=null
				for associate in snapshot.associates:
					if int(associate.id)==int(value.binding.associateId):target=associate;break
				value.associateLifetime=target.lifetime if target!=null else null
			"0x14098f7d0":value.children=materialize(snapshot,{"rows":direct(int(value.low32))})
			"0x140992240":value.children=materialize(snapshot,more_plan(snapshot,int(plan.cursor)))
		result.append(value)
	return result
static func selection_valid(captured: Dictionary,current: Dictionary,entry: Dictionary) -> bool:
	if not captured.get("known",false) or not current.get("known",false) or captured.actorId!=current.actorId or captured.revision!=current.revision or captured.rawIds!=current.rawIds:return false
	if int(entry.get("binding",{}).get("type",0))!=39:return true
	var binding: Dictionary=entry.binding;var id:=int(binding.associateId)
	if id==INVALID:return true # Explicit original sentinel result; no invented actor.
	if not integer(entry.get("associateLifetime")) or int(entry.associateLifetime)<=0:return false
	for associate in current.associates:
		if int(associate.id)==id:return associate.lifetime==entry.associateLifetime
	return false
