extends RefCounted
# Received action-queue changes are client GUI metadata. Widget serials are
# local presentation identities and are never transmitted to the server.
const INVALID:=0x7f000000
static func merge_network_action_queue(current: Array,changes: Array,next_serial: int) -> Dictionary:
	var entries: Array=current.duplicate(true)
	var target:=INVALID
	var position: Array=[0,0,0]
	for change in changes:
		var action: String=str(change.get("action",""))
		if action=="D":
			for index in entries.size():
				if int(entries[index].type)==int(change.type) and int(entries[index].group)==int(change.group):
					entries.remove_at(index)
					break
			continue
		if change.has("target"):target=int(change.target)
		if action=="U":continue
		if action!="A" and action!="S":return {"error":"Invalid native action-queue update"}
		if action=="A" and change.has("position") and change.position!=null:position=change.position.duplicate(true)
		var entry: Dictionary={"type":change.type,"group":change.group,"target":target,"position":[0,0,0] if action=="S" else position.duplicate(true),"special":action=="S","widgetSerial":next_serial}
		next_serial+=1
		if change.has("field5A4"):entry.spell=change.field5A4
		if action=="S":
			var special_count:=0
			for existing in entries:
				if bool(existing.get("special",false)):special_count+=1
			entries.insert(special_count,entry)
		else:entries.append(entry)
	return {"entries":entries,"nextSerial":next_serial}
