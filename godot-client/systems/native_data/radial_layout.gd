extends RefCounted
# CRadialMenu attaches icon frames to GUI_RA_MENU's 0hook..7hook nodes.
# Preserve the active resource's hierarchy instead of inventing a new wheel.
static func parse(model: Dictionary) -> Dictionary:
	var poses: Array[Transform3D]=[]; var hooks: Dictionary={}
	for row in model.get("nodes",[]):
		var p: Array=row.get("position",[]); var q: Array=row.get("orientation",[])
		if p.size()!=3 or q.size()!=4: return {"error":"Original radial hook transform is incomplete"}
		var position:=Vector3(p[0],p[1],p[2]); var quaternion:=Quaternion(q[0],q[1],q[2],q[3]); var scale_value:=float(row.get("scale",1.0))
		if not position.is_finite() or not quaternion.is_finite() or quaternion.length_squared()<0.000001 or not is_finite(scale_value): return {"error":"Original radial hook transform is invalid"}
		var parent:=int(row.get("parent",-1))
		if parent>=poses.size() or parent < -1: return {"error":"Original radial hook hierarchy is invalid"}
		var pose:=Transform3D(Basis(quaternion.normalized()).scaled(Vector3.ONE*scale_value),position)
		if parent>=0: pose=poses[parent]*pose
		poses.append(pose)
		var name:=str(row.get("name","")).to_lower()
		if hooks.has(name): return {"error":"Original radial hook name is ambiguous"}
		hooks[name]=Vector2(pose.origin.x,-pose.origin.y)*100.0
	for name in ["center","text","0hook","1hook","2hook","3hook","4hook","5hook","6hook","7hook","0submenu","1submenu","2submenu","3submenu","4submenu","5submenu","6submenu","7submenu"]:
		if not hooks.has(name): return {"error":"Original radial attachment is missing: "+name}
	return {"hooks":hooks,"error":""}
