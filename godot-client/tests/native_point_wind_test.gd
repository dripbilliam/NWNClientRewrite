extends "res://tests/native_particle_schedule_test.gd"
const Points=preload("res://systems/native_render/point_wind.gd")
const World=preload("res://systems/native_render/live_world.gd")
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
func wind_list(rows: Array,capacity: int) -> Dictionary:
	var list:=Points.empty(); list.capacity=capacity
	for row in rows: list.records.append({"position":M.values(row.slice(0,3)),"radius":M.f(row[3]),"duration":M.f(row[4]),"remaining":M.f(row[5]),"strength":M.f(row[6])})
	return list
func list_state(list: Dictionary) -> Dictionary:
	return {"capacity":list.capacity,"records":list.records.map(func(w):return w.position+[w.radius,w.duration,w.remaining,w.strength])}
func emitter(parent: Node3D,position: Vector3,services: Dictionary={}) -> Node3D:
	var part:=Node3D.new(); parent.add_child(part); part.position=position
	var out:=Emitter.new(); out.services=services; out.source_path=NodePath(".."); out.original_properties={"update":"Explosion","render":"Normal","blend":"Normal","flags":0,"xgrid":1,"ygrid":1,"birthrate":2,"lifeexp":1,"blastradius":4,"blastlength":0.5,"sizestart":0.1,"sizeend":0.1,"alphastart":1,"alphaend":1}
	var image:=Image.create(1,1,false,Image.FORMAT_RGBA8); image.fill(Color.WHITE); out.original_texture=ImageTexture.create_from_image(image)
	part.add_child(out); out.set_process(false); return out
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var path:=ProjectSettings.globalize_path("res://").path_join("../backups/animations/native-point-wind-observations.json").simplify_path()
	var bytes:=FileAccess.get_file_as_bytes(path); var data: Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
	check(data.binarySha256==BINARY_SHA and data.queries.size()==189 and data.adds.size()==126 and data.advances.size()==60,"Original point-source corpus identity and counts")
	for index in data.queries.size():
		var row: Dictionary=data.queries[index]; var actual:=Points.sample(wind_list(row.winds,row.winds.size()),row.position)
		check(same(actual,row.result).is_empty(),"Original point-source vector "+str(index)+" "+same(actual,row.result))
	for index in data.adds.size():
		var row: Dictionary=data.adds[index]; var list:=wind_list(row.winds,int(row.capacity))
		Points.add(list,row.position,row.radius,row.duration,row.strength)
		check(same(list_state(list),row.result).is_empty(),"Original point-source append/growth "+str(index))
	for index in data.advances.size():
		var row: Dictionary=data.advances[index]; var list:=wind_list(row.winds,16)
		Points.advance(list,row.delta)
		check(same(list_state(list),row.result).is_empty(),"Original point-source expiry/shift "+str(index))
	var a:=World.new(); root.add_child(a); a.set_process(false); a.point_wind.set_process(false)
	var b:=World.new(); root.add_child(b); b.set_process(false); b.point_wind.set_process(false)
	var camera:=Camera3D.new(); a.add_child(camera); camera.position=Vector3(0,5,8); camera.look_at(Vector3.ZERO); camera.current=true
	var first=emitter(a,Vector3(1,2,-3)); var second=emitter(b,Vector3(-2,0,1))
	check(a.point_wind!=b.point_wind and first.providers.has("addPointSourceWind") and second.providers.has("addPointSourceWind"),"Live-world ancestry binds private native scene providers automatically")
	first.detonate(); first.tick(0.1)
	check(first.failure.is_empty() and first.allocated==2 and a.point_wind.stats.added==1 and b.point_wind.stats.added==0,"Compiled explosion births and registers a real source in only its own scene")
	check(a.point_wind.state.records[0].position==[1.0,3.0,2.0] and a.point_wind.state.records[0].strength==1,"Native effect pose is converted to original Z-up coordinates and strength is retained")
	first.tick(0.1)
	check(a.point_wind.stats.added==1,"Untriggered subsequent frame adds no spurious blast")
	second.detonate(); second.tick(0.1)
	a.point_wind.tick(0.5)
	check(a.point_wind.state.records.size()==1 and a.point_wind.state.records[0].remaining==0 and b.point_wind.state.records[0].remaining==0.5,"Exact-zero lifetime survives and worlds own independent clocks")
	a.point_wind.tick(0.01)
	check(a.point_wind.state.records.is_empty() and b.point_wind.state.records.size()==1,"Negative lifetime retires only the expired source")
	check(b.point_wind.point_vector([-2.0,-1.0,0.0])==[1.0,0.0,0.0],"Native scene sampling preserves original center normalization")
	var before: Dictionary=b.point_wind.snapshot(); camera.reparent(b,true); a.close(); a.queue_free(); await process_frame; await process_frame
	check(b.point_wind.snapshot().records==before.records and b.point_wind.snapshot().added==before.added,"Retiring another world preserves current point-wind state")
	var counts:={"moves":0}; var custom=emitter(b,Vector3.ZERO,{"moveParticles":func(_e,_delta):counts.moves+=1}); custom.tick(0.1)
	check(not custom.fused_dispatch and counts.moves==1 and custom.failure.is_empty(),"Explicit custom movement services retain composed dispatch semantics")
	var bounded=emitter(b,Vector3.ZERO); b.point_wind.maximum_records=1; bounded.detonate(); bounded.tick(0.1)
	check(bounded.failure.contains("allocation exceeds") and b.point_wind.state.records.size()==1,"Allocation-limit failure is explicit rather than silently dropping a source")
	check(not bounded.surface.visible,"A callback failure cannot republish the failed emitter's GPU surface")
	var metrics: Dictionary=b.point_wind.snapshot(); b.close()
	check(b.point_wind.closed and b.point_wind.state.records.is_empty() and b.point_wind.state.capacity==0,"World close releases native wind state")
	b.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"original_sha256":CacheSha(bytes),"metrics":metrics,"publicConnections":0,"scope":"375 original point-list/vector cases plus actual automatic native-world provider binding, compiled explosion, isolated lifetime/retirement and explicit overflow. Authored GPU inputs; not ambient/noise wind, scene collision or full effects/frame-order acceptance."},"\t")); file.close()
	print("NATIVE_POINT_WIND ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
func CacheSha(bytes: PackedByteArray) -> String:
	var hash:=HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(bytes); return hash.finish().hex_encode()
