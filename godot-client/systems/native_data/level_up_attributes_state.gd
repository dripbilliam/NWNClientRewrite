extends RefCounted
# CG_LEVUP_ATTRIB constructor8dc330 and its twelve callbacks. The draft owner
# applies/removes the one selected ability increase; this holds no live actor.
var selected:=-1
func reset(value: int=-1) -> void:selected=value if value>=0 and value<6 else -1
func points() -> int:return 1 if selected<0 else 0
func move(index: int,direction: int) -> bool:
	if index<0 or index>=6:return false
	if direction==1 and selected<0:selected=index;return true
	if direction==-1 and selected==index:selected=-1;return true
	return false
static func recommended_index(attribute: String) -> int:
	# Source uses exact case-sensitive four-byte comparisons including NUL.
	var bytes: PackedByteArray=attribute.to_ascii_buffer();bytes.append(0);bytes=bytes.slice(0,4)
	for pair in [["DEX",1],["INT",3],["CHA",5],["CON",2],["WIS",4]]:
		var compared: PackedByteArray=str(pair[0]).to_ascii_buffer();compared.append(0)
		if bytes==compared:return int(pair[1])
	return 0
func recommend(attribute: String,loaded: bool=true) -> void:
	# Original refunds an existing choice before attempting Packages load.
	selected=-1
	if loaded:selected=recommended_index(attribute)
func snapshot() -> Dictionary:return {"selected":selected,"points":points()}
