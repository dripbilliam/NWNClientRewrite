extends RefCounted
# CPanelPartyBar1408503c0 / CPanelPartyMember1408509c0 / AddMember140851220.
const Model=preload("res://systems/native_data/inventory_equipment_layout.gd")
const RESOURCES=["pnl_party_bar","pb_portrait","pb_pnl_member","pb_mbr_pic","pb_nametag","ctl_playr_health","ctl_party_health","ctl_btn_pb_lvlup","pb_but_map","pb_but_inv","pb_but_jour","pb_but_char","pb_but_rest","pb_but_spell","pb_but_opts","pb_but_pvp","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
const ACTIONS={"map":["pb_but_map","mapbutton",0x1b7c],"inventory":["pb_but_inv","invbutton",0x1b7b],"journal":["pb_but_jour","jourbutton",0x1b7d],"character":["pb_but_char","charbutton",0x1b7f],"rest":["pb_but_rest","restbutton",0x1fa9],"spells":["pb_but_spell","spellbutton",0x1b7e],"options":["pb_but_opts","optsbutton",0x1b80],"pvp":["pb_but_pvp","pvpbutton",0x1faa]}
const FONT="ttf fnt_default 14"
static func entry(models: Dictionary,name: String,offset: Vector2) -> Dictionary:
	var rect: Rect2=models[name].bounds; rect.position+=offset
	return {"resource":name,"model":models[name],"rect":rect,"offset":offset}
static func parse(source: Dictionary) -> Dictionary:
	var models: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Original party HUD model missing: "+name}
		models[name]=Model.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	for hook in ["portrait","health","partymembers","scrollmin","scrollmax"]:
		if not models.pnl_party_bar.hooks.has(hook): return {"error":"Original party HUD attachment missing: "+hook}
	for hook in ["partymember","health","text","nextlink"]:
		if not models.pb_pnl_member.hooks.has(hook): return {"error":"Original member attachment missing: "+hook}
	var actions: Dictionary={}
	for id in ACTIONS:
		var row: Array=ACTIONS[id]
		if not models.pnl_party_bar.hooks.has(row[1]): return {"error":"Original HUD action attachment missing: "+str(row[1])}
		actions[id]=entry(models,row[0],models.pnl_party_bar.hooks[row[1]]); actions[id].tooltip=int(row[2])
	return {"error":"","models":models,"actions":actions,"portrait":entry(models,"pb_portrait",models.pnl_party_bar.hooks.portrait),"member_portrait":entry(models,"pb_mbr_pic",models.pb_pnl_member.hooks.partymember),"level":entry(models,"ctl_btn_pb_lvlup",models.pnl_party_bar.hooks.portrait),"row_height":models.pb_pnl_member.hooks.nextlink.y,"members":models.pnl_party_bar.hooks.partymembers}
