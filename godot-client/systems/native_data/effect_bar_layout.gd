extends RefCounted
# Original895040/895340/895b20: source leftward list and layered effect icon.
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
const RESOURCES=["pnl_ig_plr_state","ctl_ig_plreffect"]
static func parse(source: Dictionary) -> Dictionary:
	var geometry: Dictionary={}
	for name in RESOURCES:
		if not source.has(name): return {"error":"Original effect bar model missing: "+name}
		geometry[name]=Geometry.model(source[name])
		if not str(geometry[name].error).is_empty(): return {"error":str(geometry[name].error)}
	if not geometry.pnl_ig_plr_state.hooks.has("queue") or not geometry.ctl_ig_plreffect.hooks.has("nextlink"): return {"error":"Original effect bar attachment missing"}
	var model: Dictionary=source.ctl_ig_plreffect; var transforms: Array[Transform3D]=[]; var parts: Array=[]
	for node in model.nodes:
		var p: Array=node.position; var q: Array=node.orientation; var parent:=int(node.parent)
		var pose:=Transform3D(Basis(Quaternion(q[0],q[1],q[2],q[3]).normalized()).scaled(Vector3.ONE*float(node.scale)),Vector3(p[0],p[1],p[2]))
		if parent>=0: pose=transforms[parent]*pose
		transforms.append(pose)
		var mesh: Dictionary=node.get("mesh",{})
		if not mesh.get("render",false): continue
		var xyz: PackedFloat32Array=mesh.vertices; var indices: PackedInt32Array=mesh.indices; var uv: Array=mesh.uv
		if xyz.size()!=12 or indices.size()!=6 or uv.size()!=1 or uv[0].size()!=8 or mesh.textures.size()!=1: return {"error":"Original effect icon topology is unsupported"}
		var points:=PackedVector2Array(); var tex:=PackedVector2Array(); var faces: Array=[]
		for index in 4:
			var point:=pose*Vector3(xyz[index*3],xyz[index*3+1],xyz[index*3+2])
			points.append(Vector2(point.x,-point.y)*100-geometry.ctl_ig_plreffect.bounds.position); tex.append(Vector2(uv[0][index*2],uv[0][index*2+1]))
		for start in [0,3]:
			var vertices:=PackedVector2Array(); var coords:=PackedVector2Array()
			for index in 3:
				var at:=int(indices[start+index])
				if at<0 or at>=4: return {"error":"Original effect icon index is invalid"}
				vertices.append(points[at]); coords.append(tex[at])
			if (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0])<0: faces.append({"vertices":vertices,"uv":coords})
		parts.append({"node":str(node.name).to_lower(),"resource":str(mesh.textures[0]).to_lower(),"alpha":float(node.get("alpha",1)),"faces":faces})
	if parts.size()!=2 or parts.filter(func(part):return part.resource=="gui_replace01").size()!=1: return {"error":"Original effect icon layers are unsupported"}
	var keys: Array=[]; var length:=0.0; var icon_node: String=parts.filter(func(part):return part.resource=="gui_replace01")[0].node
	for clip in model.get("animations",[]):
		if str(clip.name)!="flashing": continue
		length=float(clip.length)
		for node in clip.get("controller_nodes",[]):
			if str(node.name).to_lower()!=icon_node: continue
			var storage: Dictionary=node.storage
			for control in storage.controllers78:
				if int(control.displacement0)!=Actor.remap_controller(128,int(storage.flags98)): continue
				if int(control.columnsA)!=1: return {"error":"Original effect alpha interpolation is unsupported"}
				var pool: Variant=storage.values88; var count:=int(control.rows4); var times:=int(control.timeIndex6); var first:=int(control.valueIndex8)
				if count<1 or times<0 or first<0 or times+count>pool.size() or first+count>pool.size(): return {"error":"Original effect alpha keys are invalid"}
				for index in count: keys.append({"time":float(pool[times+index]),"value":[float(pool[first+index])]})
	if length<=0 or keys.is_empty(): return {"error":"Original effect flashing controller is missing"}
	return {"error":"","models":geometry,"parts":parts,"length":length,"keys":keys}
static func slot(plan: Dictionary,index: int) -> Rect2:
	var rect: Rect2=plan.models.ctl_ig_plreffect.bounds
	rect.position+=plan.models.pnl_ig_plr_state.hooks.queue+plan.models.ctl_ig_plreffect.hooks.nextlink*float(index)
	return rect
static func alpha(plan: Dictionary,time: float) -> float:
	return float(Pose.sample(plan.keys,clampf(time,0,float(plan.length)),"alpha","linear")[0])
