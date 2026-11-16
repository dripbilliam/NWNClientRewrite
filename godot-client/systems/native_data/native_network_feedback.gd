extends RefCounted
# Server combat reports. Decoding must never resolve attacks, damage, or spells
# locally: these are presentation data from original CC message sender 4cf090.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Area=preload("res://systems/native_data/native_area_state.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
const DAMAGE_COLOR=[60,99,255,102,1,62]
const SPELL_COLOR=[60,99,204,119,255,62]
const FEEDBACK_GROUPS=[
	[[1,24,49,110,112,115,116,148,149,182,183,222,242],[["int","integers",0]]],
	[[5,151],[["object","objects",0],["int","integers",0]]],
	[[13,31,32,34,35,36,37,38,39,40,41,42,43,44,46,48,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,154,155,156,157,158,159,202,203,234,235,241,254,257],[["object","objects",0]]],
	[[62,66,67,70,111],[["object","objects",0],["int","integers",0],["int","integers",1]]],
	[[63,64,68,69],[["object","objects",0],["int","integers",0]]],
	[[71,108,109,113,114],[["int","integers",0],["int","integers",1]]],
	[[161,162,164,165],[["object","objects",0],["string","strings",1],["int","integers",0],["int","integers",1]]],
	[[163],[["object","objects",0],["string","strings",1],["int","integers",0],["int","integers",1],["string","strings",2],["int","integers",2],["int","integers",3]]],
	[[204],[["string","strings",0]]]
]

static func accepted(major: int,minor: int)->bool:
	return major==18 and minor in [3,5,6,8,11,14]

static func decode_packet(packet: PackedByteArray,server_build: Dictionary={})->Dictionary:
	if packet.size()<8 or packet[0]!=80 or not accepted(int(packet[1]),int(packet[2])):
		return {"error":"Invalid native combat feedback envelope"}
	var minor:=int(packet[2])
	if minor in [3,11] and not valid_build(server_build):
		return {"error":"Native combat feedback server build is unavailable"}
	var reader:=Requirements.Reader.new()
	if not reader.configure(packet.slice(3)):
		return {"error":"Invalid native combat feedback stream: "+reader.error}
	var message: Dictionary={}
	match minor:
		3:message=damage(reader,server_build)
		5,6:message=attack(reader,minor)
		8:message=spell(reader)
		11:message=feedback(reader,server_build)
		14:message={"kind":"initiative-feedback","sourceId":reader.object_id(),"roll":reader.byte_bits(5),"modifier":reader.signed_byte()}
	message.major=18;message.minor=minor
	if message.has("error") or not reader.finished():
		return {"error":"Invalid native combat feedback fields: "+str(message.get("error",reader.error if not reader.error.is_empty() else "stream incomplete"))}
	return message

static func valid_build(build: Dictionary)->bool:
	for key in ["number","revision","postfix"]:
		var value: Variant=build.get(key)
		if not (value is int or value is float) or int(value)<0 or float(value)!=float(int(value)):return false
	return true

static func damage(reader: Requirements.Reader,build: Dictionary)->Dictionary:
	var source_id:=reader.object_id();var target_id:=reader.object_id()
	var slots:=32 if Area.at_least(build,35) else 13
	var values: Array[int]=[]
	for _index in range(slots):values.append(reader.word_bits(14) if reader.boolean() else -1)
	var debug: Variant=null
	if reader.boolean():debug=reader.string()
	return {"kind":"damage-feedback","sourceId":source_id,"targetId":target_id,"damage":values,"debug":debug}

static func attack(reader: Requirements.Reader,minor: int)->Dictionary:
	var message: Dictionary={"kind":"attack-feedback","minor":minor,"sourceId":reader.object_id(),"targetId":reader.object_id(),"modifier":reader.signed_byte(),"roll":reader.byte_bits(5),"result":reader.byte_bits(4)}
	message.attackType=reader.word_bits(16) if minor==6 else null
	message.combatMode=reader.byte_bits(4)
	message.offhand=int(reader.boolean());message.sneakAttack=int(reader.boolean());message.deathAttack=int(reader.boolean())
	message.specialMinus534=int(reader.boolean()) if minor==5 else 0
	message.coupDeGrace=int(reader.boolean()) if minor==5 else 0
	message.threatened=int(reader.boolean())
	message.confirmation=reader.byte_bits(5) if message.threatened else null
	message.concealmentChance=reader.byte_bits(7) if message.result in [8,9] else 0
	message.debug=reader.string() if reader.boolean() else null
	return message

static func spell(reader: Requirements.Reader)->Dictionary:
	var message: Dictionary={"kind":"spell-feedback","sourceId":reader.object_id(),"spellId":reader.dword(),"identified":int(reader.boolean()),"casting":int(reader.boolean()),"hasItem":int(reader.boolean()),"itemName":""}
	if message.hasItem:
		if message.identified:
			message.itemName=Characters.localized(reader) if reader.boolean() else {"text":reader.string()}
		else:message.baseItem=reader.byte()
	return message

static func feedback(reader: Requirements.Reader,build: Dictionary)->Dictionary:
	var type:=reader.word()
	var data: Dictionary={"integers":{},"objects":{},"strings":{}}
	if type in [4,47,50,51]:
		if type in [4,47]:data.objects["0"]=reader.object_id()
		if reader.boolean():
			data.strings["0"]=Characters.localized(reader) if reader.boolean() else {"text":reader.string()}
		else:data.strings["0"]={"baseItem":reader.dword() if Area.at_least(build,36,4) else reader.byte()}
	elif type in [93,94]:
		data.objects["0"]=reader.object_id()
		if type==93:data.integers["0"]=reader.signed_dword()
		else:data.strings["0"]={"text":reader.string()}
		data.integers["1" if type==93 else "0"]=int(reader.boolean()) if Area.at_least(build,36,1) else 1
	elif type==160:
		data.objects["0"]=reader.object_id()
		data.strings["0"]={"text":reader.string()}
		data.strings["1"]={"text":reader.string()}
		data.integers["0"]=reader.signed_dword()
		data.strings["2"]={"text":reader.string()} if Area.at_least(build,35) else {"text":""}
	else:
		for group in FEEDBACK_GROUPS:
			if type not in group[0]:continue
			for field in group[1]:
				var family: String=field[1];var slot: String=str(field[2])
				match field[0]:
					"object":data[family][slot]=reader.object_id()
					"int":data[family][slot]=reader.signed_dword()
					"string":data[family][slot]={"text":reader.string()}
			break
	var color: String=""
	if type in [62,63,64,66,67]:color=control_color(DAMAGE_COLOR)
	elif type in [68,69,70]:color=control_color(SPELL_COLOR)
	return {"kind":"combat-feedback","type":type,"data":data,"color":color}

static func control_color(codes: Array)->String:
	var result: String=""
	for code in codes:result+=String.chr(code)
	return result
