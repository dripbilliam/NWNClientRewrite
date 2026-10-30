extends RefCounted
# CGuiInGameChatDialog14087d1e0 / content-sized geometry14087dd00.
const Model=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
const M=preload("res://systems/native_render/particle_math.gd")
const RESOURCES=["pnl_dialog","ctl_dialog_entry","ctl_dialog_reply","scrollbar_simple","pb_scrl_up","pb_scrl_down"]
const FONT="ttf fnt_default 14"
const COLOR=Color(0.4,0.7,1.0,1.0)
static func flow(entry_pixels: float,reply_pixels: float,clearance_pixels: float=0) -> Dictionary:
	if not is_finite(entry_pixels) or not is_finite(reply_pixels) or not is_finite(clearance_pixels) or minf(entry_pixels,reply_pixels)<0: return {"error":"Invalid original dialog text dimensions"}
	var entry:=M.f(entry_pixels*0.01); var entry_scroll:=entry>2.0; entry=minf(entry,2.0)
	var top:=maxf(M.f(entry+M.f(0.39999998)),M.f(1.12))
	var total:=maxf(M.f(M.f(M.f(reply_pixels*0.01)+top)+M.f(0.049999997)),M.f(2.54))
	var limit:=maxf(M.f(4.0),M.f(clearance_pixels*0.01)); var height:=minf(total,limit)
	var time:=M.f(M.f(M.f(height-M.f(0.64))/M.f(0.01))/M.f(30.0))
	return {"error":"","entry_scroll":entry_scroll,"reply_scroll":total>limit,"reply_top":top*100.0,"height":height*100.0,"logical_height":M.f(height+M.f(0.04))*100.0,"time":time,"poses":[{"clip":"size","time":time}]}
static func parse(source: Dictionary) -> Dictionary:
	var models: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Missing original conversation model: "+name}
		models[name]=Model.model(source[name])
		if not str(models[name].error).is_empty(): return {"error":str(models[name].error)}
	for pair in [["pnl_dialog",["name0","name1","portrait","entrytext","repliestext","entryviewport0","entryviewport1","repliesviewport0","repliesviewport1","indextextbottom"]],["ctl_dialog_entry",["text0","text1","scrollmin","scrollmax"]],["ctl_dialog_reply",["text0","text1","indextext0","indextext1","scrollmin","scrollmax"]]]:
		for hook in pair[1]:
			if not models[pair[0]].hooks.has(hook): return {"error":"Original conversation attachment missing: "+pair[0]+"/"+hook}
	return {"error":"","models":models}
static func layout(source: Dictionary,definition: Dictionary,reflow: Dictionary) -> Dictionary:
	if not str(reflow.get("error","")).is_empty(): return reflow
	var original: Dictionary=source.pnl_dialog; var changed:=original.duplicate(); changed.nodes=original.nodes.duplicate()
	for at in changed.nodes.size():
		if str(changed.nodes[at].name).to_lower()=="repliestext":
			var node: Dictionary=changed.nodes[at].duplicate(); node.position=node.position.duplicate(); node.position[1]=-float(reflow.reply_top)*0.01; changed.nodes[at]=node
	var nodes:=Pose.nodes(changed,reflow.poses); var parser:=Actor.new(); var rig: Dictionary=original.rig_asset if original.has("rig_asset") else parser.rig_asset(original); var mesh:=Pose.compose(rig,reflow.poses)
	if not str(nodes.error).is_empty(): return nodes
	if not str(mesh.error).is_empty(): return mesh
	for at in mesh.meshes:
		if mesh.meshes[at].has("positions"):
			var node: Dictionary=nodes.model.nodes[int(at)].duplicate(); node.mesh=node.mesh.duplicate(); node.mesh.vertices=mesh.meshes[at].positions; nodes.model.nodes[int(at)]=node
	var main:=Model.model(nodes.model)
	if not str(main.error).is_empty(): return main
	var entry: Dictionary=definition.models.ctl_dialog_entry; var reply: Dictionary=definition.models.ctl_dialog_reply.duplicate(true)
	var entry_height:=minf(entry.hooks.text1.y-entry.hooks.text0.y,maxf(1,reflow.reply_top-main.hooks.entrytext.y-5))
	var reply_height:=maxf(1,main.hooks.indextextbottom.y-main.hooks.repliestext.y)
	reply.hooks.text1.y=reply_height; reply.hooks.indextext1.y=reply_height; reply.hooks.scrollmax.y=maxf(reply.hooks.scrollmin.y+4,reply_height-9)
	return {"error":"","size":Vector2(360,reflow.logical_height),"background":main.bounds,"name":Rect2(main.hooks.name0,main.hooks.name1-main.hooks.name0),"portrait":Rect2(main.hooks.portrait-Vector2(32,50),Vector2(64,100)),"entry":Rect2(main.hooks.entrytext+entry.hooks.text0,Vector2(entry.hooks.text1.x-entry.hooks.text0.x,entry_height)),"replies":Rect2(main.hooks.repliestext+reply.hooks.indextext0,Vector2(reply.hooks.text1.x-reply.hooks.indextext0.x,reply_height)),"entry_bar":{"model":entry,"offset":main.hooks.entrytext,"caption":{"AurString_Font":FONT}},"reply_bar":{"model":reply,"offset":main.hooks.repliestext,"caption":{"AurString_Font":FONT}},"flow":reflow}
