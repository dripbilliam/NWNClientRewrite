extends RefCounted
# Original normal-player world root98ec00 and emote creator994130. This owner
# projects received fields at an open/selection boundary; it holds no world copy.
# DM role4 remains separately scoped; normal party/familiar/shape use exact
# received predicates, with shape overriding an earlier normal role4.
const Quickbar=preload("res://systems/native_data/quickbar_radial.gd")
const INVALID:=0x7f000000
var rules
var common:=Quickbar.new()
func row(slot: int,icon: String,ref: int,action: String,extra: Dictionary={}) -> Dictionary:
	common.rules=rules
	return common.row(slot,icon,ref,action,extra)
func branch(slot: int,icon: String,ref: int,kind: String) -> Dictionary:
	common.rules=rules
	return common.branch(slot,icon,ref,kind)
static func integer(value: Variant,limit: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=0 and value<=limit
static func combat_action(controlled: Dictionary,clicked: Dictionary) -> Dictionary:
	var source: Dictionary=clicked.get("replicated",{})
	var current: Dictionary=controlled.get("replicated",{})
	var id: Variant=clicked.get("id")
	if not integer(id,4294967295):return {"available":false,"missing":["clicked.id"]}
	if not integer(source.get("field8D6"),255):return {"available":false,"missing":["clicked.replicated.field8D6"]}
	# Delta merge may retain field8D8 after leaving combat. Original781e80 resets
	# its corresponding native field unless the newly received mode is exactly2.
	if int(source.field8D6)==2:
		if not integer(source.get("field8D8"),4294967295):return {"available":false,"missing":["clicked.replicated.field8D8"]}
		if int(source.field8D8)==int(id):return {"available":true,"action":"world-disengage","icon":"IR_DISENGAGE","ref":1057,"missing":[]}
	if not integer(current.get("field8D4"),65535):return {"available":false,"missing":["controlled.replicated.field8D4"]}
	return {"available":true,"action":"world-attack" if int(current.field8D4)&128 else "","icon":"IR_ATTACK","ref":1056,"missing":[]}
static func boolean(value: Variant) -> bool:return value is bool or integer(value,1)
func self_role(controlled: Dictionary,context: Dictionary={}) -> Dictionary:
	var flags: Variant=controlled.get("playerState",{}).get("playerFlags")
	if not integer(flags,4294967295):return {"available":false,"missing":["controlled.playerState.playerFlags"],"entry":{}}
	# PlayerUpdate7b4f70 mask8 ->80a700/+408 bit10 and80abc0/+40c
	# bit17. This later source branch overrides party and familiar sector4.
	if (int(flags)&1024)!=0 and (int(flags)&131072)==0:return {"available":true,"missing":[],"entry":row(4,"IR_SKILLSELF",8272,"world-cancel-polymorph",{"binding":{"type":43,"intParam":-1}})}
	var source: Dictionary=controlled.get("replicated",{})
	if not integer(source.get("field908"),65535):return {"available":false,"missing":["controlled.replicated.field908"],"entry":{}}
	if integer(source.get("field908"),65535) and int(source.field908)==3:
		if not context.get("partyOwnerPresent") is bool:return {"available":false,"missing":["partyOwnerPresent"],"entry":{}}
		if context.partyOwnerPresent:return {"available":true,"missing":[],"entry":row(4,"IFE_UNPOSSESS",1566,"world-associate",{"command":-13,"targetId":int(controlled.id)})}
	var party: Variant=source.get("party")
	if not party is Dictionary:return {"available":false,"missing":["controlled.replicated.party"],"entry":{}}
	for key in ["player","field8D4Bit6","singleton","leader","field7DC"]:
		if not boolean(party.get(key)):return {"available":false,"missing":["controlled.replicated.party."+key],"entry":{}}
	var result: Dictionary={}
	if bool(party.player) and bool(party.field8D4Bit6):
		if bool(party.leader) and bool(party.field7DC):
			if not integer(party.get("field7D8"),4294967295) or int(party.field7D8)==INVALID:return {"available":false,"missing":["controlled.replicated.party.field7D8"],"entry":{}}
			if not party.has("firstName"):return {"available":false,"missing":["controlled.replicated.party.firstName"],"entry":{}}
			result=row(4,"IR_ACCEPT",6386,"world-party",{"operation":"accept","targetId":int(party.field7D8)})
			result.label+=" "+str(rules.text.raw(party.firstName))
		elif not bool(party.leader) or not bool(party.singleton):
			# Original997f30 leaves this visible entry inert for captured
			# associateType1; it does not send the player's Leave packet.
			result=row(4,"IR_LEAVE",1071,"none" if int(source.field908)==1 else "world-party",{"operation":"leave"})
	return {"available":true,"missing":[],"entry":result}
func normal_self(controlled: Dictionary,context: Dictionary={}) -> Dictionary:
	var entries: Array=[]
	var role:=self_role(controlled,context)
	if not role.entry.is_empty():entries.append(role.entry)
	var combat:=combat_action(controlled,controlled)
	if combat.available and not str(combat.action).is_empty():entries.append(row(2,str(combat.icon),int(combat.ref),str(combat.action)))
	entries.append(row(0,"IR_CHARSHEET",1059,"panel",{"panel":"character"}))
	entries.append(branch(1,"IR_CAST",557,"spell-root"))
	entries.append(branch(7,"IR_EMOTES",1025,"world-emotes"))
	entries.append(branch(3,"IR_XATTACK",1055,"world-attacks"))
	entries.append(branch(6,"IR_XABILITY",949,"abilities"))
	entries.append(branch(5,"IR_COMMAND",683,"world-commands"))
	return {"entries":entries,"coverage":"normal-player-self","missing":combat.missing+role.missing,"pending":["dm-role"]}
func commands() -> Array:
	common.rules=rules
	return common.commands()
func emotes(page: int,first_class: int,controlled: Dictionary) -> Array:
	common.rules=rules
	var result:=common.emotes(page,first_class)
	var value: Variant=controlled.get("replicated",{}).get("field8E0")
	var known:=integer(value,65535)
	for entry in result:
		if entry.has("menu"):
			entry.menu.kind="world-emotes-more" if page==0 else "world-emotes-last"
			# Original994130 leaves the first More entry enabled;991fe0 disables
			# its More entry as well. Assignment wheels deliberately differ.
			if page>0:entry.disabled=not known or (int(value)&16)!=0
		else:
			entry.action="world-emote"
			entry.disabled=not known or (int(value)&16)!=0
			entry.availability="received" if known else "unavailable"
	return result
