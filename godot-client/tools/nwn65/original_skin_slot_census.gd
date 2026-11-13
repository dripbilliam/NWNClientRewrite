extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const ActorModel=preload("res://systems/native_data/actor_model.gd")

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var report: String=""
	var install: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.substr(9)
		elif arg.begins_with("--install="):install=arg.substr(10)
	if report.is_empty() or install.is_empty() or FileAccess.file_exists(report):quit(2);return
	var failures: Array=[]
	var catalog:=Catalog.new()
	if not catalog.mount_install(install):failures.append("Original install catalog mount failed")
	var rows: Array=[]
	for name in ["pme0_robe038","c_goldem","pme2_robe030","pmh0_robe038","pfe0_robe032"]:
		var bytes: PackedByteArray=catalog.read_resource(name,2002)
		if bytes.is_empty():failures.append(name+": source missing");continue
		var parser:=ActorModel.new();parser.packed_keys=true
		var model: Dictionary=parser.parse(bytes)
		if not parser.failure.is_empty():failures.append(name+": "+str(parser.failure));continue
		for index in model.nodes.size():
			var node: Dictionary=model.nodes[index]
			if not node.has("skin"):continue
			var skin: Dictionary=node.skin
			var slots: Array=Array(skin.boneConstantSlots)
			var weights: PackedFloat32Array=skin.weights
			var indices: PackedInt32Array=skin.boneIndices
			var used: Dictionary={}
			for component in mini(weights.size(),indices.size()):
				if weights[component]>0.0:used[int(indices[component])]=true
			var active:=0
			var first_root:=false
			for slot in mini(64,slots.size()):
				if int(slots[slot])==0:
					if first_root:break
					first_root=true
				if int(slots[slot])>=0:active+=1
			rows.append({"resource":name,"source_bytes":bytes.size(),"node_index":index,"node_name":str(node.name),"declared_slots":slots.size(),"active_physical_slots":active,"weighted_slot_indices":used.keys().size(),"maximum_weighted_slot":used.keys().max() if not used.is_empty() else -1,"weight_components":weights.size()})
	var result:={"passed":failures.is_empty(),"failures":failures,"rows":rows,"scope":"Five installed skin-bearing names from the saved original-world entry report decoded read-only. Counts weighted skin slots and active physical slots; not live Arelith prevalence, FPS, or authorization to omit authored bone callbacks."}
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify({"passed":result.passed,"failures":failures,"skins":rows.size(),"rows":rows}));quit(0 if failures.is_empty() else 1)
