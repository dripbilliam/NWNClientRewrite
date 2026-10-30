extends SceneTree
const Surface=preload("res://systems/native_data/tile_surface.gd")
const Terrain=preload("res://systems/native_render/terrain_surface.gd")
const Definition=preload("res://systems/native_data/area_definition.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Motion=preload("res://systems/network_motion.gd")
var checks:=0
var failures: Array=[]
var maximum_height_error:=0.0
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value and failures.size()<25: failures.append(label)
func geometry(mesh: Dictionary,table: Dictionary,allowed: bool) -> String:
	var values:=PackedFloat32Array()
	for index in mesh.faces.size():
		if Surface.walkable(table,int(mesh.materials[index]))!=allowed: continue
		for vertex in mesh.faces[index]: values.append_array(PackedFloat32Array(mesh.vertices[vertex]))
		values.append_array(PackedFloat32Array(mesh.normals[index])); values.append(mesh.constants[index]); values.append(mesh.materials[index])
	return Cache.digest(values.to_byte_array())
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var catalog:=Catalog.new(); check(catalog.mount_install(oracle.install),"Native installed resource catalog")
	check(catalog.mount_erf(str(oracle.install).path_join("data/nwm/Prelude.nwm"),100000000),"Native original Prelude archive")
	var raw_table: PackedByteArray=catalog.get_resource("surfacemat",2017)
	check(Cache.digest(raw_table)==oracle.tableSha256,"Original physical surface table bytes")
	var parser:=Table.new(); var table:=parser.parse(Binary.new(raw_table).text(0,raw_table.size()))
	check(parser.failure.is_empty(),"Original physical surface rows decode natively")
	var rotated:=0; var faces:=0
	for sample in oracle.samples:
		var raw: PackedByteArray=catalog.get_resource(sample.name,2016)
		check(catalog.failure.is_empty() and Cache.digest(raw)==sample.sha256,"Original WOK bytes "+str(sample.name))
		var decoder:=Surface.new(); var mesh:=decoder.parse_bytes(raw)
		check(decoder.failure.is_empty() and not mesh.is_empty(),"Native WOK decode "+str(sample.name)+": "+decoder.failure)
		if mesh.is_empty(): continue
		faces+=mesh.faces.size()
		if mesh.node_rotation: rotated+=1
		check(geometry(mesh,table,true)==sample.walkableGeometrySha256,"Exact f32 walkable geometry/planes/material order "+str(sample.name))
		check(geometry(mesh,table,false)==sample.deniedGeometrySha256,"Exact f32 denied geometry/planes/material order "+str(sample.name))
		for query in sample.queries:
			var actual:=Surface.height(mesh,table,query.point); var error:=absf(actual-float(query.height)); maximum_height_error=maxf(maximum_height_error,error)
			check(error<0.00001,"Original WOK height "+str(sample.name)+" "+str(query.point))
	for orientation in 4:
		var point:=[2.0,3.0]; var canonical:=Surface.canonical(point,orientation)
		check(Surface.canonical(canonical,(4-orientation)%4)==point,"Exact original quarter-turn inverse %d"%orientation)
	var overlapping:={"vertices":[[0.0,0.0,9.0],[10.0,0.0,9.0],[10.0,10.0,9.0],[0.0,0.0,2.0],[10.0,0.0,2.0],[10.0,10.0,2.0]],"faces":[[0,1,2],[3,4,5]],"normals":[[0.0,0.0,1.0],[0.0,0.0,1.0]],"constants":[-9.0,-2.0],"materials":[0,1]}
	var flags:={"orderedRows":[{"Walk":"0"},{"Walk":"-1"}],"defaultValue":"0"}
	check(Surface.height(overlapping,flags,[8.0,2.0,1000.0])==2,"Walkable source face wins over physically earlier denied face and reference Z")
	flags.orderedRows[1].Walk="0"
	check(Surface.height(overlapping,flags,[8.0,2.0,-1000.0])==9,"Denied fallback uses first source face rather than nearest rendered floor")
	check(Surface.height(overlapping,flags,[-20.0,-20.0])==0,"Outside surface returns original zero height")
	var authored:="node aabb test\nposition 0 0 0\norientation 0 0 1 0\nverts 3\n-5 -5 0\n5 -5 0\n5 5 0\nfaces 1\n0 1 2 0 0 0 0 0\nendnode\n"
	for bad in [authored.replace("verts 3","verts 3 binary"),authored.replace("0 1 2 0","0 1 9 0"),authored.replace("5 5 0","NaN 5 0"),authored.replace("faces 1","faces 2"),authored+authored,"binary"]:
		var decoder:=Surface.new(); check(decoder.parse(bad).is_empty() and not decoder.failure.is_empty(),"Malformed/unsupported WOK is diagnosed")
	var binary_decoder:=Surface.new(); check(binary_decoder.parse_bytes(PackedByteArray([0,0,7,19])).is_empty() and not binary_decoder.failure.is_empty(),"Binary WOK is rejected before text conversion")
	# Exercise the actual frame owner's height callback, using an authored
	# sloped collision plane and a placement with a nonzero area elevation.
	var slope:=overlapping.duplicate(true); slope.vertices=[[0.0,0.0,0.0],[10.0,0.0,2.0],[10.0,10.0,2.0]]; slope.faces=[[0,1,2]]; slope.normals=[Surface.normal(slope.vertices[0],slope.vertices[1],slope.vertices[2])]; slope.constants=[0.0]; slope.materials=[1]
	var floor_owner:=Terrain.new(); floor_owner.done=true; floor_owner.table={"orderedRows":[{"Walk":"0"},{"Walk":"1"}]}; floor_owner.meshes={"slope":slope}; floor_owner.definition={"width":1,"height":1,"tiles":[{"model":"slope","orientation":0,"position":Vector3(5,7,-5)}]}
	var mover:=Motion.new(); mover.height_query=floor_owner.height
	mover.observe(1,{"position":[2.0,1.0,7.4],"orientation":[1.0,0.0,0.0],"animation":4,"runRate":1000.0,"path":[[2.0,1.0],[5.0,1.0]],"field8F4":1,"field8EC":1.0},true)
	for frame in 120:
		mover.update(1.0/60.0); var state: Dictionary=mover.objects[1]
		check(absf(float(state.position.z)-(7.0+0.2*float(state.position.x)))<0.00001,"Native path follows elevated slope each frame %d"%frame)
	mover.height_query=Callable(); floor_owner.close(); floor_owner.free()
	var definition_parser:=Definition.new(); var definition:=definition_parser.load_original(catalog,"m0q1a")
	check(definition_parser.failure.is_empty(),"Native original area definition for worker integration")
	var cache_path:=ProjectSettings.globalize_path("user://native-surface-check-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec()))
	var worker_runs: Array=[]
	for pass_index in 2:
		var owner:=Terrain.new(); root.add_child(owner); owner.configure(catalog,definition,cache_path)
		var began:=Time.get_ticks_msec()
		while not owner.done and Time.get_ticks_msec()-began<30000: await process_frame
		check(owner.ready(),"Native bounded original WOK workers complete %d: %s"%[pass_index,str(owner.stats.errors)])
		check(owner.stats.models==definition.models.size(),"One prepared WOK per original model %d"%pass_index)
		check(owner.stats.cache_hits==(0 if pass_index==0 else definition.models.size()+1),"Cold/warm persistent native WOK/table reuse %d"%pass_index)
		if owner.ready():
			var tile: Dictionary=definition.tiles[0]; var point:=Vector3(5,5,999); var expected:=Surface.f(Surface.height(owner.meshes[tile.model],owner.table,Surface.canonical([5.0,5.0],int(tile.orientation)))+Surface.f(tile.position.y))
			check(owner.height(point,999)==expected,"Live native tile placement queries original WOK")
			check(owner.height(Vector3(-1,-1,0),37)==37,"Outside area retains prior authoritative height")
		worker_runs.append(owner.snapshot()); owner.close()
		check(owner.assets.running.is_empty() and owner.assets.pending.is_empty(),"Surface worker scope drains %d"%pass_index)
		owner.queue_free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"samples":oracle.samples.size(),"faces":faces,"nonzero_node_rotations":rotated,"height_queries":oracle.samples.size()*441,"maximum_height_error":maximum_height_error,"worker_runs":worker_runs,"cache_path":cache_path,"scope":"Native original Prelude WOK decode/height/cache/worker integration against offline existing native-method oracle; no GPU/server, adjacency/line collision or WASD acceptance"},"\t")); file.close()
	print(JSON.stringify({"checks":checks,"failures":failures,"samples":oracle.samples.size(),"maximum_height_error":maximum_height_error})); quit(0 if failures.is_empty() else 1)
