extends "res://tests/native_particle_schedule_test.gd"
const Vertices=preload("res://systems/native_render/particle_vertices.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var index:=0
	var compiled: bool=args.get("kernel","")=="compiled"
	if compiled: check(Kernel.available(),"Compiled native extension loads")
	for row in original("native-particle-vertices-observations",245):
		var c: Dictionary=row.case; var calls: Array=[]; var instance:={"fade":M.f(c.fade),"height50":M.f(c.height),"opacity70":M.f(c.elevationOpacity)}; var source_instance: Dictionary=instance.duplicate(); source_instance.fade=M.f(c.sourceFade); var list: Array=[]
		for id in int(c.count): list.append({"position10":[1+id,2+id*2,3-id],"trail64":[-1+id,1+id*2,2-id],"quaternion34":[0.5,-0.5,0.5,0.5],"direction4c":[0,0,1],"rotation1c":M.f(c.rotation+id*0.125),"age":M.f(c.age+id*0.125),"field48":M.f(c.frameTime),"frame44":c.initialFrame,"stopped70":c.stopped})
		var e:={"renderMode1a8":c.mode,"active188":{"records":list},"lifeExp":M.f(c.life),"source50":{"opacity108":M.f(c.opacity),"instance":source_instance if c.sourceInstance else null} if c.source else null,"instance100":instance if c.instance else null,"flags":c.flags,"position1e0":[1,2,3],"quaternion1d0":[0.5,0.5,0.5,0.5],"ageMode1cc":c.ageMode,"xGrid":c.grid[0],"yGrid":c.grid[1],"elevationThreshold":5,"colorStart":M.values(c.colorStart),"colorEnd":M.values(c.colorEnd),"alphaStart":M.f(c.alphaStart),"alphaEnd":M.f(c.alphaEnd),"sizeStart":M.f(c.sizes[0]),"sizeEnd":M.f(c.sizes[1]),"sizeStartY":M.f(c.sizes[2]),"sizeEndY":M.f(c.sizes[3]),"fps":M.f(c.fps),"frameStart":M.f(c.frameStart),"frameEnd":M.f(c.frameEnd),"blendMode68":c.blend,"twoSided":c.twoSided}
		var p:={"sourceFactor":func(_source):calls.append(["source",c.factor]); return c.factor,"cameraQuaternion":func():return c.camera,"lightColor":func(position):calls.append(["tint",position]); return c.tint}
		var out:=Kernel.build(e,p) if compiled else Vertices.build(e,p); check(not out.has("error"),"Original draw case prepares "+str(index)); var words: Array=[]
		if out.has("buffer"):
			var bytes: PackedByteArray=out.buffer
			for word in bytes.size()/4: words.append(bytes.decode_u32(word*4))
		var actual:={"calls":calls,"committed":out.get("count",0),"drawn":out.get("count",0),"soft":out.get("softInverse"),"words":words,"particles":list.map(func(part):return {"frame":part.frame44,"frameTime":part.field48})}
		var expected: Dictionary=row.duplicate(); expected.erase("case"); var difference:=same(actual,expected)
		check(difference.is_empty(),"Original vertex stream "+str(index)+" "+difference); index+=1
		if compiled:
			# Atlas mutations above are already committed; compare the direct GPU
			# streams to the captured stream after the identical atlas update.
			var expected_stream:=Kernel.build(e,p,true)
			var direct:=Kernel.build_streams(e,p,192,true)
			check(not direct.has("error"),"Direct streams prepare "+str(index))
			if direct.has("error"): continue
			var packed: PackedByteArray=expected_stream.get("buffer",PackedByteArray())
			var positions:=PackedByteArray(); var attributes:=PackedByteArray()
			positions.resize(int(direct.capacity)*12); attributes.resize(int(direct.capacity)*12)
			for vertex in int(expected_stream.get("count",0)):
				var offset:=vertex*24; var target:=vertex*12
				positions.encode_float(target,packed.decode_float(offset+4)); positions.encode_float(target+4,packed.decode_float(offset+12)); positions.encode_float(target+8,-packed.decode_float(offset+8))
				attributes.encode_u32(target,packed.decode_u32(offset)); attributes.encode_float(target+4,packed.decode_float(offset+16)); attributes.encode_float(target+8,packed.decode_float(offset+20))
			check(direct.positions==positions and direct.attributes==attributes and int(direct.count)==int(expected_stream.get("count",0)),"Direct GPU bytes and cleared capacity match original "+str(index))
			var saved_positions: PackedByteArray=direct.positions.duplicate(); var saved_attributes: PackedByteArray=direct.attributes.duplicate()
			var empty: Dictionary=e.duplicate(true); empty.active188.records.clear()
			var cleared:=Kernel.build_streams(empty,p,int(direct.capacity),true)
			check(int(cleared.get("count",-1))==0 and direct.positions==saved_positions and direct.attributes==saved_attributes,"Next emitter/frame cannot mutate queued streams "+str(index))
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"binarySha256":BINARY_SHA,"originalEvidence":evidence,"scope":"All seven CPU draw modes against captured uint32 vertex words and atlas mutations; no GPU pixel or world integration acceptance"},"\t")); file.close()
	print("NATIVE_PARTICLE_VERTICES ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
