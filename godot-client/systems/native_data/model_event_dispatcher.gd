extends RefCounted

# Per-model Gob event listeners. Registration order is reversed at delivery.
var owner: Variant
var listeners: Array=[]
var handles: Array=[]
var capacity:=0
var failure:=""

func _init(value: Variant=null) -> void:
	owner=value

static func ascii_lower(value: Variant) -> String:
	var text:=str(value)
	for byte in text.to_utf8_buffer():
		if byte>127:return ""
	return text.to_lower()

func add(pattern: String,callback: Callable,data: Variant=null) -> Dictionary:
	var record:={"pattern":pattern,"callback":callback,"data":data}
	listeners.append(record)
	return record

func remove(record: Dictionary) -> void:
	var index:=listeners.find(record)
	if index>=0:listeners.remove_at(index)

func _matches(pattern: String,name: String) -> bool:
	if pattern.is_empty() or pattern.begins_with("*"):return true
	var lower_pattern:=ascii_lower(pattern)
	var lower_name:=ascii_lower(name)
	if lower_pattern.is_empty() and not pattern.is_empty() or lower_name.is_empty() and not name.is_empty():
		failure="Native model event locale comparison is unavailable"
		return false
	return lower_pattern==lower_name

func accepts(name: String) -> bool:
	failure=""
	for listener in listeners:
		if _matches(str(listener.pattern),name):return true
		if not failure.is_empty():return false
	return false

func dispatch(name: String,data: Variant=null) -> int:
	failure=""
	var index:=listeners.size()-1
	if handles.size()==capacity:capacity=16 if capacity==0 else capacity*2
	var frame:={"owner":owner,"index":handles.size()}
	handles.append(frame)
	var delivered:=0
	while frame.owner!=null and index>=0:
		if index>=listeners.size():
			failure="Native model listener removal during dispatch is unavailable"
			break
		var listener: Dictionary=listeners[index]
		index-=1
		var accepted:=_matches(str(listener.pattern),name)
		if not failure.is_empty():break
		if accepted:
			listener.callback.call(frame.owner,name,data if data!=null else listener.data)
			delivered+=1
			if not failure.is_empty():break
	if frame.owner!=null and int(frame.index)>=0 and int(frame.index)<handles.size():
		var at:=int(frame.index)
		handles[at]=handles.back()
		handles.pop_back()
		if at<handles.size():handles[at].index=at
	return -1 if not failure.is_empty() else delivered

func destroy() -> void:
	for frame in handles:frame.owner=null
	handles.clear()
	owner=null
