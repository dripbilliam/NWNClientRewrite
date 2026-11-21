extends RefCounted
# Fresh received 5/1 and 31/22 visibility frames. World and SceneVisibility
# retain canonical identity, tile state and the actual native setters.
const MAX_ID:=4294967295
var tile_serial:=0
var permission_serial:=0
var tile_unavailable:=0
var permission_unavailable:=0

static func integer(value: Variant,low: int,high: int)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high
static func flag(value: Variant)->bool:
	return value is bool or value is int and value in [0,1] or value is float and value in [0.0,1.0]
static func lifetime(row: Variant)->Array:
	var native: Variant=row.get("nativeLifetime") if row is Dictionary else null
	var known: Variant=row.get("clientKnownLifetime",row.get("disclosureLifetime")) if row is Dictionary else null
	return [["nativeLifetime",integer(native,0,MAX_ID),native if integer(native,0,MAX_ID) else null],["disclosureLifetime",integer(known,0,MAX_ID),known if integer(known,0,MAX_ID) else null]]
static func projected(world: RefCounted,actor: Dictionary)->Dictionary:
	var id: Variant=actor.get("id")
	var handle: Variant=world.disclosure_handles.get(int(id)) if integer(id,0,MAX_ID) else null
	return world.disclosures.transport_row(handle,actor)

func tile_frames(world: RefCounted,message: Dictionary,generation: int,connection: int)->Array:
	var output: Array=[]
	if message.get("kind")!="object-updates":return output
	for row in message.get("records",[]):
		if not row is Dictionary or row.get("action")!="player-state" or not row.get("state") is Dictionary or not row.state.has("automap"):continue
		if not integer(connection,0,MAX_ID) or not integer(generation,0,MAX_ID) or not integer(world.area_id,0,MAX_ID) or row.get("id")!=world.local_object_id:
			tile_unavailable+=1;continue
		var actor: Variant=world.registry.get(row.id)
		var change: Variant=row.state.automap
		if not actor is Dictionary or actor.get("replicationRemoved")==true or actor.get("areaId")!=world.area_id or not change is Dictionary or not change.get("mode") is Array or change.mode.size()!=2 or not flag(change.mode[0]) or not flag(change.mode[1]):
			tile_unavailable+=1;continue
		var detached: Dictionary={"mode":[bool(change.mode[0]),bool(change.mode[1])]}
		if bool(change.mode[1]):
			var packed_source: Variant=change.get("bytes")
			if not (packed_source is Array or packed_source is PackedByteArray) or packed_source.size()>255:
				tile_unavailable+=1;continue
			var bytes: Array=[]
			var packed_invalid:=false
			for value in packed_source:
				if not integer(value,0,255):packed_invalid=true;break
				bytes.append(int(value))
			if packed_invalid:tile_unavailable+=1;continue
			detached.bytes=bytes
		else:
			var point_source: Variant=change.get("points")
			if not point_source is Array or point_source.size()>131072:
				tile_unavailable+=1;continue
			var points: Array=[]
			var point_invalid:=false
			for point in point_source:
				if not point is Dictionary or not integer(point.get("x"),0,255) or not integer(point.get("y"),0,255) or not bool(change.mode[0]) and not flag(point.get("state")):
					point_invalid=true;break
				var copy: Dictionary={"x":int(point.x),"y":int(point.y)}
				if not bool(change.mode[0]):copy.state=bool(point.state)
				points.append(copy)
			if point_invalid:tile_unavailable+=1;continue
			detached.points=points
		var identity: Dictionary=projected(world,actor)
		if identity.get("id")!=actor.get("id"):
			tile_unavailable+=1;continue
		tile_serial+=1
		output.append({"kind":"raw-tile-visibility","connection":connection,"generation":generation,"areaId":world.area_id,"actorId":row.id,"lifetime":lifetime(identity),"serial":tile_serial,"change":detached})
	return output

func permission_frames(world: RefCounted,message: Dictionary,generation: int,connection: int)->Array:
	if message.get("kind")!="game-master-permission":return []
	if not integer(connection,0,MAX_ID) or not integer(generation,0,MAX_ID) or not integer(world.area_id,0,MAX_ID) or not integer(message.get("permission"),0,1) or not integer(message.get("field114"),0,1) or not integer(message.get("parameter"),-2147483648,2147483647):
		permission_unavailable+=1;return []
	var candidate: Variant=world.registry.get(world.local_object_id)
	var actor: Variant=candidate if candidate is Dictionary and candidate.get("objectType")==5 and candidate.get("replicationRemoved")!=true else null
	var identity: Variant=projected(world,actor) if actor is Dictionary else null
	var recipient_owner: Variant=world.clock_owner_transport(int(actor.id)) if actor is Dictionary else null
	var recipient_lifetime: Variant=null
	if actor is Dictionary:recipient_lifetime=lifetime(identity if identity is Dictionary and identity.get("id")==actor.get("id") else null)
	permission_serial+=1
	return [{"kind":"raw-creature-visibility-permission","connection":connection,"generation":generation,"areaId":world.area_id,"actorId":actor.id if actor is Dictionary else null,"lifetime":recipient_lifetime,"recipientOwner":recipient_owner.duplicate(true) if recipient_owner is Dictionary else null,"serial":permission_serial,"permission":bool(message.permission),"field114":bool(message.field114),"parameter":int(message.parameter),"source":"received_game_master_permission_31_22"}]
