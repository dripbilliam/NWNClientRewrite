extends RefCounted
# Local request/presentation correlation only. The Session and original server
# still own transaction validation, packets and received character state.
const MAX_EXACT=9007199254740991
const CONTEXT=["generation","areaId","actorId","nativeLifetime","knownLifetime"]
const FIELDS=["version","owner","entry","request","generation","areaId","actorId","nativeLifetime","knownLifetime","operation","token"]
var _owner:="level-up:"+str(get_instance_id())
var _serial:=0
var _entry: Dictionary={}
var _pending: Dictionary={}
static func integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high
static func context(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()!=CONTEXT.size():return {}
	var result: Dictionary={}
	for key in CONTEXT:
		var low:=1 if key in ["nativeLifetime","knownLifetime"] else 0
		var high:=4294967295 if key in ["areaId","actorId"] else MAX_EXACT
		if not integer(value.get(key),low,high):return {}
		result[key]=int(value[key])
	return result
static func metadata(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size()!=FIELDS.size():return {}
	for key in FIELDS:
		if not value.has(key):return {}
	if not value.owner is String or value.owner.is_empty() or value.owner.length()>128:return {}
	for index in value.owner.length():
		var character: int=value.owner.unicode_at(index)
		if character<32 or character>126:return {}
	if not integer(value.version,1,1) or not integer(value.entry,0,MAX_EXACT) or not integer(value.request,1,MAX_EXACT) or not value.operation is String or value.operation not in ["begin","submit","cancel"]:return {}
	var low: int=0 if value.operation=="submit" else -1
	var high: int=-1 if value.operation=="begin" else MAX_EXACT
	if not integer(value.token,low,high):return {}
	var scoped: Dictionary={}
	for key in CONTEXT:scoped[key]=value[key]
	var result:=context(scoped)
	if result.is_empty():return {}
	result.merge({"version":1,"owner":value.owner,"entry":int(value.entry),"request":int(value.request),"operation":value.operation,"token":int(value.token)})
	return result
func open(value: Dictionary,entry: int) -> bool:
	retire()
	var scoped:=context(value)
	if scoped.is_empty() or not integer(entry,0,MAX_EXACT):return false
	_entry=scoped;_entry.owner=_owner;_entry.entry=entry;return true
func issue(operation: String,token: int) -> Dictionary:
	if _entry.is_empty() or _serial>=MAX_EXACT:return {"ready":false}
	for pending in _pending.values():
		if pending.operation==operation:return {"ready":false}
	var value:=_entry.duplicate();value.merge({"version":1,"request":_serial+1,"operation":operation,"token":token})
	value=metadata(value)
	if value.is_empty():return {"ready":false}
	_serial+=1;_pending[_serial]=value.duplicate()
	return {"ready":true,"value":value.duplicate()}
func current(value: Dictionary,entry: int) -> bool:
	var scoped:=context(value)
	if scoped.is_empty() or _entry.is_empty() or not integer(entry,0,MAX_EXACT) or _entry.entry!=entry:return false
	for key in CONTEXT:
		if scoped[key]!=_entry[key]:return false
	return true
func consume(value: Variant,scope: Dictionary,entry: int,operation: String) -> bool:
	var reply:=metadata(value)
	if reply.is_empty() or not current(scope,entry) or reply.operation!=operation:return false
	var request: int=int(reply.request)
	if not _pending.has(request) or reply!=_pending[request]:return false
	_pending.erase(request);return true
func pending_count() -> int:return _pending.size()
func is_open() -> bool:return not _entry.is_empty()
func retire() -> void:
	_entry={};_pending={}
