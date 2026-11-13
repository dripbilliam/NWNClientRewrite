extends RefCounted
# Call once from a separately pinned diagnostic driver. No _process hook or
# counters are installed in the profile-off candidate.
static func snapshot(tree: SceneTree)->Dictionary:
	var result:={"lights":0,"eligible_now":0,"final_publications":0,"original_publications":0,"inherited":0,"children":0,"visibility_observers":0,"input_or_slot_guard":0}
	for lamp in tree.get_nodes_in_group("native_original_model_lights"):
		if not lamp.has_method("_can_publish_final"):continue
		result.lights+=1
		result.final_publications+=int(lamp.publication_final_count)
		result.original_publications+=int(lamp.publication_original_count)
		var inherited: bool=lamp.get_script().get_base_script()!=null
		var children: bool=lamp.get_child_count(true)!=0
		var observers: bool=not lamp.visibility_changed.get_connections().is_empty()
		if inherited:result.inherited+=1
		if children:result.children+=1
		if observers:result.visibility_observers+=1
		var inputs: bool=lamp._can_publish_final(lamp.native_properties)
		if not inputs and not children and not observers:result.input_or_slot_guard+=1
		if not inherited and inputs:result.eligible_now+=1
	return result
