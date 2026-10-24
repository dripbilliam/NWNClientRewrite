extends SceneTree
const Definition=preload("res://systems/native_data/area_definition.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func compare(value: Dictionary, expected: Array, label: String) -> void:
	check(value.tiles.size()==expected.size(),label+" tile count")
	for i in mini(value.tiles.size(),expected.size()):
		var tile: Dictionary=value.tiles[i]; var row: Dictionary=expected[i]
		check(tile.model==row.model,label+" original model "+str(i))
		check(tile.position.is_equal_approx(Vector3(row.position[0],row.position[1],row.position[2])) and is_equal_approx(float(tile.rotation_y),float(row.rotation_y)),label+" native placement/orientation "+str(i))
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("fixture") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.fixture))
	var parser:=Definition.new(); var tileset:=parser.parse_set(fixture.authored.setText)
	check(parser.failure.is_empty() and tileset.tiles[0].fields.PathNode=="7","Native SET preserves non-model fields")
	var area:=parser.compose(fixture.authored.area,tileset)
	check(parser.failure.is_empty() and area.models.size()==3,"Native authored area groups repeated models")
	compare(area,fixture.authored.expected,"Authored all-quarter-turn/height cases")
	for invalid in [{"Width":0},{"Height":1.5},{"Width":65536,"Height":2},{"Tile_List":[]},{"Tile_List":null}]:
		var root_data: Dictionary=fixture.authored.area.duplicate(true); root_data.merge(invalid,true)
		check(parser.compose(root_data,tileset).is_empty() and not parser.failure.is_empty(),"Invalid ARE dimensions/list rejected")
	for invalid in [{"Tile_ID":3},{"Tile_ID":-1},{"Tile_Orientation":4},{"Tile_Orientation":0.5},{"Tile_Height":-1}]:
		var root_data: Dictionary=fixture.authored.area.duplicate(true); root_data.Tile_List[0].merge(invalid,true)
		check(parser.compose(root_data,tileset).is_empty() and not parser.failure.is_empty(),"Invalid ARE tile rejected")
	for text in ["[TILES]\nCount=0","[TILES]\nCount=65537","[TILES]\nCount=1\n[GENERAL]\nTransition=-1","[TILES]\nCount=1\n[GENERAL]\nTransition=NaN"]:
		check(parser.parse_set(text).is_empty() and not parser.failure.is_empty(),"Invalid SET count/height rejected")
	var catalog:=Catalog.new()
	check(catalog.mount_install(fixture.install) and catalog.mount_erf(fixture.module,4000000),"Native installed plus owned-local module mount: "+catalog.failure)
	check(FileAccess.get_sha256(fixture.module)==fixture.moduleSha256,"Owned-local module hash unchanged")
	for sample in fixture.areas:
		var value:=parser.load_original(catalog,sample.name)
		check(parser.failure.is_empty(),"Original area reads/decodes without JS: "+parser.failure)
		if value.is_empty(): continue
		check(value.are_sha256==sample.are_sha256 and value.set_sha256==sample.set_sha256,"Original ARE/SET byte hashes agree")
		compare(value,sample.tiles,str(sample.name))
	check(parser.load_original(catalog,"missing_area").is_empty() and not parser.failure.is_empty(),"Missing area fails explicitly")
	var report: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_only":true,"scope":fixture.scope,"sourceSha256":{"systems/native_data/area_definition.gd":FileAccess.get_sha256("res://systems/native_data/area_definition.gd"),"tests/native_area_definition_test.gd":FileAccess.get_sha256("res://tests/native_area_definition_test.gd")}}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); quit(0 if failures.is_empty() else 1)
