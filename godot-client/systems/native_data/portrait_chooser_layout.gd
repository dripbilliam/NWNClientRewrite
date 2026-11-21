extends RefCounted
# CG_PORTRAIT and programmatically attached original grid/bitmap planes.
const Dialog=preload("res://systems/native_data/connection_dialog_layout.gd")
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
static func bitmap(model: Dictionary) -> Dictionary:
	var poses: Array[Transform3D]=[]; var vertices: Array=[]; var texcoords: Array=[]
	for node in model.get("nodes",[]):
		var parent:=int(node.get("parent",-1)); var p: Array=node.get("position",[]); var q: Array=node.get("orientation",[])
		if p.size()!=3 or q.size()!=4 or parent < -1 or parent>=poses.size(): return {"error":"Invalid portrait bitmap hierarchy"}
		var pose:=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3])).scaled(Vector3.ONE*float(node.get("scale",1))),Vector3(p[0],p[1],p[2]))
		if parent>=0: pose=poses[parent]*pose
		poses.append(pose)
		var mesh: Dictionary=node.get("mesh",{})
		if not mesh.get("render",false) or not mesh.get("textures",[]).has("gui_replace01"): continue
		if not vertices.is_empty(): return {"error":"Ambiguous portrait bitmap plane"}
		var xyz: PackedFloat32Array=mesh.get("vertices",PackedFloat32Array()); var uv: Array=mesh.get("uv",[])
		if xyz.size()!=12 or uv.size()!=1 or uv[0].size()!=8: return {"error":"Original portrait bitmap is not a four-corner plane"}
		for index in 4:
			var point:=pose*Vector3(xyz[index*3],xyz[index*3+1],xyz[index*3+2])
			vertices.append(Vector2(point.x,-point.y)*100.0); texcoords.append(Vector2(uv[0][index*2],uv[0][index*2+1]))
	if vertices.is_empty(): return {"error":"Original portrait bitmap plane is missing"}
	var bounds:=Rect2(vertices[0],Vector2.ZERO)
	for point in vertices: bounds=bounds.expand(point)
	var corners:=[bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]; var ordered:=PackedVector2Array()
	for corner in corners:
		var found:=-1
		for index in vertices.size():
			if corner.distance_to(vertices[index])<0.001: found=index; break
		if found<0: return {"error":"Original portrait bitmap is not axis-aligned"}
		ordered.append(texcoords[found])
	return {"error":"","rect":bounds,"uv":ordered}
static func parse(root: Dictionary,models: Dictionary) -> Dictionary:
	var result:=Dialog.panel(root,models,["title"],[],{"okbutton":"0x1408e5370","cancelbutton":"0x1408e1210"},["portrait"])
	if not str(result.error).is_empty(): return result
	# Original8edb00 sets the claimed Title object's bounds flag4.
	result.entries.title.erase("floating");result.entries.title.erase("anchor")
	for name in ["ctl_cg_portraits","ctl_cg_mportrait","scrollbar_simple","pb_scrl_up","pb_scrl_down"]:
		if not models.has(name): return {"error":"Original portrait component is missing: "+name}
	var main:=Geometry.model(models[result.resource]); var grid:=Geometry.model(models.ctl_cg_portraits); var small:=Geometry.model(models.ctl_cg_mportrait)
	if not str(grid.error).is_empty() or not str(small.error).is_empty(): return {"error":"Invalid original portrait grid geometry"}
	if not main.hooks.has("portraits"): return {"error":"Original portrait panel attachment is missing"}
	for hook in ["nextrow","top","bottom","scrollmin","scrollmax"]:
		if not grid.hooks.has(hook): return {"error":"Original portrait grid hook is missing: "+hook}
	for hook in ["next","nextrow"]:
		if not small.hooks.has(hook): return {"error":"Original portrait button hook is missing: "+hook}
	var checked:=Pose.nodes(models.ctl_cg_mportrait,[{"clip":"checkedup","time":0.0}])
	if not str(checked.error).is_empty(): return checked
	var button:=Geometry.model(checked.model); var photo:=bitmap(models.ctl_cg_mportrait); var preview:=bitmap(models[result.entries.portrait.resource])
	if not str(photo.error).is_empty(): return photo
	if not str(preview.error).is_empty(): return preview
	var offset: Vector2=result.origin+main.hooks.portraits
	var viewport:=Rect2(grid.hooks.top,grid.hooks.bottom-grid.hooks.top).abs(); viewport.position+=offset
	var row: Vector2=small.hooks.next*5+small.hooks.nextrow
	if absf(row.x)>0.001 or absf(row.y-107)>0.001 or viewport.size.x<=0 or viewport.size.y<=0: return {"error":"Unsupported original portrait grid placement"}
	result.grid={"resource":"ctl_cg_portraits","rect":Rect2(offset+grid.bounds.position,grid.bounds.size),"offset":offset,"model":grid,"viewport":viewport,"first":offset+grid.hooks.nextrow,"column":small.hooks.next,"row":row,"button":button.bounds,"photo":photo}
	preview.rect.position+=result.entries.portrait.offset; result.preview=preview
	return result
