extends SceneTree
# SOURCE-ONLY/unexecuted golden-corpus exporter. Calls the unchanged production
# Surface.height directly; there is deliberately no native height hook here.
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
var cases: Array=[]
var checks:=0
var failures: Array=[]
var sources: Array=[]
func check(value: bool,label: String)->void:
	checks+=1
	if not value and failures.size()<50:failures.append(label)
func _initialize()->void:call_deferred("run")
func digest(bytes: PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func double_hex(value: float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
func mesh(z: float=2.0,material: int=0)->Dictionary:
	return {"vertices":[[0.0,0.0,z],[10.0,0.0,z],[10.0,10.0,z]],"faces":[[0,1,2]],"normals":[[0.0,0.0,1.0]],"constants":[-z],"materials":[material]}
func trace(source: Dictionary,table: Dictionary,point: Array)->Dictionary:
	var x:=Surface.f(point[0]);var y:=Surface.f(point[1])
	for allowed in [true,false]:
		for index in source.faces.size():
			if Surface.walkable(table,int(source.materials[index]))!=allowed:continue
			var face: Array=source.faces[index];var a: Array=source.vertices[face[0]];var b: Array=source.vertices[face[1]];var c: Array=source.vertices[face[2]]
			if Surface.edge(a,b,x,y)>=0 and Surface.edge(b,c,x,y)>=0 and Surface.edge(c,a,x,y)>=0:return {"found":true,"index":index,"walk":allowed}
	return {"found":false,"index":0xffffffff,"walk":false}
func add_case(label: String,source: Dictionary,table: Dictionary,points: Array,policy: int=1)->void:
	var queries: Array=[]
	for point in points:
		var expected:=Surface.height(source,table,point);var selected:=trace(source,table,point)
		queries.append({"x":float(point[0]),"y":float(point[1]),"expected":expected,"found":selected.found,"face":selected.index,"walk":selected.walk,"policy":policy})
	cases.append({"label":label,"mesh":source.duplicate(true),"table":table.duplicate(true),"queries":queries})
func points_grid()->Array:
	var points: Array=[]
	for y in 21:
		for x in 21:points.append([Surface.f(float(x)/2),Surface.f(float(y)/2)])
	points.append_array([[0.0,0.0],[10.0,0.0],[10.0,10.0],[5.0,5.0],[-0.0,0.0],[5.0,-0.0],[-1.0,-1.0],[5.0,5.0000001],[5.0,4.9999999]])
	return points
func authored()->void:
	var flags:={"orderedRows":[{"Walk":"0"},{"Walk":"-1"}],"defaultValue":"0"}
	var overlap:={"vertices":[[0.0,0.0,9.0],[10.0,0.0,9.0],[10.0,10.0,9.0],[0.0,0.0,2.0],[10.0,0.0,2.0],[10.0,10.0,2.0]],"faces":[[0,1,2],[3,4,5]],"normals":[[0.0,0.0,1.0],[0.0,0.0,1.0]],"constants":[-9.0,-2.0],"materials":[0,1]}
	check(Surface.height(overlap,flags,[8.0,2.0,1000.0])==2.0,"Original first walkable wins over physically earlier denied plane/reference Z")
	add_case("walkable-before-denied",overlap,flags,points_grid())
	flags.orderedRows[1].Walk="0"
	check(Surface.height(overlap,flags,[8.0,2.0,-1000.0])==9.0,"Original denied fallback keeps physical order")
	add_case("all-denied-first-physical",overlap,flags,points_grid())
	var same_pass:=overlap.duplicate(true);same_pass.materials=[1,1];same_pass.constants=[-2.0,-9.0]
	var same_flags:={"orderedRows":[{"Walk":"0"},{"Walk":"1"}]}
	check(Surface.height(same_pass,same_flags,[8.0,2.0])==2.0,"Same-pass selection keeps first physical face, not highest plane")
	add_case("same-walkable-pass-physical-order",same_pass,same_flags,points_grid())
	for value in ["0","1","-1","0.5","-0.5","1.25","1e1","****",""," 1",0,1,-1,0.5,true,false,null]:
		for default_value in ["0","1","-1","****"]:
			var table:={"orderedRows":[{"Walk":value},{}],"defaultValue":default_value}
			for material in [-1,0,1,99]:add_case("material-type-"+str(typeof(value))+"-"+str(value)+"/default-"+default_value+"/id-"+str(material),mesh(2,material),table,[[8.0,2.0],[0.0,0.0],[-1.0,-1.0]])
	var all:={"orderedRows":[{"Walk":"1"}],"defaultValue":"0"}
	check(double_hex(Surface.height(mesh(0),all,[8.0,2.0]))=="0000000000000080","Ordinary zero plane preserves negative-zero solve bits")
	add_case("ordinary-negative-zero-solve",mesh(0),all,[[8.0,2.0],[0.0,0.0]])
	for nz in [0.0,-0.0,1.0,-1.0]:
		var source:=mesh();source.normals[0][2]=nz
		if nz==0:check(double_hex(Surface.height(source,all,[8.0,2.0]))=="0000000000000000","Vertical plane explicitly returns positive zero even for negative-zero n.z")
		add_case("normal-z-"+str(nz),source,all,points_grid())
	var degenerate:=mesh();degenerate.vertices=[[0.0,0.0,99.0],[0.0,0.0,-99.0],[0.0,0.0,0.0]];degenerate.constants=[-3.0]
	check(Surface.height(degenerate,all,[900.0,-700.0])==3.0,"Original height does not insert a degenerate-area rejection")
	add_case("degenerate-inclusive-edges",degenerate,all,[[900.0,-700.0],[0.0,0.0],[-1.0,-1.0]])
	var clockwise:=mesh();clockwise.faces=[[2,1,0]];add_case("clockwise-not-normalized",clockwise,all,points_grid())
	var slope:=mesh();slope.normals=[[Surface.f(0.25),Surface.f(-0.5),Surface.f(0.75)]];slope.constants=[Surface.f(-1.25)];add_case("slope-plane-stored-order",slope,all,points_grid())
	var tiny:=mesh();tiny.normals=[[1.401298464324817e-45,-1.401298464324817e-45,1.0]];tiny.constants=[-0.0]
	add_case("subnormal-and-signed-zero",tiny,all,[[0.0,0.0],[-0.0,0.0],[1.401298464324817e-45,0.0],[-1.401298464324817e-45,0.0],[1.0000001192092896,0.0],[0.9999999403953552,0.0]])
	var constant:=mesh();constant.constants=[0.1];add_case("explicit-non-f32-constant-rounding",constant,all,[[8.123456789,2.987654321]])
	var unsupported:=mesh();unsupported.vertices[0][0]=0.1;add_case("non-f32-vertex-must-fallback",unsupported,all,[[8.0,2.0]],0)
	unsupported=mesh();unsupported.normals[0][0]=0.1;add_case("non-f32-normal-must-fallback",unsupported,all,[[8.0,2.0]],0)
	unsupported=mesh();unsupported.normals[0][2]=0.0;unsupported.constants=[1.7976931348623157e308]
	check(double_hex(Surface.height(unsupported,all,[8.0,2.0]))=="0000000000000000","Original vertical-plane branch does not evaluate its unused overflowing constant")
	add_case("unsupported-constant-with-valid-zero-fallback",unsupported,all,[[8.0,2.0]],0)
	add_case("nonfinite-query-must-fallback",mesh(),all,[[INF,0.0],[NAN,0.0]],0)
	var empty:={"vertices":[],"faces":[],"normals":[],"constants":[],"materials":[]};add_case("empty-valid-zero",empty,all,[[1.0,1.0]])
	var rng:=RandomNumberGenerator.new();rng.seed=0x42c197a
	for sample in 150:
		var source:={"vertices":[],"faces":[],"normals":[],"constants":[],"materials":[]}
		for face in 1+sample%9:
			var offset: int=source.vertices.size()
			for corner in 3:source.vertices.append([Surface.f(rng.randf_range(-20,20)),Surface.f(rng.randf_range(-20,20)),Surface.f(rng.randf_range(-5,5))])
			if sample%17==0:source.vertices[offset+2]=source.vertices[offset+1].duplicate()
			source.faces.append([offset,offset+1,offset+2]);source.normals.append([Surface.f(rng.randf_range(-1,1)),Surface.f(rng.randf_range(-1,1)),0.0 if sample%29==0 else Surface.f(rng.randf_range(0.01,1))]);source.constants.append(Surface.f(rng.randf_range(-5,5)));source.materials.append(face%2)
		var points: Array=[]
		for query in 12:points.append([rng.randf_range(-20,20),rng.randf_range(-20,20)])
		add_case("seeded-mixed-"+str(sample),source,{"orderedRows":[{"Walk":"0"},{"Walk":"1"}]},points)
func original(args: Dictionary)->void:
	var catalog
	var names: Array=[]
	var expected_hashes: Dictionary={}
	var expected_table_sha:=""
	if args.has("catalog"):
		catalog=Recorded.new();check(catalog.mount(str(args.catalog)),"Sealed recorded catalog mounts read-only")
		names=Array(str(args.get("models","ttu01_w06_01,ttu01_a01_01,ttu01_a01_02,ttu01_a01_03,ttu01_a02_01,ttu01_a02_02,ttu01_a02_03,ttu01_a04_01")).split(",",false))
	elif args.has("fixture"):
		var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(str(args.fixture)))
		check(fixture is Dictionary and fixture.get("samples") is Array and fixture.get("install") is String,"Original surface fixture descriptor")
		if not fixture is Dictionary or not fixture.get("samples") is Array or not fixture.get("install") is String:return
		catalog=Catalog.new();check(catalog.mount_install(str(fixture.install)),"Original install mounts read-only")
		expected_table_sha=str(fixture.get("tableSha256",""));check(expected_table_sha.length()==64,"Original surface-table descriptor identity")
		for sample in fixture.samples:
			names.append(str(sample.name));expected_hashes[str(sample.name)]=str(sample.get("sha256",""));check(str(sample.get("sha256","")).length()==64,"Original WOK descriptor identity "+str(sample.name))
	else:return
	if not failures.is_empty():return
	check(names.size()<=16,"Bounded original WOK corpus, at most 16 resources")
	if names.size()>16:return
	var bytes: PackedByteArray=catalog.get_resource("surfacemat",2017);var parser:=Table.new();var table:=parser.parse(Binary.new(bytes).text(0,bytes.size()))
	check(not bytes.is_empty() and parser.failure.is_empty(),"Original/recorded surfacemat decodes")
	var table_sha:=digest(bytes)
	if not expected_table_sha.is_empty():check(table_sha==expected_table_sha,"Original physical surface-table bytes match descriptor")
	sources.append({"resource":"surfacemat","type":2017,"sha256":table_sha})
	if not failures.is_empty():return
	for name in names:
		bytes=catalog.get_resource(str(name),2016);var decoder:=Surface.new();var source:=decoder.parse_bytes(bytes)
		check(not bytes.is_empty() and decoder.failure.is_empty() and not source.is_empty(),"Original/recorded WOK decodes "+str(name))
		var source_sha:=digest(bytes)
		if expected_hashes.has(name):check(source_sha==expected_hashes[name],"Original physical WOK bytes match descriptor "+str(name))
		if source.is_empty():continue
		sources.append({"resource":name,"type":2016,"sha256":source_sha,"faces":source.faces.size()})
		for orientation in 4:
			var points: Array=[]
			for point in points_grid():points.append(Surface.canonical(point,orientation))
			add_case(str(name)+"/canonical-"+str(orientation),source,table,points)
func write_corpus(path: String)->Dictionary:
	if FileAccess.file_exists(path):return {"error":"Existing corpus preserved"}
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return {"error":"Corpus output could not be opened"}
	file.big_endian=false;file.store_buffer("NWNHGT01".to_utf8_buffer());file.store_32(cases.size());var queries:=0
	for value in cases:
		var label: PackedByteArray=str(value.label).to_utf8_buffer();var source: Dictionary=value.mesh;var table: Dictionary=value.table
		if label.size()>4096 or source.faces.size()>100000 or value.queries.size()>100000:file.close();return {"error":"Corpus shape exceeds bound"}
		file.store_16(label.size());file.store_buffer(label);file.store_32(source.faces.size());file.store_32(value.queries.size())
		for index in source.faces.size():
			if source.faces[index].size()!=3 or source.normals[index].size()!=3:file.close();return {"error":"Corpus physical-face shape is invalid"}
			for corner in source.faces[index]:
				file.store_double(float(source.vertices[corner][0]));file.store_double(float(source.vertices[corner][1]))
			for component in source.normals[index]:file.store_double(float(component))
			file.store_double(float(source.constants[index]));file.store_8(1 if Surface.walkable(table,int(source.materials[index])) else 0)
		for query in value.queries:
			file.store_double(query.x);file.store_double(query.y);file.store_double(query.expected);file.store_8(1 if query.found else 0);file.store_32(query.face);file.store_8(1 if query.walk else 0);file.store_8(query.policy);queries+=1
		if file.get_position()>64*1024*1024:file.close();return {"error":"Corpus payload exceeds 64 MiB"}
	var bytes:=file.get_position();file.close();return {"bytes":bytes,"cases":cases.size(),"queries":queries,"sha256":digest(FileAccess.get_file_as_bytes(path)),"format":"NWNHGT01, little endian, typed raw source + actual original Godot height bits"}
func run()->void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("corpus") or not args.has("report") or FileAccess.file_exists(str(args.report)):quit(2);return
	authored();original(args)
	var output: Dictionary={} if not failures.is_empty() else write_corpus(str(args.corpus))
	if output.has("error"):failures.append(str(output.error))
	var proof:={"success":failures.is_empty(),"checks":checks,"failures":failures,"corpus":output,"sources":sources,"engine":Engine.get_version_info(),"activation":{"pid":OS.get_process_id(),"display":DisplayServer.get_name(),"executable":OS.get_executable_path()},"surface_script_sha256":digest(FileAccess.get_file_as_bytes("res://systems/native_data/tile_surface.gd")),"scope":"Golden bytes from unchanged production GDS height; no native height integration, performance claim, graphics or server connection."}
	var report:=FileAccess.open(str(args.report),FileAccess.WRITE)
	if report!=null:report.store_string(JSON.stringify(proof,"  ")+"\n");report.close()
	print(JSON.stringify({"success":proof.success,"checks":checks,"cases":cases.size(),"failures":failures}));quit(0 if failures.is_empty() else 1)
