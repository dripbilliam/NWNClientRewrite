extends RefCounted
# Original Client7b2740 replicated character-sheet fields in G/S.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Area=preload("res://systems/native_data/native_area_state.gd")

static func bounded(reader: Requirements.Reader,count: int,minimum: int=1)->bool:
	return count>=0 and count<=int((reader.byte_size-reader.byte_cursor)/minimum)

static func combat_node(reader: Requirements.Reader,build: Dictionary,second: bool)->Dictionary:
	var node: Dictionary={"field0":reader.signed_byte()}
	if second:node.field1=reader.byte_bits(5 if Area.at_least(build,35) else 4)
	node.field2=reader.byte_bits(3)
	node.field5=reader.byte() if reader.boolean() else 28
	node.field3=reader.byte_bits(2) if reader.boolean() else 0
	node.field4=reader.byte_bits(3) if reader.boolean() else 0
	return node

static func decode(reader: Requirements.Reader,build: Dictionary,providers: Dictionary)->Dictionary:
	var id:=reader.object_id();var mask:=reader.dword();var state: Dictionary={}
	var record: Dictionary={"action":"inventory-stats","id":id,"objectType":5,"mask":mask,"state":state}
	if (mask & 1)!=0:
		var values: Array[int]=[];var modifiers: Array[int]=[];var savings: Array[int]=[]
		for _index in range(6):values.append(reader.byte())
		for _index in range(6):modifiers.append(reader.signed_byte())
		for _index in range(7):savings.append(reader.signed_byte())
		state.fields70=values;state.fields7d=modifiers;state.fields76=savings
	for bit_and_name in [[2,"field98"],[4,"field99"],[8,"field9a"],[0x2000,"field9c"],[0x4000,"field9d"],[0x8000,"field9e"]]:
		if (mask & int(bit_and_name[0]))!=0:state[bit_and_name[1]]=reader.signed_byte()
	if (mask & 16)!=0:state.field94=reader.dword()
	if (mask & 32)!=0:state.field9b=reader.byte();state.fielda0=reader.boolean()
	if (mask & 64)!=0:
		var combat: Dictionary={"field0":reader.byte_bits(3),"field1":reader.signed_byte(),"field2":reader.signed_byte(),"field5":reader.signed_byte(),"field6":reader.byte_bits(7),"field7":reader.byte_bits(5),"field8":reader.byte_bits(5),"field9":reader.byte_bits(5)}
		var triplets: Array=[]
		for _index in range(3):triplets.append([reader.byte_bits(5),reader.byte_bits(5),reader.signed_byte()])
		combat.triplets=triplets;combat.field13=reader.byte_bits(4);combat.field14=reader.byte_bits(3);combat.field18=reader.boolean()
		if combat.field18:combat.field3=reader.signed_byte();combat.field4=reader.signed_byte();combat.field1c=reader.byte_bits(4);combat.field1d=reader.byte_bits(3)
		var count:=reader.byte()
		if not bounded(reader,count):return {"error":"Invalid native combat information group0 count"}
		var first: Array[Dictionary]=[]
		for _index in range(count):first.append(combat_node(reader,build,false))
		count=reader.byte()
		if not bounded(reader,count):return {"error":"Invalid native combat information group1 count"}
		var second: Array[Dictionary]=[]
		for _index in range(count):second.append(combat_node(reader,build,true))
		combat.group0=first;combat.group1=second;state.combatInformation=combat
	if (mask & 0x400)!=0:state.field8c=reader.short()
	if (mask & 0x800)!=0:state.field88=reader.short();state.field8a=reader.short()
	if (mask & 128)!=0:
		var skill_count: Variant=providers.get("skillCount")
		if not skill_count is int or int(skill_count)<0 or int(skill_count)>32:return {"error":"Inventory skill schema is unavailable"}
		var bits:=reader.dword_bits(skill_count);var skills: Array[Dictionary]=[]
		for index in range(skill_count):
			if (bits & (1 << (index & 31)))!=0:skills.append({"index":index,"value":reader.signed_byte(),"flag":reader.boolean()})
		state.skills=skills
	if (mask & 256)!=0:
		var wide:=Area.at_least(build,37,2)
		var count:=reader.word() if wide else reader.byte()
		if not bounded(reader,count,2 if wide else 1):return {"error":"Invalid native removed-feat count"}
		var removed: Array[int]=[]
		for _index in range(count):removed.append(reader.word() if wide else reader.byte())
		count=reader.word() if wide else reader.byte()
		if not bounded(reader,count,2 if wide else 1):return {"error":"Invalid native added-feat count"}
		var added: Array[Dictionary]=[]
		for _index in range(count):added.append({"id":reader.word() if wide else reader.byte(),"flag":reader.boolean()})
		state.featsRemoved=removed;state.featsAdded=added
	if (mask & 512)!=0:
		var count:=reader.word()
		if not bounded(reader,count,2):return {"error":"Invalid native field118 count"}
		var first: Array[int]=[]
		for _index in range(count):first.append(reader.word())
		count=reader.word()
		if not bounded(reader,count,2):return {"error":"Invalid native field128 count"}
		var second: Array[int]=[]
		for _index in range(count):second.append(reader.word())
		state.fields118=first;state.fields128=second
	if (mask & 0x1000)!=0:
		var count:=reader.byte()
		if not bounded(reader,count):return {"error":"Invalid native class-field count"}
		var fields: Array[int]=[]
		for _index in range(count):fields.append(reader.byte())
		state.fieldsClass=fields
	return record
