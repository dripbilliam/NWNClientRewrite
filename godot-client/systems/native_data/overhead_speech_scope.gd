extends RefCounted
# Native presentation provenance only. Channel, duration, popup art and text
# rules belong to the original-backed speech policy, never to this boundary.
const MAX_SAFE:=9007199254740991
const MAX_ID:=4294967295
static func integer(value: Variant,minimum: int,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floorf(float(value))==float(value) and float(value)>=minimum and float(value)<=maximum
static func pending(reason: String) -> Dictionary:return {"ready":false,"pending":true,"reason":reason}
static func context(connection: Variant,generation: Variant,area: Variant) -> Dictionary:
	if not integer(connection,0,MAX_SAFE) or not integer(generation,0,MAX_SAFE) or not integer(area,0,MAX_ID):return pending("Current native speech scope is unavailable.")
	return {"ready":true,"connection":int(connection),"generation":int(generation),"areaId":int(area)}
static func current_context(value: Dictionary) -> bool:
	return value.get("ready",false)==true and integer(value.get("connection"),0,MAX_SAFE) and integer(value.get("generation"),0,MAX_SAFE) and integer(value.get("areaId"),0,MAX_ID)
static func valid_header(value: Variant) -> bool:
	# A captured-but-unknown area is explicit null. It may retain a log echo,
	# but must still carry the same complete transport identity as an anchor.
	if not value is Dictionary or not integer(value.get("version"),1,1) or not integer(value.get("serial"),1,MAX_SAFE):return false
	if not integer(value.get("connection"),0,MAX_SAFE) or not integer(value.get("generation"),0,MAX_SAFE) or not value.has("areaId") or not value.has("source"):return false
	if value.areaId!=null and not integer(value.areaId,0,MAX_ID):return false
	var source: Variant=value.source
	if source==null:return true
	if not source is Dictionary or not integer(source.get("id"),0,MAX_ID) or not integer(source.get("nativeLifetime"),1,MAX_SAFE) or not integer(source.get("knownLifetime"),1,MAX_SAFE):return false
	for key in ["areaId","objectType"]:
		if not source.has(key) or source[key]!=null and not integer(source[key],1 if key=="objectType" else 0,MAX_ID):return false
	return true
static func event(message: Dictionary,current: Dictionary) -> Dictionary:
	if not current_context(current):return pending("Current native speech scope is unavailable.")
	var value: Variant=message.get("nativeTextEvent")
	if not valid_header(value):return {"ready":false,"reason":"Native speech event provenance is malformed."}
	for key in ["connection","generation"]:
		if not integer(value.get(key),0,MAX_SAFE) or int(value[key])!=int(current[key]):return {"ready":false,"retired":true,"reason":"Native speech event belongs to a retired scope."}
	if value.get("areaId")==null:return pending("Native speech event area is not yet known.")
	if not integer(value.areaId,0,MAX_ID) or int(value.areaId)!=int(current.areaId):return {"ready":false,"retired":true,"reason":"Native speech event belongs to another area."}
	if not value.has("source"):return {"ready":false,"reason":"Native speech source provenance is absent."}
	var source: Variant=value.source
	var scope: Array=[int(current.connection),int(current.generation),int(current.areaId)]
	if source==null:return {"ready":true,"anchor":false,"serial":int(value.serial),"scope":scope,"source":null}
	if not source is Dictionary or not integer(source.get("id"),0,MAX_ID) or not integer(source.get("nativeLifetime"),1,MAX_SAFE) or not integer(source.get("knownLifetime"),1,MAX_SAFE):return {"ready":false,"reason":"Native speech source identity is malformed."}
	for key in ["areaId","objectType"]:
		if not source.has(key):return {"ready":false,"reason":"Native speech source metadata is incomplete."}
		if source[key]!=null and not integer(source[key],1 if key=="objectType" else 0,MAX_ID):return {"ready":false,"reason":"Native speech source metadata is malformed."}
	if source.areaId!=null and int(source.areaId)!=int(current.areaId):return {"ready":false,"retired":true,"reason":"Native speech source belongs to another area."}
	var projected:={"id":int(source.id),"objectType":int(source.objectType) if source.objectType!=null else null,"areaId":int(source.areaId) if source.areaId!=null else null,"nativeLifetime":int(source.nativeLifetime),"knownLifetime":int(source.knownLifetime)}
	return {"ready":true,"anchor":true,"serial":int(value.serial),"scope":scope,"source":projected,"witness":[int(source.id),int(source.nativeLifetime),int(source.knownLifetime)]}
static func received_source(value: Dictionary,row: Dictionary,current: Dictionary,existing_visual: bool=false) -> Dictionary:
	if not value.get("ready",false) or not value.get("anchor",false) or not value.get("source") is Dictionary or not current_context(current):return pending("Native speech has no current anchor witness.")
	if value.get("scope")!=[int(current.connection),int(current.generation),int(current.areaId)]:return {"ready":false,"retired":true,"reason":"Retired native speech presentation scope."}
	if row.is_empty():return pending("Native speech is waiting for its received speaker.")
	var source: Dictionary=value.source
	for pair in [["id","id"],["nativeLifetime","nativeLifetime"],["knownLifetime","clientKnownLifetime"]]:
		if not integer(row.get(pair[1]),0 if pair[0]=="id" else 1,MAX_ID if pair[0]=="id" else MAX_SAFE):return pending("Native speech speaker identity is not disclosed.")
		if int(row[pair[1]])!=int(source[pair[0]]):return {"ready":false,"mismatch":true,"reason":"Native speech is waiting for its exact speaker lifetime."}
	# Delete+104 blocks NEW speech. An already-bound popup can keep ticking on
	# the same fading visual; its anchor owner decides when that visual ends.
	if row.get("destroyed",false) or row.get("replicationRemoved",false) and not existing_visual:return {"ready":false,"retired":true,"reason":"Native speech speaker is removed."}
	if not integer(row.get("areaId"),0,MAX_ID) or not integer(row.get("objectType"),1,MAX_ID):return pending("Native speech speaker placement/type is not disclosed.")
	if int(row.areaId)!=int(current.areaId) or source.areaId!=null and int(row.areaId)!=int(source.areaId):return {"ready":false,"retired":true,"reason":"Native speech speaker left its area."}
	if source.objectType!=null and int(row.objectType)!=int(source.objectType):return {"ready":false,"retired":true,"reason":"Native speech speaker type changed."}
	return {"ready":true,"id":int(source.id),"objectType":int(row.objectType),"areaId":int(row.areaId),"witness":value.witness.duplicate(),"scope":value.scope.duplicate()}
static func localized_context(message: Dictionary,current: Dictionary) -> Dictionary:
	var metadata: Variant=message.get("nativeTextEvent")
	if not metadata is Dictionary or not metadata.get("context") is Dictionary:return pending("Native speech token context witness is unavailable.")
	if not integer(message.get("contextId"),0,MAX_ID):return {"ready":false,"reason":"Native speech token context ID is malformed."}
	var projected:=event({"nativeTextEvent":{"version":metadata.get("version"),"serial":metadata.get("serial"),"connection":metadata.get("connection"),"generation":metadata.get("generation"),"areaId":metadata.get("areaId"),"source":metadata.context}},current)
	if not projected.get("ready",false) or not projected.get("anchor",false):return projected
	if int(projected.source.id)!=int(message.contextId):return {"ready":false,"reason":"Native speech token context witness does not match its ID."}
	return projected
