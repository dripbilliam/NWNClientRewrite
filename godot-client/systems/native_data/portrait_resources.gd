extends RefCounted
# Original84c2f0/84c1b0 size selection and9d04a0 image-folder enumeration.
# Catalog membership only: no texture decoding, filesystem writes or network.
const SUFFIXES=["","t","s","m","l","h"]
static func resref(value: String) -> String: return value.left(16).to_lower()
static func exists(name: String,provider: Callable) -> bool:
	return not provider.is_valid() or bool(provider.call(name,3)) or bool(provider.call(name,2033))
static func sized(base: String,size: int,provider: Callable=Callable()) -> String:
	base=resref(base)
	if base.is_empty() or size==0: return base
	if size<1 or size>5: return ""
	for candidate in [size,size+1,size-1,size+2,size-2,size+3,size-3,size+4,size-4]:
		if candidate<1 or candidate>5: continue
		var name:=resref(base+SUFFIXES[candidate])
		if exists(name,provider): return name
	return resref(base+SUFFIXES[size])
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
