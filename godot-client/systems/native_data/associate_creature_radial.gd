extends RefCounted
# Original98e340 / inline98e550 and98f8e0. This detached projection is not yet
# imported by Desktop: target Record must have a real displayed-character owner.
const Base=preload("res://systems/native_data/creature_radial.gd")
const ROOT_COMMANDS=[[5,"IR_GUARD",1474,-7],[4,"IR_STANDGROUND",1477,-2],[3,"IR_FOLLOW",682,-5],[2,"IR_ATTACKNEAREST",5345,-3],[0,"IR_HEALME",1483,-4]]
const HENCHMAN_COMMANDS=[[1,"IR_UNLOCK",1467,-18],[2,"IR_INVENTORY",3731,-19],[4,"IR_HAND_TRAP",1482,-20],[7,"IR_SEARCH",83411,-23],[5,"IR_SPELL",83327,-21],[6,"IR_STEALTH",83410,-22]]
var rules
var common:=Base.new()
func row(slot:int,icon:String,ref:int,action:String,extra:Dictionary={}) -> Dictionary:
	common.rules=rules;return common.row(slot,icon,ref,action,extra)
func branch(slot:int,icon:String,ref:int,kind:String,extra:Dictionary={}) -> Dictionary:
	common.rules=rules
	var value:=common.branch(slot,icon,ref,kind)
	value.menu.merge(extra,true)
	return value
func command_row(source:Array,target_id:int) -> Dictionary:
	return row(int(source[0]),str(source[1]),int(source[2]),"world-associate",{"targetId":target_id,"command":int(source[3]),"binding":{"type":39,"intParam":int(source[3]),"associateType":1,"associateId":target_id}})
func root_rows(associate_type:int,can_cast:bool,target_id:int) -> Array:
	var entries:Array=[]
	for source in ROOT_COMMANDS.slice(0,3):entries.append(command_row(source,target_id))
	entries.append(branch(6,"IR_XABILITY",949,"abilities"))
	for source in ROOT_COMMANDS.slice(3):entries.append(command_row(source,target_id))
	if can_cast:entries.append(branch(1,"IR_CAST",557,"spell-root"))
	entries.append(branch(7,"IR_ASSOC_ACTION",66848,"associate-actions",{"associateType":associate_type,"targetId":target_id}))
	return entries
func action_rows(associate_type:int,target_id:int) -> Array:
	# Normal997e00 opens the displayed target's Character Record for owned
	# types1..4. The caller must bind that owner, not substitute own/Examine UI.
	var entries:Array=[row(0,"IR_EXAMINE",549,"associate-record" if associate_type in [1,2,3,4] else "examine",{"targetId":target_id,"binding":{"type":40}})]
	match associate_type:
		1:
			# Kick997f30 directly sends -17; unlike995f10 it has no quickbar
			# assignment path. Do not invent a draggable type39 Kick shortcut.
			entries.append(row(3,"IR_KICK",1068,"world-associate",{"targetId":target_id,"command":-17}))
			for source in HENCHMAN_COMMANDS:entries.append(command_row(source,target_id))
		2:
			entries.append(command_row([3,"IR_UNSUMMON",1569,-9],target_id))
			entries.append(row(7,"IR_DIALOG",1072,"interact",{"interaction":"conversation.start","binding":{"type":6}}))
		3:
			entries.append(command_row([3,"IR_UNSUMMON",1569,-8],target_id))
			entries.append(row(2,"IFE_POSSESS",523,"power",{"binding":{"type":38}}))
		4:entries.append(command_row([3,"IR_UNSUMMON",1569,-10],target_id))
		5:entries.append(command_row([3,"IR_RELDOM",6393,-12],target_id))
	return entries
static func admission(controlled:Dictionary,clicked:Dictionary,context:Dictionary) -> Dictionary:
	var missing:Array=[]
	if not context.get("dmPermission") is bool or context.dmPermission:missing.append("normal-player.dmPermission")
	if controlled.get("objectType")!=5 or not Base.integer(controlled.get("id"),4294967295) or controlled.get("id")==Base.INVALID:missing.append("controlled.creature")
	if clicked.get("objectType")!=5 or not Base.integer(clicked.get("id"),4294967295) or clicked.get("id")==Base.INVALID:missing.append("clicked.creature")
	var source:Dictionary=clicked.get("replicated",{})
	if not Base.integer(source.get("master"),4294967295):missing.append("clicked.replicated.master")
	if not Base.integer(source.get("field908"),65535):missing.append("clicked.replicated.field908")
	if not Base.integer(controlled.get("playerState",{}).get("playerFlags"),4294967295):missing.append("controlled.playerState.playerFlags")
	if not missing.is_empty():return {"available":false,"owned":null,"missing":missing}
	return {"available":true,"owned":int(source.master)==int(controlled.id) and int(clicked.id)!=int(controlled.id),"missing":[]}
func project(controlled:Dictionary,clicked:Dictionary,context:Dictionary,actions:bool=false) -> Dictionary:
	var result:={"entries":[],"portrait":true,"available":false,"missing":[],"pending":[],"coverage":"normal-owned-associate-98e340" if not actions else "normal-owned-associate-actions-98f8e0"}
	var state:=admission(controlled,clicked,context)
	result.missing=state.missing
	if not state.available:return result
	if not state.owned:result.pending.append("not-current-controlled-associate");return result
	result.available=true
	var associate_type:=int(clicked.replicated.field908)
	result.entries=action_rows(associate_type,int(clicked.id)) if actions else root_rows(associate_type,(int(controlled.playerState.playerFlags)&1024)==0,int(clicked.id))
	return result
