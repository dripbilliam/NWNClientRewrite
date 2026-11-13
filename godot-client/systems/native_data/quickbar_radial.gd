extends RefCounted
# Original CGuiQuickbarMenu9ab4d0/9adb20. Engine sectors/labels are compiled
# constants; spell/skill/feat names, descriptions and icons stay active data.
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const EMOTES=[
	["IR_CHEER",1010],["IR_CHEER",1010],["IR_CHEER",1010],
	["IR_SALUTE",703],["IR_LAUGH",66856],["IR_GOODBYE",66857],
	["IR_GREET",1069],["IR_BOW",699],["IR_THREATEN",66859],
	["IR_LOOKFAR",66860],["IR_BORED",66861],["IR_WOOSEY",8047],
	["IR_SCRATCH",984],["IR_BEG",985],["IR_TIRED",66863],["IR_NOD",66864],
	["IR_READ",110524],["IR_DRINK",110525],["IR_MEDITATE",110526],
	["IR_WORSHIP",110527],["IR_SIT",110528],["IR_FALLBACK",110529],["IR_FALLFRONT",110530]]
const EMOTE_ANIMATIONS=[46,45,44,34,41,29,29,35,28,48,56,58,55,39,57,30,71,70,32,33,47,8,6]
const EMOTE_VOICES=[44,44,44,65535,42,40,34,65535,65535,65535,65535,19,47,65535,38,65535,65535,65535,65535,65535,65535,65535,65535]
const COMMANDS=[[5,"IR_GUARD",1474,9],[4,"IR_STANDGROUND",1477,10],[3,"IR_FOLLOW",682,22],[2,"IR_ATTACKNEAREST",5345,0],[6,"IR_HEALME",1483,4]]
var rules
func text(ref: int) -> String:return rules.text.raw({"strRef":ref})
func row(slot: int,icon: String,ref: int,action: String,extra: Dictionary={}) -> Dictionary:
	return {"slot":slot,"icon":icon,"label":text(ref),"action":action,"disabled":false,"uses":null,"canDrag":extra.has("binding"),"submenu":extra.has("menu")}.merged(extra,true)
func branch(slot: int,icon: String,ref: int,kind: String) -> Dictionary:
	return row(slot,icon,ref,"branch",{"menu":{"kind":kind,"title":text(ref),"center":icon}})
func valid(table: String,id: int) -> bool:
	var source: Dictionary=rules.row(table,id)
	return not source.is_empty() and (table!="feat" or Rules.cell(source,"FEAT")!=null and str(Rules.cell(source,"FEAT")) not in ["","****"])
func empty(disengage: bool=false) -> Array:
	return [row(0,"IR_TEXTMACRO",1159,"quickbar-macro"),branch(1,"IR_CAST",1158,"spell-root"),row(2,"IR_DISENGAGE" if disengage else "IR_ATTACK",1057 if disengage else 1056,"power",{"binding":{"type":7}}),branch(3,"IR_XATTACK",1156,"quickbar-attacks"),branch(4,"IR_ACTION",67564,"quickbar-actions"),branch(5,"IR_COMMAND",1157,"quickbar-commands"),branch(6,"IR_XABILITY",1155,"abilities"),branch(7,"IR_EMOTES",1025,"quickbar-emotes")]
func actions(actor: Dictionary) -> Array:
	var result: Array=[row(0,"IR_EXAMINE",67566,"power",{"binding":{"type":40}}),row(2,"IR_DIALOG",67565,"power",{"binding":{"type":6}}),row(7,"IR_BARTER",67569,"power",{"binding":{"type":41}})]
	var available: Dictionary={}
	for skill in actor.get("inventoryStats",{}).get("skills",[]):
		if skill.get("flag",false):available[int(skill.get("index",-1))]=true
	for source in [[5,"isk_pocket",67568,13],[4,"isk_aniemp",67567,0],[6,"ISK_OLOCK",68656,9]]:
		if available.has(int(source[3])):result.append(row(int(source[0]),str(source[1]),int(source[2]),"power",{"binding":{"type":3,"intParam":int(source[3])}}))
	return result
func commands() -> Array:
	# Original9945d0, reached from empty quickslot9ac860. Associate-specific
	# sectors0/1/7 require separate party count/index ownership, not guessed IDs.
	var result: Array=[]
	for source in COMMANDS:
		result.append(row(int(source[0]),str(source[1]),int(source[2]),"power",{"binding":{"type":42,"intParam":int(source[3])}}))
	return result
func command(id: int) -> Dictionary:
	for source in COMMANDS:
		if int(source[3])==id:return {"icon":str(source[1]),"labelRef":int(source[2])}
	return {}
func associate(binding: Dictionary) -> Dictionary:
	# Original8693b0 packs the wire INT's low SHORT above the associate WORD;
	# 860760 and bound-menu9ab4d0 recognize these five command captions.
	var command_id: int=int(binding.get("intParam",0))&65535
	if command_id&32768:command_id-=65536
	var source: Array={-20:["IR_HAND_TRAP",1482],-19:["IR_INVENTORY",3731],-18:["IR_UNLOCK",1467],-9:["IFE_NOFAMILIAR",1569],-8:["IFE_NOFAMILIAR",1569]}.get(command_id,[])
	return {"icon":str(source[0]),"labelRef":int(source[1]),"command":command_id} if not source.is_empty() else {}
func emote(id: int) -> Dictionary:
	return {"icon":str(EMOTES[id][0]),"labelRef":int(EMOTES[id][1]),"animation":int(EMOTE_ANIMATIONS[id]),"voice":int(EMOTE_VOICES[id])} if id>=0 and id<EMOTES.size() else {}
func emotes(page: int,first_class: int) -> Array:
	var result: Array=[];var ids: Array=[];var slots: Array=[]
	if page==0:
		ids=[0 if first_class==8 else 1 if first_class in [2,3,6,9,10] else 2,3,4,5,6,7,8];slots=[5,4,3,6,2,0,1]
	elif page==1:ids=[9,10,11,12,13,15,14];slots=[5,4,3,6,2,0,1]
	else:ids=[16,17,18,19,20,21,22];slots=[5,4,3,6,2,7,0]
	for index in ids.size():
		var id:=int(ids[index]);result.append(row(int(slots[index]),str(EMOTES[id][0]),int(EMOTES[id][1]),"power",{"binding":{"type":8,"intParam":id}}))
	if page<2:result.append(branch(7,"IR_MOREEMOTES",702,"quickbar-emotes-more" if page==0 else "quickbar-emotes-last"))
	return result
func bound(binding: Dictionary,enabled: bool,icon: String,label: String,disengage: bool=false) -> Array:
	var type:=int(binding.get("type",0));var result: Array=[row(4,"IR_EMPTYQS",1389,"quickbar-clear")]
	if type in [2,3,4,44]:
		var table: String={2:"spells",44:"spells",3:"skills",4:"feat"}[type];var id:=int(binding.get("intParam",-1));id=id&65535 if type in [3,4] else id
		if not valid(table,id):return result
		icon=rules.icon(table,id);label=rules.title(table,id,"FEAT" if type==4 else "Name")
		if type==3 and id==22:icon="ir_craft";label=text(84543)
		result.append(row(0,"IR_EXAMINE",549,"quickbar-examine"))
		result.append(row(3,icon,554,"quickbar-use",{"label":text(554)+" : "+label,"disabled":not enabled}))
	elif type==10:
		var id:=int(binding.get("intParam",-1));var ref: int={0:4848,1:4850,5:693,10:1762}.get(id,-1)
		if ref>=0:result.append(row(0,"IR_EXAMINE",549,"quickbar-examine"));result.append(row(3,icon,ref,"quickbar-use",{"disabled":not enabled}))
	elif type==18:
		result.append(row(3,"IR_CAST",6629,"quickbar-use",{"disabled":not enabled}));result.append(row(6,"IR_TEXTMACRO",6902,"quickbar-macro-line"));result.append(row(2,"IR_TEXTMACRO",6903,"quickbar-macro-label"))
	else:
		var ref: int={6:1072,7:1057 if disengage else 1056,38:523,40:549,41:263,43:8272}.get(type,-1)
		if type==39:ref=int(associate(binding).get("labelRef",-1))
		if type==42:ref={0:5345,4:1483,9:1474,10:1477,22:682}.get(int(binding.get("intParam",-1)),-1)
		if type==8:ref=554;label=text(554)+" : "+label
		if ref>=0:result.append(row(3,icon,ref,"quickbar-use",{"label":label if type==8 else text(ref),"disabled":not enabled}))
	return result
func information(binding: Dictionary) -> Dictionary:
	var type:=int(binding.get("type",0));var table: String={2:"spells",44:"spells",3:"skills",4:"feat"}.get(type,"")
	if type==10:
		var pair: Array={0:[4848,40068],1:[4850,40067],5:[693,40069],10:[1762,40070]}.get(int(binding.get("intParam",-1)),[])
		return {"ready":true,"name":text(int(pair[0])),"description":text(int(pair[1])),"icon":""} if pair.size()==2 else {}
	var id:=int(binding.get("intParam",-1));id=id&65535 if type in [3,4] else id
	if table.is_empty():return {}
	var source: Dictionary=rules.row(table,id)
	if not valid(table,id):return {}
	if type==3 and id==22:return {"ready":true,"name":text(84543),"description":text(100924),"icon":"ir_craft"}
	return {"ready":true,"name":rules.title(table,id,"FEAT" if type==4 else "Name"),"description":text(Rules.number(Rules.cell(source,"SpellDesc" if table=="spells" else "Description"),4294967295)),"icon":rules.icon(table,id)}
