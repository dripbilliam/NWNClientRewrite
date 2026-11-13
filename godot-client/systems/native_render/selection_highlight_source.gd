extends RefCounted
# Registration-boundary adapter over the existing physical owners. No world
# registry, vertex readback, mesh preparation or public Node/Resource API.
static func property(owner: Object,name: String) -> Variant:
	if not is_instance_valid(owner):return null
	for item in owner.get_property_list():
		if str(item.name)==name:return owner.get(name)
	return null
static func collect(owner: Node3D) -> Dictionary:
	var result:={"available":false,"parts":[],"missing":[],"skin_parts":0,"geometry_parts":0,"retired_supported":false}
	if not is_instance_valid(owner):return result
	result.retired_supported=property(owner,"retired") is bool
	var physical: Array=[]
	var rigs: Variant=property(owner,"rigs")
	if rigs is Node and is_instance_valid(rigs):
		var id: Variant=property(owner,"object_id")
		var entities: Variant=property(rigs,"entities")
		if not entities is Dictionary or id==null or not entities.has(id):return result
		var models: Variant=entities[id].get("model_parts")
		if not models is Array:return result
		for model in models:
			if not model is Array:return result
			for index in model:
				var part: Variant=rigs.node_at(int(id),int(index))
				if part is Node3D:physical.append(part)
	else:
		var parts: Variant=property(owner,"parts")
		if not parts is Array:return result
		physical=parts
	var seen: Dictionary={}
	for part in physical:
		if not part is Node3D or not is_instance_valid(part) or seen.has(part.get_instance_id()):continue
		seen[part.get_instance_id()]=true
		if not part.has_meta("native_mesh_source"):continue # Ordinary dummy/anchor.
		var source: Variant=part.get_meta("native_mesh_source")
		if not source is Dictionary:result.missing.append("Part provenance unavailable");continue
		var flags: Variant=source.get("node_flags")
		if not flags is int or flags<0:result.missing.append("Canonical source node kind unavailable");continue
		if (flags&0x20)==0:continue
		result.geometry_parts+=1
		if (flags&0x40)!=0:result.skin_parts+=1;continue # Native AsPartSkin gate.
		if source.get("native_bounds_available")!=true or source.get("native_bounds_valid")!=true or not source.get("native_bounds") is Dictionary:
			result.missing.append("Authored bounds unavailable for "+str(source.get("part_name","")));continue
		# Part34 starts1. Every Part represented here has TriMesh geometry, so
		# TreeSetGeometryFlags retains it. Explicit native subtree overrides use
		# their own metadata; neither mesh.visible nor authored render/alpha is it.
		var enabled:=true;var ancestor: Node=part
		while ancestor!=null and ancestor!=owner:
			if ancestor.has_meta("native_highlight_subtree_enabled"):
				var value: Variant=ancestor.get_meta("native_highlight_subtree_enabled")
				if not value is bool:result.missing.append("Explicit subtree state unavailable");enabled=false;break
				enabled=enabled and value
			ancestor=ancestor.get_parent()
		result.parts.append({"anchor":part,"native_bounds":source.native_bounds.duplicate(true),"is_skin":false,"subtree_enabled":enabled,"model_index":int(source.get("model_index",0))})
	result.available=true
	return result
static func layer(owner: Object) -> Variant:
	var value: Variant=property(owner,"actor_alpha")
	return value if value!=null else property(owner,"renderer_alpha")
