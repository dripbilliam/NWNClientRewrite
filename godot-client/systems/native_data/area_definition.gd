extends RefCounted
# Original ARE + SET data only. No scene construction or JS-produced manifest.
const Gff = preload("res://systems/native_data/gff_document.gd")
const Binary = preload("res://systems/native_data/binary_data.gd")
const Cache = preload("res://systems/native_data/prepared_cache.gd")
const MAX_TILES := 65536
var failure := ""
func reject(message: String) -> Dictionary:
	failure = message; return {}
func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum
func parse_set(text: String) -> Dictionary:
	failure = ""
	var sections := {}; var section := ""
	for source_line in text.replace("\r", "").split("\n"):
		var line := source_line.strip_edges()
		if line.is_empty() or line.begins_with(";"): continue
		if line.begins_with("[") and line.ends_with("]"):
			section = line.substr(1,line.length()-2).to_upper()
			if not sections.has(section): sections[section] = {}
			continue
		var split := line.find("=")
		if split > 0 and not section.is_empty(): sections[section][line.left(split).strip_edges()] = line.substr(split+1).strip_edges()
	var count_text := str(sections.get("TILES",{}).get("Count",""))
	if not count_text.is_valid_int() or not whole(count_text.to_int(),1,MAX_TILES): return reject("Invalid SET tile count")
	var transition_text := str(sections.get("GENERAL",{}).get("Transition","1"))
	if not transition_text.is_valid_float() or not is_finite(transition_text.to_float()) or transition_text.to_float()<0: return reject("Invalid SET height transition")
	var tiles: Array = []
	for index in count_text.to_int():
		var row: Dictionary = sections.get("TILE"+str(index),{})
		tiles.append({"model":str(row.get("Model","")).to_lower(),"fields":row.duplicate(true)})
	return {"transition":transition_text.to_float(),"tiles":tiles,"sections":sections}
func compose(area: Dictionary, tileset: Dictionary, signed_heights: bool=false) -> Dictionary:
	failure = ""
	if not whole(area.get("Width"),1,MAX_TILES) or not whole(area.get("Height"),1,MAX_TILES): return reject("Invalid ARE dimensions")
	var width := int(area.Width); var height := int(area.Height)
	if width*height > MAX_TILES: return reject("ARE tile count exceeds supported bound")
	if not area.get("Tile_List") is Array or area.Tile_List.size()!=width*height: return reject("ARE tile list differs from dimensions")
	var tiles: Array = []; var models := {}
	for index in area.Tile_List.size():
		var source: Variant = area.Tile_List[index]
		if not source is Dictionary or not whole(source.get("Tile_ID"),0,tileset.tiles.size()-1): return reject("ARE tile ID is outside SET")
		if not whole(source.get("Tile_Orientation",0),0,3): return reject("Invalid ARE tile orientation")
		if not whole(source.get("Tile_Height",0),-2147483648 if signed_heights else 0,2147483647): return reject("Invalid ARE tile height")
		var model := str(tileset.tiles[int(source.Tile_ID)].model)
		if model.is_empty() or model=="****": return reject("SET tile has no model")
		var orientation := int(source.get("Tile_Orientation",0)); var elevation := int(source.get("Tile_Height",0))
		# Same source tile center and quarter-turn basis as the original-data path.
		var tile := {"index":index,"tile_id":int(source.Tile_ID),"model":model,"orientation":orientation,"height":elevation,"position":Vector3((index%width)*10+5,elevation*float(tileset.transition),-(floori(float(index)/width)*10+5)),"rotation_y":orientation*PI/2,"main_lights":[int(source.get("Tile_MainLight1",0))&255,int(source.get("Tile_MainLight2",0))&255],"fields":source.duplicate(true)}
		tiles.append(tile)
		if not models.has(model): models[model] = []
		models[model].append(index)
	return {"width":width,"height":height,"tiles":tiles,"models":models,"transition":tileset.transition,"area":area,"tileset":tileset,"scope":"Native terrain definition; replicated actors, behavior, lighting and tile animation still separate"}
func load_original(catalog, name: String) -> Dictionary:
	failure = ""
	var bytes: PackedByteArray = catalog.get_resource(name,2012)
	if not catalog.failure.is_empty(): return reject(catalog.failure)
	var parser := Gff.new(); var document := parser.parse(bytes,"ARE ")
	if not parser.failure.is_empty(): return reject(parser.failure)
	var set_name := str(document.root.get("Tileset","")).to_lower()
	if set_name.is_empty() or set_name=="****": return reject("ARE has no tileset")
	var set_bytes: PackedByteArray = catalog.get_resource(set_name,2013)
	if not catalog.failure.is_empty(): return reject(catalog.failure)
	var tileset := parse_set(Binary.new(set_bytes).text(0,set_bytes.size()))
	if not failure.is_empty(): return {}
	var definition := compose(document.root,tileset)
	if not failure.is_empty(): return {}
	definition.merge({"name":name.to_lower(),"tileset_name":set_name,"are_sha256":Cache.digest(bytes),"set_sha256":Cache.digest(set_bytes)})
	return definition
func load_network(catalog, state: Dictionary) -> Dictionary:
	failure=""
	var set_name:=str(state.get("tileset","")).to_lower()
	if set_name.is_empty() or not state.get("tiles") is Array: return reject("Raw area packet lacks tileset/tiles")
	var root_data: Dictionary={"Width":state.get("width"),"Height":state.get("height"),"Tile_List":[]}
	for tile in state.tiles:
		if not tile is Dictionary or not tile.get("fields") is Dictionary: return reject("Invalid raw tile packet")
		root_data.Tile_List.append({"Tile_ID":tile.fields.get("14"),"Tile_Height":tile.fields.get("18"),"Tile_Orientation":tile.fields.get("24"),"Tile_MainLight1":tile.fields.get("28",0),"Tile_MainLight2":tile.fields.get("29",0),"wire_fields":tile.fields.duplicate(true)})
	var raw: PackedByteArray=catalog.get_resource(set_name,2013)
	if not catalog.failure.is_empty(): return reject(catalog.failure)
	var tileset:=parse_set(Binary.new(raw).text(0,raw.size()))
	if not failure.is_empty(): return {}
	var definition:=compose(root_data,tileset,true)
	if not failure.is_empty(): return {}
	definition.merge({"name":str(state.get("resRef","")),"tileset_name":set_name,"network_area":state,"set_sha256":Cache.digest(raw),"source":"raw-network-area"})
	return definition
