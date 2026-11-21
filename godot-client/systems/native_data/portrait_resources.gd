extends RefCounted
# Original84c2f0/84c1b0 size selection and9d04a0 image-folder enumeration.
# Catalog membership only: no texture decoding, filesystem writes or network.
const SUFFIXES=["","t","s","m","l","h"]
static func resref(value: String) -> String: return value.left(16).to_lower()
static func exists(name: String,provider: Callable) -> bool:
	return not provider.is_valid() or bool(provider.call(name,3)) or bool(provider.call(name,2033))
static func candidates(base: String,size: int) -> Array[String]:
	var result: Array[String]=[]
	if size<0 or size>5:
		push_error("Invalid portrait size")
		return result
	if base.is_empty():return result
	if size==0:result.append(base);return result
	for candidate in [size,size+1,size-1,size+2,size-2,size+3,size-3,size+4,size-4]:
		if candidate<1 or candidate>5: continue
		result.append(base+SUFFIXES[candidate])
	return result
static func sized(base: String,size: int,provider: Callable=Callable()) -> String:
	var choices:=candidates(base,size)
	for name in choices:
		if exists(name,provider):return name
	return choices[0] if not choices.is_empty() else ""
static func available(base: String,provider: Callable=Callable()) -> bool:
	return not base.is_empty() and exists(sized(base,3,provider),provider)
static func files(layers: Array) -> Array:
	var output: Array=[]
	# Preserve each selected alias's directory-index order, independently of
	# winning resource priority. Global raster names are not portrait files.
	for type in [3,2033]:
		for alias in ["portraitsinstall","portraits"]:
			var selected: Array=[]
			for layer in layers:
				if layer.get("portrait_alias","")==alias: selected.append(layer)
			selected.sort_custom(func(a,b):return int(a.serial)<int(b.serial))
			for layer in selected:
				for key in layer.entries:
					if str(key).ends_with(":"+str(type)):
						output.append(str(key).trim_suffix(":"+str(type))+(".tga" if type==3 else ".dds"))
	return output
