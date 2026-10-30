extends RefCounted
# Original CGuiIngamePVPPanel887570/889350; data only, no active UI owner.
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const RESOURCES=["pnl_ig_pvp","ctl_ig_plyr_list","ctl_ig_btn_pvp","ctl_ig_btn_attit","ctl_ig_btn_icon","ctl_btn_x"]
const BUTTONS={"bootbutton":{"icon":"ir_boot","tooltip":0x1f3e},"banbutton":{"icon":"ir_ban","tooltip":0x1f3d},"invitebutton":{"icon":"ir_invite","tooltip":0x42b},"transferbutton":{"icon":"ir_transleader","tooltip":0x18ef},"tellbutton":{"icon":"ir_chat","tooltip":0x104db},"leavebutton":{"icon":"ir_leave","tooltip":0x42f}}
static func entry(name: String,models: Dictionary,point: Vector2) -> Dictionary:
	var model: Dictionary=models[name]; var rect: Rect2=model.bounds; rect.position+=point
	return {"resource":name,"model":model,"offset":point,"rect":rect,"caption":{"AurString_Font":"fnt_galahad14"}}
static func parse(root: Dictionary,source: Dictionary) -> Dictionary:
	var models: Dictionary={}
	var main_name:=str(root.get("Obj_ResRef","")).to_lower()
	if main_name.is_empty(): return {"error":"Missing original player-list frame resource"}
	var resources:=RESOURCES.duplicate(); resources.erase("pnl_ig_pvp"); resources.append(main_name)
	for name in resources:
		if not source.has(name): return {"error":"Missing original player-list model: "+name}
		models[name]=Geometry.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	if not models[main_name].drawn: return {"error":"Invalid original player-list frame"}
	for pair in [[main_name,["playerlist","helptext"]],["ctl_ig_plyr_list",["top","bottom","listitem","scrollmin","scrollmax"]],["ctl_ig_btn_pvp",["attitudebutton","reaction","text0","text1","next"]],["ctl_ig_btn_attit",["text"]]]:
		for hook in pair[1]:
			if not models[pair[0]].hooks.has(hook): return {"error":"Missing original player-list attachment: "+pair[0]+"/"+hook}
	var controls:=Gui.elements(root,source,Vector2.ZERO)
	if not str(controls.error).is_empty(): return controls
	for tag in ["xbutton","pvpsettinglabel","tguilabel","tguilabel1","tguilabel2","tguilabel3"]:
		if not controls.entries.has(tag): return {"error":"Missing original player-list control: "+tag}
	for tag in BUTTONS:
		if not controls.entries.has(tag): return {"error":"Missing original player-list action: "+tag}
		controls.entries[tag].merge(BUTTONS[tag],true)
	var main: Dictionary=models[main_name]; var list: Dictionary=models.ctl_ig_plyr_list
	var point: Vector2=main.hooks.playerlist; var row: Dictionary=models.ctl_ig_btn_pvp; var row_origin: Vector2=point+list.hooks.listitem
	var view:=Rect2(point+list.hooks.bottom,list.hooks.top-list.hooks.bottom).abs()
	var name_rect:=Rect2(row_origin+row.hooks.text0,row.hooks.text1-row.hooks.text0).abs()
	return {"error":"","models":models,"size":main.bounds.size,"main":entry(main_name,models,Vector2.ZERO),"entries":controls.entries,"list_origin":point,"view":view,"row":entry("ctl_ig_btn_pvp",models,row_origin),"row_step":row.hooks.next,"name_rect":name_rect,"attitude":entry("ctl_ig_btn_attit",models,row_origin+row.hooks.attitudebutton),"attitude_text":row_origin+row.hooks.attitudebutton+models.ctl_ig_btn_attit.hooks.text,"reaction":row_origin+row.hooks.reaction,"scroll":{"model":list,"offset":point,"caption":{"AurString_Font":"fnt_galahad14"}},"help":main.hooks.helptext,"native_data_only":true,"full_players_parity":false}
