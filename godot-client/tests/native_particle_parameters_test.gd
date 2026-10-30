extends "res://tests/native_particle_schedule_test.gd"
const Emitter=preload("res://systems/native_render/particle_emitter.gd")
const Kernel=preload("res://systems/native_render/particle_kernel.gd")
func bits(value: float) -> PackedByteArray: return PackedFloat32Array([value]).to_byte_array()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var index:=0
	var mismatches: Array=[]
	# Construct signed zero from bits: this engine's constant pool can merge
	# literal +0.0/-0.0, which otherwise changes the reference's default word.
	var zero_bytes:=PackedByteArray(); zero_bytes.resize(4); zero_bytes.encode_u32(0,0x80000000)
	var negative_zero:=zero_bytes.decode_float(0)
	for value in [-100.25,negative_zero,0.0,1.0/3.0,16777217.0,1e20,1e-20]:
		for mask in 3:
			var parameters: Dictionary={}; var field_index:=0
			for name in Emitter.FIELDS:
				if mask==0 or mask==1 and field_index%2==0: parameters[name]=value
				field_index+=1
			var colors: Array=[[],[1.2],[value,0.4,0.7],[1.0,2.0,3.0,4.0,5.0]][index%4]
			if mask!=2: parameters.colorstart=colors; parameters.colorend=colors.duplicate()
			var actual:={"sentinel":[1,2,3],"detonate108":123}; var expected:=actual.duplicate(true)
			for name in Emitter.FIELDS: expected[Emitter.FIELDS[name]]=M.f(parameters.get(name,1.0 if name=="blurlength" else 0.0))
			expected.colorStart=M.values(parameters.get("colorstart",[0.0,0.0,0.0])); expected.colorEnd=M.values(parameters.get("colorend",[0.0,0.0,0.0]))
			var out:=Kernel.simulate("parameters",actual,0.0,{},parameters)
			check(not out.has("error"),"Native parameter transfer accepts fixture "+str(index))
			for name in Emitter.FIELDS:
				var destination: String=Emitter.FIELDS[name]
				if bits(float(actual.get(destination,INF)))!=bits(float(expected[destination])) and mismatches.size()<3: mismatches.append({"field":destination,"actual":actual.get(destination),"expected":expected[destination],"actual_bits":bits(float(actual.get(destination,INF))).hex_encode(),"expected_bits":bits(float(expected[destination])).hex_encode()})
				check(bits(float(actual.get(destination,INF)))==bits(float(expected[destination])),"Exact binary32 scalar/default "+str(index)+"/"+destination)
			check(same(actual,expected).is_empty(),"Full state/color arrays and unrelated fields match existing GDScript transfer "+str(index))
			if parameters.has("colorstart") and not colors.is_empty():
				var before: float=actual.colorStart[0]; parameters.colorstart[0]=999.0
				check(actual.colorStart[0]==before,"Native state retains an independent color array "+str(index))
			index+=1
	for invalid in [{"birthrate":"bad"},{"birthrate":null},{"colorstart":"bad"},{"colorend":null}]:
		var state: Dictionary={}; var out:=Kernel.simulate("parameters",state,0.0,{},invalid)
		check(out.has("error"),"Malformed parameter values remain explicit failures")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"mismatches":mismatches,"cases":index,"fields":Emitter.FIELDS.size(),"publicConnections":0,"scope":"Cross-language exact float-word/default/color-array comparison against existing original-field GDScript transfer, including signed zero and independent arrays. No simulation/controller/FPS acceptance by this test alone."},"\t")); file.close()
	print("NATIVE_PARTICLE_PARAMETERS ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
