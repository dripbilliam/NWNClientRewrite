extends SceneTree
const Raster=preload("res://systems/native_data/texture_data.gd")
const Palette=preload("res://systems/native_data/palette_texture.gd")
const Convert=preload("res://systems/native_data/raster_conversion.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func same(a: Variant,b: Variant) -> bool: return Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b))
func _initialize() -> void: call_deferred("run")
func tga(kind: int,bits: int,width: int=11,height: int=3) -> PackedByteArray:
	var bytes:=PackedByteArray(); bytes.resize(21); bytes[0]=3; bytes[2]=kind; bytes.encode_u16(12,width); bytes.encode_u16(14,height); bytes[16]=bits; bytes[17]=48
	if kind in [1,9]:
		bytes[1]=1; bytes.encode_u16(5,8); bytes[7]=24
		for i in 24: bytes.append((i*29+11)&255)
	var pixel:=0; var count:=width*height; var stride:=bits/8
	while pixel<count:
		var run:=1; var repeat:=false
		if kind in [9,10,11]:
			run=mini(1+pixel%7,count-pixel); repeat=pixel%2==0; bytes.append((128 if repeat else 0)+run-1)
		for i in (1 if repeat else run):
			for c in stride: bytes.append((pixel+i+c*61)%8 if kind in [1,9] else ((pixel+i)*23+c*79+7)&255)
		pixel+=run
	return bytes
func dds(bits: int) -> PackedByteArray:
	var bytes:="DDS ".to_ascii_buffer(); bytes.resize(128); bytes.encode_u32(4,124); bytes.encode_u32(8,0x20000); bytes.encode_u32(12,5); bytes.encode_u32(16,7); bytes.encode_u32(28,3)
	bytes.encode_u32(88,bits); bytes.encode_u32(92,0xff0000); bytes.encode_u32(96,0xff00); bytes.encode_u32(100,0xff); bytes.encode_u32(104,0xff000000 if bits==32 else 0)
	var w:=7; var h:=5
	for level in 3:
		for i in w*h*(bits/8): bytes.append((i*43+level*71)&255)
		w=maxi(1,w>>1); h=maxi(1,h>>1)
	return bytes
func compare(bytes: PackedByteArray,type: int,label: String,valid: bool=true) -> void:
	var sha:=Cache.digest(bytes); var a:=Raster.new(); a.use_native=false; var expected:=a.parse(bytes,type)
	var b:=Raster.new(); b.use_native=true; var value:=b.parse(bytes,type)
	check(a.failure==b.failure and same(expected,value),label+": complete result/error agrees byte-for-byte")
	check(Cache.digest(bytes)==sha,label+": source storage is immutable")
	if valid: check(not value.is_empty() and b.stats.native_pixels>0 and b.stats.gd_pixels==0,label+": compiled pixel path actually executed")
func plt(width: int,height: int) -> PackedByteArray:
	var bytes:="PLT V1  ".to_ascii_buffer(); bytes.resize(24+width*height*2); bytes.encode_u32(8,10); bytes.encode_u32(16,width); bytes.encode_u32(20,height)
	for i in width*height: bytes[24+i*2]=(i*47+3)&255; bytes[25+i*2]=[8,4,3,5,0,9,2,7,1,6,255][i%11]
	return bytes
func palettes() -> Dictionary:
	var output: Dictionary={}
	for name in Palette.NAMES:
		if output.has(name): continue
		var bytes:=PackedByteArray(); bytes.resize(256*4*4)
		for i in bytes.size(): bytes[i]=(i*31+(i/(256*4))*17+output.size()*73)&255
		output[name]={"width":256,"height":4,"format":"rgba8","mips":[{"data":bytes}]}
	return output
func parallel(bytes: PackedByteArray,expected: String) -> bool:
	for iteration in 12:
		var raster:=Raster.new(); raster.use_native=true; var result:=raster.parse(bytes,3)
		if not raster.failure.is_empty() or Cache.digest(result.mips[0].data)!=expected: return false
	return true
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(Convert.available,"Pinned native raster API is registered")
	for spec in [[1,8],[2,16],[2,24],[2,32],[3,8],[3,16],[9,8],[10,16],[10,24],[10,32],[11,8],[11,16]]:
		var bytes:=tga(spec[0],spec[1]); compare(bytes,3,"Authored TGA kind/depth "+str(spec))
		compare(bytes.slice(0,17),3,"Truncated header "+str(spec),false)
		compare(bytes.slice(0,bytes.size()-1),3,"Truncated pixels "+str(spec),false)
	for bits in [24,32]: compare(dds(bits),2033,"Authored uncompressed DDS/mips "+str(bits))
	for edit in [[2,99],[12,0],[16,7],[1,1]]:
		var bad:=tga(2,24); bad[edit[0]]=edit[1]; compare(bad,3,"Malformed header "+str(edit),false)
	var overflow:=tga(10,24); overflow[21]=255; compare(overflow,3,"RLE packet overrun",false)
	var random:=RandomNumberGenerator.new(); random.seed=0x741a4730
	for trial in 100:
		var spec: Array=[[1,8],[2,16],[2,24],[2,32],[9,8],[10,24],[10,32],[11,16]][trial%8]
		var altered:=tga(spec[0],spec[1])
		for mutation in 3: altered[random.randi_range(0,altered.size()-1)]=random.randi_range(0,255)
		# Bound fuzz allocations while exercising packet/palette/header errors.
		altered.encode_u16(12,11); altered.encode_u16(14,3)
		compare(altered,3,"Seeded malformed/changed raster "+str(trial),false)
	check(Convert.bgra(PackedByteArray([1,2,3]),0,9223372036854775807,4).is_empty() and Convert.bgra(PackedByteArray([1,2,3]),-1,1,3).is_empty(),"Native direct converter rejects huge count and negative offset without overflow")
	check(Convert.colorize(plt(2,2),PackedByteArray([1])).is_empty() and Convert.layer_order(PackedByteArray())==0,"Native PLT entrypoints reject invalid lookup/header")
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../backups/animations/native-tga-origin-v1.json"))
	check(oracle.target=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" and oracle.cases.size()==288,"Pinned original resource-handler oracle is complete")
	for index in oracle.cases.size():
		var row: Dictionary=oracle.cases[index]; var parser:=Raster.new(); parser.use_native=true; var value:=parser.parse(PackedByteArray(row.input),3); var expected:=PackedByteArray(); var channels:=int(row.depth)/8
		for pixel in int(row.width)*int(row.height):
			var at:=pixel*channels
			expected.append_array(PackedByteArray([row.rawRgb[at],row.rawRgb[at],row.rawRgb[at],255]) if channels==1 else PackedByteArray([row.rawRgb[at],row.rawRgb[at+1],row.rawRgb[at+2],row.rawRgb[at+3] if channels==4 else 255]))
		check(parser.failure.is_empty() and not value.is_empty() and value.mips[0].data==expected,"Original raw origin/channel oracle "+str(index))
	var palette:=palettes(); var raw:=plt(33,7)
	for rows in [[],[0,1,2,3,4,-1,99,2,1,0],[0.9,1.1,2.8,3.0,0,1,2,3,0,1],["bad"],[NAN]]:
		var a:=Palette.new(); a.use_native=false; var expected:=a.decode(raw,palette,rows)
		var b:=Palette.new(); b.use_native=true; var value:=b.decode(raw,palette,rows)
		check(a.failure==b.failure and same(expected,value),"PLT exact pixels/clamp/invalid-row behavior "+str(rows))
		check(a.header(raw).palettes==b.header(raw).palettes,"PLT first-encounter palette dependencies remain ordered")
	var only:=plt(1,1); only[25]=0
	var a:=Palette.new(); a.use_native=false; var b:=Palette.new(); b.use_native=true
	check(same(a.decode(only,palette,[0,"unused invalid"]),b.decode(only,palette,[0,"unused invalid"])) and b.failure.is_empty(),"Unused invalid color channels do not become failures")
	var input:=tga(10,32,128,64); var expected:=Convert.tga(input); var threads: Array=[]
	for index in 4:
		var thread:=Thread.new(); thread.start(parallel.bind(input,Cache.digest(expected))); threads.append(thread)
	var joined: Array=[]
	for thread in threads: joined.append(thread.wait_to_finish())
	check(joined.all(func(value):return value),"Four concurrent loader threads preserve exact private outputs")
	var samples: Array=[]
	if args.has("catalog"):
		var catalog:=Recorded.new(); check(catalog.mount(args.catalog),"Strict frozen texture corpus mounts without fallback")
		var selected: Array=[]
		for name in catalog.resource_names(3):
			var key:=str(name)+":3"; var resource: Dictionary=catalog.manifest.resources.get(key,{})
			if not resource.has("error") and int(resource.get("bytes",0))>=1000000: selected.append({"name":name,"size":int(resource.bytes)})
		selected.sort_custom(func(x,y):return x.size>y.size)
		for item in selected.slice(0,3):
			var bytes:=catalog.get_resource(str(item.name),3); var gd:=Raster.new(); gd.use_native=false; var began:=Time.get_ticks_usec(); var reference:=gd.parse(bytes,3); var gd_ms:=(Time.get_ticks_usec()-began)/1000.0
			var native:=Raster.new(); native.use_native=true; began=Time.get_ticks_usec(); var candidate:=native.parse(bytes,3); var native_ms:=(Time.get_ticks_usec()-began)/1000.0
			check(gd.failure.is_empty() and native.failure.is_empty() and same(reference,candidate) and native.stats.native_pixels>0,"Original large TGA exact bytes "+str(item.name))
			samples.append({"name":item.name,"bytes":bytes.size(),"gd_ms":gd_ms,"native_ms":native_ms,"sha256":Cache.digest(bytes),"output_sha256":Cache.digest(candidate.mips[0].data)})
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"Exact compiled/GD TGA/DDS/PLT bytes/errors, original 288-case raw resource oracle and concurrent worker calls; no original GPU pixel or whole-world performance acceptance"},"\t")); file.close()
	print("NATIVE_RASTER_CONVERSION ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
