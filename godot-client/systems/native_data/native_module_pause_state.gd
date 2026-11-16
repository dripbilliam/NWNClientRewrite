extends RefCounted
# Admission adapter for original server 3/9. The process-owned
# ClientClockServices.receive_clock applies the native three-timer transition;
# this packet cannot certify that service's connection serial/history itself.
var connection: int=-1
var area_id: int=-1
var area_generation: int=-1
var delivery_order:=0
var last: Dictionary={}

func begin_connection(id: int,area: int,generation: int)->bool:
	if id<0 or area<0 or generation<0:return false
	connection=id;area_id=area;area_generation=generation;delivery_order=0;last={}
	return true

func set_area(area: int,generation: int)->bool:
	if connection<0 or area<0 or generation<=area_generation:return false
	area_id=area;area_generation=generation;last={}
	return true

func apply(message: Dictionary,source_connection: int,source_area: int,source_generation: int)->Dictionary:
	if connection<0 or source_connection!=connection or source_area!=area_id or source_generation!=area_generation:
		return {"accepted":false,"reason":"Stale module-pause connection or area."}
	if message.get("kind")!="module-pause-state" or message.get("major")!=3 or message.get("minor")!=9:
		return {"accepted":false,"reason":"Not a decoded native module-pause packet."}
	if not message.get("mask") is int or not message.get("value") is int or not message.get("exclusionIds") is Array:
		return {"accepted":false,"reason":"Incomplete native module-pause fields."}
	var mask: int=message.mask;var value: int=message.value
	if mask<0 or mask>3 or value<0 or value>1 or message.exclusionIds.size()>65535:
		return {"accepted":false,"reason":"Invalid native module-pause operands."}
	var exclusions: Array[int]=[]
	for id in message.exclusionIds:
		if not id is int or id<0 or id>4294967295:return {"accepted":false,"reason":"Invalid native pause exclusion ID."}
		exclusions.append(id)
	var current: Dictionary={"mask":mask,"value":value,"exclusionIds":exclusions}
	var duplicate:=current==last
	last={"mask":mask,"value":value,"exclusionIds":exclusions.duplicate()}
	delivery_order+=1
	# Do not skip duplicates: the original receiver still consumes every packet,
	# and the clock owner decides whether its native transition is a no-op.
	return {"accepted":true,"deliveryOrder":delivery_order,"duplicate":duplicate,"clockEvent":{"type":"module-pause-state","mask":mask,"value":value,"exclusionIds":exclusions},"scope":{"connection":connection,"areaId":area_id,"generation":area_generation}}

func reset()->void:
	connection=-1;area_id=-1;area_generation=-1;delivery_order=0;last={}

func snapshot()->Dictionary:
	return {"connection":connection,"areaId":area_id,"generation":area_generation,"deliveryOrder":delivery_order,"last":last.duplicate(true)}
