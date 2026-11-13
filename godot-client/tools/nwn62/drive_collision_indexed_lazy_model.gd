extends "res://tools/nwn62/drive_collision_indexed_before_reindex.gd"

# Private hypothesis: preserve Rules.cell's exact/case-insensitive precedence,
# but resolve the fallback Model column only if ModelName is absent.
static func _lazy_model_name(data: Dictionary)->Variant:
	if data.has("ModelName"):return data["ModelName"]
	for key in data:
		if str(key).to_lower()=="modelname":return data[key]
	return Rules.cell(data,"Model","")
func descriptor(object: Dictionary)->Dictionary:
	var kind:=int(object.objectType);var state: Dictionary=object.get("replicated",{});var fixed: Dictionary=object.get("staticState",object.get("lightState",{}));var data: Dictionary={}
	if kind==9:data=row("placeables",int(state.get("appearance",fixed.get("appearance",-1))))
	elif kind==10:
		var type:=int(state.get("doorType",0));data=row("genericdoors" if type==0 else "doortypes",int(state.get("genericType",0)) if type==0 else type)
		if str(Rules.cell(data,"VisibleModel","1"))=="0":return {}
	else:return {}
	var name:=str(_lazy_model_name(data)).to_lower()
	if name in ["","****"]:return {}
	return {"model":name,"door":kind==10,"state":int(state.get("doorOpenState",0))}
