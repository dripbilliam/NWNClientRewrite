extends SceneTree
# Actual installed planning, Assets workers, Pool and PackedScene publication.
# No controlled template/model publication and no World/session/network owner.
const Stream=preload("res://systems/native_render/area_border_stream.gd")
const Loader=preload("res://systems/native_render/area_border_loader.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Template=preload("res://systems/native_render/model_template.gd")
const ORACLE_PATH="res://reports/native-area-border-original-v2.json"
var checks: int=0
var failures: Array=[]
var observations: Array=[]
var output: String=""
var streams: Array=[]
var loader
var pool
var bundles: Dictionary={}
var completions: Dictionary={}
var source_fingerprints: Dictionary={}
var deadline: int=0
func _initialize()->void:run.call_deferred()
func check(value: bool,label: String)->void:
	checks+=1
	if not value:failures.append(label)
func until(condition: Callable,seconds: float=25.0)->bool:
	var limit: int=mini(deadline,Time.get_ticks_msec()+int(seconds*1000.0))
	while not condition.call() and Time.get_ticks_msec()<limit:await process_frame
	return condition.call()
func wait_stream(stream,label: String)->bool:
	var limit: int=mini(deadline,Time.get_ticks_msec()+25000);var previous: int=stream.instances.size();var maximum_added: int=0;var frames: int=0
	while not stream.done and Time.get_ticks_msec()<limit:
		await process_frame
		var current: int=stream.instances.size();maximum_added=maxi(maximum_added,current-previous);previous=current;frames+=1
	check(maximum_added<=int(stream.maximum_instances_per_frame),label+": observed scene additions honor per-frame publication count")
	observations.append({"publication_label":label,"observed_frames":frames,"maximum_instances_added_in_frame":maximum_added})
	return stream.done
func digest(bytes: PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func near_vector(a: Vector3,b: Vector3,tolerance: float=0.0002)->bool:return a.distance_to(b)<=tolerance
func near_bounds(a: AABB,b: AABB,tolerance: float=0.0002)->bool:return near_vector(a.position,b.position,tolerance) and near_vector(a.size,b.size,tolerance)
func relative_to(node: Node3D,owner: Node3D)->Transform3D:
	var pose:=Transform3D.IDENTITY;var current: Node=node
	while current!=owner and current!=null:
		if current is Node3D:pose=current.transform*pose
		current=current.get_parent()
	return pose
func converted_pose(row: Dictionary)->Transform3D:
	var xyz: Array=row.position;var xyzw: Array=row.orientation
	var q:=Quaternion(float(xyzw[0]),float(xyzw[1]),float(xyzw[2]),float(xyzw[3]))
	if q.length_squared()<1e-16:q=Quaternion.IDENTITY
	var axes:=Basis(Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,1,0))
	return Transform3D((axes*Basis(q.normalized())*axes.inverse()).scaled(Vector3.ONE*float(row.scale)),Vector3(float(xyz[0]),float(xyz[2]),-float(xyz[1])))
func raw_bounds(vertices: PackedFloat32Array,native: bool=false)->AABB:
	var box:=AABB()
	for index in vertices.size()/3:
		var p:=Vector3(vertices[index*3],vertices[index*3+1],vertices[index*3+2])
		if not native:p=Vector3(p.x,p.z,-p.y)
		box=box.expand(p) if index>0 else AABB(p,Vector3.ZERO)
	return box
func expected_scene_bounds(nodes: Array,poses: Array)->Dictionary:
	var result: Dictionary={"valid":false,"bounds":AABB()}
	for index in nodes.size():
		var mesh: Dictionary=nodes[index].mesh
		if mesh.is_empty() or mesh.indices.is_empty() or mesh.get("collision_indices",mesh.indices).is_empty():continue
		var box:=raw_bounds(mesh.vertices,true)
		# Production metadata is conservative original-face bounds, not just draw AABB.
		box=box.grow(maxf(1.0,maxf(box.position.abs().length(),box.end.abs().length()))*0.000003814697265625)
		var mapped:=AABB(Vector3(box.position.x,box.position.z,-box.end.y),Vector3(box.size.x,box.size.z,box.size.y))
		var transformed: AABB=poses[index]*mapped
		result.bounds=result.bounds.merge(transformed) if result.valid else transformed;result.valid=true
	return result
func capture(id: int,value: Dictionary)->void:
	if not str(value.get("error","")).is_empty():return
	var name:=str(value.get("resource_name",""));bundles[name]=value;completions[id]=value
	source_fingerprints[name]=digest(var_to_bytes(value.value))
func geometry(instance,bundle: Dictionary,row: Dictionary,scope: Array,label: String)->void:
	check(instance is Template.Placement,label+": actual production PackedScene Placement is published")
	if not instance is Template.Placement:return
	var nodes: Array=bundle.value.nodes;var poses: Array=[]
	check(instance.parts.size()==nodes.size(),label+": all original physical parts survive template packing")
	if instance.parts.size()!=nodes.size():return
	var expected:=Transform3D(Basis(Vector3.UP,float(row.orientation)*PI/2.0),row.position)
	check(instance.transform.is_equal_approx(expected),label+": exact planned quarter turn and source position")
	check(instance.get_meta("native_area_border_scope",[])==scope,label+": clone has exact private scope")
	for index in nodes.size():
		var source: Dictionary=nodes[index];var part: Node3D=instance.parts[index]
		var local:=converted_pose(source);var parent: int=int(source.parent)
		poses.append(poses[parent]*local if parent>=0 else local)
		check(part.transform.is_equal_approx(local) and relative_to(part,instance).is_equal_approx(poses[index]),label+": physical rest transform "+str(index))
		var actual_parent: Node=part.get_parent()
		check(int(part.get_meta("native_part_index",-2))==index and int(part.get_meta("native_part_parent",-2))==parent and str(part.get_meta("native_part_name",""))==str(source.name) and int(actual_parent.get_meta("native_part_index",-1))==parent,label+": physical source identity/parent "+str(index))
	var visible_meshes: int=0;var vertices_checked: int=0;var triangles_checked: int=0;var textured: int=0
	for index in nodes.size():
		var data: Dictionary=nodes[index].mesh
		if data.is_empty() or data.indices.is_empty() or not data.render:continue
		visible_meshes+=1;var part: Node3D=instance.parts[index]
		var render: MeshInstance3D=part if part is MeshInstance3D else part.get_node_or_null("mesh")
		check(render!=null and render.mesh is ArrayMesh,label+": actual native ArrayMesh "+str(index))
		if render==null or not render.mesh is ArrayMesh:continue
		check(render.mesh.get_surface_count()==1,label+": physical mesh keeps one original draw surface")
		if render.mesh.get_surface_count()!=1:continue
		var arrays: Array=render.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var correct_vertices: bool=vertices.size()*3==data.vertices.size();var max_error: float=0.0
		if correct_vertices:
			for vertex in vertices.size():
				var point:=Vector3(data.vertices[vertex*3],data.vertices[vertex*3+2],-data.vertices[vertex*3+1])
				max_error=maxf(max_error,vertices[vertex].distance_to(point))
			correct_vertices=max_error<=0.00001
		vertices_checked+=vertices.size();triangles_checked+=indices.size()/3
		var correct_indices: bool=indices.size()==data.indices.size()
		if correct_indices:
			for face in range(0,indices.size(),3):
				if indices[face]!=data.indices[face] or indices[face+1]!=data.indices[face+2] or indices[face+2]!=data.indices[face+1]:correct_indices=false;break
		check(correct_vertices and correct_indices,label+": complete source vertex stream and native winding conversion "+str(index))
		check(near_bounds(render.mesh.get_aabb(),raw_bounds(data.vertices)),label+": exact source render bounds "+str(index))
		check(relative_to(render,instance).is_equal_approx(poses[index]),label+": mesh retains physical ancestor transform "+str(index))
		var material: Material=render.material_override
		check(material is StandardMaterial3D,label+": real production material is attached")
		var names: Array=data.textures
		if not names.is_empty() and not str(names[0]).is_empty() and str(names[0]).to_lower()!="null":
			var name:=str(names[0]).to_lower();var raster: Dictionary=bundle.get("textures",{}).get(name,{})
			check(not raster.is_empty() and raster.has("sha256") and material is StandardMaterial3D and material.albedo_texture!=null,label+": original texture dependency published for "+name);textured+=1
		var hit=render.mesh.get_meta("native_pick_geometry",null)
		check(hit!=null and hit.cached_shape==null and hit.builds==0 and not render.has_meta("native_pick_shape"),label+": passive hit data has no built/registered collision shape")
	var expected_bounds:=expected_scene_bounds(nodes,poses)
	check(expected_bounds.valid and instance.has_meta("native_scene_bounds"),label+": source template bounds are available")
	if expected_bounds.valid and instance.has_meta("native_scene_bounds"):
		var actual: AABB=instance.get_meta("native_scene_bounds")
		check(near_bounds(actual,expected_bounds.bounds),label+": hierarchy-composed conservative source bounds")
		check(near_bounds(instance.global_transform*actual,expected*expected_bounds.bounds,0.001),label+": planned world-space bounds include exact orientation/height")
	check(visible_meshes>0 and instance.meshes.size()==visible_meshes,label+": real nonempty installed geometry was exercised")
	observations.append({"model":bundle.resource_name,"sha256":bundle.sha256,"parts":nodes.size(),"visible_meshes":visible_meshes,"vertices_checked":vertices_checked,"triangles_checked":triangles_checked,"textured_surfaces":textured,"orientation":row.orientation,"position":[row.position.x,row.position.y,row.position.z],"limitations":instance.limitations})
func decorative(instance,label: String)->void:
	var nodes: Array=[instance];nodes.append_array(instance.find_children("*","",true,false))
	var clear: bool=true;var groups: Array=[]
	for node in nodes:
		if node is CollisionObject3D or node is CollisionShape3D or node is NavigationRegion3D or node is NavigationObstacle3D:clear=false
		for key in ["objectId","object_id","entity_id","selection_id","walkmesh","native_pick_shape"]:
			if node.has_meta(key):clear=false
		for group in node.get_groups():
			groups.append(str(group))
			if str(group) in ["selectable","selection","world_entities","native_entities","colliders","walkmesh"]:clear=false
	check(clear,label+": no collision/navigation nodes or gameplay/selection identity/group registration")
	observations.append({"decorative_descendants":nodes.size(),"groups":groups})
func finish()->void:
	for stream in streams:
		if is_instance_valid(stream):stream.close();stream.free()
	streams.clear()
	if is_instance_valid(loader):loader.close();loader.free()
	if pool!=null:pool.clear()
	bundles.clear();completions.clear();source_fingerprints.clear();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:quit(3);return
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Actual installed Edge2DA worker plan, native model/texture Assets, ResourcePool/ModelTemplate PackedScene clones, source transforms/vertex streams/bounds and decorative-tree/scoped-retirement guards. Headless correctness only: no native/Godot pixels, GPU benchmark, World registry authority, network, keys or original processes."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
func run()->void:
	deadline=Time.get_ticks_msec()+45000
	var install: String="";var installed_fixture: String=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):output=argument.trim_prefix("--report=")
		if argument.begins_with("--install="):install=argument.trim_prefix("--install=")
		if argument.begins_with("--installed-fixture="):installed_fixture=argument.trim_prefix("--installed-fixture=")
	if output.is_empty() or install.is_empty() or installed_fixture.is_empty() or FileAccess.file_exists(output):quit(2);return
	var catalog:=Catalog.new();check(catalog.mount_install(install),"Read-only actual original resource catalog mounts")
	if not failures.is_empty():await finish();return
	var fixture: Variant=JSON.parse_string(FileAccess.get_file_as_string(installed_fixture))
	if not fixture is Dictionary or not fixture.get("samples") is Array:check(false,"Installed original SET/Edge metadata fixture is valid");await finish();return
	var sample: Dictionary={}
	for entry in fixture.samples:
		if str(entry.setName)=="ttf01":sample=entry;break
	if sample.is_empty():check(false,"Installed forest ttf01 SET is captured");await finish();return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(ORACLE_PATH));var original: Dictionary={}
	if oracle is Dictionary and oracle.get("binarySha256")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a":
		for entry in oracle.get("rows",[]):
			if entry.get("name")=="ttf01-turn0":original=entry;break
	if original.is_empty():check(false,"Pinned original forest case is available");await finish();return
	var definition: Dictionary={"width":original.area.width,"height":original.area.height,"tiles":original.area.tiles.duplicate(true),"tileset_name":sample.setName,"tileset":{"transition":float(sample.general.Transition),"tiles":sample.tiles}}
	var scope: Array=[get_instance_id(),1,7];var prepared: Dictionary={}
	loader=Loader.new();root.add_child(loader)
	loader.completed.connect(func(ticket,received_scope,value):prepared.merge({"ticket":ticket,"scope":received_scope,"value":value},true))
	var ticket: int=loader.request(catalog,definition,{"enabled":true,"disabled":false},scope)
	check(ticket>0 and await until(func():return not prepared.is_empty()),"Actual installed Edge2DA planning completes within fixed bound")
	if prepared.is_empty():await finish();return
	var result: Dictionary=prepared.value
	check(prepared.ticket==ticket and prepared.scope==scope and result.render.get("ready",false) and int(result.thread)!=OS.get_main_thread_id(),"Accepted current scope uses real worker planning")
	if not result.render.get("ready",false):await finish();return
	var selected: Array=[];var turns: Dictionary={};var first_model: String="";var duplicate_found: bool=false;var negative_found: bool=false
	for row in result.plan.placements:
		if not turns.has(int(row.orientation)):selected.append(row);turns[int(row.orientation)]=true
	check(turns.size()==4,"Actual original plan provides all four orientations without invented placements")
	if not selected.is_empty():first_model=str(selected[0].model)
	for row in result.plan.placements:
		if str(row.model)==first_model and not selected.has(row):selected.append(row);duplicate_found=true;break
	for row in selected:
		if row.position.y<0:negative_found=true
	if not negative_found:
		for row in result.plan.placements:
			if row.position.y<0 and not selected.has(row):selected.append(row);negative_found=true;break
	check(duplicate_found and negative_found,"Genuine source rows cover repeated model identity and negative border height")
	for row in selected:
		var ordinal: int=result.plan.attempts.find(row)
		check(ordinal>=0 and ordinal<original.calls.size(),"Selected placement has an actual original execution ordinal")
		if ordinal>=0 and ordinal<original.calls.size():
			var call: Dictionary=original.calls[ordinal]
			check(str(row.rawModel)==str(call.model) and int(row.orientation)==int(call.orientation),"Installed selected model/turn match unchanged native original call")
			for axis in 3:check(PackedFloat32Array([float(row.nativePosition[axis])]).to_byte_array().hex_encode()==str(call.positionBits[axis]),"Installed selected position matches original FLOAT bits")
	if not failures.is_empty():await finish();return
	var selected_plan: Dictionary={"ready":true,"enabled":true,"loaded":true,"placements":selected};var original_rows: Array=selected.duplicate(true)
	pool=Pool.new();pool.picking=false
	var stream=Stream.new();streams.append(stream);root.add_child(stream);stream.maximum_instances_per_frame=1
	check(stream.open_plan(catalog,selected_plan,pool,scope,output.get_base_dir().path_join("native-data-cache")),"Production border stream opens real source plan with real Pool")
	stream.assets.completed.connect(capture)
	check(await wait_stream(stream,"first scope"),"Real Assets workers and real template publication complete within bound")
	check(stream.failure.is_empty() and stream.stats.failed==0 and stream.instances.size()==selected.size(),"Every selected installed model publishes without a controlled template")
	check(int(stream.stats.publication_frames)>=selected.size() and stream.maximum_instances_per_frame==1,"Actual scene publication retains configured one-instance budget")
	check(selected==original_rows,"Original prepared source rows remain immutable through real publication")
	if stream.instances.size()!=selected.size():observations.append({"failed_stream":stream.snapshot(),"pool_failure":pool.failure});await finish();return
	for index in selected.size():
		var row: Dictionary=selected[index];var bundle: Dictionary=bundles.get(str(row.model),{})
		check(not bundle.is_empty() and bundle.get("bytes") is PackedByteArray and digest(bundle.bytes)==str(bundle.get("sha256","")),"Actual source model bytes/hash retained for "+str(row.model))
		if bundle.is_empty():continue
		geometry(stream.instances[index],bundle,row,scope,"placement"+str(index));decorative(stream.instances[index],"placement"+str(index))
		check(source_fingerprints.get(str(row.model),"")==digest(var_to_bytes(bundle.value)),"Real template publication preserves decoded model data for "+str(row.model))
	check(pool.stats.meshes_created>0 and pool.stats.templates_created>0 and pool.stats.textures_created>0 and pool.pick_shapes.is_empty(),"Real mesh/texture/template resources exist with picking disabled")
	for hit in pool.hidden_hit_geometry.values():check(hit.cached_shape==null and hit.builds==0,"Hidden native geometry remains passive data, not a collision shape")
	if not failures.is_empty():await finish();return
	var first: Dictionary=selected[0];var before_hits: int=pool.stats.template_hits
	var survivor=Stream.new();streams.append(survivor);root.add_child(survivor)
	var survivor_scope: Array=[get_instance_id(),2,8]
	check(survivor.open_plan(catalog,{"ready":true,"enabled":true,"loaded":true,"placements":[first]},pool,survivor_scope,output.get_base_dir().path_join("native-data-cache")) and await wait_stream(survivor,"second scope"),"Second real scoped stream clones from shared Pool")
	check(survivor.instances.size()==1 and pool.stats.template_hits>before_hits,"Independent scope reuses actual immutable template")
	if survivor.instances.size()!=1:await finish();return
	var survivor_node=survivor.instances[0];var first_node=stream.instances[0]
	check(first_node!=survivor_node and first_node.parts[0]!=survivor_node.parts[0] and first_node.meshes[0].mesh==survivor_node.meshes[0].mesh and first_node.meshes[0].material_override==survivor_node.meshes[0].material_override,"Private actual nodes share only immutable native mesh/material resources")
	var retired_refs: Array=[]
	for instance in stream.instances.values():retired_refs.append(weakref(instance))
	var prior_count: int=stream.instances.size();stream.begin_retirement()
	var retired_all: bool=stream.retirement_step(0.0)
	check(not retired_all and not stream.visible and stream.instances.size()==prior_count-1,"Retirement hides immediately and honors one-node budget")
	var stale_before: int=stream.stats.stale;var replay_id: int=int(completions.keys()[0]);stream.model_prepared(replay_id,completions[replay_id])
	check(stream.stats.stale==stale_before+1 and stream.instances.size()==prior_count-1,"Late captured real completion cannot publish into retired scope")
	while not stream.retirement_step(0.0) and Time.get_ticks_msec()<deadline:await process_frame
	var detached: Dictionary=stream.detach_prepared_data()
	check(stream.instances.is_empty() and detached.has("border_plans") and not detached.has("instances") and not detached.has("templates"),"Retirement detaches only private data and releases every scene instance")
	await process_frame;await process_frame
	check(retired_refs.all(func(reference):return reference.get_ref()==null),"Actual queued-free border nodes are gone after bounded retirement")
	check(is_instance_valid(survivor_node) and survivor_node.visible and not survivor_node.retired and survivor.instances.size()==1,"Retiring first scope preserves independent shared-resource clone")
	decorative(survivor_node,"surviving scope")
	observations.append({"complete_plan_count":result.plan.placements.size(),"selected_count":selected.size(),"plan_thread":result.thread,"stream":stream.snapshot(),"survivor":survivor.snapshot(),"pool":pool.snapshot()})
	await finish()
