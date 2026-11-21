extends RefCounted
# Original ProcessTilePart1400cb890 / SetTileLights1400d3e60. Palette values
# come from physical LightColor rows, not TileColor or model-template edits.
static func f(value: float) -> float: return PackedFloat32Array([value])[0]
static func colors(indices: Array,table: Dictionary) -> Array:
	var result: Array=[]; var rows: Array=table.get("orderedRows",[])
	for index in indices:
		var physical:=int(index)&255; var row: Dictionary=rows[physical] if physical<rows.size() else {}; var rgb: Array=[]
		for column in ["RED","GREEN","BLUE"]:
			var selected:=""
			for key in table.get("columns",[]):
				if str(key).to_upper()==column: selected=str(key); break
			var value: String=str(table.get("defaultValue","****")) if row.is_empty() or selected.is_empty() else str(row.get(selected,"****"))
			rgb.append(f(value.to_float()))
		result.append(rgb)
	return result
static func apply(instance,model_name: String,palette: Array) -> Array:
	var prefix:=""
	for index in mini(60,model_name.length()):
		if model_name.unicode_at(index)==0: break
		prefix+=model_name[index].to_lower()
	var slots: Array=[null,null]
	for part in instance.parts:
		var name:=str(part.get_meta("native_part_name","")).to_lower()
		var index:=0 if name==prefix+"ml1" else (1 if name==prefix+"ml2" else -1)
		if index<0: continue
		for child in part.get_children():
			if child is OmniLight3D and child.has_meta("native_model_light_properties"): slots[index]=child; break
	var result: Array=[]
	for index in 2:
		var light=slots[index]
		if not is_instance_valid(light): result.append({"present":false,"changed":false}); continue
		var properties: Dictionary=light.get_meta("native_model_light_properties").duplicate(true); var color_value: Array=properties.get("color",[1.0,1.0,1.0]); var desired: Array=palette[index]; var changed:=false
		for channel in 3:
			if f(float(color_value[channel])*float(properties.get("multiplier",1)))!=f(float(desired[channel])): changed=true
		if changed:
			properties.merge({"color":desired.duplicate(),"multiplier":1.0,"shadow":1,"affectdynamic":1,"radius":10.0 if index==0 else 5.0,"shadowradius":12.0 if index==0 else 8.0},true)
			light.configure(properties); light.set_meta("native_light_priority",4)
		result.append({"present":true,"changed":changed,"color":properties.color.duplicate(),"radius":properties.get("radius",0),"shadowRadius":properties.get("shadowradius",0),"shadow":properties.get("shadow",0),"affectDynamic":properties.get("affectdynamic",0),"priority":light.get_meta("native_light_priority",properties.get("lightpriority",0))})
	return result
