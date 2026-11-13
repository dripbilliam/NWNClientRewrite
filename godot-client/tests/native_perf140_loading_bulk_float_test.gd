extends "res://tests/native_perf140_loading_processor_capture_test.gd"
const FloatStream=preload("res://systems/native_data/binary_float_stream.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Model=preload("res://systems/native_data/binary_model.gd")
func scalar(bytes: PackedByteArray,at: int,count: int) -> PackedFloat32Array:
	var reader:=Binary.new(bytes); var values:=PackedFloat32Array()
	for index in count: values.append(reader.f32(at+index*4))
	return values
func helper_checks() -> void:
	check(FloatStream.compatible,"pinned engine admits proven little-endian integer/float packed layout")
	var words: Array=[0,0x80000000,0x00800000,0x80800000,0x7f7fffff,0xff7fffff,0x3f800000,0xbf800000,1,0x007fffff,0x80000001,0x807fffff,0x7f800000,0xff800000,0x7f800001,0x7fc00001,0x7fffffff,0xff800001,0xffc00001,0xffffffff]
	var state:=9148729
	for index in 2048:
		state=(state*1664525+1013904223)&0xffffffff; words.append(state)
	for word in words:
		var raw:=PackedByteArray(); raw.resize(4); raw.encode_u32(0,word); var original:=raw.duplicate()
		var absolute:=int(word)&0x7fffffff; var admitted:=absolute==0 or absolute>=0x00800000 and absolute<0x7f800000
		var packet:=FloatStream.read(raw,0,1)
		check(bool(packet.accepted)==admitted,"exact IEEE admission for "+str(word))
		if packet.accepted: check(packet.value.to_byte_array()==scalar(raw,0,1).to_byte_array(),"normal/signed-zero bits equal the original double-to-f32 scalar path")
		else: check(not packet.has("value"),"rejected exceptional words invent no calculated stream")
		check(raw==original,"native integer validation never mutates source words")
	var stream:=PackedByteArray([99,87,41]); var expected:=PackedFloat32Array([1.0,-4.5,0.0,-0.0,23.125]); stream.append_array(expected.to_byte_array())
	var packed:=FloatStream.read(stream,3,expected.size()); check(packed.accepted and packed.value.to_byte_array()==scalar(stream,3,expected.size()).to_byte_array(),"unaligned original stream range is exact")
	var before:=stream.duplicate(); packed.value[0]=999.0; check(stream==before,"consumer float mutation cannot change original raw bytes")
	var retained:=FloatStream.read(stream,3,expected.size()); stream.fill(0); check(retained.value.to_byte_array()==expected.to_byte_array(),"retained packed stream is isolated from later source mutation")
	for args in [[-1,1],[0,-1],[1,stream.size()],[stream.size()+1,0],[0,FloatStream.MAX_COUNT+1]]:
		check(not FloatStream.read(stream,args[0],args[1]).accepted,"invalid/overflow stream bounds retain original fallback")
	check(not FloatStream.read(before,3,expected.size(),false).accepted,"unproven endian/layout explicitly retains scalar fallback")
	var compatible:=FloatStream.compatible; FloatStream.compatible=false
	check(not FloatStream.read(before,3,expected.size()).accepted,"unknown platform capability fails closed")
	FloatStream.compatible=compatible
	check(FloatStream.read(PackedByteArray(),0,0).accepted,"zero-length stream preserves empty original data")
func first_mesh(bytes: PackedByteArray) -> int:
	var pending: Array=[int(bytes.decode_u32(84))]; var seen: Dictionary={}
	while not pending.is_empty():
		var offset:=int(pending.pop_back()); if seen.has(offset): return -1
		seen[offset]=true; var at:=12+offset; var flags:=int(bytes.decode_u32(at+108)); var cursor:=at+112
		for extension in [[2,92],[4,216],[16,68]]:
			if flags&int(extension[0]): cursor+=int(extension[1])
		if flags&32 and bytes.decode_u16(cursor+448)>0 and bytes.decode_u32(cursor+12)>0 and bytes.decode_u16(cursor+450)>0 and bytes.decode_u32(cursor+452)!=0xffffffff and bytes.decode_u32(cursor+468)!=0xffffffff: return cursor
		for child in int(bytes.decode_u32(at+76)): pending.append(int(bytes.decode_u32(12+int(bytes.decode_u32(at+72))+child*4)))
	return -1
func run() -> void:
	helper_checks()
	var enabled:=FloatStream.enabled(); var catalog:=Recorded.new(); check(catalog.mount(argument("--recorded-catalog=")),"sealed captured catalog mounts")
	var service:=Assets.new(); root.add_child(service); service.maximum_workers=1; service.cache_directory=""; service.prework_read=false; service.prework_write=false; service.configure(catalog); service.completed.connect(func(_id,result):packets.append(result))
	var cases: Array=[]; var baseline:=argument("--baseline-root=")
	for name in argument("--models=").split(",",false):
		var result: Dictionary=await request(service,name); check(str(result.get("error","")).is_empty(),"actual captured model prepares: "+name)
		var content: Dictionary=service.bundle_content(result); var file_path:=baseline.path_join(name+".bin"); var raw_file:=FileAccess.open(argument("--report=").get_base_dir().path_join(name+".bin"),FileAccess.WRITE); raw_file.store_var(content,false); raw_file.close()
		if not enabled:
			var file:=FileAccess.open(file_path,FileAccess.WRITE); file.store_var(content,false); file.close()
		else:
			var file:=FileAccess.open(file_path,FileAccess.READ); check(file!=null,"original complete packet exists: "+name)
			if file!=null:
				var expected_packet: Dictionary=file.get_var(false); file.close(); check(data_equal(content,expected_packet),"all original model/image/dependency data remain exact: "+name)
		cases.append({"name":name,"data_hash":Cache.digest(var_to_bytes(canonical(data_view(content)))),"error":result.get("error","")})
	service.close(); service.free(); catalog.preparation_cache().clear(); catalog.decoded_cache().clear()
	var raw: PackedByteArray=catalog.get_resource("ttu01_a01_01",2002); var mesh:=first_mesh(raw); check(mesh>=0,"actual captured mesh header is available for original parser fallback/error oracle")
	var parser_cases: Array=[]
	if mesh>=0:
		var raw_start:=12+int(raw.decode_u32(4)); var vertex_at:=raw_start+int(raw.decode_u32(mesh+444)); var normal_at:=raw_start+int(raw.decode_u32(mesh+468)); var uv_at:=raw_start+int(raw.decode_u32(mesh+452))
		for mutation in ["bad-vertex-offset","bad-normal-offset","bad-uv-offset","truncated","positive-snan","negative-qnan","positive-infinity","negative-subnormal","positive-subnormal","negative-zero","normal-snan","uv-snan","uv-subnormal","normal-negative-zero"]:
			var bytes:=raw.duplicate()
			match mutation:
				"bad-vertex-offset": bytes.encode_u32(mesh+444,0x7fffffff)
				"bad-normal-offset": bytes.encode_u32(mesh+468,0x7fffffff)
				"bad-uv-offset": bytes.encode_u32(mesh+452,0x7fffffff)
				"truncated": bytes.resize(bytes.size()-1)
				"positive-snan": bytes.encode_u32(vertex_at,0x7f800001)
				"negative-qnan": bytes.encode_u32(vertex_at,0xffc00001)
				"positive-infinity": bytes.encode_u32(vertex_at,0x7f800000)
				"negative-subnormal": bytes.encode_u32(vertex_at,0x80000001)
				"positive-subnormal": bytes.encode_u32(vertex_at,1)
				"negative-zero": bytes.encode_u32(vertex_at,0x80000000)
				"normal-snan": bytes.encode_u32(normal_at,0x7f800001)
				"uv-snan": bytes.encode_u32(uv_at,0x7f800001)
				"uv-subnormal": bytes.encode_u32(uv_at,1)
				"normal-negative-zero": bytes.encode_u32(normal_at,0x80000000)
			var parser:=Model.new(); var value:=parser.parse(bytes); var envelope:={"value":value,"error":parser.failure}; var file_path:=baseline.path_join(mutation+".bin")
			if not enabled:
				var file:=FileAccess.open(file_path,FileAccess.WRITE); file.store_var(envelope,false); file.close()
			else:
				var file:=FileAccess.open(file_path,FileAccess.READ); check(file!=null,"original parser edge checkpoint exists: "+mutation)
				if file!=null:
					var expected_packet: Dictionary=file.get_var(false); file.close(); check(var_to_bytes(canonical(envelope))==var_to_bytes(canonical(expected_packet)),"original numerical bits and bounds/error precedence remain exact: "+mutation)
			parser_cases.append({"case":mutation,"data_hash":Cache.digest(var_to_bytes(canonical(envelope))),"error":parser.failure})
	var proof:={"success":failures.is_empty() and cases.size()==8,"checks":checks,"enabled":enabled,"compatible":FloatStream.compatible,"failures":failures,"cases":cases,"parser_cases":parser_cases,"raw_envelopes_preserved":true,"timing_claim":false,"graphics":0,"server_connections":0,"scope":"Native integer range admission plus exact original float bytes/error fallback and eight complete captured worker packet oracle."}
	var file:=FileAccess.open(argument("--report="),FileAccess.WRITE); file.store_string(JSON.stringify(proof)); file.close(); print(JSON.stringify({"success":proof.success,"checks":checks,"enabled":enabled,"failures":failures})); quit(0 if proof.success else 1)
