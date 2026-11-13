extends "res://tests/native_drive_preview_lazy_fixture_test.gd"
# Current-main acceptance supplement. The inherited exact transcript/oracle,
# lifetime, overflow, unknown-Z, large-radius and frame fences are retained.
const FrozenGeometry=preload("res://.cache/native-presentation-parity/root/pause-fixes-v1/movement/before/systems/native_render/drive_collision_indexed.gd")
const Arithmetic=preload("res://systems/native_render/drive_preview_arithmetic.gd")
const FrozenHeight=preload("res://.cache/native-presentation-parity/root/pause-fixes-v1/movement/before-v4/systems/native_data/tile_surface.gd")
class OpaqueWalk extends RefCounted:
	var reads:=0
	func _to_string()->String:reads+=1;return "1"
class FailingCollection extends "res://systems/native_render/drive_collision_indexed.gd":
	var collection_calls:=0
	var fail_next:=false
	func collect_preview_geometry(ticket: Dictionary,id: int,minimum: Vector3,maximum: Vector3,radius: float,include_creatures: bool)->Dictionary:
		collection_calls+=1
		if fail_next:fail_next=false;return {"ready":false}
		return super.collect_preview_geometry(ticket,id,minimum,maximum,radius,include_creatures)
class MutatingSurface extends "res://systems/native_render/terrain_surface.gd":
	var once: Callable
	func height(point: Vector3,previous: float)->float:
		if once.is_valid():
			var callback:=once;once=Callable();callback.call()
		return super.height(point,previous)
func counting_and_disabled_profile()->void:
	var setup:=fixture();var world=setup.world;var collision=setup.collision
	# Eligibility is deliberately dense-only; repeated immutable floor faces
	# exercise actual memo accounting without making this a timing fixture.
	var floor: Dictionary=world.surface.meshes.floor.duplicate(true)
	for repetition in 31:
		floor.faces.append_array(world.surface.meshes.floor.faces);floor.materials.append_array(world.surface.meshes.floor.materials);floor.normals.append_array(world.surface.meshes.floor.normals);floor.constants.append_array(world.surface.meshes.floor.constants)
	world.surface.meshes.floor=floor;collision.tiles.clear()
	Profile.enabled=true;Profile.phases={};Profile.phase_frame=-1;Profile.collected_frame=-1
	var from:=Vector3(1,7,0);var target:=Vector3(2,7,0)
	var height_queries_before: int=world.surface.stats.queries
	var clear: Callable=collision.query_preview(1,from,target,from)
	for probe in 38:check(clear.call(from,target),"All38 retained probes keep the floor result")
	check(int(Profile.phases.get("count_drive_preview_probes",0))==38 and int(Profile.phases.get("count_drive_preview_initial_clears",0))==1 and int(Profile.phases.get("count_drive_preview_reused_clears",0))==37,"Each contained probe is counted once; only the first is unrestricted")
	check(int(Profile.phases.get("count_drive_height_queries",0))==76,"Height-query count reflects the unchanged two samples per successful clear")
	check(int(Profile.phases.get("count_drive_height_samples",0))==40 and int(Profile.phases.get("count_drive_height_memo_hits",0))==36,"Actual samples and memo hits partition all76 height requests")
	check(int(world.surface.stats.queries)-height_queries_before==40,"The source counts actual height executions without fake query increments")
	check(int(Profile.phases.get("count_drive_clear_calls",0))==38,"Clear calls are not duplicated by the reuse wrapper")
	for name in ["drive_preview_collection","drive_dynamic_query_ms","drive_static_query_ms","drive_candidate_sort_ms","drive_shape_prepare_ms","drive_clear_total_ms","drive_clear_prefix_ms","drive_height_ms","drive_tile_coverage_ms","drive_obstacle_triangles_ms"]:
		check(Profile.phases.has(name) and is_finite(float(Profile.phases[name])),"Profile child exists: "+name)
	var result: bool=clear.call(Vector3(50,50,0),Vector3(51,50,0))
	check(result==collision.query(1).call(Vector3(50,50,0),Vector3(51,50,0)),"Escape result agrees with unrestricted geometry")
	check(int(Profile.phases.get("count_drive_preview_probes",0))==39 and int(Profile.phases.get("count_drive_preview_fallback_clears",0))==1,"Escaped probe is counted once, not as both wrapper and fallback")
	check(collision.preview_stats.probes==collision.preview_stats.initial_clears+collision.preview_stats.reused_clears+collision.preview_stats.fallback_clears,"Cumulative preview probe ledger reconciles")
	Profile.enabled=false;Profile.phases.clear();Profile.postdraw_phases.clear()
	clear=collision.query_preview(1,from,target,from);clear.call(from,target)
	check(Profile.phases.is_empty() and Profile.postdraw_phases.is_empty(),"Disabled profile emits no child timings or counters")
	world.free()
func failed_collection_ledger()->void:
	var setup:=make_world(false);var world=setup.world
	var collision:=FailingCollection.new();world.add_child(collision);collision.world=world;collision.tables=tables();world.drive_collision=collision;collision.ensure_spatial_scope();collision.set_process(false)
	world.receive([creature(1,Vector2(1,1))],1)
	var from:=Vector3(1,7,0);var target:=Vector3(2,7,0)
	var clear: Callable=collision.query_preview(1,from,target,from)
	check(clear.is_valid() and clear.call(from,target),"First probe succeeds without optional envelope preparation")
	collision.fail_next=true
	check(clear.call(from,target)==collision.query(1).call(from,target),"Failed collection reruns the unrestricted current query")
	check(collision.preview_stats.collection_failures==1 and collision.preview_stats.probes==2 and collision.preview_stats.initial_clears==1 and collision.preview_stats.fallback_clears==1,"Failed collection records one initial and one actual fallback probe")
	check(collision.collection_calls==4,"Initial query, failed optional collection, fallback and explicit oracle each execute once")
	world.free()
func replace_surface(world)->MutatingSurface:
	var old=world.surface;var next:=MutatingSurface.new();world.add_child(next)
	next.table=old.table;next.definition=old.definition;next.meshes=old.meshes;next.done=old.done;next.set_process(false)
	world.surface=next;old.free();return next
func mutation_during_probe()->void:
	var first:=fixture();var second:=fixture()
	var a:=Vector3(2,1.5,0);var b:=Vector3(6,1.5,0)
	var cached: Callable=primed_query(first.collision,1,a,b,a);var ordinary: Callable=second.collision.query(1)
	var first_surface:=replace_surface(first.world);var second_surface:=replace_surface(second.world)
	first_surface.once=func():first.collision.publish_model("chest:placeable",{"states":[{"vertices":[],"faces":[]}]})
	second_surface.once=func():second.collision.publish_model("chest:placeable",{"states":[{"vertices":[],"faces":[]}]})
	check(cached.call(a,b)==ordinary.call(a,b),"A publication during height sampling preserves the original probe's prepared geometry")
	var before: int=first.collision.preview_stats.fallback_clears
	check(cached.call(a,b)==ordinary.call(a,b),"The next probe observes publication through unrestricted fallback")
	check(first.collision.preview_stats.fallback_clears==before+1,"In-probe source mutation invalidates subsequent reuse")
	first.world.free();second.world.free()
func world_scope_fence()->void:
	var setup:=fixture();var world=setup.world;var collision=setup.collision
	var a:=Vector3(1,7,0);var b:=Vector3(2,7,0);var clear: Callable=primed_query(collision,1,a,b,a)
	var before: int=collision.preview_stats.fallback_clears;world.generation+=1
	check(clear.call(a,b)==collision.query(1).call(a,b),"Direct world scope change preserves original query behavior via fallback")
	check(collision.preview_stats.fallback_clears==before+1,"Live world scope mismatch cannot consume an old view")
	world.free()
func initial_probe_is_unrestricted()->void:
	var setup:=fixture();var world=setup.world;var collision=setup.collision
	var a:=Vector3(1,7,0);var b:=Vector3(2,7,0);var before: int=collision.preview_stats.collections
	var clear: Callable=collision.query_preview(1,a,b,a)
	check(collision.preview_stats.collections==before,"Creating a preview closure performs no eager collection")
	check(clear.call(a,b) and collision.preview_stats.collections==before and collision.preview_stats.initial_clears==1,"Successful first probe uses only the original unrestricted geometry")
	check(clear.call(a,b) and collision.preview_stats.collections==before+1 and collision.preview_stats.reused_clears==1,"A requested second probe creates the scoped view once")
	world.free()
func immutable_xy_oracle()->void:
	var seed:=RandomNumberGenerator.new();seed.seed=0x79ac1e35
	for index in 512:
		var scale:=100000.0 if index%17==0 else 10.0
		var a:=Vector3(seed.randf_range(-scale,scale),seed.randf_range(-scale,scale),seed.randf_range(-2,2))
		var b:=Vector3(seed.randf_range(-scale,scale),seed.randf_range(-scale,scale),seed.randf_range(-2,2))
		var c:=Vector3(seed.randf_range(-scale,scale),seed.randf_range(-scale,scale),seed.randf_range(-2,2))
		if index%16==0:b=a
		if index%19==0:c=a+Vector3(0.00001,0.00001,0)
		var original: Dictionary=FrozenGeometry.triangle(a,b,c);var cached: Dictionary=Collision.triangle(a,b,c)
		var prepared:=Arithmetic.TileTerms.new();prepared.configure([cached],Arithmetic.Counts.new())
		var from:=Vector2(seed.randf_range(-scale,scale),seed.randf_range(-scale,scale));var to:=Vector2(seed.randf_range(-scale,scale),seed.randf_range(-scale,scale))
		if index%11==0:to=from
		var expected: Vector2=FrozenGeometry.interval(from,to,original)
		check(var_to_bytes(Collision.interval(from,to,cached))==var_to_bytes(expected),"Cached immutable XY interval is bit-exact against prechange source "+str(index))
		check(var_to_bytes(Collision.interval(from,to,original))==var_to_bytes(expected),"Uncached external triangle keeps original interval "+str(index))
		check(var_to_bytes(prepared.interval(from,to,0,cached))==var_to_bytes(expected),"Prepared from-side first sample is bit-exact against frozen interval "+str(index))
		check(var_to_bytes(prepared.interval(from,to,0,cached))==var_to_bytes(expected),"Reused from-side sample is bit-exact against frozen interval "+str(index))
		for radius in [0.0,0.3,1.2]:
			check(Collision.hits(from,to,cached,radius,-1,2)==FrozenGeometry.hits(from,to,original,radius,-1,2),"Cached exact hit oracle "+str(index)+" radius "+str(radius))
func height_memo_oracle_and_bounds()->void:
	var setup:=fixture();var world=setup.world;var surface=world.surface
	check(not Arithmetic.worthwhile(surface,Vector3.ZERO,Vector3(9,9,0)),"Sparse decoded geometry bypasses arithmetic cache without constructing tiles")
	for point in [Vector3(1,1,0),Vector3(3.8,1.5,0),Vector3(9.99999,9.99999,0),Vector3.ZERO]:
		var arithmetic:=Arithmetic.new();arithmetic.configure(point,surface,{})
		check(arithmetic.accepts(surface,point),"Published pure height owner is eligible")
		var local: Array=[FrozenHeight.f(point.x),FrozenHeight.f(point.y)]
		var expected: float=FrozenHeight.f(FrozenHeight.height(surface.meshes.floor,surface.table,local)+FrozenHeight.f(surface.definition.tiles[0].position.y))
		check(var_to_bytes(arithmetic.start_height(surface,point,point.z))==var_to_bytes(expected),"First height sample agrees with frozen math")
		check(var_to_bytes(arithmetic.start_height(surface,point,point.z))==var_to_bytes(expected) and arithmetic.counts.height_hits==1,"Repeated start height retains frozen result bits")
		var replacement: Dictionary=surface.table.duplicate(true);surface.table=replacement
		check(not arithmetic.accepts(surface,point),"Source table replacement cannot reuse the old memo")
	var positive:=Vector3(0.0,1,0);var negative:=Vector3(PackedByteArray([0,0,0,128]).decode_float(0),1,0)
	var exact:=Arithmetic.new();exact.configure(positive,surface,{})
	check(Arithmetic.point_bits(positive)!=Arithmetic.point_bits(negative) and not exact.matches(negative),"Input point keys distinguish signed zero")
	var opaque:=OpaqueWalk.new();surface.table={"orderedRows":[{"Walk":opaque}]}
	var unknown:=Arithmetic.new();unknown.configure(positive,surface,{})
	check(not unknown.accepts(surface,positive) and opaque.reads==0,"Opaque table conversion is neither invoked nor memoized")
	var cache:=Arithmetic.new();cache.configure(positive,surface,{})
	var huge: Array=[];huge.resize(Arithmetic.MAX_BYTES/25+1)
	check(cache.tile_terms(0,huge)==null and cache.bytes==0,"Oversized numeric cache is rejected before allocation")
	var tri: Dictionary=Collision.triangle(Vector3.ZERO,Vector3.RIGHT,Vector3.UP);var triangles: Array=[tri]
	for index in Arithmetic.MAX_TILES:check(cache.tile_terms(index,triangles)!=null,"Bounded metadata slot "+str(index))
	check(cache.tile_terms(Arithmetic.MAX_TILES,triangles)==null and cache.tiles.size()==Arithmetic.MAX_TILES and cache.bytes<=Arithmetic.MAX_BYTES,"Tile metadata and numeric payload remain bounded")
	check(cache.tile_terms(0,[tri])==null,"Replaced triangle-array identity falls back")
	world.free()
func run()->void:
	geometry_and_paths();corner_and_radius();invalidations();pending_and_height();await collection_once();orientation_order()
	counting_and_disabled_profile();failed_collection_ledger();mutation_during_probe();world_scope_fence();initial_probe_is_unrestricted();immutable_xy_oracle();height_memo_oracle_and_bounds()
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Current-main exact preview-envelope transcript/oracle plus actual probe accounting, disabled profiling, failed-collection fallback, in-probe publication and live scope invalidation. No graphics, live server or FPS acceptance."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
