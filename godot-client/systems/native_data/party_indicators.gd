extends RefCounted
# Original853720 selects PB_MBR_STATE;853980 moves one shared leader crest.
# Cache received role fields across area-only snapshots. A repeated snapshot is
# not another leadership event and must not move the crest back to an old row.
const INVALID=0x7f000000
var controlled:=INVALID
var leader:=INVALID
var seen: Dictionary={}
var states: Dictionary={}
var areas: Dictionary={}
static func flag(value: Variant) -> bool:
	return value if value is bool else value!=0 if value is int or value is float else false
static func state_clip(flags: int,mode: int) -> String:
	flags&=65535; mode&=255
	return "dead" if (flags&1)==0 else "combat" if mode in [2,14] else "resting" if mode==28 else "default"
static func leadership(old: int,actor: int,target: int,is_leader: Variant,singleton: Variant,member_exists: bool) -> Dictionary:
	var calls: Array=[]; var next:=old&0xffffffff
	target&=0xffffffff; actor&=0xffffffff
	if target==next and (not flag(is_leader) or flag(singleton)):
		calls.append(["remove"]); next=INVALID
	if flag(is_leader) and target!=next:
		var attachment:="self"
		if target!=actor or flag(singleton):
			calls.append(["lookup",target])
			if not member_exists: return {"leader":next,"result":0,"calls":calls}
			attachment="member"
		calls.append(["attach",attachment])
		return {"leader":target,"result":1,"calls":calls}
	return {"leader":next,"result":0,"calls":calls}
func reset() -> void: controlled=INVALID; leader=INVALID; seen.clear(); states.clear(); areas.clear()
func observe(actor: int,roster: Array,objects: Dictionary) -> void:
	if controlled!=actor: reset(); controlled=actor
	for id in seen.keys():
		if not roster.has(id): seen.erase(id)
	for id in states.keys():
		if not roster.has(id): states.erase(id)
	for id in areas.keys():
		if not roster.has(id): areas.erase(id)
	if leader!=actor and not roster.has(leader): leader=INVALID
	for raw_id in objects:
		var id:=int(raw_id)
		if not roster.has(id): continue
		var data: Dictionary=objects[raw_id].get("replicated",{})
		if data.has("areaId"): areas[id]=int(data.areaId)
		elif objects[raw_id].has("areaId"): areas[id]=int(objects[raw_id].areaId)
		if data.has("field8D4") and data.has("field8D6"): states[id]=state_clip(int(data.field8D4),int(data.field8D6))
		var party: Dictionary=data.get("party",{})
		if not party.has("leader") or not party.has("singleton"): continue
		var received:=[flag(party.leader),flag(party.singleton)]
		if seen.get(id)==received: continue
		seen[id]=received
		leader=int(leadership(leader,actor,id,received[0],received[1],id!=actor and roster.has(id)).leader)
func for_member(id: int) -> Dictionary:
	return {"leader":leader==id,"state":str(states.get(id,"")) if id!=controlled else "","area":int(areas.get(id,INVALID))}
