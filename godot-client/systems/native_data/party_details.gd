extends RefCounted
# CPanelPartyMember8509c0/850330 initializes name/HP/area independently of
# the live creature.853430,853820 and8537f0 update only disclosed fields.
# Keep that small UI cache while a roster member is outside the current area.
const INVALID:=0x7f000000
var members: Dictionary={}
func reset() -> void: members.clear()
func observe(roster: Array,objects: Dictionary,text) -> void:
	var retained: Dictionary={}
	for id in roster:
		var target:=int(id)
		if target==INVALID: continue
		retained[target]=true
		if not members.has(target): members[target]={"name":"","current":0,"maximum":0,"area":INVALID}
		var member: Dictionary=members[target]; var object: Dictionary=objects.get(target,{})
		if int(object.get("objectType",0))!=5: continue
		var data: Dictionary=object.get("replicated",{})
		if data.has("name"): member.name=text.name(data.name,target)
		if data.has("areaId"): member.area=int(data.areaId)
		elif object.has("areaId"): member.area=int(object.areaId)
		var hp: Dictionary=data.get("hitPoints",{})
		if hp.has("current") and hp.has("maximum"):
			member.current=int(hp.current)+int(hp.get("fieldE8",0)); member.maximum=maxi(1,int(hp.maximum))
	for id in members.keys():
		if not retained.has(id): members.erase(id)
func tooltip(id: int,module: Dictionary) -> String:
	if not members.has(id): return ""
	var member: Dictionary=members[id]; var area:=""
	for row in module.get("areas",[]):
		if int(row.id)==int(member.area): area=str(row.get("name","")); break
	# Original879f10 does not replace unknown UI defaults with predicted health.
	return "%s %d/%d\n%s"%[member.name,member.current,member.maximum,area]
