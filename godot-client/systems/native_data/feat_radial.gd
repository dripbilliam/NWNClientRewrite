extends RefCounted
# Native client leaf1409957a0 / variants140991230 / callback140998520.
# Only received ownership/uses and the active physical 2DA rows are consulted.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const INVALID=2130706432
const MODES={28:3,19:4,30:7,204:6,899:6,866:6,389:8,390:9,425:11,947:12}
var rules
var errors: Array=[]
static func signed32(value: int) -> int:
	value&=0xffffffff
	return value-0x100000000 if value&0x80000000 else value
static func binding(id: int,auxiliary: int=0) -> Dictionary:
	# Type4 quickbar replication serializes one signed INT, not a separate aux.
	return {"type":4,"intParam":signed32((id&65535)|((auxiliary&65535)<<16))}
func context(actor: Dictionary,target_id: int,assignment: bool=false) -> Dictionary:
	var owned: Dictionary={}
	for id in rules.feats(actor): owned[int(id)&65535]=true
	return {"actor":actor,"owned":owned,"controlled":int(actor.get("objectType",0))==5 and not actor.get("replicationRemoved",false),"self":int(actor.get("id",-1))==target_id,"targetId":target_id,"assignment":assignment,"familiar":{},"defensiveStance":0}
func feat(id: int) -> Dictionary:
	var row: Dictionary=rules.row("feat",id&65535)
	# A numeric Feat cell validates the physical row; its value is a TLK ref,
	# never a remapping from the row index to a different gameplay feat ID.
	var name_ref:=Rules.number(Rules.cell(row,"FEAT"),-2147483648)
	if row.is_empty() or name_ref==-2147483648: return {}
	var icon:=str(Rules.cell(row,"ICON",""))
	return {"nameRef":name_ref,"icon":"" if icon=="****" else icon.left(16),"successor":signed32(Rules.number(Rules.cell(row,"SUCCESSOR"),-1)),"targetSelf":Rules.number(Rules.cell(row,"TargetSelf"),0),"spellId":Rules.number(Rules.cell(row,"SpellId"),-1)}
func children(spell: int) -> Array:
	var result: Array=[]; var row: Dictionary=rules.row("spells",spell)
	for n in range(1,9):
		var value:=Rules.number(Rules.cell(row,"SubRadSpell"+str(n)),-2147483648)
		if value!=-2147483648: result.append(value)
	return result
func remaining(ctx: Dictionary,id: int) -> int:
	id&=65535
	if not ctx.owned.has(id): return 0
	var counters: Dictionary=ctx.actor.get("playerState",{}).get("featUses",{})
	var unlimited: bool=(Rules.number(Rules.cell(rules.row("feat",id),"UsesPerDay"),0)&255)==0
	return int(counters.get(str(id),counters.get(id,100 if unlimited else 0)))&255
func leaf(ctx: Dictionary,requested: int) -> Dictionary:
	if not ctx.controlled: return {}
	var id:=requested&65535
	if not ctx.owned.has(id): return {}
	var visited: Dictionary={}
	while true:
		if visited.has(id):
			if not errors.has("Native radial feat successor cycle"): errors.append("Native radial feat successor cycle")
			return {}
		visited[id]=true
		var info:=feat(id); var next:=int(info.get("successor",-1))
		if next<=0 or not ctx.owned.has(next&65535): break
		id=next
	var info:=feat(id)
	if info.is_empty(): return {}
	var auxiliary:=((requested>>16)&65535)|((id>>16)&65535)
	id&=65535
	var uses:=remaining(ctx,id)
	if not rules.row("spells",int(info.spellId)).is_empty() and not children(int(info.spellId)).is_empty(): return {"featId":id,"auxiliary":auxiliary,"submenu":true}
	var result:={"featId":id,"auxiliary":auxiliary,"labelRef":info.nameRef,"icon":info.icon,"uses":null if uses==100 else uses,"disabled":not ctx.assignment and (uses==0 or int(info.targetSelf)!=0 and not ctx.self),"action":"feat.use"}
	if id==5 and auxiliary in [65000,65001]: result.labelRef=517 if auxiliary==65001 else 518; result.icon="IR_CALLEDARM" if auxiliary==65001 else "IR_CALLEDLEG"
	elif id==303 and not ctx.familiar.is_empty(): result.labelRef=523; result.icon="IFE_POSSESS"; result.uses=null; result.action="associate.possessFamiliar"; result.disabled=not(ctx.self or int(ctx.targetId)==int(ctx.familiar.id))
	if id==947 and int(ctx.defensiveStance)==1: result.labelRef=84555; result.uses=null; result.disabled=false
	return result
func variants(ctx: Dictionary,id: int) -> Array:
	id&=65535
	var info:=feat(id); var result: Array=[]
	if info.is_empty() or rules.row("spells",int(info.spellId)).is_empty(): return result
	var slots:=children(int(info.spellId))
	for slot in slots.size():
		var child: Dictionary=rules.row("spells",int(slots[slot]))
		if child.is_empty(): continue
		var uses:=remaining(ctx,id)
		result.append({"slot":slot,"featId":id,"auxiliary":(Rules.number(Rules.cell(child,"FeatID"),0)>>16)&65535,"labelRef":Rules.number(Rules.cell(child,"Name"),-1),"icon":str(Rules.cell(child,"IconResRef","")).left(16),"uses":null if uses==100 else uses,"disabled":not ctx.assignment and (uses<1 or int(info.targetSelf)!=0 and not ctx.self),"action":"feat.use"})
	return result
func select(ctx: Dictionary,packed: int) -> Dictionary:
	if not ctx.controlled: return {"mode":"none"}
	packed&=0xffffffff
	if ctx.assignment: return {"mode":"assign","packed":packed}
	var id:=packed&65535; var auxiliary:=packed>>16
	if auxiliary==0 and MODES.has(id): return {"mode":"mode","modeId":MODES[id]}
	var info:=feat(id)
	if info.is_empty(): return {"mode":"none"}
	if ctx.self and int(info.targetSelf)==0: return {"mode":"target","featId":id,"auxiliary":auxiliary if id==5 or id>1072 else 0}
	return {"mode":"use","featId":id,"auxiliary":auxiliary}
func target_spell(id: int,auxiliary: int) -> int:
	var info:=feat(id)
	if info.is_empty(): return -1
	var spell:=int(info.spellId)
	for child in children(spell):
		var row: Dictionary=rules.row("spells",int(child))
		if not row.is_empty() and ((Rules.number(Rules.cell(row,"FeatID"),0)>>16)&65535)==(auxiliary&65535): return int(child)
	return spell
func mode_entry(ctx: Dictionary,id: int,slot: int,icon: String="",self_only: bool=false,label_ref: int=-1) -> Dictionary:
	if not ctx.owned.has(id): return {}
	var info:=feat(id)
	if info.is_empty() and icon.is_empty(): return {}
	return {"slot":slot,"featId":id,"auxiliary":0,"icon":str(info.get("icon","")) if icon.is_empty() else icon,"labelRef":int(info.get("nameRef",label_ref)),"uses":null,"disabled":self_only and not ctx.self,"action":"feat.use"}
func special(ctx: Dictionary) -> Array:
	# Native controlled-creature builder140995090 and More page140991720/3.
	# These IDs/slots are compiled engine branches; names, successors, family
	# metadata and charges are still read from the active server's rules/state.
	if not ctx.controlled: return []
	var result: Array=[]
	var flurry:=mode_entry(ctx,19,5,"",true)
	if not flurry.is_empty(): result.append(flurry)
	for source in [[23,17,4],[9,16,6]]:
		if ctx.owned.has(source[0]):
			var value:=leaf(ctx,source[1] if ctx.owned.has(source[1]) else source[0])
			if not value.is_empty(): value.slot=source[2]; result.append(value)
	if ctx.owned.has(5):
		for source in [[65000,3],[65001,1]]:
			var value:=leaf(ctx,(source[0]<<16)|5)
			if not value.is_empty(): value.slot=source[1]; result.append(value)
	var power:=mode_entry(ctx,28,2,"",true)
	if not power.is_empty(): result.append(power)
	if [31,30,425,389,390,39,867].any(func(id):return ctx.owned.has(id)):
		var more: Array=[]
		for source in [[31,2],[867,6],[39,5]]:
			var value:=leaf(ctx,int(source[0]))
			if not value.is_empty(): value.slot=source[1]; more.append(value)
		for source in [[30,3,"ife_rapidshot",true,63804],[389,0,"ife_X1Expert",false,1587],[390,1,"ife_X1ImpExp",false,1700],[425,4,"ife_X1DirFig",true,3877]]:
			var value:=mode_entry(ctx,int(source[0]),int(source[1]),str(source[2]),bool(source[3]),int(source[4]))
			if not value.is_empty(): more.append(value)
		result.append({"kind":"group","slot":7,"labelRef":1065,"icon":"IR_MOREATTACKS","children":more})
	result.append({"kind":"parry","slot":0,"labelRef":4852,"icon":"isk_parry","disabled":not ctx.assignment and not ctx.self})
	return result
