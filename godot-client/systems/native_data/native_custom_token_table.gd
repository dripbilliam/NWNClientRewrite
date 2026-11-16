extends RefCounted
# CTlkTable::SetCustomToken owns sorted byte records. Text conversion belongs at
# the presentation edge: Godot Strings cannot preserve an embedded NUL byte.
const TextEncoding=preload("res://systems/native_data/native_text_encoding.gd")

var records: Array[Dictionary]=[]
var revision: int=0

func apply(id: int,value: PackedByteArray)->bool:
	# The native setter receives a signed 32-bit ID. A negative ID is ignored;
	# the script-only 0..9 guard is not part of this table or server receive path.
	if id<0 or id>2147483647:return false
	var owned: PackedByteArray=PackedByteArray() if not value.is_empty() and value[0]==0 else value.duplicate()
	var at:=_index(id)
	if at<records.size() and int(records[at].id)==id:
		records[at]={"id":id,"bytes":owned}
	else:
		records.insert(at,{"id":id,"bytes":owned})
	revision+=1
	return true

func lookup_bytes(id: int)->Dictionary:
	if id<0 or id>2147483647:return {"found":false}
	var at:=_index(id)
	if at>=records.size() or int(records[at].id)!=id:return {"found":false}
	return {"found":true,"bytes":(records[at].bytes as PackedByteArray).duplicate()}

func project_ui(id: int,language: int=0)->Dictionary:
	var found:=lookup_bytes(id)
	if not found.found:return {"ready":false,"reason":"Custom token is unavailable."}
	var bytes: PackedByteArray=found.bytes
	if bytes.has(0):return {"ready":false,"reason":"Custom token contains an embedded NUL byte; use lookup_bytes for exact content."}
	var decoded: Dictionary=TextEncoding.decode(bytes,language)
	if not decoded.get("ready",false):return decoded
	return {"ready":true,"text":str(decoded.text),"revision":revision}

func snapshot()->Array[Dictionary]:
	var copy: Array[Dictionary]=[]
	for record in records:copy.append({"id":int(record.id),"bytes":(record.bytes as PackedByteArray).duplicate()})
	return copy

func reset()->void:
	records.clear()
	revision+=1

func _index(id: int)->int:
	var low:=0;var high:=records.size()
	while low<high:
		var middle: int=(low+high)>>1
		if int(records[middle].id)<id:low=middle+1
		else:high=middle
	return low
