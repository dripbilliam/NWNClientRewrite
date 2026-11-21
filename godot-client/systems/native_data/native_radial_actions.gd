extends RefCounted
# Direct DTO translation of the retired network radial-action tree. Leaves
# unsupported actions present so selection can diagnose their real owner.
static func entry(slot: int,label: String,icon: String,action: Variant,extra: Dictionary={}) -> Dictionary:
	var result: Dictionary={"slot":slot,"label":label,"icon":icon,"action":action}
	result.merge(extra,true)
	return result
static func menu(title: String,entries: Array) -> Dictionary:return {"title":title,"entries":entries}
static func placeholder(slot: int,label: String,icon: String,action: String,system: String,extra: Dictionary={}) -> Dictionary:
	var fields: Dictionary={"system":system};fields.merge(extra,true)
	return entry(slot,label,icon,action,fields)
static func associate_command(slot: int,label: String,icon: String,command: int) -> Dictionary:
	return placeholder(slot,label,icon,"associate.command","associate command dispatch",{"command":command})
static func choices(title: String,values: Array,fallback: Dictionary,system: String) -> Dictionary:
	if values.is_empty():return menu(title,[placeholder(0,"Select "+title.to_lower(),str(fallback.icon),str(fallback.action),system)])
	var entries: Array=[]
	for slot in mini(values.size(),7):
		var value: Dictionary=values[slot]
		var icon: Variant=value.get("icon")
		var action: Variant=value.get("action")
		entries.append(placeholder(slot,str(value.get("label","")),str(fallback.icon if icon==null else icon),str(fallback.action if action==null else action),system))
	if values.size()>7:
		var remaining: Array=values.slice(7)
		entries.append(entry(7,"More…","IR_XABILITY",null,{"children":func():return choices(title,remaining,fallback,system)}))
	return menu(title,entries)
static func branch(slot: int,label: String,icon: String,children: Callable,extra: Dictionary={}) -> Dictionary:
	var fields: Dictionary={"children":children};fields.merge(extra,true)
	return entry(slot,label,icon,null,fields)
static func cast(actor: Dictionary,options: Dictionary) -> Dictionary:
	var provider: Variant=options.get("castMenu")
	var provided: Variant=provider.call() if provider is Callable and provider.is_valid() else null
	return provided if provided is Dictionary else choices("Spell",actor.get("spells",[]),{"icon":"IR_CAST","action":"spell.select"},"spellcasting")
static func special_attacks(actor: Dictionary) -> Dictionary:
	return choices("Special attack",actor.get("specialAttacks",[]),{"icon":"IR_XATTACK","action":"combat.selectSpecialAttack"},"combat feats")
static func abilities(actor: Dictionary,options: Dictionary) -> Dictionary:
	var provider: Variant=options.get("abilityMenu")
	var provided: Variant=provider.call() if provider is Callable and provider.is_valid() else null
	return provided if provided is Dictionary else choices("Special ability",actor.get("specialAbilities",[]),{"icon":"IR_XABILITY","action":"ability.select"},"character abilities")
static func traps() -> Dictionary:
	return menu("Trap",[placeholder(0,"Disarm trap","IR_TRAP","trap.disarm","trap rules"),placeholder(2,"Recover trap","IR_TRAP","trap.recover","trap rules"),placeholder(4,"Set trap","IR_TRAP","trap.set","inventory and trap rules")])
static func emote(slot: int,label: String,icon: String,action: String) -> Dictionary:
	return placeholder(slot,label,icon,"emote."+action,"emote animation selection")
static func final_emotes() -> Dictionary:
	return menu("More emotes",[emote(0,"Fall down forwards","IR_FALLFRONT","fallFront"),emote(2,"Sit on ground","IR_SIT","sit"),emote(3,"Meditate","IR_MEDITATE","meditate"),emote(4,"Drink potion","IR_DRINK","drink"),emote(5,"Read","IR_READ","read"),emote(6,"Worship","IR_WORSHIP","worship"),emote(7,"Fall down backwards","IR_FALLBACK","fallBack")])
static func more_emotes() -> Dictionary:
	return menu("More emotes",[emote(0,"Nod","IR_NOD","nod"),emote(1,"Tired","IR_TIRED","tired"),emote(2,"Beg","IR_BEG","beg"),emote(3,"Poisoned","IR_WOOSEY","poisoned"),emote(4,"Bored","IR_BORED","bored"),emote(5,"Look far","IR_LOOKFAR","lookFar"),emote(6,"Scratch head","IR_SCRATCH","scratch"),branch(7,"More emotes","IR_MOREEMOTES",final_emotes)])
static func emotes() -> Dictionary:
	return menu("Emote",[emote(0,"Bow","IR_BOW","bow"),emote(1,"Threaten","IR_THREATEN","threaten"),emote(2,"Greet","IR_GREET","greet"),emote(3,"Laugh","IR_LAUGH","laugh"),emote(4,"Salute","IR_SALUTE","salute"),emote(5,"Cheer","IR_CHEER","cheer"),emote(6,"Goodbye","IR_GOODBYE","goodbye"),branch(7,"More emotes","IR_MOREEMOTES",more_emotes)])
static func commands() -> Dictionary:
	return menu("Issue command",[placeholder(2,"Attack nearest","IR_ATTACKNEAREST","associate.attack","party and associate AI"),placeholder(3,"Follow","IR_FOLLOW","associate.follow","party and associate AI"),placeholder(4,"Stand ground","IR_STANDGROUND","associate.stand","party and associate AI"),placeholder(5,"Guard","IR_GUARD","associate.guard","party and associate AI"),placeholder(6,"Heal me","IR_HEALME","associate.heal","party and associate AI"),branch(7,"Associate actions","IR_ASSOC_ACTION",func():return menu("Associate actions",[placeholder(0,"Disarm trap","IR_HAND_TRAP","associate.disarm","party and trap rules"),placeholder(1,"Inventory","IR_INVENTORY","associate.inventory","party and inventory"),placeholder(7,"Unlock","IR_UNLOCK","associate.unlock","party and lock rules")]))])
static func build_owned_associate_actions(type: int) -> Dictionary:
	var entries: Array=[placeholder(0,"Examine","IR_EXAMINE","object.examine","object descriptions")]
	if type==1:
		entries.append_array([placeholder(3,"Dismiss","IR_KICK","associate.dismissHenchman","henchman removal"),associate_command(1,"Unlock","IR_UNLOCK",-18),associate_command(2,"Inventory","IR_INVENTORY",-19),associate_command(4,"Disarm trap","IR_HAND_TRAP",-20),associate_command(7,"Search","IR_SEARCH",-23),associate_command(5,"Cast spells","IR_SPELL",-21),associate_command(6,"Stealth","IR_STEALTH",-22)])
	elif type==2:entries.append_array([associate_command(3,"Unsummon","IR_UNSUMMON",-9),placeholder(7,"Talk","IR_DIALOG","conversation.start","conversations")])
	elif type==3:entries.append_array([associate_command(3,"Unsummon","IR_UNSUMMON",-8),placeholder(2,"Possess","IFE_POSSESS","associate.possess","familiar possession")])
	elif type==4:entries.append(associate_command(3,"Unsummon","IR_UNSUMMON",-10))
	elif type==5:entries.append(associate_command(3,"Release domination","IR_RELDOM",-12))
	return menu("Associate actions",entries)
static func build_ground_radial_actions(actor: Dictionary,options: Dictionary={}) -> Dictionary:
	return menu("Ground",[branch(1,"Cast spell","IR_CAST",func():return cast(actor,options)),placeholder(2,"Move to","IR_MOVETO","movement.moveTo","ground movement requests"),branch(3,"More actions","IR_TILEACTION",func():return choices("Ground action",actor.get("groundActions",[]),{"icon":"IR_TILEACTION","action":"ground.selectAction"},"ground-targeted actions")),branch(6,"Special abilities","IR_XABILITY",func():return abilities(actor,options))])
static func build_radial_actions(target: Dictionary,actor: Dictionary,options: Dictionary={}) -> Dictionary:
	var title_value: Variant=options.get("title")
	if title_value==null:
		for candidate in [target.get("tag"),target.get("name"),target.get("kind")]:
			if candidate!=null and not str(candidate).is_empty():title_value=candidate;break
	var title: String=str(title_value) if title_value!=null else ""
	var examine: Dictionary=placeholder(0,"Examine","IR_EXAMINE","object.examine","object descriptions")
	var spell: Dictionary=branch(1,"Cast spell","IR_CAST",func():return cast(actor,options))
	var kind:=str(target.get("kind",""))
	if kind=="door":
		var open: bool=target.get("animationState")==1 or target.get("animationState")==2
		var destroyed: bool=target.get("animationState")==3
		var inactive_spell: Dictionary=spell.duplicate();inactive_spell.disabled=open or destroyed
		var entries: Array=[examine,inactive_spell,entry(2,"Close" if open else "Open","IR_OPEN","door.toggle",{"disabled":destroyed or target.get("usable")==false or bool(target.get("animating",false))}),branch(3,"Trap","IR_TRAP",traps,{"disabled":open or destroyed or target.get("trapped")==false}),placeholder(5,"Bash","IR_BASH","combat.bash","combat",{"disabled":open or destroyed})]
		if bool(target.get("locked",false)) or target.get("lockable")!=false:entries.append(placeholder(6,"Unlock" if target.get("locked",false) else "Lock","IR_PICKLOCK" if target.get("locked",false) else "IR_LOCK","lock.pick" if target.get("locked",false) else "lock.lock","lock and key rules",{"disabled":open or destroyed}))
		return menu(title,entries)
	if kind=="placeable":
		var entries: Array=[examine,spell,placeholder(2,"Use","IR_USE","placeable.use","placeable scripts and inventory",{"disabled":target.get("usable")==false}),branch(3,"Trap","IR_TRAP",traps,{"disabled":target.get("trapped")==false}),placeholder(5,"Bash","IR_BASH","combat.bash","combat"),placeholder(6,"Unlock" if target.get("locked",false) else "Lock","IR_PICKLOCK" if target.get("locked",false) else "IR_LOCK","lock.pick" if target.get("locked",false) else "lock.lock","lock and key rules",{"disabled":target.get("lockable")==false and not bool(target.get("locked",false))})]
		return menu(title,entries)
	if kind=="item":
		var owned: bool=target.get("ownerId")==actor.get("id")
		var stack: Variant=target.get("stackSize")
		var entries: Array=[examine,spell,placeholder(2,"Unequip" if target.get("equipped",false) else "Use / equip","IR_UNEQUIP" if target.get("equipped",false) else "IR_USE","item.use","inventory and equipment"),placeholder(4,"Drop" if owned else "Pick up","IR_DROP" if owned else "IR_PICKUP","item.drop" if owned else "item.pickup","inventory"),placeholder(6,"Split stack","IR_SPLIT","item.split","inventory",{"disabled":not ((stack is int or stack is float) and float(stack)>1)})]
		var provider: Variant=options.get("itemUseEntries")
		if provider is Callable and provider.is_valid():
			var extras: Variant=provider.call()
			if extras is Array:entries.append_array(extras)
		return menu(title,entries)
	if target.get("id")==actor.get("id") or kind=="player":
		var entries: Array=[placeholder(0,"Character sheet","IR_CHARSHEET","character.sheet","character UI"),spell,placeholder(2,"Attack","IR_ATTACK","combat.attack","combat"),branch(3,"Special attacks","IR_XATTACK",func():return special_attacks(actor))]
		if actor.get("nativeField97c") is int and int(actor.nativeField97c)!=0 and int(actor.get("nativeField9f8",-1))==0:entries.append(entry(4,"Cancel polymorph","IR_SKILLSELF","character.cancelPolymorph"))
		elif bool(options.get("unpossessFamiliar",false)):entries.append(associate_command(4,"Unpossess Familiar","IFE_UNPOSSESS",-13))
		var command_provider: Variant=options.get("commandMenu")
		entries.append_array([branch(5,"Issue command","IR_COMMAND",command_provider if command_provider is Callable else commands),branch(6,"Special abilities","IR_XABILITY",func():return abilities(actor,options)),branch(7,"Emote","IR_EMOTES",emotes)])
		return menu(title,entries)
	if target.get("masterId")==actor.get("id"):
		return menu(title,[associate_command(0,"Heal me","IR_HEALME",-4),spell,associate_command(2,"Attack nearest","IR_ATTACKNEAREST",-3),associate_command(3,"Follow","IR_FOLLOW",-5),associate_command(4,"Stand ground","IR_STANDGROUND",-2),associate_command(5,"Guard","IR_GUARD",-7),branch(6,"Special abilities","IR_XABILITY",func():return abilities(actor,options)),branch(7,"Associate actions","IR_ASSOC_ACTION",func():return build_owned_associate_actions(int(target.get("associateType",0))&65535))])
	return menu(title,[examine,spell,placeholder(2,"Attack","IR_ATTACK","combat.attack","combat"),branch(3,"Special attacks","IR_XATTACK",func():return special_attacks(actor)),placeholder(4,"Animal empathy","isk_aniemp","skill.animalEmpathy","skill rules"),placeholder(5,"Pick pocket","isk_pocket","skill.pickPocket","skill rules"),branch(6,"Special abilities","IR_XABILITY",func():return abilities(actor,options)),placeholder(7,"Talk","IR_DIALOG","conversation.start","conversations")])
static func radial_hit(dx: float,dy: float,scale: float=1.0) -> Dictionary:
	if not scale>0:return {"error":"Invalid radial scale"}
	var radius_squared:=roundi((dx*dx+dy*dy)/(scale*scale))
	var octant:=posmod(int(floor((PI/2.0-atan2(-dy,dx))/TAU*8.0+0.5)),8)
	var zone: String="center" if radius_squared<=400 else "cancel" if radius_squared<=3136 else "select" if radius_squared<=22500 else "submenu" if radius_squared<=90000 else "exit"
	return {"octant":octant,"zone":zone,"radiusSquared":radius_squared}
static func radial_action_request(selected: Dictionary,target: Dictionary,actor: Dictionary,ground_point: Variant=null) -> Dictionary:
	return {"action":selected.get("action"),"targetId":target.get("id"),"actorId":actor.get("id"),"areaId":target.get("areaId"),"label":selected.get("label"),"system":selected.get("system"),"groundPoint":ground_point}
