extends RefCounted
# CJournalPanel883610/8853e0; CJournalQuestPage883730; personal notes884b40.
const Model=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Gui=preload("res://systems/native_data/inventory_frame_layout.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const RESOURCES=["pnl_jnl_panel","pnl_jnl_page1","ctl_jnl_btn_tab","ctl_jnl_btn_tab2","ctl_jnl_btn_tab3","ctl_jnl_questbtn","ctl_jnl_entrytxt","ctl_btn_xch","ctl_btn_x","edit_jnl_348x408"]
const FONT="fnt_galahad14"
const TAB_REFS=[0xf809,0xf80b,0xf80a]
static func box(model: Dictionary,a: String,b: String,offset: Vector2=Vector2.ZERO) -> Rect2:
	return Rect2(offset+model.hooks[a],model.hooks[b]-model.hooks[a]).abs()
static func entry(models: Dictionary,name: String,offset: Vector2) -> Dictionary:
	var rect: Rect2=models[name].bounds; rect.position+=offset
	return {"resource":name,"model":models[name],"offset":offset,"rect":rect,"caption":{"AurString_Font":FONT}}
static func description(source: Dictionary,pixels: float,offset: Vector2=Vector2.ZERO) -> Dictionary:
	if not is_finite(pixels) or pixels<0: return {"error":"Invalid original journal entry text height"}
	var poses: Array=[{"clip":"textheight","time":M.f(minf(M.f(pixels),1536.0)/M.f(30.0))}]
	var sampled:=Pose.nodes(source,poses)
	if not str(sampled.error).is_empty(): return sampled
	var parser:=Actor.new(); var rig: Dictionary=source.rig_asset if source.has("rig_asset") else parser.rig_asset(source); var mesh:=Pose.compose(rig,poses)
	if not str(mesh.error).is_empty(): return mesh
	for at in mesh.meshes:
		if mesh.meshes[at].has("positions"):
			var node: Dictionary=sampled.model.nodes[int(at)].duplicate(); node.mesh=node.mesh.duplicate(); node.mesh.vertices=mesh.meshes[at].positions; sampled.model.nodes[int(at)]=node
	var model:=Model.model(sampled.model)
	if not str(model.error).is_empty(): return model
	# Both text hooks have the same Y. Original885b50 assigns measured string
	# height separately; only the model animation/linkage is capped at1536px.
	var text:=Rect2(offset+model.hooks.text0,Vector2(model.hooks.text1.x-model.hooks.text0.x,pixels))
	return {"error":"","model":model,"offset":offset,"rect":Rect2(offset+model.bounds.position,model.bounds.size),"text":text,"next":offset+model.hooks.nextlink,"poses":poses}
static func parse(layouts: Dictionary,source: Dictionary) -> Dictionary:
	for name in ["jnl_panel","jnl_page_quest","jnl_page_notes"]:
		if not layouts.has(name): return {"error":"Missing original journal GUI: "+name}
	var models: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Missing original journal model: "+name}
		models[name]=Model.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	for pair in [["pnl_jnl_panel",["pages","tabs"]],["pnl_jnl_page1",["view0","view1","treeview","scrollmin","scrollmax"]],["ctl_jnl_questbtn",["text","nextlink"]],["ctl_jnl_entrytxt",["text0","text1","nextlink"]],["edit_jnl_348x408",["text0","text1","scrollmin","scrollmax"]]]:
		for hook in pair[1]:
			if not models[pair[0]].hooks.has(hook): return {"error":"Missing original journal attachment: "+pair[0]+"/"+hook}
	var main: Dictionary=models.pnl_jnl_panel; var origin: Vector2=main.hooks.pages; var page: Dictionary=models.pnl_jnl_page1
	var controls:=Gui.elements(layouts.jnl_panel,source,Vector2.ZERO)
	var sorting:=Gui.elements(layouts.jnl_page_quest,source,origin)
	var notes:=Gui.elements(layouts.jnl_page_notes,source,origin)
	for parsed in [controls,sorting,notes]:
		if not str(parsed.error).is_empty(): return parsed
	for pair in [[controls,["xbutton","title"]],[sorting,["dateradio","nameradio","priorityradio"]],[notes,["textbox"]]]:
		for tag in pair[1]:
			if not pair[0].entries.has(tag): return {"error":"Missing original journal control: "+tag}
	var tabs: Array=[]; var point: Vector2=main.hooks.tabs
	for at in 3:
		var name: String=["ctl_jnl_btn_tab","ctl_jnl_btn_tab2","ctl_jnl_btn_tab3"][at]
		if not models[name].hooks.has("next"): return {"error":"Missing original journal tab linkage"}
		tabs.append(entry(models,name,point)); point+=models[name].hooks.next
	var sort_labels: Array=[]
	for child in layouts.jnl_page_quest.get("Obj_ChildList",[]):
		var tag:=str(child.get("Obj_Tag","")).to_lower()
		for label in child.get("Obj_ChildList",[]):
			var offset: Vector2=sorting.entries[tag].offset+Vector2(float(label.get("Obj_Label_X",0)),-float(label.get("Obj_Label_Y",0)))*100.0
			sort_labels.append({"rect":Rect2(offset,Vector2(float(label.get("Obj_Label_Width",0)),float(label.get("Obj_Label_Height",0)))*100.0),"caption":label.get("Obj_Caption",{})})
	return {"error":"","models":models,"size":Vector2(main.bounds.size.x,origin.y+page.bounds.end.y),"page_origin":origin,"main":entry(models,"pnl_jnl_panel",Vector2.ZERO),"page":entry(models,"pnl_jnl_page1",origin),"title":controls.entries.title,"close":controls.entries.xbutton,"tabs":tabs,"sort":sorting.entries,"sort_labels":sort_labels,"quest_view":box(page,"view0","view1",origin),"quest_tree":origin+page.hooks.treeview,"quest_bar":{"model":page,"offset":origin,"caption":{"AurString_Font":FONT}},"notes":notes.entries.textbox,"notes_view":box(notes.entries.textbox.model,"text0","text1",notes.entries.textbox.offset)}
