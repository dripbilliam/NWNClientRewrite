extends RefCounted
# Part08f560/08f740 and Gob08f680. Stored FLOAT areas and physical child order,
# including skins (flags &0x21); never weights recomputed from animated meshes.
const M=preload("res://systems/native_render/particle_math.gd")
static func graph(parts: Array) -> Dictionary:
	var rows: Dictionary={}; var root: Variant=null
	for part in parts:
		if part.area==null: return {"error":"Original stored mesh area unavailable: "+str(part.name)}
		var row:={"name":part.name,"area":M.f(float(part.area)),"children":[]}; rows[int(part.index)]=row
		if int(part.parent)<0:
			if root!=null: return {"error":"Original physical impact graph has multiple roots"}
			root=row
		elif not rows.has(int(part.parent)): return {"error":"Original physical impact graph parent unavailable"}
		else: rows[int(part.parent)].children.append(row)
	return {"root":root,"partArea":-1.0} if root!=null else {"error":"Original physical impact graph is empty"}
static func area(part: Dictionary) -> float:
	var total:=M.f(float(part.area))
	for child in part.children: total=M.f(total+area(child))
	return total
static func select(part: Dictionary,remaining: Array) -> Variant:
	var local:=M.f(float(part.area))
	if float(remaining[0])<local: return part
	remaining[0]=M.f(float(remaining[0])-local)
	for child in part.children:
		var found: Variant=select(child,remaining)
		if found!=null: return found
	return null
static func choose(model: Dictionary,random: Callable) -> Variant:
	var total:=float(model.get("partArea",-1))
	if total==-1: total=area(model.root); model.partArea=total
	if total==0: return null
	var draw:=int(random.call()); var remaining: Array=[M.f(M.f(M.f(draw%10000)*M.f(total))/10000.0)]
	if model.root==null: model.partArea=0.0; return null
	var found: Variant=select(model.root,remaining)
	return str(found.name) if found!=null else str(model.root.name)
