extends RefCounted

const DriveTile=preload("res://systems/native_data/native_tile_drive_surface.gd")
const TileSurface=preload("res://systems/native_data/tile_surface.gd")
var surface: Variant=null
var tiles: Dictionary={}
var tile_failures: Dictionary={}
var models: Dictionary={}
var report: Callable

static func _node_integer(value: Variant)->int:
	# area_geometry.js extracts the decimal prefix before coercing to int32.
	var expression:=RegEx.new()
	expression.compile("^\\s*([+-]?\\d+)")
	var match_result:=expression.search(str(value) if value!=null else "")
	if match_result==null:return 0
	var integer:=int(float(match_result.get_string(1)))&0xffffffff
	return integer-0x100000000 if integer>=0x80000000 else integer

static func _node_byte(value: Variant)->int:
	var source:=str(value) if value!=null else ""
	return (source.unicode_at(0)&255) if not source.is_empty() else 0

static func _node_orientation(value: Variant)->int:
	match _node_integer(value):
		0,360,-360:return 0
		90,-270:return 1
		180,-180:return 2
		270,-90:return 3
	return 4

func configure(current_surface: Variant,on_diagnostic: Callable=Callable())->void:
	surface=current_surface
	report=on_diagnostic
	tiles.clear();tile_failures.clear();models.clear()

func tile_failure(index: int,message: String)->Dictionary:
	var result:={"error":message}
	tile_failures[index]=result
	return result

func tile(area: Dictionary,x: int,y: int)->Variant:
	if surface==null or not is_instance_valid(surface) or not surface.ready():return {"error":"Native area tile geometry is unavailable"}
	var width:=int(area.get("width",0));var height:=int(area.get("height",0))
	if width<=0 or height<=0 or width*height>65536:return {"error":"Native area dimensions are unavailable or invalid"}
	if x<0 or y<0 or x>=width or y>=height:return null
	var index:=y*width+x
	if tiles.has(index):return tiles[index]
	if tile_failures.has(index):return tile_failures[index]
	if index>=surface.definition.tiles.size():return tile_failure(index,"Native area Tile_List is unavailable or truncated")
	if not bool(surface.definition.tileset.get("transition_entry",false)):
		return tile_failure(index,"Native tileset Transition value is unavailable")
	var placement: Dictionary=surface.definition.tiles[index]
	var orientation:=int(placement.get("orientation",-1))
	if orientation<0 or orientation>3:return tile_failure(index,"Native tile orientation is not implemented")
	var model:=str(placement.get("model",""))
	if surface.model_failures.has(model):
		tile_failures[index]=surface.model_failures[model]
		return tile_failures[index]
	if not surface.meshes.has(model):return tile_failure(index,"Native tileset has no model for tile "+str(placement.get("tile_id",-1)))
	if not models.has(model):models[model]=DriveTile.classify(surface.meshes[model],surface.table)
	if models[model].has("error"):
		tile_failures[index]=models[model]
		return models[model]
	var authored_height:=int(placement.get("height",0))
	var transition:=DriveTile.f(float(surface.definition.get("transition",1.0)))
	var height_offset:=DriveTile.f(DriveTile.f(float(authored_height))*transition)
	var tile_id:=int(placement.get("tile_id",-1))
	var source_tiles: Array=surface.definition.tileset.get("tiles",[])
	var fields: Dictionary=source_tiles[tile_id].get("pathNodeFields",{}) if tile_id>=0 and tile_id<source_tiles.size() else {}
	var path_nodes: Dictionary={"path":_node_byte(fields.get("PathNode")),"pathOrientation":_node_orientation(fields.get("Orientation")),
		"visibility":_node_byte(fields.get("VisibilityNode")),"visibilityOrientation":_node_orientation(fields.get("VisibilityOrientation")),
		"doorVisibility":_node_byte(fields.get("DoorVisibilityNode")),"doorVisibilityOrientation":_node_orientation(fields.get("DoorVisibilityOrientation")),"doors":_node_integer(fields.get("Doors"))&255}
	var result: Dictionary={"x":x,"y":y,"orientation":orientation,"heightOffset":height_offset,"mesh":models[model],"model":model,"tileId":tile_id,"pathNodes":path_nodes}
	tiles[index]=result
	return result

func clipped_walkable(value: Dictionary,start: Array,end: Array)->Dictionary:
	var warning:=Callable()
	if report.is_valid():warning=func(message:String):report.call(message,{"model":value.get("model",""),"tileX":value.get("x",-1),"tileY":value.get("y",-1),"orientation":value.get("orientation",-1),"from":start.duplicate(),"to":end.duplicate()})
	return DriveTile.clipped_area_tile_line(value,start,end,warning)
func surface_material(area: Dictionary,point: Array)->Variant:
	var x:=DriveTile.f(float(point[0]));var y:=DriveTile.f(float(point[1]))
	if not is_finite(x) or not is_finite(y):return {"error":"Native area GetTile point is unavailable"}
	var tile_x:=-1;var tile_y:=-1
	for index in 32:
		var low:=DriveTile.f(DriveTile.f(float(index))*10.0);var high:=DriveTile.f(DriveTile.f(float(index+1))*10.0)
		if x>=low and x<high:tile_x=index
		if y>=low and y<high:tile_y=index
	if tile_x<0 or tile_y<0:return 0
	var value: Variant=tile(area,tile_x,tile_y)
	if value==null:return 0
	if value is Dictionary and value.has("error"):return value
	return TileSurface.area_material(value,[x,y])
func position_walkable(area: Dictionary,point: Array)->Variant:
	if surface==null or not is_instance_valid(surface) or not surface.ready():return {"error":"Native area tile geometry is unavailable"}
	var value: Variant=surface_material(area,point)
	if value is Dictionary:return value
	return int(DriveTile._walk(surface.table,int(value)))
func providers()->Dictionary:
	return {"tile":func(area,x,y):return tile(area,x,y),
		"clippedWalkable":func(value,start,end):return clipped_walkable(value,start,end),
		"noNonWalkTile":func(value,start,end,low,high,radius,flag):return DriveTile.no_denied_area_tile_polygons(value,start,end,low,high,radius,flag),
		"surfaceMaterial":func(area,point):return surface_material(area,point),
		"positionWalkable":func(area,point):return position_walkable(area,point)}
