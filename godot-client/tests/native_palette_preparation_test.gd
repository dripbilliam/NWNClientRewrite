extends "res://tests/native_raster_conversion_test.gd"
const Store=preload("res://systems/native_data/preparation_store.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
class HeldPalette:
	extends Palette
	var entered:=Semaphore.new()
	var release:=Semaphore.new()
	func parse_palette(raw: PackedByteArray) -> Dictionary:
		entered.post(); release.wait(); return super.parse_palette(raw)
func write(path: String,bytes: PackedByteArray) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE); file.store_buffer(bytes); file.close()
func palette_job(owner,raw: PackedByteArray,store) -> Dictionary: return owner.palette_data(raw,store)
func prepare_job(catalog,rows: Array) -> Dictionary: return Palette.new().prepare(catalog.fork(),"authored",rows)
func coalesced_case(raw: PackedByteArray,valid: bool) -> void:
	var store:=Store.new(); var leader:=HeldPalette.new(); var threads: Array=[]; var owners: Array=[leader]
	var first:=Thread.new(); first.start(palette_job.bind(leader,raw,store)); threads.append(first); leader.entered.wait()
	for index in 3:
		var owner:=Palette.new(); owners.append(owner); var thread:=Thread.new(); thread.start(palette_job.bind(owner,raw,store)); threads.append(thread)
	var deadline:=Time.get_ticks_msec()+5000
	while store.snapshot().coalesced<3 and Time.get_ticks_msec()<deadline: await process_frame
	check(store.snapshot().coalesced==3,"Three concurrent palette requests wait for one actual decoder")
	leader.release.post(); var results: Array=[]
	for thread in threads: results.append(thread.wait_to_finish())
	check(results.filter(func(value):return value.decoded).size()==1,"One source palette decode owns all concurrent results")
	check(results.all(func(value):return str(value.error).is_empty()==valid),"All palette followers receive the same success/error")
	check(results.all(func(value):return same(value.value,results[0].value)),"Palette followers receive exact immutable source pixels")
	check(store.snapshot().inflight==0 and store.snapshot().entries==(1 if valid else 0),"Success caches once; errors wake followers without committing invalid data")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	check(Convert.available,"Compiled palette path is available")
	var folder:=OS.get_temp_dir().path_join("nwn-native-palette-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())); DirAccess.make_dir_recursive_absolute(folder)
	var raw:=plt(33,7); write(folder.path_join("authored.plt"),raw)
	var unique: Dictionary={}; var samples: Array=[]
	for name in Palette.NAMES:
		if unique.has(name): continue
		var bytes:=tga(2,32,256,4)
		for pixel in 256*4:
			for channel in 4: bytes[21+pixel*4+channel]=((pixel%256)*13+(pixel/256)*67+channel*37+unique.size()*43)&255
		unique[name]=bytes; write(folder.path_join(name+".tga"),bytes)
	var rows: Array=[0,1,2,3,4,-1,99,2,1,0]
	var catalog:=Catalog.new(); check(catalog.mount_directory(folder),"Authored PLT/palette catalog mounts without installed assets")
	var reference:=Palette.new(); reference.use_native=false; var expected:=reference.prepare(catalog,"authored",rows)
	catalog=Catalog.new(); catalog.mount_directory(folder); var candidate:=Palette.new(); var value:=candidate.prepare(catalog,"authored",rows)
	check(str(expected.error).is_empty() and str(value.error).is_empty() and same(expected.value,value.value),"Actual raw palette reads/decodes/bake match the GD reference exactly")
	check(expected.sha256==value.sha256 and expected.palette_dependencies==value.palette_dependencies,"Native path preserves existing content/color/dependency identities")
	check(value.conversion.native_pixels==33*7 and value.conversion.gd_pixels==0,"Actual prepare uses compiled PLT pixel conversion")
	var warmed:=candidate.prepare(catalog,"authored",rows)
	check(warmed.palette_decodes==0 and same(value.value,warmed.value),"Warm shared palettes perform no second source decode")
	# Fresh full prepare calls, not just direct store probes, share every source.
	catalog=Catalog.new(); catalog.mount_directory(folder); var threads: Array=[]
	for index in 4:
		var thread:=Thread.new(); thread.start(prepare_job.bind(catalog,rows)); threads.append(thread)
	var results: Array=[]
	for thread in threads: results.append(thread.wait_to_finish())
	var total:=0
	for result in results: total+=int(result.get("palette_decodes",0))
	check(results.all(func(result):return str(result.error).is_empty() and same(result.value,expected.value)),"Concurrent actual PLT prepares retain identical complete results")
	check(total==unique.size() and catalog.preparation_cache().snapshot().inflight==0,"Full prepare decodes each unique palette once across four callers")
	await coalesced_case(unique.values()[0],true)
	await coalesced_case(PackedByteArray([1,2,3]),false)
	var cache_folder:=folder.path_join("prepared"); var first:=Palette.new().prepare(catalog,"authored",rows,cache_folder); var second:=Palette.new().prepare(catalog,"authored",rows,cache_folder)
	check(not first.cache_hit and second.cache_hit and same(first.value,second.value),"Verified persistent baked-pixel cache reloads exact output")
	var recolored: Array=rows.duplicate(); recolored[8]=3
	var changed:=Palette.new().prepare(catalog,"authored",recolored,cache_folder)
	check(changed.sha256!=first.sha256 and not same(changed.value,first.value),"Used color-row change creates distinct identity and actual pixels")
	# Preserve the cached result while mounting changed authoritative bytes in a
	# new immutable catalog context. Never rely on loose-file live editing.
	var edited: PackedByteArray=unique.pal_tattoo01.duplicate()
	for index in range(21,edited.size()): edited[index]^=127
	write(folder.path_join("pal_tattoo01.tga"),edited)
	var remounted:=Catalog.new(); remounted.mount_directory(folder); var replaced:=Palette.new().prepare(remounted,"authored",rows,cache_folder)
	check(replaced.sha256!=first.sha256 and not replaced.cache_hit and not same(replaced.value,first.value),"Changed mounted palette bytes invalidate persistent color result")
	# High-density PLT isolates pixel conversion with identical lookup rows.
	var big:=plt(512,256); var prepared:=palettes(); var gd:=Palette.new(); gd.use_native=false; var began:=Time.get_ticks_usec(); var a:=gd.decode(big,prepared,rows); var gd_ms:=(Time.get_ticks_usec()-began)/1000.0
	var compiled:=Palette.new(); began=Time.get_ticks_usec(); var b:=compiled.decode(big,prepared,rows); var native_ms:=(Time.get_ticks_usec()-began)/1000.0
	check(gd.failure.is_empty() and compiled.failure.is_empty() and same(a,b),"Large PLT complete pixels are exact across reference/native paths")
	samples.append({"pixels":512*256,"gd_ms":gd_ms,"native_ms":native_ms,"output_sha256":Cache.digest(b.mips[0].data)})
	# Only authored bytes and our derived cache live in this unique temp scope.
	for file in DirAccess.get_files_at(cache_folder):
		check(file.ends_with(".bin") and file.get_basename().length()==64,"Cleanup targets only owned prepared-cache leaves")
		DirAccess.remove_absolute(cache_folder.path_join(file))
	DirAccess.remove_absolute(cache_folder)
	for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"publicConnections":0,"scope":"Actual authored PLT prepare, parallel source ownership, error wakeups, persistent pixel cache, color/palette remount invalidation and exact large bake; not original GPU sampling or world/FPS acceptance"},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
