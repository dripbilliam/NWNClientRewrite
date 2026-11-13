extends "res://tests/nwn64_resident_test.gd"
const InstanceCodec=preload("res://systems/native_render/particle_instance_codec.gd")
# Original instruction-captured words, not another implementation's output.
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(Kernel.available(),"Compact native extension loads")
	var index:=0
	var instances: bool=args.get("particle-streams","")=="instances"
	var direct: bool=args.get("particle-streams","")=="direct"
	for row in original("native-particle-vertices-observations",245):
		var c: Dictionary=row.case
		var base:=make_owner(false,"fountain",int(c.flags),false,false)
		var e: Dictionary=base.state
		var instance:={"fade":M.f(c.fade),"height50":M.f(c.height),"opacity70":M.f(c.elevationOpacity)}
		var source_instance: Dictionary=instance.duplicate(); source_instance.fade=M.f(c.sourceFade)
		var list: Array=[]
		for id in int(c.count): list.append({"position10":[1+id,2+id*2,3-id],"trail64":[-1+id,1+id*2,2-id],"quaternion34":[0.5,-0.5,0.5,0.5],"direction4c":[0,0,1],"rotation1c":M.f(c.rotation+id*0.125),"age":M.f(c.age+id*0.125),"field48":M.f(c.frameTime),"frame44":c.initialFrame,"stopped70":c.stopped,"inheritedSpeed20":0.0,"inheritedDirection24":[0,0,0],"velocity58":[0,0,0]})
		e.merge({"renderMode1a8":c.mode,"active188":{"records":list,"capacity":list.size()},"lifeExp":M.f(c.life),"instance100":instance if c.instance else null,"position1e0":[1,2,3],"quaternion1d0":[0.5,0.5,0.5,0.5],"ageMode1cc":c.ageMode,"xGrid":c.grid[0],"yGrid":c.grid[1],"elevationThreshold":5,"colorStart":M.values(c.colorStart),"colorEnd":M.values(c.colorEnd),"alphaStart":M.f(c.alphaStart),"alphaEnd":M.f(c.alphaEnd),"sizeStart":M.f(c.sizes[0]),"sizeEnd":M.f(c.sizes[1]),"sizeStartY":M.f(c.sizes[2]),"sizeEndY":M.f(c.sizes[3]),"fps":M.f(c.fps),"frameStart":M.f(c.frameStart),"frameEnd":M.f(c.frameEnd),"blendMode68":c.blend,"twoSided":c.twoSided},true)
		if c.source:
			e.source50.opacity108=M.f(c.opacity); e.source50.instance=source_instance if c.sourceInstance else null
		else: e.source50=null
		var owner: RefCounted=ClassDB.instantiate("NwnParticleOwner")
		var configured: Dictionary=owner.call("dispatch",0,{"state":e,"update":"fountain","compactRecords":true,"typedEmitter":args.get("particle-emitter","")=="typed"},{})
		check(not configured.has("error"),"Compact original vertex fixture configures "+str(index))
		if configured.has("error"): base.providers.clear(); continue
		var out: Dictionary=owner.call("dispatch",7 if direct else 6,{"factor":M.f(c.factor) if c.source else 1.0,"camera":M.values(c.camera),"tint":M.values(c.tint) if int(c.flags)&8 else [1.0,1.0,1.0],"capacity":192,"instances":instances},{})
		check(not out.has("error"),"Compact original vertex fixture builds "+str(index))
		if out.has("error"): base.providers.clear(); continue
		var bytes:=PackedByteArray(); bytes.resize(row.words.size()*4)
		for word in row.words.size(): bytes.encode_u32(word*4,int(row.words[word]))
		var expected:=expected_bytes(bytes,int(out.get("capacity",out.count)))
		if direct:
			var converted:=PackedByteArray(); converted.resize(int(row.drawn)*24)
			for vertex in int(row.drawn):
				var offset:=vertex*24; converted.encode_u32(offset,bytes.decode_u32(offset)); converted.encode_float(offset+4,bytes.decode_float(offset+4)); converted.encode_float(offset+8,bytes.decode_float(offset+12)); converted.encode_float(offset+12,-bytes.decode_float(offset+8)); converted.encode_u32(offset+16,bytes.decode_u32(offset+16)); converted.encode_u32(offset+20,bytes.decode_u32(offset+20))
			check(out.buffer==converted and int(out.count)==int(row.drawn),"Active-only interleaved bytes match original uint32 geometry "+str(index))
			if index%20==0:
				var retained: PackedByteArray=out.buffer.duplicate()
				var next: Dictionary=owner.call("dispatch",7,{"factor":2.0,"camera":[1,0,0,0],"tint":[1,1,1]},{})
				check(not next.has("error") and out.buffer==retained,"New geometry cannot mutate a retained direct frame packet "+str(index))
		else:
			var actual: Dictionary=InstanceCodec.to_streams(out.instances,int(out.count),int(out.capacity)) if instances else out
			check(actual.positions==expected[0] and actual.attributes==expected[1] and int(out.count)==int(row.drawn),"Compact direct GPU bytes match original uint32 words "+str(index))
		if instances: check(out.instances.size()==int(out.count)/6*80,"Instance packet contains only populated records "+str(index))
		if instances and index%20==0:
			var retained: PackedByteArray=out.instances.duplicate()
			var next: Dictionary=owner.call("dispatch",6,{"factor":2.0,"camera":[1,0,0,0],"tint":[1,1,1],"capacity":192,"instances":true},{})
			check(not next.has("error") and out.instances==retained,"A later frame never mutates a previously published instance packet "+str(index))
		var snapshot: Dictionary=owner.call("dispatch",2,{},{})
		var atlas: Array=snapshot.active188.records.map(func(part):return {"frame":part.frame44,"frameTime":part.field48})
		check(same(atlas,row.particles).is_empty(),"Compact atlas mutation matches original "+str(index))
		base.providers.clear(); owner=null; index+=1
	check(index==245,"Every original draw-mode case reached compact storage")
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"cases":index,"binarySha256":BINARY_SHA,"network_connections":0,"scope":"Compact records and all seven draw modes against original instruction-captured uint32 geometry/atlas corpus. No simulation advance or GPU pixel claim."},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
