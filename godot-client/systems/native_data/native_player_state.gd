extends RefCounted
# Original WriteGameObjUpdate_PlayerUpdate inverse. These are server-owned
# controlled-creature deltas, never locally calculated combat or spell state.
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Area=preload("res://systems/native_data/native_area_state.gd")

static func bounded(reader: Requirements.Reader,count: int,minimum: int)->bool:
	return count>=0 and count<=int((reader.byte_size-reader.byte_cursor)/minimum)

static func level_counts(reader: Requirements.Reader)->Dictionary:
	var count:=reader.byte()
	if not bounded(reader,count,3):return {"error":"Invalid native player spell-class change count"}
	if count>8:return {"error":"Invalid native spell-class change count"}
	var changes: Array[Dictionary]=[]
	for _index in range(count):
		var position:=reader.byte();var mask:=reader.word()
		if position>=8 or (mask & ~1023)!=0:return {"error":"Invalid native spell-class level mask"}
		var levels: Array[Dictionary]=[]
		for level in range(10):
			if (mask & (1 << level))!=0:levels.append({"level":level,"count":reader.byte()})
		changes.append({"position":position,"levels":levels})
	return {"changes":changes}

static func effect_icons(reader: Requirements.Reader,build: Dictionary)->Dictionary:
	var wide:=Area.at_least(build,37,2)
	var removed_count:=reader.word() if wide else reader.byte()
	if not bounded(reader,removed_count,2 if wide else 1):return {"error":"Invalid native player removed effect-icon count"}
	var removed: Array[int]=[]
	for _index in range(removed_count):removed.append(reader.word() if wide else reader.byte())
	var added_count:=reader.word() if wide else reader.byte()
	if not bounded(reader,added_count,2 if wide else 1):return {"error":"Invalid native player added effect-icon count"}
	var added: Array[Dictionary]=[]
	for _index in range(added_count):added.append({"icon":reader.word() if wide else reader.byte(),"state":reader.boolean()})
	return {"removed":removed,"added":added}

static func decode(reader: Requirements.Reader,build: Dictionary,providers: Dictionary)->Dictionary:
	var id:=reader.dword();var mask:=reader.word();var state: Dictionary={}
	var record: Dictionary={"action":"player-state","objectType":5,"id":id,"mask":mask,"state":state}
	if (mask & 1)!=0:
		var combat: Dictionary={"armorClass":reader.short(),"field898":reader.dword(),"field978":reader.signed_dword(),"canLevelUp":reader.boolean()}
		state.combat=combat
		if combat.canLevelUp:
			var skill_count: Variant=providers.get("skillCount")
			if not skill_count is int or int(skill_count)<0 or int(skill_count)>255:return {"unhandled":"Native skill-count owner for level-up state is unavailable"}
			var field_dc6:=reader.word()
			if not bounded(reader,int(skill_count),1):return {"error":"Invalid native player level-up skill count"}
			var skills: Array[int]=[]
			for _index in range(skill_count):skills.append(reader.signed_byte())
			state.levelUp={"fieldDC6":field_dc6,"skills":skills,"fieldE34":reader.signed_dword(),"fieldE48":reader.string(),"fieldE30":reader.signed_dword(),"fieldE38":reader.string(),"fieldD4":reader.dword() if Area.at_least(build,36,4) else reader.byte(),"fieldC0":reader.byte()}
	if (mask & 2)!=0:state.skillFlags=reader.dword()
	if (mask & 8)!=0:state.playerFlags=reader.dword()
	if (mask & 0x8000)!=0:state.fields9E8=[reader.signed_dword(),reader.signed_dword(),reader.signed_dword()]
	if (mask & 128)!=0:
		var counts:=level_counts(reader)
		if counts.has("error"):return counts
		state.memorizedSlotCounts=counts.changes
	var class_slots:=8 if Area.at_least(build,35) else 3
	if (mask & 16)!=0:
		var changes: Array[Dictionary]=[]
		for position in range(class_slots):
			var removed_count:=reader.word()
			if not bounded(reader,removed_count,4):return {"error":"Invalid native player known spell removal count"}
			var removed: Array[int]=[]
			for _index in range(removed_count):removed.append(reader.dword())
			var added_count:=reader.word()
			if not bounded(reader,added_count,4):return {"error":"Invalid native player known spell addition count"}
			var added: Array[int]=[]
			for _index in range(added_count):added.append(reader.dword())
			changes.append({"position":position,"removed":removed,"added":added})
		state.knownSpellChanges=changes
	if (mask & 32)!=0:
		var changes: Array[Dictionary]=[]
		for position in range(class_slots):
			var removed_count:=reader.word()
			if not bounded(reader,removed_count,2):return {"error":"Invalid native player prepared-spell removal count"}
			var removed: Array[Dictionary]=[]
			for _index in range(removed_count):removed.append({"level":reader.byte(),"index":reader.byte()})
			var added_count:=reader.word()
			if not bounded(reader,added_count,7):return {"error":"Invalid native player prepared-spell addition count"}
			var added: Array[Dictionary]=[]
			for _index in range(added_count):added.append({"spell":reader.dword(),"index":reader.byte(),"level":reader.byte(),"ready":reader.boolean(),"domain":reader.boolean(),"metamagic":reader.byte()})
			changes.append({"position":position,"removed":removed,"added":added})
		state.memorizedSpellChanges=changes
	if (mask & 64)!=0:
		var counts:=level_counts(reader)
		if counts.has("error"):return counts
		state.spontaneousUses=counts.changes
	if (mask & 0x400)!=0:
		var icons:=effect_icons(reader,build)
		if icons.has("error"):return icons
		state.effectIcons=icons
	if (mask & 4)!=0:
		var count:=reader.word()
		if not bounded(reader,count,3):return {"error":"Invalid native player feat change count"}
		var changes: Array[Dictionary]=[]
		for _index in range(count):
			var action:=char(reader.signed_byte() & 255)
			if action not in ["A","B","D","X"]:return {"error":"Invalid native feat-change action"}
			changes.append({"action":action,"feat":reader.word()})
		state.featChanges=changes
		count=reader.word()
		if not bounded(reader,count,3):return {"error":"Invalid native player feat use count"}
		var uses: Array[Dictionary]=[]
		for _index in range(count):uses.append({"feat":reader.word(),"uses":reader.byte()})
		state.featUses=uses
	if (mask & 0x200)!=0:
		var mode: Array[bool]=[reader.boolean(),reader.boolean()]
		var map: Dictionary={"mode":mode}
		if mode[1]:
			var count:=reader.byte()
			if not bounded(reader,count,1):return {"error":"Invalid native player automap byte count"}
			var bytes: Array[int]=[]
			for _index in range(count):bytes.append(reader.byte())
			map.bytes=bytes
		else:
			var count:=reader.dword()
			if not bounded(reader,count,2):return {"error":"Invalid native player automap point count"}
			var points: Array[Dictionary]=[]
			for _index in range(count):points.append({"x":reader.byte(),"y":reader.byte()} if mode[0] else {"state":reader.boolean(),"x":reader.byte(),"y":reader.byte()})
			map.points=points
		state.automap=map
	if (mask & 256)!=0:
		var count:=reader.byte()
		if not bounded(reader,count,5):return {"error":"Invalid native player action-queue change count"}
		var changes: Array[Dictionary]=[]
		for _index in range(count):
			var action:=char(reader.signed_byte() & 255);var entry: Dictionary={"action":action,"type":reader.word(),"group":reader.word()}
			if action in ["S","U"]:entry.target=reader.dword()
			elif action=="A":
				if int(entry.type) not in [0,2]:entry.target=reader.dword()
				if int(entry.type) in [0,2,4,12,19]:entry.position=[reader.float32(),reader.float32(),reader.float32()]
				if int(entry.type) in [4,19]:entry.field5A4=reader.dword()
			elif action!="D":return {"error":"Invalid native action-queue change"}
			changes.append(entry)
		state.actionQueueChanges=changes
	if (mask & 0x2000)!=0:
		var count:=reader.dword()
		if not bounded(reader,count,4):return {"error":"Invalid native player visibility removal count"}
		var removed: Array[int]=[]
		for _index in range(count):removed.append(reader.dword())
		count=reader.dword()
		if not bounded(reader,count,4):return {"error":"Invalid native player visibility update count"}
		var updated: Array[Dictionary]=[]
		for _index in range(count):updated.append({"id":reader.dword(),"flags":[reader.boolean(),reader.boolean(),reader.boolean()]})
		state.visibilityChanges={"removed":removed,"updated":updated}
	if (mask & 0x800)!=0:
		if reader.boolean():
			var base: Array[int]=[];var current: Array[int]=[]
			for _index in range(6):base.append(reader.byte())
			for _index in range(6):current.append(reader.byte())
			state.abilities={"base":base,"current":current}
		else:state.abilities=null
	if (mask & 0x4000)!=0:
		var count:=reader.word()
		if not bounded(reader,count,3):return {"error":"Invalid native player special ability change count"}
		var changes: Array[Dictionary]=[]
		for _index in range(count):
			var action:=char(reader.byte());var entry: Dictionary={"action":action}
			if action=="S":entry.size=reader.word()
			elif action=="U":entry.index=reader.word();entry.state=reader.boolean();entry.level=reader.byte();entry.spell=reader.word()
			else:return {"error":"Invalid native special-ability change"}
			changes.append(entry)
		state.specialAbilityChanges=changes
	return record
