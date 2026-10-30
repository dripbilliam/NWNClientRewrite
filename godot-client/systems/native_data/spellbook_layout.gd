extends RefCounted
# Original spellbook88c8d0 / memorization88f800 / linked nine-slot rows890930.
# Source attachment plan used by the native frame and metadata tests.
const Model=preload("res://systems/native_data/inventory_equipment_layout.gd")
const RESOURCES=["pnl_spellbook","ctl_wizardpage","ctl_sb_btn_sptab","ctl_treebtn_root","ctl_treebtn_spel","ctl_spl_btn_arow","ctl_cg_btn_help","pnl_spellmemoriz","ctl_btn_x","ctl_spells_tmp","ctl_spelbx_first","ctl_spelbx_next"]
const FONT="fnt_galahad14"
const LEVEL_ICONS=["IR_CANTRIPS","IR_LEVEL1","IR_LEVEL2","IR_LEVEL3","IR_LEVEL4","IR_LEVEL5","IR_LEVEL6","IR_LEVEL789","IR_LEVEL789","IR_LEVEL789"]
const LEVEL_REFS=[0x10c42,0x10c43,0x10c44,0x10c45,0x10c46,0x10c47,0x10c48,0x10c49,0x10c4a,0x10c4b]
const META=[{"mask":0,"feat":-1,"label":0x104b8,"icon":"IR_CANTRIPS"},{"mask":1,"feat":11,"label":0x104b2,"icon":"IR_EMPOWER"},{"mask":2,"feat":12,"label":0x104b3,"icon":"IR_EXTEND"},{"mask":4,"feat":25,"label":0x104b4,"icon":"IR_MAXIMIZE"},{"mask":8,"feat":29,"label":0x104b5,"icon":"IR_QUICKEN"},{"mask":16,"feat":33,"label":0x104b6,"icon":"IR_SILENT"},{"mask":32,"feat":37,"label":0x104b7,"icon":"IR_STILL"}]
static func box(model: Dictionary,first: String,last: String,offset: Vector2=Vector2.ZERO) -> Rect2:
	return Rect2(offset+model.hooks[first],model.hooks[last]-model.hooks[first]).abs()
static func entry(models: Dictionary,name: String,offset: Vector2) -> Dictionary:
	var rect: Rect2=models[name].bounds; rect.position+=offset
	return {"resource":name,"rect":rect,"offset":offset,"model":models[name]}
static func tabs(models: Dictionary,count: int,origin: Vector2) -> Array:
	var result: Array=[]
	for index in count:
		result.append(entry(models,"ctl_sb_btn_sptab",origin)); origin+=models.ctl_sb_btn_sptab.hooks.next
	return result
static func parse(source: Dictionary) -> Dictionary:
	var models: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Original spellbook model missing: "+name}
		models[name]=Model.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	var required:={"pnl_spellbook":["pages","tabs","title","xbutton"],"pnl_spellmemoriz":["title","xbutton","view0","view1","treeview","scrollmin","scrollmax"],"ctl_wizardpage":["view0","view1","treeview","tabs","scrollmin","scrollmax","scrollup","scrolldown"],"ctl_sb_btn_sptab":["icon","next"],"ctl_treebtn_root":["text","nextlink","descbutton"],"ctl_treebtn_spel":["icon","nextlink","text0","text1","arrowbutton","descriptionbutton"],"ctl_spells_tmp":["next","nextlink"],"ctl_spelbx_first":["next","icon"],"ctl_spelbx_next":["next","icon"]}
	for name in required:
		for hook in required[name]:
			if not models[name].hooks.has(hook): return {"error":"Original spellbook attachment missing: "+name+"/"+hook}
	var known: Dictionary=models.pnl_spellbook; var memory: Dictionary=models.pnl_spellmemoriz; var page: Dictionary=models.ctl_wizardpage; var offset: Vector2=known.hooks.pages
	return {"error":"","models":models,"main_size":known.bounds.size,"memory_size":memory.bounds.size,"class_tabs":tabs(models,8,known.hooks.tabs),"level_tabs":tabs(models,10,offset+page.hooks.tabs),"page_origin":offset,"known_view":box(page,"view0","view1",offset),"memory_view":box(memory,"view0","view1"),"known_tree":offset+page.hooks.treeview,"memory_tree":memory.hooks.treeview,"known_close":entry(models,"ctl_btn_x",known.hooks.xbutton),"memory_close":entry(models,"ctl_btn_x",memory.hooks.xbutton)}
static func known_rows(models: Dictionary,count: int,origin: Vector2=Vector2.ZERO) -> Dictionary:
	if count<0 or count>65535: return {"error":"Invalid original known row count"}
	var root:=entry(models,"ctl_treebtn_root",origin); var point: Vector2=origin+models.ctl_treebtn_root.hooks.nextlink; var rows: Array=[]
	for index in count:
		var row:=entry(models,"ctl_treebtn_spel",point)
		row.caption=box(models.ctl_treebtn_spel,"text0","text1",point); row.icon=point+models.ctl_treebtn_spel.hooks.icon; row.arrow=entry(models,"ctl_spl_btn_arow",point+models.ctl_treebtn_spel.hooks.arrowbutton); row.help=entry(models,"ctl_cg_btn_help",point+models.ctl_treebtn_spel.hooks.descriptionbutton)
		rows.append(row); point+=models.ctl_treebtn_spel.hooks.nextlink
	return {"error":"","root":root,"rows":rows,"next_origin":point}
static func memory_slots(models: Dictionary,count: int,origin: Vector2=Vector2.ZERO) -> Dictionary:
	if count<0 or count>65535: return {"error":"Invalid original prepared slot count"}
	var root:=entry(models,"ctl_treebtn_root",origin); var row_origin: Vector2=origin+models.ctl_treebtn_root.hooks.nextlink; var point:=row_origin; var slots: Array=[]; var row_count:=0
	for index in count:
		var resource:="ctl_spelbx_next"
		if index%9==0:
			resource="ctl_spelbx_first"; point=row_origin+models.ctl_spells_tmp.hooks.next; row_origin+=models.ctl_spells_tmp.hooks.nextlink; row_count+=1
		var slot:=entry(models,resource,point); slot.index=index; slot.icon=point+models[resource].hooks.icon; slots.append(slot); point+=models[resource].hooks.next
	return {"error":"","root":root,"slots":slots,"row_count":row_count,"next_origin":row_origin}
