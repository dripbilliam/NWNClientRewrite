extends RefCounted
# Optional worker-owned CPU Image and private GPU texture construction.
# Resource-pool mutation stays on main. Original decoded rasters are untouched.
const REVISION:="raster-upload-v2"
const WORKER_TEXTURE_REVISION:="worker-texture-v1"
const MAX_WORKER_WEAK_KEYS:=4096
const MIN_TRANSFORM_PIXELS:=256*256
const MAX_PIXELS:=16777216
const MAX_BYTES:=96*1024*1024
const MAX_RETAINED_BYTES:=64*1024*1024
const MAX_RETAINED_ENTRIES:=256
const MAX_JOB_BYTES:=16*1024*1024
class Flight:
	extends RefCounted
	var wake:=Semaphore.new()
	var waiters:=0
	var prepared: Dictionary={}
class TextureFlight:
	extends RefCounted
	var wake:=Semaphore.new()
	var waiters:=0
	var texture: ImageTexture=null
static var mutex:=Mutex.new()
static var cache: Dictionary={}
static var order: Array[String]=[]
static var flights: Dictionary={}
static var retained_bytes:=0
static var generation:=0
static var counts:={"requests":0,"hits":0,"builds":0,"coalesced":0,"evictions":0,"declined":0}
static var texture_weak_cache: Dictionary={}
static var texture_flights: Dictionary={}
static var texture_attempted: Dictionary={}
static var texture_counts:={"requests":0,"hits":0,"builds":0,"coalesced":0,"failures":0,"weak_resets":0,"redundant_skips":0,"capacity_skips":0}
const FORMATS:={"rgba8":Image.FORMAT_RGBA8,"dxt1_rgb":Image.FORMAT_DXT1,"dxt1_rgba":Image.FORMAT_DXT1,"dxt3":Image.FORMAT_DXT3,"dxt5":Image.FORMAT_DXT5,"etc1":Image.FORMAT_ETC,"bc6h_signed":Image.FORMAT_BPTC_RGBF,"bc6h_unsigned":Image.FORMAT_BPTC_RGBFU}
static func configured_enabled() -> bool:
	var value: Variant=ProjectSettings.get_setting("nwn/private/raster_upload_preparation",false)
	return value is bool and value
static func configured_worker_texture_creation() -> bool:
	var value: Variant=ProjectSettings.get_setting("nwn/private/worker_texture_creation",false)
	return value is bool and value
static func byte_count(width: int,height: int,format: int,mipmaps: bool) -> int:
	var total:=0
	while true:
		if format==Image.FORMAT_RGBA8:total+=width*height*4
		elif format==Image.FORMAT_RGB8:total+=width*height*3
		elif format in [Image.FORMAT_DXT1,Image.FORMAT_ETC]:total+=((width+3)/4)*((height+3)/4)*8
		elif format in [Image.FORMAT_DXT3,Image.FORMAT_DXT5,Image.FORMAT_BPTC_RGBF,Image.FORMAT_BPTC_RGBFU]:total+=((width+3)/4)*((height+3)/4)*16
		else:return -1
		if not mipmaps or width==1 and height==1:return total
		width=maxi(1,width>>1);height=maxi(1,height>>1)
	return -1
static func source_supported(data: Dictionary) -> bool:
	if not data.get("width") is int or not data.get("height") is int or not data.get("format") is String or not data.get("mips") is Array:return false
	var width: int=data.width;var height: int=data.height;var mips: Array=data.mips
	if width<1 or height<1 or width>=32768 or height>=32768 or width*height>MAX_PIXELS or not FORMATS.has(data.format) or mips.is_empty() or mips.size()>16:return false
	if data.has("generate_mips") and not data.generate_mips is bool:return false
	if bool(data.get("generate_mips",false)) and data.format not in ["rgba8","etc1"]:return false
	var expected_width:=width;var expected_height:=height;var bytes:=0
	for mip in mips:
		if not mip is Dictionary or mip.get("width")!=expected_width or mip.get("height")!=expected_height or not mip.get("data") is PackedByteArray:return false
		if mip.data.size()!=byte_count(expected_width,expected_height,int(FORMATS[data.format]),false):return false
		bytes+=mip.data.size()
		expected_width=maxi(1,expected_width>>1);expected_height=maxi(1,expected_height>>1)
	return bytes<=MAX_BYTES and (mips.size()==1 or int(mips[-1].width)==1 and int(mips[-1].height)==1)
static func cpu_image(data: Dictionary,profile: bool=false) -> Dictionary:
	if not source_supported(data):return {"error":"unsupported-source"}
	var began:=Time.get_ticks_usec() if profile else 0;var phases: Dictionary={}
	var bytes:=PackedByteArray()
	for mip in data.mips:bytes.append_array(mip.data)
	var image:=Image.create_from_data(data.width,data.height,data.mips.size()>1,int(FORMATS[data.format]),bytes)
	if profile:phases.create_us=Time.get_ticks_usec()-began;began=Time.get_ticks_usec()
	if image==null or image.is_empty():return {"error":"image-construction"}
	if int(FORMATS[data.format])==Image.FORMAT_ETC and image.decompress()!=OK:return {"error":"etc-decompression"}
	if profile:phases.decompress_us=Time.get_ticks_usec()-began;began=Time.get_ticks_usec()
	if bool(data.get("generate_mips",false)) and image.generate_mipmaps()!=OK:return {"error":"mipmap-generation"}
	if profile:phases.mipmap_us=Time.get_ticks_usec()-began
	return {"error":"","image":image,"phases":phases}
static func prepare(record: Dictionary,profile: bool=false) -> Dictionary:
	if not record.get("sha256") is String or str(record.sha256).length()!=64 or not record.get("value") is Dictionary:return {}
	if estimated_bytes(record)>MAX_BYTES:return {}
	var value: Dictionary=record.value
	var source_sha: String=record.sha256
	if not source_supported(value):return {}
	# Packed arrays inside Variants share their wrapper. Explicit constructors
	# create independent COW owners: later listener writes must not change the
	# proof or the private source used by this worker's Image preparation.
	var source_bytes: Array=[];var source_mips: Array=[]
	for mip in value.mips:
		var source_blob:=PackedByteArray(mip.data);source_bytes.append(source_blob)
		source_mips.append({"width":mip.width,"height":mip.height,"data":source_blob})
	source_bytes.make_read_only();source_mips.make_read_only()
	var source:={"width":value.width,"height":value.height,"format":value.format,"mips":source_mips,"generate_mips":bool(value.get("generate_mips",false))}
	var result:=cpu_image(source,profile)
	if not str(result.error).is_empty():return {}
	var began:=Time.get_ticks_usec() if profile else 0
	var image: Image=result.image;var bytes: PackedByteArray=image.get_data()
	if profile:result.phases.packet_us=Time.get_ticks_usec()-began
	if bytes.size()>MAX_BYTES:return {}
	var prepared:={"revision":REVISION,"source_sha256":source_sha,"width":image.get_width(),"height":image.get_height(),"format":image.get_format(),"mipmaps":image.has_mipmaps(),"bytes":bytes,"source_format":source.format,"source_mips":source_mips.size(),"source_generate_mips":source.generate_mips,"source_bytes":source_bytes}
	if not packet_supported(prepared):return {}
	prepared.make_read_only()
	return {"prepared":prepared,"phases":result.phases,"thread":OS.get_thread_caller_id()}
static func valid(record: Dictionary,prepared: Dictionary) -> bool:
	if not packet_supported(prepared) or prepared.source_sha256!=record.get("sha256") or not record.get("value") is Dictionary:return false
	var value: Dictionary=record.value
	if not source_supported(value) or prepared.width!=value.width or prepared.height!=value.height or prepared.get("source_format")!=value.format or prepared.get("source_mips")!=value.mips.size() or prepared.get("source_generate_mips")!=bool(value.get("generate_mips",false)):return false
	for index in value.mips.size():
		if value.mips[index].data!=prepared.source_bytes[index]:return false
	return true
static func packet_supported(prepared: Dictionary) -> bool:
	if prepared.size()!=11 or prepared.get("revision")!=REVISION or not prepared.get("source_sha256") is String or prepared.source_sha256.length()!=64:return false
	if not prepared.get("width") is int or not prepared.get("height") is int or not prepared.get("format") is int or not prepared.get("mipmaps") is bool or not prepared.get("bytes") is PackedByteArray or not prepared.get("source_format") is String or not prepared.get("source_mips") is int or not prepared.get("source_generate_mips") is bool:return false
	if prepared.width<1 or prepared.height<1 or prepared.width>=32768 or prepared.height>=32768 or prepared.width*prepared.height>MAX_PIXELS or prepared.bytes.size()>MAX_BYTES or prepared.source_mips<1 or prepared.source_mips>16 or not FORMATS.has(prepared.source_format):return false
	if not prepared.get("source_bytes") is Array or prepared.source_bytes.size()!=prepared.source_mips:return false
	var width: int=prepared.width;var height: int=prepared.height;var retained: int=prepared.bytes.size()
	for bytes in prepared.source_bytes:
		if not bytes is PackedByteArray or bytes.size()!=byte_count(width,height,int(FORMATS[prepared.source_format]),false):return false
		retained+=bytes.size();width=maxi(1,width>>1);height=maxi(1,height>>1)
	if retained>MAX_BYTES:return false
	var expected_format: int=FORMATS[prepared.source_format]
	if expected_format==Image.FORMAT_ETC:
		if prepared.format not in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8]:return false
	elif prepared.format!=expected_format:return false
	if prepared.mipmaps!=(prepared.source_mips>1 or prepared.source_generate_mips):return false
	return prepared.bytes.size()==byte_count(prepared.width,prepared.height,prepared.format,prepared.mipmaps)
static func image(record: Dictionary,prepared: Dictionary) -> Image:
	if not valid(record,prepared):return null
	return Image.create_from_data(prepared.width,prepared.height,prepared.mipmaps,prepared.format,prepared.bytes)
static func retained_size(prepared: Dictionary) -> int:
	var total: int=prepared.bytes.size()
	for bytes in prepared.source_bytes:total+=bytes.size()
	return total
static func identity(record: Dictionary) -> String:
	if not record.get("sha256") is String or record.sha256.length()!=64 or not record.get("value") is Dictionary or not source_supported(record.value):return ""
	var value: Dictionary=record.value
	return ":".join([REVISION,record.sha256,str(value.width),str(value.height),str(value.format),str(value.mips.size()),str(bool(value.get("generate_mips",false)))])
static func estimated_bytes(record: Dictionary) -> int:
	if not record.get("value") is Dictionary or not source_supported(record.value):return -1
	var value: Dictionary=record.value
	# ETC decoding produces RGB/RGBA; reserve the conservative RGBA bound.
	var format: int=Image.FORMAT_RGBA8 if value.format=="etc1" else FORMATS[value.format]
	var total:=byte_count(value.width,value.height,format,value.mips.size()>1 or bool(value.get("generate_mips",false)))
	for mip in value.mips:total+=mip.data.size()
	return total
static func prepare_cached(record: Dictionary) -> Dictionary:
	var id:=identity(record)
	if id.is_empty():return {}
	mutex.lock();counts.requests+=1
	var epoch:=generation;var key:=str(epoch)+":"+id
	if cache.has(key):
		var ready: Dictionary=cache[key];order.erase(key);order.append(key);counts.hits+=1;mutex.unlock()
		return {"prepared":ready,"phases":{},"thread":OS.get_thread_caller_id(),"cache_hit":true}
	if flights.has(key):
		var pending: Flight=flights[key];pending.waiters+=1;counts.coalesced+=1;mutex.unlock()
		# The producer is already executing and calls no nested pool task, scene,
		# external service or renderer. A saturated pool cannot delay its work.
		pending.wake.wait()
		return {"prepared":pending.prepared,"phases":{},"thread":OS.get_thread_caller_id(),"cache_hit":true} if not pending.prepared.is_empty() else {}
	var flight:=Flight.new();flights[key]=flight;counts.builds+=1;mutex.unlock()
	var result:=prepare(record);var payload: Dictionary=result.get("prepared",{})
	mutex.lock()
	if not payload.is_empty() and epoch==generation and retained_size(payload)<=MAX_RETAINED_BYTES:
		var bytes:=retained_size(payload)
		while not order.is_empty() and (cache.size()>=MAX_RETAINED_ENTRIES or retained_bytes+bytes>MAX_RETAINED_BYTES):
			var oldest: String=order.pop_front();retained_bytes-=retained_size(cache[oldest]);cache.erase(oldest);counts.evictions+=1
		cache[key]=payload;order.append(key);retained_bytes+=bytes
	else:counts.declined+=1
	flight.prepared=payload;flights.erase(key);var waiters:=flight.waiters;mutex.unlock()
	for index in waiters:flight.wake.post()
	return result
static func texture_cached_on_worker(record: Dictionary,prepared: Dictionary) -> Dictionary:
	if OS.get_thread_caller_id()==OS.get_main_thread_id() or not valid(record,prepared):return {}
	var id:=identity(record)
	if id.is_empty():return {}
	mutex.lock();texture_counts.requests+=1
	var epoch:=generation;var key:=str(epoch)+":"+id
	if texture_weak_cache.has(key):
		var cached: ImageTexture=texture_weak_cache[key].get_ref()
		if cached!=null and cached.get_rid().is_valid():texture_counts.hits+=1;mutex.unlock();return {"texture":cached,"cache_hit":true,"create_us":0}
		texture_weak_cache.erase(key)
	if texture_flights.has(key):
		var pending: TextureFlight=texture_flights[key];pending.waiters+=1;texture_counts.coalesced+=1;mutex.unlock()
		pending.wake.wait()
		return {"texture":pending.texture,"cache_hit":true,"create_us":0} if pending.texture!=null else {}
	# A finished speculative texture may have lost its last owner before use.
	# Recreating it for every model result can multiply GPU work. A later
	# actual demand retains the normal main-thread construction fallback.
	if texture_attempted.has(key):texture_counts.redundant_skips+=1;mutex.unlock();return {"declined":"already-attempted"}
	if texture_attempted.size()>=MAX_WORKER_WEAK_KEYS:texture_counts.capacity_skips+=1;mutex.unlock();return {"declined":"attempt-capacity"}
	texture_attempted[key]=true
	var flight:=TextureFlight.new();texture_flights[key]=flight;texture_counts.builds+=1;mutex.unlock()
	var image_value:=image(record,prepared)
	var began:=Time.get_ticks_usec()
	var created: ImageTexture=ImageTexture.create_from_image(image_value) if image_value!=null else null
	var elapsed:=Time.get_ticks_usec()-began
	if created!=null and not created.get_rid().is_valid():created=null
	mutex.lock()
	if created!=null and epoch==generation:
		if texture_weak_cache.size()>=MAX_WORKER_WEAK_KEYS:texture_weak_cache.clear();texture_counts.weak_resets+=1
		texture_weak_cache[key]=weakref(created)
	if created==null:texture_counts.failures+=1
	flight.texture=created;texture_flights.erase(key);var waiters:=flight.waiters;mutex.unlock()
	for index in waiters:flight.wake.post()
	return {"texture":created,"cache_hit":false,"create_us":elapsed} if created!=null else {}
static func snapshot() -> Dictionary:
	mutex.lock();var value:=counts.duplicate();value.merge({"entries":cache.size(),"retained_bytes":retained_bytes,"maximum_bytes":MAX_RETAINED_BYTES,"maximum_entries":MAX_RETAINED_ENTRIES,"inflight":flights.size(),"generation":generation});mutex.unlock();return value
static func worker_texture_snapshot() -> Dictionary:
	mutex.lock();var value:=texture_counts.duplicate();value.merge({"weak_entries":texture_weak_cache.size(),"attempted_entries":texture_attempted.size(),"inflight":texture_flights.size(),"generation":generation});mutex.unlock();return value
static func clear() -> void:
	# Old producers still finish and wake their waiters. Their epoch cannot
	# repopulate a cleared partition or erase a newer generation's flight.
	mutex.lock();cache.clear();order.clear();texture_weak_cache.clear();texture_attempted.clear();retained_bytes=0;generation+=1;mutex.unlock()
static func worker_decline_reason(record: Dictionary,worker_texture: bool=false) -> String:
	if not record.get("value") is Dictionary:return "unsupported"
	var value: Dictionary=record.value
	if not value.get("width") is int or not value.get("height") is int or value.width<1 or value.height<1 or value.width>=32768 or value.height>=32768:return "unsupported"
	# Full-mip DDS concatenation saved little after the source-byte proof,
	# while tiny rasters could cost more on main. Reserve the sidecar for
	# substantial CPU transforms; all declined records keep the original path.
	if not worker_texture:
		if value.width*value.height<MIN_TRANSFORM_PIXELS:return "tiny"
		if not bool(value.get("generate_mips",false)) and value.get("format")!="etc1":return "no_transform"
	return "" if source_supported(value) else "unsupported"
static func sidecar_on_worker(result: Dictionary,worker_texture: bool=false) -> Dictionary:
	var rows: Dictionary={};var stats:={"prepared":0,"bytes":0,"declined":0,"tiny":0,"no_transform":0,"unsupported":0}
	var gpu_rows: Dictionary={}
	if worker_texture:stats.merge({"gpu_prepared":0,"gpu_cache_hits":0,"gpu_create_us":0,"gpu_failures":0})
	if OS.get_thread_caller_id()==OS.get_main_thread_id() or not str(result.get("error","")).is_empty():return {}
	var records: Array=[]
	if result.get("value") is Dictionary and result.value.has("mips"):records.append(result)
	for field in ["textures","emitter_textures"]:
		if result.get(field) is Dictionary:records.append_array(result[field].values())
	for record in records:
		if not record is Dictionary:continue
		var sha:=str(record.get("sha256",""))
		if rows.has(sha):continue
		var reason:=worker_decline_reason(record,worker_texture)
		if not reason.is_empty():stats.declined+=1;stats[reason]+=1;continue
		if rows.size()>=MAX_RETAINED_ENTRIES:stats.declined+=1;continue
		var needed:=estimated_bytes(record)
		if needed<0 or needed>MAX_JOB_BYTES-int(stats.bytes):stats.declined+=1;continue
		var packet:=prepare_cached(record)
		if packet.is_empty():stats.declined+=1;continue
		rows[sha]=packet.prepared;stats.prepared+=1;stats.bytes+=retained_size(packet.prepared)
		if worker_texture:
			var gpu:=texture_cached_on_worker(record,packet.prepared)
			if gpu.has("declined"):stats["gpu_redundant_skips"]=int(stats.get("gpu_redundant_skips",0))+1
			elif gpu.is_empty():stats.gpu_failures+=1
			else:
				gpu_rows[sha]=gpu.texture;stats.gpu_prepared+=1;stats.gpu_create_us+=int(gpu.create_us)
				if bool(gpu.cache_hit):stats.gpu_cache_hits+=1
	rows.make_read_only();stats.make_read_only()
	var sidecar:={"revision":REVISION,"rows":rows,"stats":stats,"thread":OS.get_thread_caller_id()};sidecar.make_read_only()
	if worker_texture:
		gpu_rows.make_read_only()
		sidecar={"revision":REVISION,"rows":rows,"stats":stats,"thread":OS.get_thread_caller_id(),"gpu_revision":WORKER_TEXTURE_REVISION,"gpu_rows":gpu_rows};sidecar.make_read_only()
	return sidecar
