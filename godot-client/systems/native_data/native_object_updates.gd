extends RefCounted
# Original GameObjectUpdate/1. Unknown records stop at the last known boundary;
# this native stream has no record lengths that would permit guessing a skip.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const Area=preload("res://systems/native_data/native_area_state.gd")
const PlayerState=preload("res://systems/native_data/native_player_state.gd")
const InventoryStats=preload("res://systems/native_data/native_inventory_stats.gd")
class StagedState extends RefCounted:
	var states: Dictionary={}
	var external: Callable
	func get_state(id: int)->Variant:
		return states[id] if states.has(id) else external.call(id) if external.is_valid() else null

static func at_least(build: Dictionary,revision: int,postfix: int=0)->bool:
	return Area.at_least(build,revision,postfix)

static func vector(reader: Requirements.Reader)->Array[float]:
	return [reader.float32(),reader.float32(),reader.float32()]

static func raw_resref(reader: Requirements.Reader)->PackedByteArray:
	reader.expect_type(13)
	return reader.raw(16)

static func named(reader: Requirements.Reader)->Dictionary:
	return Characters.localized(reader) if reader.boolean() else {"text":reader.string()}

static func bounded(reader: Requirements.Reader,count: int,minimum: int)->bool:
	return count>=0 and count<=int((reader.byte_size-reader.byte_cursor)/minimum)

static func visual_leaf(reader: Requirements.Reader,build: Dictionary)->Dictionary:
	if at_least(build,35) and reader.boolean():return {"identity":true}
	var channels: Array[Dictionary]=[]
	for _index in range(10):
		var channel: Dictionary={"value":reader.float32()}
		if at_least(build,21):
			channel.type=reader.signed_dword();channel.duration=reader.signed_dword()
			if int(channel.duration)!=0:
				channel.target=reader.float32();channel.parameter=reader.float32();channel.progress=reader.float32()
				if at_least(build,35):channel.field18=reader.signed_dword();channel.field1c=reader.signed_dword()
		channels.append(channel)
	return {"channels":channels}

static func visual_transform(reader: Requirements.Reader,build: Dictionary)->Dictionary:
	if not at_least(build,35):return {"legacy":visual_leaf(reader,build)}
	var key_count:=reader.signed_dword()
	if not bounded(reader,key_count,4):return {"error":"Invalid native visual-transform keys"}
	var keys: Array[int]=[]
	for _index in range(key_count):keys.append(reader.signed_dword())
	var entry_count:=reader.signed_dword()
	if not bounded(reader,entry_count,4):return {"error":"Invalid native visual-transform entries"}
	var entries: Array[Dictionary]=[]
	for _index in range(entry_count):entries.append({"key":reader.signed_dword(),"value":visual_leaf(reader,build)})
	return {"keys":keys,"entries":entries}

static func item_appearance(reader: Requirements.Reader,build: Dictionary,providers: Dictionary)->Dictionary:
	var base_item:=reader.dword()
	var lookup: Callable=providers.get("baseItemModelType",Callable())
	if not lookup.is_valid():return {"unhandled":"Base-item model type %d is unavailable" % base_item}
	var model_value: Variant=lookup.call(base_item)
	if not model_value is int:return {"unhandled":"Base-item model type %d is unavailable" % base_item}
	var model:=int(model_value)
	var item: Dictionary={"baseItem":base_item,"modelType":model}
	if model in [0,1,2,3]:
		if model in [0,1,2]:
			var parts: Array[int]=[]
			for _index in range(3 if model==2 else 1):parts.append(reader.word() if at_least(build,35) else reader.byte())
			item.parts=parts
		else:
			var parts: Array[int]=[]
			for _index in range(19):parts.append(reader.word() if at_least(build,35) else reader.byte())
			item.parts=parts
		if model in [1,3]:
			var colors: Array[int]=[]
			for _index in range(6):colors.append(reader.byte())
			item.colors=colors
		if model==3:
			var part_colors: Array=[]
			for _index in range(19):
				var colors: Array[int]=[]
				for _channel in range(6):colors.append(reader.byte())
				part_colors.append(colors)
			item.partColors=part_colors
	if model==2:item.field462=reader.byte()
	item.visualTransform=visual_transform(reader,build)
	if item.visualTransform.has("error"):return item.visualTransform
	return item

static func active_item(reader: Requirements.Reader,build: Dictionary,providers: Dictionary)->Dictionary:
	var item: Dictionary=item_appearance(reader,build,providers)
	if item.has("error") or item.has("unhandled"):return item
	if int(item.baseItem)==16:item.field35c=reader.short()
	item.name=named(reader);item.identified=reader.boolean();item.cost=reader.dword()
	item.field454=reader.dword();item.canUse=reader.boolean();item.field458=reader.boolean()
	item.field450=reader.boolean();item.field468=reader.boolean()
	if at_least(build,36,2):item.field2b8=reader.signed_dword();item.field2c0=reader.string()
	var count:=reader.byte()
	if not bounded(reader,count,7):return {"error":"Invalid native active-item property count"}
	var properties: Array[Dictionary]=[]
	for _index in range(count):properties.append({"type":reader.word(),"subtype":reader.word(),"costValue":reader.word(),"field9":reader.byte()})
	item.properties=properties
	item.field350=reader.byte();item.reserved=reader.byte()
	var rest: Array=[]
	for index in range(8):rest.append(reader.byte() if (int(item.reserved) & (1 << index))!=0 else null)
	item.field351=rest
	return item

static func inventory_entry(reader: Requirements.Reader,build: Dictionary,providers: Dictionary)->Dictionary:
	var action:=char(reader.signed_byte() & 255);var entry: Dictionary={"action":action,"id":reader.object_id(),"slot":reader.dword()}
	if action=="A":entry.item=active_item(reader,build,providers)
	elif action=="U":entry.item={"field462":reader.byte(),"visualTransform":visual_transform(reader,build)}
	elif action!="D":return {"unhandled":"Inventory appearance action %s is unavailable" % action}
	if entry.has("item") and entry.item.has("visualTransform") and entry.item.visualTransform.has("error"):return entry.item.visualTransform
	if entry.has("item") and (entry.item.has("error") or entry.item.has("unhandled")):return entry.item
	return entry

static func creation(reader: Requirements.Reader,build: Dictionary,providers: Dictionary)->Dictionary:
	var object_type:=reader.byte();var id:=reader.object_id()
	var state: Dictionary={};var record: Dictionary={"action":"create","objectType":object_type,"id":id,"state":state}
	match object_type:
		5:
			state.position=vector(reader);state.orientation=vector(reader);state.animation=reader.word();state.visualTransform=visual_transform(reader,build)
		6:state.item=active_item(reader,build,providers)
		10:
			state.doorType=reader.dword()
			if int(state.doorType)==0:state.genericType=reader.dword()
			state.visualTransform=visual_transform(reader,build);state.name=named(reader);state.reaction=reader.boolean()
			state.animation=reader.word();state.field424=reader.boolean();state.field428=reader.boolean();state.fieldFC=reader.boolean();state.hasTransition=reader.boolean()
		11:state.field30c=reader.signed_dword();state.creator=reader.object_id()
		9:
			state.name=named(reader);state.field540=reader.byte();state.reaction=reader.boolean();state.appearance=reader.word();state.animation=reader.word()
			state.field514=reader.boolean()
			if state.field514:state.field510=reader.object_id()
			for key in ["fieldFC","field264","field3BC","field500","field378","field4FC","hasDescription","lightOn"]:state[key]=reader.boolean()
			state.visualTransform=visual_transform(reader,build)
		7:
			state.name=Characters.localized(reader);state.isTrap=reader.boolean();state.hasTransition=reader.boolean();state.displayType=reader.byte()
			if state.isTrap:state.reaction=reader.boolean()
			state.field40c=reader.float32()
			var count:=reader.byte()
			if not bounded(reader,count,12):return {"error":"Invalid native trigger vertices"}
			var vertices: Array=[]
			for _index in range(count):vertices.append(vector(reader))
			state.vertices=vertices
		_:return {"unhandled":"Object creation type %d is unavailable" % object_type}
	if state.has("visualTransform") and state.visualTransform.has("error"):return state.visualTransform
	if state.has("item") and (state.item.has("error") or state.item.has("unhandled")):return state.item
	return record

static func appearance(reader: Requirements.Reader,build: Dictionary,providers: Dictionary)->Dictionary:
	var object_type:=reader.byte();var id:=reader.object_id();var mask:=reader.word();var state: Dictionary={}
	if object_type!=5:return {"error":"Invalid native creature appearance type"}
	var record: Dictionary={"action":"appearance","objectType":object_type,"id":id,"mask":mask,"state":state}
	if (mask & 0x400)!=0:state.name={"firstName":Characters.localized(reader),"lastName":Characters.localized(reader)} if reader.boolean() else {"text":reader.string()}
	if (mask & 1)!=0:state.appearance=reader.word()
	if (mask & 2)!=0:state.phenotype=reader.byte()
	if (mask & 4)!=0:state.gender=reader.byte()
	if (mask & 128)!=0:state.head=reader.word() if at_least(build,35) else reader.byte()
	if (mask & 0x800)!=0:state.fieldAA4=reader.dword()
	if (mask & 0x1000)!=0:state.fieldAA8=reader.dword()
	for bit_and_name in [[8,"skin"],[16,"hair"],[32,"tattoo1"],[64,"tattoo2"]]:
		if (mask & int(bit_and_name[0]))!=0:state[bit_and_name[1]]=reader.byte()
	if (mask & 256)!=0:
		var count:=reader.byte();var parts: Array[Dictionary]=[]
		if count>19:return {"error":"Invalid native creature body-part count"}
		if count<10:
			for _index in range(count):
				var index:=reader.byte()
				if index>=19:return {"error":"Invalid native creature body-part index"}
				parts.append({"index":index,"value":reader.word() if at_least(build,35) else reader.byte()})
		else:
			for index in range(19):parts.append({"index":index,"value":reader.word() if at_least(build,35) else reader.byte()})
		state.bodyParts=parts
	if (mask & 0x2000)!=0:state.field8A0=reader.word();state.field8A4=reader.signed_dword()
	if (mask & 0x4000)!=0 and at_least(build,14):state.field8F0=reader.byte()
	if (mask & 512)!=0:
		var count:=reader.byte()
		if not bounded(reader,count,9):return {"error":"Invalid native equipment appearance count"}
		var equipment: Array[Dictionary]=[]
		for _index in range(count):
			var item: Dictionary=inventory_entry(reader,build,providers)
			if item.has("error") or item.has("unhandled"):return item
			equipment.append(item)
		state.equipment=equipment
	return record

static func update(reader: Requirements.Reader,build: Dictionary,providers: Dictionary)->Dictionary:
	var object_type:=reader.byte();var id:=reader.object_id();var mask:=reader.dword();var state: Dictionary={}
	var record: Dictionary={"action":"update","objectType":object_type,"id":id,"mask":mask,"state":state}
	if (mask & 1)!=0:state.position=[reader.float_scaled(100.0,16),reader.float_scaled(100.0,16),reader.float_range(-20.0,320.0,18)]
	if (mask & 2)!=0:
		state.orientation={"vector":[reader.float_range(-2.0,2.0,16),reader.float_range(-2.0,2.0,16),reader.float_range(-2.0,2.0,16)]} if reader.boolean() else {"yaw":reader.float_scaled(10.0,12)}
		if object_type==5:state.facingTarget=reader.object_id() if reader.boolean() else 0x7f000000
	if (mask & 0x100000)!=0:
		state.visualTransform=visual_transform(reader,build)
		if state.visualTransform.has("error"):return state.visualTransform
	if (mask & 0x200000)!=0:
		var count:=reader.word()
		if not bounded(reader,count,9):return {"error":"Invalid native shader uniform count"}
		var uniforms: Array[Dictionary]=[]
		for _index in range(count):
			var uniform: Dictionary={"type":reader.byte()}
			if int(uniform.type)==1:uniform.value=reader.signed_dword()
			elif int(uniform.type)==2:
				var value: Array[float]=[]
				for _component in range(4):value.append(reader.float32())
				uniform.value=value
			uniform.name=reader.string();uniform.selector=reader.string();uniforms.append(uniform)
		state.uniforms=uniforms
	if (mask & 32)!=0:
		state.portrait=reader.word()
		if int(state.portrait)>0xfffd:state.portraitRef=reader.resref()
	if (mask & 0x400000)!=0:
		var light: Dictionary={}
		if at_least(build,14):light.position=vector(reader);light.field260=reader.signed_dword()
		if at_least(build,35):light.field264=reader.boolean();light.field26c=reader.signed_dword();light.field270=reader.signed_dword();light.field278=reader.string()
		state.light=light
	for bit_and_name in [[0x800000,"materials"],[0x1000000,"textures"]]:
		var bit:=int(bit_and_name[0])
		if (mask & bit)!=0 and at_least(build,14 if bit==0x800000 else 35):
			var count:=reader.dword()
			if not bounded(reader,count,32):return {"error":"Invalid native material override count"}
			var pairs: Array=[]
			for _index in range(count):pairs.append([raw_resref(reader),raw_resref(reader)])
			state[bit_and_name[1]]=pairs
	if (mask & 4)!=0:
		state.animationTime=reader.float32();state.animation=reader.word()
		if object_type==5:
			if int(state.animation)==9:
				var count:=reader.byte_bits(2);var attacks: Array[Dictionary]=[]
				for _index in range(count):
					attacks.append({"target":reader.object_id(),"fieldA":reader.word(),"fieldC":reader.word(),"field2":reader.word(),"result":reader.byte_bits(4),"field7A":reader.word(),"damage":reader.word_bits(9),"field5C":reader.boolean(),"field68":reader.boolean(),"field56":reader.byte_bits(4)})
				state.attacks=attacks
			elif int(state.animation) in [15,16,17,18,19,20,61]:
				var cast: Dictionary={"spell":reader.dword(),"casterTarget":reader.object_id(),"silent":reader.boolean()}
				if int(state.animation) in [17,18,19,20,61]:
					cast.targetType=reader.byte()
					if int(cast.targetType)==1:cast.target=reader.object_id()
					elif int(cast.targetType)==2:cast.position=vector(reader)
					else:return {"error":"Invalid native casting target type"}
					cast.field220=reader.dword()
				state.cast=cast
	if (mask & 8)!=0:
		var count:=reader.word()
		if not bounded(reader,count,3):return {"error":"Invalid native looping visual-effect count"}
		var effects: Array[Dictionary]=[]
		var classify: Callable=providers.get("isBeam",Callable())
		for _index in range(count):
			var effect: Dictionary={"action":char(reader.byte()),"visualId":reader.word()}
			if not classify.is_valid():return {"unhandled":"Looping-effect beam classification %d is unavailable" % int(effect.visualId)}
			var beam: Variant=classify.call(int(effect.visualId))
			if not beam is bool:return {"unhandled":"Looping-effect beam classification %d is unavailable" % int(effect.visualId)}
			if beam:effect.target=reader.object_id();effect.field8=reader.byte()
			if at_least(build,14):
				effect.visualTransform=visual_transform(reader,build)
				if effect.visualTransform.has("error"):return effect.visualTransform
			effects.append(effect)
		state.visualEffects=effects
	if (mask & 16)!=0:
		if object_type==10:
			var flags: Array[bool]=[]
			for _index in range(6):flags.append(reader.boolean())
			state.interactionFlags=flags;state.field424=flags[2];state.field428=flags[3];state.hasTransition=flags[5]
		elif object_type==9:
			var flags: Array[bool]=[]
			for _index in range(5):flags.append(reader.boolean())
			state.interactionFlags=flags
		elif object_type==7:
			var lookup: Callable=providers.get("objectState",Callable())
			if not lookup.is_valid():return {"unhandled":"Trigger creation state is unavailable"}
			var base: Variant=lookup.call(id)
			if not (base is Dictionary) or not base.has("isTrap") or not (base.isTrap is bool):return {"unhandled":"Trigger creation state for update is unavailable"}
			var flags: Array[bool]=[]
			for _index in range(2 if bool(base.isTrap) else 1):flags.append(reader.boolean())
			state.interactionFlags=flags
	if (mask & 0x80000)!=0 and object_type in [6,9,10]:state.name=named(reader)
	if (mask & 64)!=0 and object_type==6:state.field468=reader.boolean()
	if object_type!=5:return record
	if (mask & 4)!=0:
		state.actionFlag=reader.byte();var count:=reader.word()
		if not bounded(reader,count,4):return {"error":"Invalid native creature path count"}
		var path: Array=[]
		if count>0:
			state.field8F4=reader.boolean()
			if state.field8F4:state.field8EC=reader.float32()
		for _index in range(count):path.append([reader.float_scaled(100.0,16),reader.float_scaled(100.0,16)])
		state.path=path
	if (mask & 64)!=0:
		state.field8D4=reader.word();state.field8D6=reader.byte();state.field8E0=reader.word();state.reaction=reader.byte();state.field700=reader.boolean()
		if int(state.field8D6)==2:state.field8D8=reader.object_id()
	if (mask & 256)!=0:state.walkRate=reader.float32();state.runRate=reader.float32()
	if (mask & 0x40000)!=0:state.areaId=reader.object_id()
	if (mask & 512)!=0:state.mapPosition=[reader.signed(10),reader.signed(10)]
	if (mask & 1024)!=0:state.hitPoints={"current":reader.short(),"fieldE4":reader.short(),"fieldE8":reader.short(),"maximum":reader.short()}
	if (mask & 0x10000)!=0:state.name={"firstName":Characters.localized(reader),"lastName":Characters.localized(reader)} if reader.boolean() else {"text":reader.string()}
	if (mask & 0x4000)!=0:
		var party: Dictionary={"player":reader.boolean(),"field8D4Bit6":reader.boolean(),"singleton":reader.boolean(),"leader":reader.boolean(),"field7DC":reader.boolean()}
		if party.field7DC:party.field7D8=reader.object_id();party.firstName=Characters.localized(reader);party.lastName=Characters.localized(reader)
		party.field8B4=reader.boolean();party.field8B0=reader.boolean();state.party=party
	if (mask & 0x8000)!=0:state.visibility=[reader.boolean(),reader.boolean(),reader.boolean()]
	if (mask & 0x20000)!=0:state.associateState=reader.word()
	if (mask & 0x800)!=0:state.damageLevel=reader.byte()
	if (mask & 0x1000)!=0:
		var stats: Dictionary={"fieldD20":reader.word(),"fieldD28":reader.string(),"fieldE58":reader.string(),"race":reader.byte(),"fieldDE4":reader.short(),"fieldDE6":reader.short(),"fieldF8":reader.boolean(),"field4E8":reader.boolean()}
		stats.racialType=stats.fieldD20
		var count:=reader.byte()
		if not bounded(reader,count,2):return {"error":"Invalid native creature class count"}
		var classes: Array[Dictionary]=[]
		var classify: Callable=providers.get("classInfo",Callable())
		for _index in range(count):
			var cls: Dictionary={"id":reader.byte(),"level":reader.byte()}
			if not classify.is_valid():return {"unhandled":"Creature class schema %d is unavailable" % int(cls.id)}
			var schema: Variant=classify.call(int(cls.id))
			if not schema is Dictionary:return {"unhandled":"Creature class schema %d is unavailable" % int(cls.id)}
			if bool(schema.get("pickSchool",false)):cls.school=reader.byte()
			if bool(schema.get("pickDomains",false)):cls.domains=[reader.byte(),reader.byte()]
			classes.append(cls)
		stats.classes=classes;state.stats=stats
	if (mask & 0x2000)!=0:
		state.master=reader.object_id();state.field908=reader.word();state.field910=reader.boolean();state.field914=reader.boolean()
		if at_least(build,31):state.takesCommands=reader.boolean()
	return record

static func gui_inventory(reader: Requirements.Reader,build: Dictionary,providers: Dictionary)->Dictionary:
	var channel:=char(reader.signed_byte() & 255)
	if channel=="S":return InventoryStats.decode(reader,build,providers)
	if channel=="Q":
		var count:=reader.byte()
		if not bounded(reader,count,9):return {"error":"Invalid native quickbar item-use count"}
		var entries: Array[Dictionary]=[]
		for _index in range(count):entries.append({"index":reader.byte(),"type":reader.byte(),"id":reader.object_id(),"propertyIndex":reader.byte(),"count":reader.word()})
		return {"action":"item-use-counts","entries":entries}
	if channel=="M":
		var operation:=char(reader.signed_byte() & 255);var entry: Dictionary={"action":"inventory","channel":channel,"operation":operation}
		if operation=="P":entry.pageCount=reader.byte();entry.panel=reader.byte();return entry
		if operation=="D":entry.id=reader.object_id();return entry
		if operation in ["A","U"]:
			entry.x=reader.byte();entry.y=reader.byte();entry.id=reader.object_id()
			if operation=="A":
				entry.item=active_item(reader,build,providers)
				if entry.item.has("error") or entry.item.has("unhandled"):return entry.item
			return entry
		return {"unhandled":"Inventory M/%s is unavailable" % operation}
	if channel not in ["R","r","A","B","C","c","I","i"]:return {"unhandled":"Inventory channel %s is unavailable" % channel}
	var operation:=char(reader.signed_byte() & 255);var entry: Dictionary={"action":"inventory","channel":channel,"operation":operation}
	var equipped:=channel in ["I","i"];var container:=channel in ["C","c"]
	if operation=="P" and container:entry.pageCount=reader.byte();return entry
	if operation=="U" and equipped:entry.state={"field28c":reader.signed_dword(),"field8c":reader.short(),"field70":reader.byte()};return entry
	if operation=="A":
		if equipped:entry.slot=reader.dword()
		else:entry.x=reader.byte();entry.y=reader.byte()
		entry.id=reader.object_id();entry.item=active_item(reader,build,providers)
		return entry.item if entry.item.has("error") or entry.item.has("unhandled") else entry
	if operation=="D":
		if equipped:entry.slot=reader.dword()
		else:entry.id=reader.object_id()
		return entry
	if operation=="U":entry.id=reader.object_id();entry.stackSize=reader.dword();entry.field280=reader.dword();return entry
	if operation=="M" and not equipped:entry.x=reader.byte();entry.y=reader.byte();entry.id=reader.object_id();return entry
	return {"unhandled":"Inventory %s/%s is unavailable" % [channel,operation]}

static func decode_packet(packet: PackedByteArray,build: Dictionary,providers: Dictionary)->Dictionary:
	if packet.size()<8 or packet[0]!=80 or packet[1]!=5 or packet[2]!=1:return {"error":"Not a native object-update message"}
	for field in ["number","revision","postfix"]:
		var value: Variant=build.get(field)
		if not (value is int or value is float and is_finite(value) and floor(value)==value):return {"error":"Native client build for object updates is unavailable"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):return {"error":reader.error}
	var staged:=StagedState.new();staged.external=providers.get("objectState",Callable())
	var scoped:=providers.duplicate();scoped.objectState=staged.get_state
	var records: Array[Dictionary]=[]
	while reader.byte_cursor<reader.byte_size:
		var cursor:=reader.byte_cursor;var fragment_cursor:=reader.fragment_cursor;var bit:=reader.bit_cursor
		var tag:=char(reader.signed_byte() & 255);var record: Dictionary={}
		match tag:
			"A":record=creation(reader,build,scoped)
			"P":record=appearance(reader,build,scoped)
			"U":record=update(reader,build,scoped)
			"I":record=PlayerState.decode(reader,build,scoped)
			"G":record=gui_inventory(reader,build,scoped)
			"D":
				record={"action":"delete","objectType":reader.byte(),"id":reader.object_id()}
				if int(record.objectType) in [5,6,9]:record.remove=reader.boolean()
			"W":record={"action":"work-remaining","completed":reader.byte(),"total":reader.byte()}
			_:
				return {"records":records,"complete":false,"unhandled":{"tag":tag,"reason":"Object update record "+tag+" is unavailable","cursor":cursor,"fragmentCursor":fragment_cursor,"bit":bit}}
		if record.has("unhandled"):
			return {"records":records,"complete":false,"unhandled":{"tag":tag,"reason":str(record.unhandled),"cursor":cursor,"fragmentCursor":fragment_cursor,"bit":bit}}
		if record.has("error"):return {"error":str(record.error),"objectUpdate":{"tag":tag,"cursor":cursor,"fragmentCursor":fragment_cursor,"bit":bit}}
		if not reader.error.is_empty():return {"error":reader.error,"objectUpdate":{"tag":tag,"cursor":cursor,"fragmentCursor":fragment_cursor,"bit":bit}}
		records.append(record)
		if record.has("state") and record.has("id"):
			var current: Variant=staged.get_state(int(record.id))
			var state: Dictionary=current.duplicate() if current is Dictionary else {}
			state.merge(record.state,true)
			staged.states[int(record.id)]=state
	if not reader.finished():return {"error":reader.error if not reader.error.is_empty() else "Native object-update stream is incomplete"}
	return {"records":records,"complete":true}
