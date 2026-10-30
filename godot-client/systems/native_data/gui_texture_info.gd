extends RefCounted
# Original CAurTextureBasic constructor/ParseField and GL sampler flags.
# Only GUI sampling is consumed here; other TXI fields remain outside this owner.
# v2 also invalidates finished GUI pixels that missed animated mesh identity.
const REVISION:="original-gui-sampler-v3-source-culling"
static func defaults() -> Dictionary: return {"filter":true,"mipmap":true,"clamp":0}
static func parse(bytes: PackedByteArray) -> Dictionary:
	var result:=defaults(); var field:=RegEx.new(); field.compile("^\\s*(\\S+)\\s+(\\S+)")
	var number:=RegEx.new(); number.compile("^[+-]?[0-9]+")
	for line in bytes.get_string_from_ascii().replace("\r","\n").split("\n",false):
		var found:=field.search(line)
		if found==null: continue
		var name:=found.get_string(1).to_lower(); var value:=found.get_string(2).to_lower()
		if name in ["filter","mipmap"]:
			# Original bool Parse accepts only these four tokens; e.g.2 retains
			# the previous value rather than meaning true. Later fields win.
			if value in ["0","false"]: result[name]=false
			elif value in ["1","true"]: result[name]=true
		elif name=="clamp":
			var integer:=number.search(value)
			if integer!=null: result.clamp=posmod(int(integer.get_string())+32768,65536)-32768
	return result
static func read(reader,name: String) -> Dictionary:
	# The tracked catalog reader records both absent lookups and present bytes,
	# so persistent prework revalidates TXI changes, additions and removals.
	var result:=defaults(); result.resource=name.to_lower(); result.present=reader.has_resource(name,2022); result.sha256=""
	if result.present:
		var bytes: PackedByteArray=reader.get_resource(name,2022)
		result.merge(parse(bytes),true); result.sha256=preload("res://systems/native_data/prepared_cache.gd").digest(bytes)
	return result
static func attach(reader,name: String,raster: Dictionary) -> Dictionary:
	var result:=raster.duplicate(); result.gui_sampler=read(reader,name)
	var data: Dictionary=raster.get("value",{})
	result.gui_sampler.mip_levels=int(floor(log(float(maxi(int(data.get("width",1)),int(data.get("height",1)))))/log(2.0)))+1 if data.get("generate_mips",false) else data.get("mips",[]).size()
	return result
