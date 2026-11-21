extends RefCounted

const Controls = preload("res://systems/model_controllers.gd")
const EnhancedMaterial=preload("res://systems/native_render/native_model_material.gd")
const ColourScopes=preload("res://systems/native_data/model_colour_scopes.gd")
const PoseTiming=preload("res://systems/native_render/frame_profile.gd")
const ControllerPlan=preload("res://systems/native_data/model_control_plan.gd")
var profile_parts:=OS.get_environment("NWN_PROFILE_MODEL_PARTS")=="1"
var colour_scopes:=ColourScopes.create()
var _parts: Array = []
var _root_part: Dictionary
# Debugger/export reads materialize snapshots. The frame path uses private
# native storage, never a freshly allocated PackedByteArray per Part.
var parts: Array:
	get:
		_sync_views()
		return _parts
var root_part: Dictionary:
	get:
		_sync_views()
		return _root_part
	set(value): _root_part=value
static func configured_native_storage() -> bool:
	var args:=OS.get_cmdline_user_args()
	if args.has("--model-storage=views"): return false
	if args.has("--model-storage=native"): return true
	var choice:=OS.get_environment("NWN_MODEL_STORAGE")
	return choice=="native" or choice!="views" and OS.get_name()=="Windows"
var native_storage:=configured_native_storage()
var native_context: RefCounted
var native_revision:=0
var snapshot_revision:=0
var native_in_flight:=false
var native_calls:=0
var native_publish_calls:=0
var native_failures:=0
var direct_plan: Variant=null
var metadata: Dictionary
var position_scale := 1.0
var diagnostics: Array = []
var binding: Dictionary
var nodes: Array
static func configured_compiled_controls() -> bool:
	var args:=OS.get_cmdline_user_args()
	if args.has("--model-controls=scripted"): return false
	if args.has("--model-controls=compiled"): return true
	var choice:=OS.get_environment("NWN_MODEL_CONTROLS")
	return choice=="compiled" or choice!="scripted" and OS.get_name()=="Windows"
var compiled_controls:=configured_compiled_controls()
var compiled_control_available:=false
var compiled_control_calls:=0
var compiled_control_failures:=0
static func configured_direct_flush() -> bool:
	var args:=OS.get_cmdline_user_args()
	if args.has("--model-pose=arrays"): return false
	if args.has("--model-pose=direct"): return true
	return OS.get_environment("NWN_MODEL_POSE")!="arrays"
static func configured_root_hierarchy() -> bool:
	var args:=OS.get_cmdline_user_args()
	if args.has("--model-hierarchy=legacy"): return false
	if args.has("--model-hierarchy=root"): return true
	return OS.get_environment("NWN_MODEL_HIERARCHY")!="legacy"
var direct_flush:=configured_direct_flush()
var root_hierarchy:=configured_root_hierarchy()
var direct_flush_calls:=0
var root_hierarchy_calls:=0
static func configured_bulk_evaluation() -> bool:
	var args:=OS.get_cmdline_user_args()
	if args.has("--model-evaluation=individual"): return false
	if args.has("--model-evaluation=bulk"): return true
	var choice:=OS.get_environment("NWN_MODEL_EVALUATION")
	return choice=="bulk" or choice!="individual" and OS.get_name()=="Windows"
var bulk_evaluation:=configured_bulk_evaluation()
var bulk_available:=false
var bulk_calls:=0
var bulk_controls:=0
var bulk_empty_controls:=0
var bulk_failures:=0
static func configured_prepared_plan() -> bool:
	var args:=OS.get_cmdline_user_args()
	if args.has("--model-plan=dynamic"): return false
	if args.has("--model-plan=prepared"): return true
	var choice:=OS.get_environment("NWN_MODEL_PLAN")
	return choice=="prepared" or choice!="dynamic" and OS.get_name()=="Windows"
var prepared_plan:=configured_prepared_plan()
var plan_requests:=0
var plan_hits:=0
var plan_builds:=0
var plan_prepare_failures:=0
var plan_prepare_ms:=0.0
var plan_prepare_peak_ms:=0.0
var prepared_calls:=0
var prepared_failures:=0

func configure(data: Dictionary, source: Dictionary, rig_nodes: Array, manual: Dictionary = {}) -> void:
	compiled_control_available=ClassDB.class_exists("NwnParticleKernel") and ClassDB.class_has_method("NwnParticleKernel","model_control")
	bulk_available=compiled_control_available and ClassDB.class_has_method("NwnParticleKernel","model_hierarchy")
	if compiled_controls and not compiled_control_available: compiled_control_failures+=1; diagnose("compiled model controller kernel unavailable")
	metadata = data
	binding = source
	nodes = rig_nodes
	for index in data.parts.size():
		var original: Dictionary = data.parts[index]
		var storage := PackedByteArray()
		storage.resize(0x240)
		storage.fill(0)
		storage.encode_float(28, 1.0)
		storage.encode_float(44, 1.0)
		var fields := {16: 3, 28: 4, 44: 1}
		if original.type == "light":
			for pair in [[104, 3], [116, 1], [124, 1], [128, 1], [168, 1]]: fields[pair[0]] = pair[1]
			storage.encode_float(168, 1.0)
		elif original.type == "trimesh":
			fields[128] = 3; fields[168] = 1
			storage.encode_float(168, 1.0)
		elif original.type == "emitter":
			for key in data.emitterFields: fields[int(key)] = 3 if str(data.emitterFields[key]).begins_with("color") else 1
			storage.encode_float(0xe8, 1.0)
			for offset in [0x224, 0x225, 0x226]: storage[offset] = 255
		var object: Node3D = nodes[int(source.parts[index])]
		var materials: Array = []
		if original.type == "trimesh":
			for child in object.get_children():
				if child is MeshInstance3D:
					# A geometry-wide override wins over surface overrides. Animate
					# a private copy of the binding that is actually drawn; leaving
					# the shared pool override in place hides all controller changes.
					if child.material_override is StandardMaterial3D or child.material_override is EnhancedMaterial:
						var unique=child.material_override.duplicate()
						child.material_override=unique
						materials.append(_material_record(unique,original.transparencyHint))
						continue
					for surface in child.mesh.get_surface_count():
						var material: Material = child.get_active_material(surface)
						if material is StandardMaterial3D or material is EnhancedMaterial:
							var unique=material.duplicate()
							child.set_surface_override_material(surface, unique)
							materials.append(_material_record(unique,original.transparencyHint))
		_parts.append({"_native_index":index,"source": original, "object": object, "id30": original.node.id34, "dirty60": 0, "field8c": int(original.properties.get("isdynamic", 0)), "owner50": null, "children38": [], "childCount40": original.children.size(), "view": storage, "fields": fields, "materials": materials})
		if original.type=="light":
			for child in object.get_children():
				if child.has_method("publish_native_light"): _parts.back().light=child; break
	for part in _parts:
		for index in part.source.children: part.children38.append(_parts[int(index)])
		# Static node controllers initialize their Part before placement.
		control(part.source.node, part, 0, 0, 1)
	_root_part = _parts[int(data.root)]
	for index in manual:
		set_manual(int(index), manual[index].position, manual[index].quaternion)
	flush(manual)
	# Explicit legacy math/publication choices retain their own implementation;
	# a storage default must not silently override a rollback or reference mode.
	if native_storage and (not compiled_controls or not bulk_evaluation or not prepared_plan or not direct_flush or not root_hierarchy):native_storage=false
	if native_storage:
		if not ClassDB.class_exists("NwnModelPoseStorage"):
			native_failures+=1;diagnose("native model storage prerequisites unavailable");return
		var context: RefCounted=ClassDB.instantiate("NwnModelPoseStorage")
		var result: Dictionary=context.call("dispatch",0,{"parts":_parts,"binding":source.parts,"root":data.root,"emitter_fields":data.emitterFields})
		if result.has("error"):
			native_failures+=1;diagnose("native model storage configuration failed: "+str(result.error));return
		native_context=context;native_revision=int(result.revision);snapshot_revision=native_revision

func _material_record(material,source_hint: bool) -> Dictionary:
	# A lazy Part owner can arrive after actor alpha/vector publication. Capture
	# its raw Part input, not the already composed renderer colour/pass, or the
	# factor would be applied twice and a temporary fade would become a hint.
	if material.has_method("publish_actor_part_pose"):
		return {"material":material,"color":material.actor_part_color,"hint":source_hint or material.actor_part_blended or material.actor_base_transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED}
	return {"material":material,"color":material.albedo_color,"hint":source_hint or material.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED}
func _owned_index(part: Dictionary) -> int:
	var index:=int(part.get("_native_index",-1))
	return index if index>=0 and index<_parts.size() and is_same(part,_parts[index]) else -1

func _sync_views() -> void:
	var context:=native_context
	if context==null or not native_in_flight and snapshot_revision==native_revision: return
	var result: Dictionary=context.call("dispatch",5,{"since":snapshot_revision})
	if native_context!=context or result.has("error"): return
	if result.has("views"):
		for index in _parts.size():
			_parts[index].view=result.views[index];_parts[index].dirty60=result.dirty[index]
	snapshot_revision=int(result.revision)
	native_revision=snapshot_revision

func _native_dispatch(operation: int,input: Dictionary) -> Dictionary:
	# Retain the owner across synchronous Node/material callbacks. Closing during
	# publication requests deferred cleanup; never retry a partial mutation.
	var context:=native_context
	if context==null: return {"error":"Native model storage is closed"}
	var was_in_flight:=native_in_flight
	native_in_flight=true
	var result: Dictionary=context.call("dispatch",operation,input)
	native_in_flight=was_in_flight
	if native_context!=context: return result
	native_revision=int(result.get("revision",native_revision))
	if result.has("error"):
		native_failures+=1;diagnose("native model storage failed: "+str(result.error));push_error("Native model storage failed: "+str(result.error));return result
	for message in result.get("diagnostics",[]): diagnose(str(message))
	return result

func close() -> void:
	var context:=native_context
	native_context=null
	if context!=null: context.call("dispatch",8,{})
	_parts.clear();_root_part={};nodes=[];binding={};direct_plan=null

func storage_statistics() -> Dictionary:
	return native_context.call("dispatch",7,{}) if native_context!=null else {}

func part_for(rig_node: int) -> int:
	for index in binding.parts.size():
		if int(binding.parts[index]) == rig_node: return index
	return -1

func set_manual(rig_node: int, position: Vector3, quaternion: Quaternion) -> void:
	var index := part_for(rig_node)
	if index < 0: return
	_write(_parts[index], 16, [position.x, -position.z, position.y])
	_write(_parts[index], 28, [quaternion.w, quaternion.x, -quaternion.z, quaternion.y])

func read(part: Dictionary, offset: int, count: int) -> Array:
	assert(part.fields.get(offset) == count, "Native controller field is unavailable")
	var owned:=_owned_index(part)
	if native_context!=null and owned>=0:
		var values: Dictionary=native_context.call("dispatch",4,{"index":owned,"offset":offset,"count":count})
		return values.get("values",[])
	var result: Array = []
	for index in count: result.append(part.view.decode_float(offset + index * 4))
	return result

func write(part: Dictionary, offset: int, value: Array) -> void:
	_write(part,offset,value)
	_sync_views()

func _write(part: Dictionary, offset: int, value: Array) -> void:
	assert(part.fields.get(offset) == value.size(), "Native controller field is unavailable")
	var owned:=_owned_index(part)
	if native_context!=null and owned>=0:
		var current:=snapshot_revision==native_revision
		var result:=_native_dispatch(3,{"index":owned,"offset":offset,"values":value})
		if not result.has("error") and current and native_context!=null:
			# Explicit writes preserve the existing PackedByteArray alias, as
			# encode_float does in the reference. Controller evaluation replaces
			# the logical view; a retained prior controller snapshot stays old.
			for index in value.size():part.view.encode_float(offset+index*4,value[index])
			snapshot_revision=native_revision
		return
	for index in value.size(): part.view.encode_float(offset + index * 4, value[index])

func diagnose(message: String) -> void:
	if not diagnostics.has(message): diagnostics.append(message)

func control(node: Dictionary, part: Dictionary, previous: float, time: float, weight: float) -> void:
	if int(node.flags98) & 0x80:
		diagnose("native animated-vertex solver unavailable")
		return
	var applied:=false
	if compiled_controls and compiled_control_available:
		compiled_control_calls+=1
		var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_control",node,part.view,part.fields,time,weight,position_scale)
		if result.has("view"):
			part.view=result.view; applied=true
		else:
			compiled_control_failures+=1; diagnose("compiled model controller rejected storage: "+str(result.get("error","unknown failure")))
	if not applied: Controls.control(node, part, previous, time, weight, {"read": read, "write": write, "positionScale": func(): return position_scale, "activeMotionRun": func(): return false, "motion": func(_c, _p, _n, _from, _to): pass})
	if int(node.flags98) & 256: diagnose("native dangly solver unavailable")

func apply(tree: Dictionary, previous: float, time: float, weight: float, scale_value: float, manual: Dictionary, plan: Variant=null) -> void:
	var timed:=profile_parts and PoseTiming.enabled
	if native_context!=null:
		if plan==null:
			if direct_plan==null or not is_same(direct_plan.source,tree):
				var acquired:=ControllerPlan.acquire(tree)
				if acquired.has("error"):
					native_failures+=1;diagnose("native model storage plan failed: "+str(acquired.error));return
				direct_plan=acquired.value
			plan=direct_plan
		native_calls+=1;native_publish_calls+=1;bulk_calls+=1;prepared_calls+=1
		var result:=_native_dispatch(1,{"plan":plan.blob,"time":time,"weight":weight,"scale":scale_value,"manual":manual,"scope":ColourScopes.selected(colour_scopes),"profile":timed})
		position_scale=float(result.get("scale",position_scale))
		bulk_controls+=int(result.get("controls",0));bulk_empty_controls+=int(result.get("empty_controls",0))
		if timed and not result.has("error"):
			PoseTiming.record("model_parts_manual_ms",float(result.manual_ms));PoseTiming.record("model_parts_evaluate_ms",float(result.evaluate_ms));PoseTiming.record("model_parts_publish_ms",float(result.publish_ms))
		return
	var began:=Time.get_ticks_usec() if timed else 0
	position_scale = Controls.f(scale_value)
	for index in _parts.size(): _parts[index].dirty60 = 1 if manual.has(int(binding.parts[index])) else 0
	if timed: PoseTiming.finish("model_parts_manual_ms",began)
	if bulk_evaluation and compiled_controls:
		bulk_calls+=1
		if not bulk_available:
			bulk_failures+=1; diagnose("bulk model hierarchy unavailable"); push_error("Requested bulk model hierarchy unavailable"); return
		var ports: Dictionary={}
		if plan!=null: ports.plan=plan.blob;prepared_calls+=1
		if timed: ports.allocations=true;began=Time.get_ticks_usec()
		var result: Dictionary=ClassDB.class_call_static("NwnParticleKernel","model_hierarchy",_root_part,tree,previous,time,weight,position_scale,{"depth":0},ports)
		if timed:
			PoseTiming.finish("model_parts_evaluate_ms",began)
			PoseTiming.count("count_model_part_arrays",int(result.get("part_arrays",0)));PoseTiming.count("count_model_part_bytes",int(result.get("part_bytes",0)));PoseTiming.count("count_model_part_result_dictionaries",int(result.get("part_result_dictionaries",0)))
		if result.has("error"):
			# Even the context depth is imperative state. Never rerun a partial
			# traversal through the reference and duplicate callbacks or writes.
			bulk_failures+=1
			if plan!=null: prepared_failures+=1
			diagnose("bulk model hierarchy failed: "+str(result.error)); push_error("Bulk model hierarchy failed: "+str(result.error)); return
		if plan!=null and not result.get("prepared",false): prepared_failures+=1;push_error("Requested model plan was not executed");return
		bulk_controls+=int(result.controls); bulk_empty_controls+=int(result.empty_controls)
		for message in result.diagnostics: diagnose(str(message))
		flush(manual); return
	var providers:={"control": control, "light": func(part): return part if part.source.type == "light" else null,
		"animateStaticLight": func(_owner, light):
			if not is_instance_valid(light.get("light")): diagnose("native static-light invalidation unavailable")}
	if root_hierarchy:
		root_hierarchy_calls+=1
		Controls.hierarchy_root(_root_part,tree,previous,time,weight,{"depth":0},providers)
	else: Controls.hierarchy(_root_part,tree,previous,time,weight,{"depth":0},providers)
	flush(manual)

static func srgb(value: float) -> float:
	return value * 0.0773993808 if value < 0.04045 else pow(value * 0.9478672986 + 0.0521327014, 2.4)

func flush(manual: Dictionary = {}) -> void:
	if native_context!=null:
		native_publish_calls+=1
		var timed:=profile_parts and PoseTiming.enabled
		var result:=_native_dispatch(2,{"manual":manual,"scope":ColourScopes.selected(colour_scopes),"profile":timed})
		if timed and not result.has("error"): PoseTiming.record("model_parts_publish_ms",float(result.publish_ms))
		return
	var began:=Time.get_ticks_usec() if profile_parts and PoseTiming.enabled else 0
	if direct_flush:
		_flush_direct(manual)
		if began>0: PoseTiming.finish("model_parts_publish_ms",began)
		return
	var scoped: Variant=ColourScopes.selected(colour_scopes)
	for index in _parts.size():
		var part: Dictionary = _parts[index]
		if manual.has(int(binding.parts[index])): continue
		var position := read(part, 16, 3)
		var q := read(part, 28, 4)
		var scale_value: float = read(part, 44, 1)[0]
		var object: Node3D = part.object
		object.position = Vector3(position[0], position[2], -position[1])
		object.quaternion = Quaternion(q[1], q[3], -q[2], q[0])
		object.scale = Vector3.ONE * scale_value
		if part.source.type == "trimesh":
			var alpha := clampf(read(part, 168, 1)[0], 0.0, 1.0)
			var color := read(part, 128, 3)
			if scoped!=null: color=scoped
			for row in part.materials:
				var material=row.material
				if material.has_method("publish_actor_part_pose"):
					material.publish_actor_part_pose(Color(scoped[0],scoped[1],scoped[2],alpha) if scoped!=null else Color(row.color.r,row.color.g,row.color.b,alpha),Color(srgb(color[0]),srgb(color[1]),srgb(color[2])),row.hint or alpha<1.0);continue
				material.albedo_color = Color(scoped[0],scoped[1],scoped[2],alpha) if scoped!=null else Color(row.color.r, row.color.g, row.color.b, alpha)
				material.emission_enabled = color.any(func(value): return value != 0)
				material.emission = Color(srgb(color[0]), srgb(color[1]), srgb(color[2]))
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if row.hint or alpha < 1 else BaseMaterial3D.TRANSPARENCY_DISABLED
		elif part.source.type == "light":
			_publish_light(part)
	if began>0: PoseTiming.finish("model_parts_publish_ms",began)

func _flush_direct(manual: Dictionary) -> void:
	# Each private Part is created at a fixed size with these declared fields;
	# controller publication preserves that storage layout and byte length.
	# Decode the same floats without constructing three temporary read Arrays.
	direct_flush_calls+=1
	var scoped: Variant=ColourScopes.selected(colour_scopes)
	for index in _parts.size():
		var part: Dictionary=_parts[index]
		if manual.has(int(binding.parts[index])): continue
		var view: PackedByteArray=part.view; var object: Node3D=part.object
		object.position=Vector3(view.decode_float(16),view.decode_float(24),-view.decode_float(20))
		object.quaternion=Quaternion(view.decode_float(32),view.decode_float(40),-view.decode_float(36),view.decode_float(28))
		object.scale=Vector3.ONE*view.decode_float(44)
		if part.source.type=="trimesh":
			var alpha:=clampf(view.decode_float(168),0.0,1.0)
			var red:=view.decode_float(128); var green:=view.decode_float(132); var blue:=view.decode_float(136)
			if scoped!=null: red=float(scoped[0]); green=float(scoped[1]); blue=float(scoped[2])
			for row in part.materials:
				var material=row.material
				if material.has_method("publish_actor_part_pose"):
					material.publish_actor_part_pose(Color(red,green,blue,alpha) if scoped!=null else Color(row.color.r,row.color.g,row.color.b,alpha),Color(srgb(red),srgb(green),srgb(blue)),row.hint or alpha<1.0);continue
				material.albedo_color=Color(red,green,blue,alpha) if scoped!=null else Color(row.color.r,row.color.g,row.color.b,alpha)
				material.emission_enabled=red!=0.0 or green!=0.0 or blue!=0.0
				material.emission=Color(srgb(red),srgb(green),srgb(blue))
				material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if row.hint or alpha<1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
		elif part.source.type=="light": _publish_light(part)

func _publish_light(part: Dictionary) -> void:
	var light=part.get("light")
	if not is_instance_valid(light): diagnose("native animated-light renderer binding unavailable"); return
	var view: PackedByteArray=part.view
	light.publish_native_light(Color(view.decode_float(104),view.decode_float(108),view.decode_float(112)),view.decode_float(116),view.decode_float(124),view.decode_float(128),view.decode_float(168))

func set_colour_scope(scope: int,rgb: Variant,manual: Dictionary={}) -> bool:
	if not ColourScopes.set_colour(colour_scopes,scope,rgb): return false
	flush(manual); return true

func emitter_properties(rig_node: int) -> Dictionary:
	var part_index := part_for(rig_node)
	if part_index < 0 or _parts[part_index].source.type != "emitter": return {}
	if native_context!=null: return native_context.call("dispatch",6,{"index":part_index})
	var part: Dictionary = _parts[part_index]
	var result := {}
	for key in metadata.emitterFields:
		var name := str(metadata.emitterFields[key])
		var offset := int(key)
		if name.begins_with("percent") or name == "detonate": result[name] = int(part.view[offset])
		elif name.begins_with("color"): result[name] = read(part, offset, 3)
		else: result[name] = read(part, offset, 1)[0]
	return result
