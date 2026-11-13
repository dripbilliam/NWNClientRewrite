extends RefCounted
# Original79d4f0 selects the received owner.857cd0 owns visible-window
# lifetime and its separate local container mode. No server item state mutates.
const INVALID:=2130706432
static func select(owner: int,controlled: int,objects: Dictionary,primary_available: bool=true,alternate_available: bool=true) -> Dictionary:
	if owner==INVALID or owner==controlled:return {"role":"primary","available":primary_available,"reply":{}}
	var creature: Dictionary=objects.get(owner,{})
	if creature.is_empty() or int(creature.get("objectType",0))!=5 or bool(creature.get("replicationRemoved",false)):
		return {"role":"alternate","available":false,"reply":{"open":false,"ownerId":owner}}
	return {"role":"alternate","available":alternate_available,"reply":{}}
static func transition(current: Dictionary,opened: bool,requested_owner: int,controlled: int,notify: bool=false,message_available: bool=true) -> Dictionary:
	for field in ["active","displayedOwner","containerMode","containerId","containerField","attached"]:
		if not current.has(field):return {"ready":false,"missing":field}
	for field in ["active","attached"]:
		if not current[field] is bool:return {"ready":false,"missing":field}
	for field in ["displayedOwner","containerMode","containerId","containerField"]:
		var value: Variant=current[field]
		if not (value is int or value is float) or not is_finite(float(value)) or floorf(float(value))!=float(value):return {"ready":false,"missing":field}
	var state:=current.duplicate(true);var events: Array=[]
	if not opened:
		if not bool(state.active):return {"ready":true,"changed":false,"state":state,"events":events}
		if int(state.containerMode)!=0:
			state.containerMode=0;state.containerField=0;state.containerId=INVALID
			events.append({"kind":"clearContainer"});events.append({"kind":"detachContainer"});events.append({"kind":"attachEquipment"})
			if message_available:events.append({"kind":"containerClose","targetId":0})
		state.active=false;events.append({"kind":"deactivate"})
	else:
		# Compare the raw requested ID first: INVALID is resolved only after
		# this original duplicate-open test, so INVALID can force a refresh.
		if bool(state.active) and int(state.displayedOwner)==requested_owner:return {"ready":true,"changed":false,"state":state,"events":events}
		if requested_owner==INVALID and controlled<0:return {"ready":false,"missing":"controlled"}
		if not bool(state.attached):events.append({"kind":"attach"})
		state.active=true;events.append({"kind":"forceVisible"});events.append({"kind":"hideConflicts"})
		state.displayedOwner=controlled if requested_owner==INVALID else requested_owner
		events.append({"kind":"refreshOwner","ownerId":state.displayedOwner})
	if notify and message_available:events.append({"kind":"statusRequest","open":1 if bool(state.active) else 0,"ownerId":state.displayedOwner})
	return {"ready":true,"changed":true,"state":state,"events":events}
