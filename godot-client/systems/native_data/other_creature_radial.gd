extends RefCounted
# Normal-world993790 only. Caller must supply verified dispatch/lookup owners;
# unavailable player metadata is never interpreted as an NPC. Desktop binds only
# verified normal world-origin targets with current disclosure lifetime tokens.
const Base=preload("res://systems/native_data/creature_radial.gd")
var rules
var common:=Base.new()
func row(slot:int,icon:String,ref:int,action:String,extra:Dictionary={}) -> Dictionary:
	common.rules=rules;return common.row(slot,icon,ref,action,extra)
func branch(slot:int,icon:String,ref:int,kind:String) -> Dictionary:
	common.rules=rules;return common.branch(slot,icon,ref,kind)
static func cast_visibility(controlled:Dictionary,target_id:int) -> Dictionary:
	var source:Variant=controlled.get("playerState",{}).get("visibility")
	if not source is Dictionary:return {"available":false,"value":null,"missing":["controlled.playerState.visibility"]}
	var flags:Variant=source.get(str(target_id),source.get(target_id))
	if flags==null:return {"available":true,"value":true,"matched":false,"missing":[]}
	if not flags is Array or flags.size()!=3 or not Base.boolean(flags[0]):return {"available":false,"value":null,"missing":["controlled.playerState.visibility.target.flags"]}
	return {"available":true,"value":bool(flags[0]),"matched":true,"missing":[]}
func project(controlled:Dictionary,clicked:Dictionary,context:Dictionary) -> Dictionary:
	var result:={"entries":[],"disabledSlots":[],"portrait":false,"missing":[],"pending":[],"coverage":"normal-other-creature-993790"}
	var entries:Array=result.entries;var missing:Array=result.missing
	if context.get("dmPermission")!=false:
		missing.append("normal-player.dmPermission");result.pending.append("dm-context");return result
	if not Base.integer(clicked.get("id"),4294967295):missing.append("clicked.id");return result
	entries.append(row(0,"IR_EXAMINE",549,"examine"))
	var cast:=branch(1,"IR_CAST",557,"spell-root")
	var visible:=cast_visibility(controlled,int(clicked.id))
	if visible.available:cast.disabled=not visible.value
	else:cast.disabled=true;cast.availability="unavailable";missing.append_array(visible.missing)
	entries.append(cast)
	var lookup:Variant=context.get("playerLookup")
	if not lookup is Dictionary or lookup.get("available")!=true or not lookup.get("isPlayer") is bool:
		missing.append("clicked.selected-character-player-lookup");return result
	var is_player:bool=lookup.isPlayer
	var source:Dictionary=clicked.get("replicated",{})
	if not Base.integer(source.get("field8D4"),65535):missing.append("clicked.replicated.field8D4");return result
	if is_player and int(source.field8D4)==0:return result
	result.portrait=true
	var combat:=Base.combat_action(controlled,clicked)
	if combat.available and not str(combat.action).is_empty():entries.append(row(2,str(combat.icon),int(combat.ref),str(combat.action)))
	else:missing.append_array(combat.missing)
	entries.append(branch(3,"IR_XATTACK",1055,"world-attacks"))
	entries.append(branch(6,"IR_XABILITY",949,"abilities"))
	var reaction:Variant=source.get("reaction")
	if not Base.integer(reaction,255):missing.append("clicked.replicated.reaction");return result
	if is_player and int(reaction)!=2:
		entries.append(row(7,"IR_BARTER",263,"barter"))
		result.pending.append("friendly-player-party-extras");return result
	var skills:Dictionary=context.get("skills",{})
	for skill in [13,0]:
		var admission:Variant=skills.get(str(skill),skills.get(skill))
		if not admission is Dictionary or admission.get("available")!=true or not admission.get("value") is bool:
			missing.append("controlled.native-skill-admission."+str(skill));continue
		if not admission.value:continue
		var value:=row(5 if skill==13 else 4,"isk_pocket" if skill==13 else "isk_aniemp",282 if skill==13 else 269,"world-skill",{"binding":{"type":3,"intParam":skill}})
		if skill==0:
			var racial_type:Variant=source.get("stats",{}).get("racialType")
			if Base.integer(racial_type,65535):value.disabled=int(racial_type) not in [8,9,19]
			else:value.disabled=true;value.availability="unavailable";missing.append("clicked.replicated.stats.racialType")
		entries.append(value)
	var loot:Variant=source.get("stats",{}).get("field4E8")
	if int(source.field8D4)==0:
		if not Base.boolean(loot):missing.append("clicked.replicated.stats.field4E8");return result
		if bool(loot):
			entries.append(row(7,"IR_USE",83575,"interact",{"interaction":"object.use"}))
			result.disabledSlots=[5,4,2]
			for value in entries:
				if int(value.slot) in [5,4,2]:value.disabled=true
			return result
	if int(reaction)!=2:entries.append(row(7,"IR_DIALOG",1072,"interact",{"interaction":"conversation.start"}))
	return result
