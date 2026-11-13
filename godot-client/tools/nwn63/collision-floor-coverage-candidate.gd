extends "res://tools/nwn63/collision-preview-lazy-candidate.gd"
# Compare the current narrow phase with the exact pre-NWN63 source. Authored
# geometry supplements the retained original-preview/path and lifecycle suite.
const Before=preload("res://.cache/nwn63/before/systems/native_render/drive_collision_indexed.gd")
var case_count:=0
var compared_probes:=0
var skipped_intervals:=0
func pair()->Array:
	var result: Array=[]
	for old in [true,false]:
		var setup:=make_world(false);var world=setup.world
		var collision=Before.new() if old else Collision.new()
		world.add_child(collision);collision.world=world;collision.tables=tables();world.drive_collision=collision;collision.ensure_spatial_scope();collision.set_process(false)
		world.receive([creature(1,Vector2(1,1))],1)
		result.append(setup.merged({"collision":collision},true))
	return result
func face(a: Vector3,b: Vector3,c: Vector3,walk: bool=true)->Dictionary:
	var value: Dictionary=Collision.triangle(a,b,c);value.walk=walk;return value
func floor_faces(repetitions: int=1)->Array:
	var result: Array=[]
	for i in repetitions:
		result.append(face(Vector3(0,0,0),Vector3(10,0,0),Vector3(10,10,0)))
		result.append(face(Vector3(0,0,0),Vector3(10,10,0),Vector3(0,10,0)))
	return result
func grid_faces(divisions: int)->Array:
	var result: Array=[]
	for y in divisions:
		for x in divisions:
			var a:=Vector3(10.0*x/divisions,10.0*y/divisions,0);var b:=Vector3(10.0*(x+1)/divisions,10.0*y/divisions,0)
			var c:=Vector3(10.0*x/divisions,10.0*(y+1)/divisions,0);var d:=Vector3(10.0*(x+1)/divisions,10.0*(y+1)/divisions,0)
			result.append(face(a,b,d));result.append(face(a,d,c))
	return result
func compare_faces(geometry: Array,lines: Array,label: String)->void:
	var worlds:=pair();var old=worlds[0].collision;var next=worlds[1].collision
	old.tiles[0]=geometry;next.tiles[0]=geometry
	for line in lines:
		for radius in [0.0,0.3,1.2]:
			var a: Vector3=line[0];var b: Vector3=line[1]
			old.stats.erase("last_blocked");next.stats.erase("last_blocked")
			var before: bool=old.clear(a,b,radius,1.8,[],[],[])
			var after: bool=next.clear(a,b,radius,1.8,[],[],[])
			compared_probes+=1
			check(before==after,label+": clear decision "+str(case_count))
			check(old.stats.get("last_blocked",{}).get("reason","")==next.stats.get("last_blocked",{}).get("reason",""),label+": original first blocked reason "+str(case_count))
			case_count+=1
		var a: Vector3=line[0];var b: Vector3=line[1];var transcript_a: Array=[];var transcript_b: Array=[]
		var clear_a:=func(from: Vector3,to: Vector3):
			var result: bool=old.clear(from,to,0.3,1.8,[],[],[]);transcript_a.append([from,to,result]);return result
		var clear_b:=func(from: Vector3,to: Vector3):
			var result: bool=next.clear(from,to,0.3,1.8,[],[],[]);transcript_b.append([from,to,result]);return result
		var before: Dictionary=Plan.path(a,b,a,clear_a);var after: Dictionary=Plan.path(a,b,a,clear_b)
		check(var_to_bytes(before)==var_to_bytes(after),label+": exact original path result")
		check(transcript_a==transcript_b,label+": original bounded probe order/endpoints")
		compared_probes+=transcript_a.size()
	check(worlds[0].world.surface.stats.queries==worlds[1].world.surface.stats.queries,label+": height queries and sampling order are preserved")
	for setup in worlds:setup.world.free()
func authored_coverage()->void:
	var lines: Array=[[Vector3(1,1,0),Vector3(3,1,0)],[Vector3(1,8,0),Vector3(3,8,0)],[Vector3(2,1,0),Vector3(1,2,0)],[Vector3(5,5,0),Vector3(5,5,0)],[Vector3(0,0,0),Vector3(10,10,0)],[Vector3(1,1,1000),Vector3(3,1,-1000)]]
	compare_faces(floor_faces(),lines,"ordinary floor and shared edge")
	compare_faces(floor_faces(256),lines,"dense overlapping floor")
	compare_faces(grid_faces(24),lines,"dense tessellated floor")
	var blocked:=floor_faces(64);blocked.append(face(Vector3(2,0,0),Vector3(2,4,0),Vector3(2,4,3),false))
	compare_faces(blocked,lines,"late blocking face cannot be hidden by complete coverage")
	blocked=floor_faces(64);blocked.append(face(Vector3(2,0,1000),Vector3(2,4,1000),Vector3(2,4,1003),false))
	compare_faces(blocked,lines,"high overlapping blocking face keeps original elevation test")
	var slope: Array=[]
	for repeat in 32:
		slope.append(face(Vector3(0,0,0),Vector3(10,0,2),Vector3(10,10,4)))
		slope.append(face(Vector3(0,0,0),Vector3(10,10,4),Vector3(0,10,2)))
	compare_faces(slope,lines,"sloped coverage retains XY and unknown-Z semantics")
	for epsilon in [-0.00002,-0.00001,-0.000005,0.0,0.000005,0.00001,0.00002]:
		var trimmed: Array=[face(Vector3(epsilon,-10,0),Vector3(2,-10,0),Vector3(epsilon,10,0)),face(Vector3(2,-10,0),Vector3(2,10,0),Vector3(epsilon,10,0))]
		compare_faces(trimmed,[[Vector3.ZERO,Vector3(1,0,0)],[Vector3(1,0,0),Vector3.ZERO]],"start/end tolerance "+str(epsilon))
	var degenerate: Array=[face(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO),face(Vector3.ZERO,Vector3(0.00000001,0,0),Vector3(0,0.00000001,0))]
	degenerate.append_array(floor_faces(64));compare_faces(degenerate,lines,"degenerate and tiny-area prefixes")
	var gap: Array=[face(Vector3(0,0,0),Vector3(4,0,0),Vector3(4,10,0)),face(Vector3(6,0,0),Vector3(10,0,0),Vector3(6,10,0))]
	compare_faces(gap,[[Vector3(1,1,0),Vector3(9,1,0)],[Vector3(1,1,0),Vector3(3,1,0)]],"disconnected coverage keeps full sorted-union fallback")
	for count in [3,7,12]:
		var reversed: Array=[]
		for section in range(count-1,-1,-1):
			var left: float=10.0*section/count;var right: float=10.0*(section+1)/count
			reversed.append(face(Vector3(left,0,0),Vector3(right,0,0),Vector3(right,2,0)))
			reversed.append(face(Vector3(left,0,0),Vector3(right,2,0),Vector3(left,2,0)))
		compare_faces(reversed,[[Vector3(0.1,1,0),Vector3(9.9,1,0)],[Vector3(9.9,1,0),Vector3(0.1,1,0)]],"reversed span bridge and bounded pending fallback "+str(count))
func seeded_coverage()->void:
	var rng:=RandomNumberGenerator.new();rng.seed=0x4d36c911
	for index in 96:
		var faces: Array=floor_faces(12) if index%3==0 else []
		for i in 8:
			var a:=Vector3(rng.randf_range(-1,11),rng.randf_range(-1,11),rng.randf_range(-2,2))
			var b:=Vector3(rng.randf_range(-1,11),rng.randf_range(-1,11),rng.randf_range(-2,2))
			var c:=Vector3(rng.randf_range(-1,11),rng.randf_range(-1,11),rng.randf_range(-2,2))
			if index%17==0:c=b
			faces.append(face(a,b,c,i%5!=0))
		var a:=Vector3(rng.randf_range(0.5,8),rng.randf_range(0.5,8),0)
		var b:=Vector3(rng.randf_range(0.5,8),rng.randf_range(0.5,8),0)
		compare_faces(faces,[[a,b]],"seeded mixed faces "+str(index))
func actual_counts()->void:
	var worlds:=pair();var old=worlds[0].collision;var next=worlds[1].collision
	var geometry:=floor_faces(256);old.tiles[0]=geometry;next.tiles[0]=geometry
	Profile.enabled=true;Profile.phases={};Profile.phase_frame=-1;Profile.collected_frame=-1
	var before: bool=old.query_preview(1,Vector3(1,1,0),Vector3(3,1,0),Vector3(1,1,0)).call(Vector3(1,1,0),Vector3(3,1,0))
	var before_phases: Dictionary=Profile.phases.duplicate();Profile.phases={}
	var after: bool=next.query_preview(1,Vector3(1,1,0),Vector3(3,1,0),Vector3(1,1,0)).call(Vector3(1,1,0),Vector3(3,1,0))
	skipped_intervals=int(Profile.phases.get("count_drive_walkable_intervals_skipped",0))
	check(before and after and skipped_intervals==511,"Actual first preview skips 511/512 redundant floor intervals")
	check(int(before_phases.get("count_drive_clear_calls",0))==1 and int(Profile.phases.get("count_drive_clear_calls",0))==1,"Actual request/probe count remains one, with preserved observable scheduling")
	check(int(before_phases.get("count_drive_height_samples",0))==int(Profile.phases.get("count_drive_height_samples",0)),"Height call count is unchanged")
	Profile.enabled=false;Profile.phases={}
	for setup in worlds:setup.world.free()
func run()->void:
	geometry_and_paths();corner_and_radius();invalidations();pending_and_height();await collection_once();orientation_order()
	authored_coverage();seeded_coverage();actual_counts()
	await process_frame;await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"compared_probes":compared_probes,"skipped_intervals_in_512_face_probe":skipped_intervals,"scope":"Exact prechange source versus complete-coverage proof for finite-radius, slope, overlap, gap, boundary/degenerate/mixed faces and full native path transcripts. Retained dynamic blocker/door/elevation/lifetime/correction/area/frame fences. Native request ordering remains unchanged. No live server or FPS acceptance."}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file:=FileAccess.open(argument.trim_prefix("--report="),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print(JSON.stringify({"success":result.success,"checks":checks,"failures":failures,"compared_probes":compared_probes,"skipped_intervals":skipped_intervals}));quit(0 if failures.is_empty() else 1)
