extends SceneTree
const Ascii=preload("res://systems/native_data/ascii_model.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Capture=preload("res://systems/native_data/capture_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, reason: String) -> void:
	checks+=1
	if not value: failures.append(reason)
func source_point(values: Array) -> Vector3: return Vector3(values[0],values[1],values[2])
func corner_normal(mesh: Dictionary,corner: int) -> Vector3:
	var normals: PackedFloat32Array=mesh.normals
	var index:=corner*3
	return Vector3(normals[index],normals[index+1],normals[index+2])
func check_smoothing() -> void:
	var source:="""newmodel smooth
beginmodelgeom smooth
node trimesh root
parent NULL
verts 4
0 0 0
2 0 0
0 1 0
0 0 1.5
tverts 5
0 0 0
1 0 0
0 1 0
1 1 0
0.5 0.5 0
faces 4
0 1 2 0x1 0 1 2 0
0 1 3 1 4 1 3 0
0 2 3 2 0 2 3 0
0 3 2 0 0 3 2 0
endnode
endmodelgeom smooth"""
	var parser:=Ascii.new()
	var model:=parser.parse(source)
	check(parser.failure.is_empty() and not model.is_empty(),"Smoothing fixture parses")
	if model.is_empty(): return
	var mesh: Dictionary=model.nodes[0].mesh
	if mesh.normals.size()!=36:
		check(false,"Every emitted face corner has a normal")
		return
	# Stock ProcessVerts sums unnormalized face crosses, including across UV seams.
	var smooth:=Vector3(0,-3,2).normalized()
	for corner in [0,1,3,4]:
		check(corner_normal(mesh,corner).distance_to(smooth)<1e-6,"Shared source vertex and overlapping mask use the area-weighted normal")
	check(mesh.uv[0][0]!=mesh.uv[0][6],"Smoothing fixture includes a UV seam")
	check(corner_normal(mesh,2).distance_to(Vector3(0,0,1))<1e-6,"Unshared corner keeps its face normal")
	check(corner_normal(mesh,6).distance_to(Vector3.RIGHT)<1e-6,"Disjoint group keeps its face normal")
	check(corner_normal(mesh,9).distance_to(Vector3.LEFT)<1e-6,"Zero smoothing mask keeps a hard edge")
	var mixed:=parser.parse(source.replace("0 1 3 1 4","0 1 3 3 4"))
	check(parser.failure.is_empty() and not mixed.is_empty(),"Mixed smoothing masks parse")
	if not mixed.is_empty() and mixed.nodes[0].mesh.normals.size()==36:
		check(corner_normal(mixed.nodes[0].mesh,6).distance_to(smooth)<1e-6,"An overlapping earlier corner reuses its accepted normal")
	else:
		check(false,"Mixed smoothing masks preserve face corners")
	var explicit:="normals 4\n0 0 1\n0 1 0\n1 0 0\n0 -1 0\n"
	var authored:=parser.parse(source.replace("faces 4",explicit+"faces 4"))
	check(parser.failure.is_empty() and not authored.is_empty(),"Explicit normal fixture parses")
	if not authored.is_empty() and authored.nodes[0].mesh.normals.size()==36:
		var authored_mesh: Dictionary=authored.nodes[0].mesh
		check(corner_normal(authored_mesh,3).distance_to(Vector3(0,0,1))<1e-6 and corner_normal(authored_mesh,4).distance_to(Vector3(0,1,0))<1e-6,"Explicit normals take precedence by source vertex")
	else:
		check(false,"Explicit normal stream has one normal per corner")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary={}
	var catalog:=Capture.new()
	if args.has("fixture"):
		var loaded: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
		if not loaded is Dictionary: quit(2); return
		fixture=loaded
		check(catalog.mount(fixture.capture,"context-1",[fixture.supplement]),"Original raw capture resources mount without JS: "+catalog.failure)
	for sample in fixture.get("samples",[]):
		var raw: PackedByteArray=catalog.get_resource(sample.name,2002); var parser:=Ascii.new()
		check(catalog.failure.is_empty() and Cache.digest(raw)==sample.sha256,"Original ASCII MDL bytes agree: "+str(sample.name))
		var model:=parser.parse(Binary.new(raw).text(0,raw.size()))
		check(parser.failure.is_empty(),"Native original ASCII parse: "+parser.failure)
		if model.is_empty(): continue
		check(model.source_node_count==sample.nodes.size(),"Original physical node count retained")
		for index in sample.nodes.size():
			var expected: Dictionary=sample.nodes[index]; var matches: Array=model.nodes.filter(func(row): return int(row.source_index)==index)
			check(not matches.is_empty(),"Original physical node exists: "+str(expected.name))
			if matches.is_empty(): continue
			var row: Dictionary=matches[0]
			check(row.name==expected.name and source_point(row.position).distance_to(source_point(expected.position))<1e-6 and absf(float(row.scale)-float(expected.scale))<1e-6,"Original position/scale/name retained: "+str(expected.name))
			var q:=Quaternion(row.orientation[0],row.orientation[1],row.orientation[2],row.orientation[3]); var reference:=Quaternion(expected.quaternion[0],expected.quaternion[1],expected.quaternion[2],expected.quaternion[3])
			check(absf(absf(q.dot(reference))-1)<1e-5,"Original axis-angle orientation: "+str(expected.name))
			var parent_name: String="NULL" if int(row.parent)==-1 else str(model.nodes[int(row.parent)].name)
			check(parent_name==expected.parent,"Original parent relation: "+str(expected.name))
			if row.features.has("aabb"):
				check(expected.groups.is_empty() and matches.all(func(part): return part.mesh.is_empty() or not part.mesh.render),"Original walkmesh remains independent collision data, never drawn")
				continue
			var groups: Array=matches.filter(func(part): return not part.mesh.is_empty())
			check(groups.size()==expected.groups.size(),"Original material-group count: "+str(expected.name))
			for group_index in mini(groups.size(),expected.groups.size()):
				var mesh: Dictionary=groups[group_index].mesh; var target: Dictionary=expected.groups[group_index]
				var positions:=PackedFloat32Array()
				for vertex in mesh.vertices.size()/3:
					positions.append_array(PackedFloat32Array([mesh.vertices[vertex*3],mesh.vertices[vertex*3+2],-mesh.vertices[vertex*3+1]]))
				check(mesh.vertices.size()/3==int(target.vertices) and Cache.digest(positions.to_byte_array())==target.positionSha256,"Original face-corner geometry matches offline renderer: "+str(expected.name))
				check(Cache.digest(mesh.uv[0].to_byte_array())==target.uvSha256,"Original UV stream matches offline renderer: "+str(expected.name))
	check_smoothing()
	var parser:=Ascii.new()
	var hex_source:="newmodel auth_hex\nbeginmodelgeom auth_hex\nnode trimesh root\nparent NULL\nverts 3\n0 0 0\n1 0 0\n0 1 0\ntverts 3\n0 0 0\n1 0 0\n0 1 0\nfaces 1\n0 1 2 0x1 0 1 2 0\nendnode\nendmodelgeom auth_hex"
	var hex_model:=parser.parse(hex_source)
	check(parser.failure.is_empty() and not hex_model.is_empty() and hex_model.nodes[0].mesh.indices.size()==3,"Original exporter hexadecimal face bitmasks decode without dropping geometry")
	var emitter:=parser.parse("newmodel auth_emit\nbeginmodelgeom auth_emit\nnode emitter spark\nparent NULL\nrender Normal\nendnode\nendmodelgeom auth_emit")
	check(parser.failure.is_empty() and not emitter.is_empty() and emitter.nodes[0].properties.render=="Normal","Emitter render mode is scoped independently from numeric mesh visibility")
	for source in ["newmodel missing", "newmodel x\nbeginmodelgeom x\nnode dummy x\nparent x\nendnode\nendmodelgeom x", "newmodel x\nbeginmodelgeom x\nnode trimesh x\nverts 2\n0 0 0"]:
		check(parser.parse(source).is_empty() and not parser.failure.is_empty(),"Malformed/truncated/cyclic ASCII MDL rejected")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"scope":fixture.get("scope","Stock-derived ASCII smoothing and parser checks"),"sourceSha256":{"systems/native_data/ascii_model.gd":FileAccess.get_sha256("res://systems/native_data/ascii_model.gd"),"tests/native_ascii_model_test.gd":FileAccess.get_sha256("res://tests/native_ascii_model_test.gd")}}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
