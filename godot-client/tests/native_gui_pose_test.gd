extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
const Animated=preload("res://systems/native_data/animated_mesh.gd")
const Geometry=preload("res://systems/native_data/inventory_equipment_layout.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Icons=preload("res://systems/native_item_icons.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original animated GUI corpus mounts read-only")
	var source: PackedByteArray=catalog.get_resource("scrollbar_simple",2002); var parser:=Actor.new(); var model:=parser.parse(source)
	check(parser.failure.is_empty(),"Original scrollbar binary including animated vertex/UV payload decodes")
	var asset: Dictionary=parser.rig_asset(model); var before:=Cache.digest(var_to_bytes([model,asset])); var payloads:=0
	for clip in model.animations:
		for track in clip.get("mesh_tracks",[]):
			var data: Dictionary=track.data
			if int(data.position_frames)>0 or int(data.uv_frames)>0: payloads+=1
			for at in [0.0,float(clip.length)*0.25,float(clip.length)*0.5,float(clip.length),float(clip.length)+10]:
				var value:=Animated.sample(data,at)
				check((not value.has("positions") or value.positions.size()==int(data.vertices)*3) and (not value.has("uv") or value.uv.size()==int(data.vertices)*2),"Original vertex-major stream preserves geometry/UV cardinality")
	check(payloads>=2,"Original size and thumbsize retain their animated mesh payloads")
	for length in [75.0,312.0,600.0]:
		for thumb in [20.0,60.0]:
			var poses: Array=[{"clip":"size","time":(length-3)/30.0},{"clip":"thumbsize","time":(thumb-3)/30.0}]
			var result:=Pose.compose(asset,poses); var nodes:=Pose.nodes(model,poses); var geometry:=Geometry.model(nodes.model)
			check(result.error.is_empty() and result.meshes.size()>=2 and nodes.error.is_empty(),"Original GUI states compose both transform and vertex/UV channels")
			check(absf(geometry.hooks.max.y-(length-6))<0.001,"Original size animation places the max hook with the recovered six-pixel inset")
			var rail_min:=INF; var rail_max:=-INF
			for index in result.meshes:
				if str(model.nodes[int(index)].name).to_lower()!="planebkg" or not result.meshes[index].has("positions"): continue
				var values: PackedFloat32Array=result.meshes[index].positions
				for at in range(1,values.size(),3): rail_min=minf(rail_min,values[at]); rail_max=maxf(rail_max,values[at])
			check(absf((rail_max-rail_min)*100.0-length)<0.01,"A later thumb-only state preserves the rail's earlier animated vertices")
			var minimum:=INF; var maximum:=-INF
			for index in result.meshes:
				if str(model.nodes[int(index)].name).to_lower()!="thumbmain": continue
				var values: PackedFloat32Array=result.meshes[index].positions
				for at in range(1,values.size(),3): minimum=minf(minimum,values[at]); maximum=maxf(maximum,values[at])
			check(absf((maximum-minimum)*100.0-(thumb-2.99))<0.01,"Original thumb center uses its authored3.01-pixel minimum and cap overlap rather than a guessed four-pixel subtraction")
	check(Cache.digest(var_to_bytes([model,asset]))==before,"GUI composition leaves shared original model and rig data immutable")
	check(not Pose.compose(asset,[{"clip":"missing","time":0}]).error.is_empty(),"Missing original state fails explicitly")
	check(not Pose.compose(asset,[{"clip":"size","time":NAN}]).error.is_empty(),"Non-finite GUI state time fails explicitly")
	check(Icons.model_key("scrollbar_simple","",{},0,"gui_scrollbar",[{"clip":"thumbsize","time":1}])!=Icons.model_key("scrollbar_simple","",{},0,"gui_scrollbar",[{"clip":"thumbsize","time":2}]),"Different original model sizes cannot share a raster cache key")
	var animated_offset:=-1
	for clip in model.animations:
		for node in clip.controller_nodes:
			var offset:=int(node.offset)+12
			if source.decode_u32(offset+108)&128 and source.decode_u32(offset+0x2a0)>0: animated_offset=offset; break
		if animated_offset>=0: break
	check(animated_offset>=0,"Original animated node offset comes from its physical hierarchy")
	if animated_offset>=0:
		for mutation in ["count","offset","period"]:
			var bytes:=source.duplicate()
			if mutation=="count": bytes.encode_u32(animated_offset+0x2a0,0x7fffffff)
			elif mutation=="offset": bytes.encode_u32(animated_offset+0x298,0x7fffffff)
			else: bytes.encode_float(animated_offset+0x270,NAN)
			var invalid:=Actor.new(); invalid.parse(bytes); check(not invalid.failure.is_empty(),"Malformed original animated mesh rejects "+mutation+" before allocation or drawing")
	var ascii:="newmodel native_gui\nsetsupermodel native_gui NULL\nbeginmodelgeom native_gui\nnode dummy native_gui\n parent NULL\nendnode\nnode animmesh center\n parent native_gui\n bitmap gui_scrollbar\n verts 3\n 0 0 0\n 1 0 0\n 0 1 0\n tverts 3\n 0 0 0\n 1 0 0\n 0 1 0\n faces 1\n 0 1 2 1 0 1 2 0\nendnode\nendmodelgeom native_gui\nnewanim size native_gui\nlength 0.5\ntranstime 0\nanimroot native_gui\nnode animmesh center\n parent native_gui\n sampleperiod 0.5\n animverts 6\n 0 0 0\n 1 0 0\n 0 1 0\n 0 0 0\n 1 0 0\n 0 3 0\n animtverts 6\n 0 0 0\n 1 0 0\n 0 1 0\n 0 0 0\n 1 0 0\n 0 3 0\nendnode\ndoneanim size native_gui\ndonemodel native_gui\n"
	for packed in [false,true]:
		var reader:=Actor.new(); reader.packed_keys=packed; var authored:=reader.parse(ascii.to_utf8_buffer())
		check(reader.failure.is_empty(),"ASCII GUI vertex/UV animation parses in both key storage modes")
		if not reader.failure.is_empty(): continue
		var data: Dictionary=authored.animations[0].mesh_tracks[0].data
		for pair in [[0.0,1.0,1.0],[0.25,2.0,2.0],[0.5,3.0,3.0],[1.0,3.0,3.0],[-1.0,1.0,-3.0]]:
			var sample:=Animated.sample(data,float(pair[0])); check(absf(sample.positions[7]-float(pair[1]))<0.00001 and absf(sample.uv[5]-float(pair[2]))<0.00001,"ASCII frame-major source maps to native vertex-major interpolation, including the shared-index negative-time UV behavior")
	var malformed:=Actor.new(); malformed.parse(ascii.replace("sampleperiod 0.5","sampleperiod 0").to_utf8_buffer()); check(not malformed.failure.is_empty(),"Multiple ASCII animated frames cannot use an invalid zero period")
	var unequal:=Animated.sample({"vertices":1,"period":1.0,"position_frames":2,"uv_frames":3,"positions":PackedFloat32Array([0,0,0,1,0,0]),"uv":PackedFloat32Array([0,0,10,0,20,0])},3.0)
	check(unequal.positions[0]==1 and unequal.uv[0]==30,"Original position clamp updates the shared UV sample index even when stream lengths differ")
	var report:=FileAccess.open(output,FileAccess.WRITE); report.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_sha256":Cache.digest(source),"scope":"Original binary scrollbar payload and fixed-state geometry, immutable composition, malformed bounds/counts, cache separation and authored ASCII topology/interpolation. Original native runtime and all animated mesh game effects are not claimed."},"\t")); report.close(); print("NATIVE_GUI_POSE ",checks," checks / ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
