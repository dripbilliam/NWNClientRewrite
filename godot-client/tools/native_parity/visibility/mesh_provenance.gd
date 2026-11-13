extends RefCounted
# Install-boundary diagnostics only. No geometry, image or Resource references.
# These facts do not classify blockers or change drawing/admission.
static func scalar(source: Dictionary,key: String) -> Variant:
	var value: Variant=source.get(key)
	return value if value is bool or value is int or value is String or value is float and is_finite(value) else null
static func bounds(source: Dictionary) -> Variant:
	if source.get("native_bounds_available")!=true: return null
	var value: Variant=source.get("native_bounds")
	if not value is Dictionary: return null
	var result:={}
	for key in ["min","max"]:
		var point: Variant=value.get(key)
		if not (point is Array or point is PackedFloat32Array) or point.size()!=3: return null
		var components: Array=[]
		for component in point:
			if not (component is int or component is float) or not is_finite(float(component)): return null
			components.append(component)
		result[key]=components
	return result
static func capture(bundle: Dictionary,row: Dictionary,part_index: int,model_index: int=0) -> Dictionary:
	var model: Dictionary=bundle.get("value",{})
	var mesh: Dictionary=row.get("mesh",{})
	var names: Variant=mesh.get("textures")
	var texture: Variant=str(names[0]).to_lower() if names is Array and not names.is_empty() else null
	var status:="not_available"
	if texture is String:
		status="no_bitmap_declared" if texture in ["","null"] else "prepared" if bundle.get("textures",{}).has(texture) else "not_in_prepared_bundle"
	var features: Variant=row.get("features")
	return {"version":1,"resource":str(bundle.get("resource_name",model.get("name",""))),"source_format":scalar(model,"format"),"model_index":model_index,"part_index":part_index,"part_name":str(row.get("name","")),"node_flags":scalar(row,"flags"),"node_is_aabb":features.has("aabb") if features is Array else null,"parsed_render":scalar(mesh,"render"),"original_alpha":scalar(row,"alpha"),"native_tilefade":scalar(mesh,"native_tilefade"),"native_tilefade_available":mesh.get("native_tilefade_available",false)==true,"native_tilefade_source":scalar(mesh,"native_tilefade_source"),"native_bounds":bounds(mesh),"native_bounds_available":mesh.get("native_bounds_available",false)==true,"native_bounds_valid":scalar(mesh,"native_bounds_valid"),"native_bounds_source":scalar(mesh,"native_bounds_source"),"texture_name":texture,"texture_resolution":status,"missing_texture":status=="not_in_prepared_bundle" if status!="not_available" else null}
static func detached(source: Dictionary) -> Dictionary:
	var result:={}
	for key in ["version","resource","source_format","model_index","part_index","part_name","node_flags","node_is_aabb","parsed_render","original_alpha","native_tilefade","native_tilefade_available","native_tilefade_source","native_bounds_available","native_bounds_valid","native_bounds_source","texture_name","texture_resolution","missing_texture"]:result[key]=scalar(source,key)
	result.native_bounds=bounds(source)
	return result
