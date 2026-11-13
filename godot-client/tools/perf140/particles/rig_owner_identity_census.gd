extends RefCounted
# Explicit one-shot companion to static_leaf_census.process_tree.rig_owners.
# Resolve only the supplied full IDs, then walk their parent chains. Never
# called from a frame loop; does not traverse or copy the whole world store.
static func _property_names(node: Object) -> Dictionary:
	var names: Dictionary={}
	for property: Dictionary in node.get_property_list():names[str(property.name)]=true
	return names
static func _script_path(node: Node) -> Variant:
	var script: Script=node.get_script()
	return script.resource_path if script!=null else null
static func _names(parent: Node,properties: Dictionary) -> Variant:
	if not properties.has("model_names"):return null
	var value: Variant=parent.get("model_names")
	if not value is Array:return null
	var result: Array=[]
	for name in value:
		if not name is String and not name is StringName:return null
		result.append(str(name))
	return result
static func _zero(row: Dictionary,keys: Array) -> bool:
	for key: String in keys:
		if not row.has(key) or not row[key] is int or int(row[key])!=0:return false
	return true
static func _manual_only(row: Dictionary) -> bool:
	return row.get("processing")==true and _zero(row,["animated_models","attachments","skins"]) and row.get("manual_poses") is int and int(row.manual_poses)>0
static func _idle(row: Dictionary) -> bool:
	return row.get("processing")==true and _zero(row,["animated_models","manual_poses","attachments","skins"])
static func _augment(scope_root: Node,original: Dictionary) -> Dictionary:
	# Keep only the original primitive census fields; malformed supplied rows
	# cannot smuggle a Node/Resource/Callable into this detached export.
	var row: Dictionary={}
	for key: String in ["node_id","animated_models","attachments","entities","manual_poses","models","native_owners","playing_players","skins"]:
		var value: Variant=original.get(key)
		row[key]=value if value is int else null
	row.processing=original.get("processing") if original.get("processing") is bool else null
	row.merge({"identity_resolved":false,"identity_error":null,"rig_path":null,"rig_script":null,"parent_id":null,"parent_path":null,"parent_script":null,"parent_native_class":null,"parent_object_id":null,"model_names":null,"native_model_name":null,"generated_meta_present":false,"native_generated_placeable_id":null,"generated_owner_path":null,"generated_plan_dynamic":null,"manual_only":_manual_only(original),"strictly_idle":_idle(original)},true)
	if not original.get("node_id") is int:row.identity_error="full node_id is unavailable or not an integer";return row
	var object: Object=instance_from_id(int(original.node_id))
	if not is_instance_valid(object) or not object is Node:row.identity_error="full node lifetime is absent or no longer a Node";return row
	var rig: Node=object
	if rig!=scope_root and not scope_root.is_ancestor_of(rig):row.identity_error="resolved Node is outside this current world scope";return row
	row.identity_resolved=true;row.rig_path=str(rig.get_path());row.rig_script=_script_path(rig)
	var parent:=rig.get_parent()
	if parent!=null:
		row.parent_id=parent.get_instance_id();row.parent_path=str(parent.get_path());row.parent_script=_script_path(parent);row.parent_native_class=parent.get_class()
		var properties:=_property_names(parent)
		row.model_names=_names(parent,properties)
		if properties.has("object_id"):
			var id: Variant=parent.get("object_id")
			if id is int:row.parent_object_id=id
	var current:=parent
	for _depth in 128:
		if current==null:break
		if row.native_model_name==null and current.has_meta("native_model_name"):
			var model: Variant=current.get_meta("native_model_name")
			if model is String or model is StringName:row.native_model_name=str(model)
		if not row.generated_meta_present and current.has_meta("native_generated_placeable_id"):
			row.generated_meta_present=true;row.generated_owner_path=str(current.get_path())
			var id: Variant=current.get_meta("native_generated_placeable_id")
			if id is int:
				row.native_generated_placeable_id=id
				var light_owner:=current.get_parent()
				if light_owner!=null and _property_names(light_owner).has("configurations"):
					var configurations: Variant=light_owner.get("configurations")
					if configurations is Dictionary and configurations.get(id) is Dictionary:
						var plan: Dictionary=configurations[id]
						if plan.get("dynamic") is bool:row.generated_plan_dynamic=plan.dynamic
		if current==scope_root:break
		current=current.get_parent()
	row["generated_light_manual_candidate"]=row.manual_only and row.generated_meta_present and row.native_generated_placeable_id is int and row.native_model_name=="fx_placeable01" and original.get("manual_poses")==1 and original.get("models")==1 and _zero(original,["native_owners","playing_players"])
	return row
static func capture(scope_root: Node,rig_rows: Array,measurement_complete: bool=false) -> Dictionary:
	var report:={"version":1,"read_only":true,"frame_hook_added":false,"measurement_complete":measurement_complete,"rows":[],"errors":[],"summary":{"requested":rig_rows.size(),"resolved":0,"unresolved":0,"manual_only":0,"strictly_idle":0,"generated_light_manual_candidates":0,"generated_dynamic":0,"generated_static":0,"generated_dynamic_unknown":0}}
	if not measurement_complete:report.errors.append("Explicit post-measurement invocation is required");return report
	if not is_instance_valid(scope_root) or not scope_root.is_inside_tree():report.errors.append("A live current-world scope is required");return report
	if OS.get_thread_caller_id()!=OS.get_main_thread_id():report.errors.append("Main-thread one-shot only");return report
	for original in rig_rows:
		if not original is Dictionary:report.errors.append("Non-Dictionary census row is unavailable");continue
		var row:=_augment(scope_root,original);report.rows.append(row)
		report.summary["resolved" if row.identity_resolved else "unresolved"]+=1
		if row.manual_only:report.summary.manual_only+=1
		if row.strictly_idle:report.summary.strictly_idle+=1
		if row.get("generated_light_manual_candidate",false):
			report.summary.generated_light_manual_candidates+=1
			if row.generated_plan_dynamic is bool:report.summary["generated_dynamic" if row.generated_plan_dynamic else "generated_static"]+=1
			else:report.summary.generated_dynamic_unknown+=1
	return report
