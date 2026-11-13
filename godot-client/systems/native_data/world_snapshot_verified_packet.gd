extends RefCounted
# Internal, same-process trust boundary from the completed metadata worker
# owner. No decoded JSON wire value can instantiate this RefCounted type. This
# is not a defense against arbitrary trusted GDScript constructing the type.
# It binds the
# worker-checked rows to their exact decoded JSON dictionaries and generation.
# The source dictionaries stay immutable under the existing borrowed-row
# contract until ordered admission finishes.
var scope: Array=[]
var area_id:=-1
var rows: Array=[]
var sources: Array=[]

func _init(value_scope: Array,value_area: int,value_rows: Array,value_sources: Array) -> void:
	scope=value_scope.duplicate();scope.make_read_only();area_id=value_area;rows=value_rows;sources=value_sources

func valid_for(metadata: Dictionary,objects: Array,generation: int,area: int) -> bool:
	if not is_same(rows,metadata.get("rows")) or scope!=metadata.get("scope") or area_id!=area or area_id!=int(metadata.get("area_id",-1)) or rows.size()!=objects.size() or sources.size()!=objects.size():return false
	if scope.size()!=4 or scope[1]!=generation or scope[3]!=area:return false
	for index in objects.size():
		var source: Variant=objects[index];var row: Variant=rows[index]
		if not source is Dictionary or not source.has("id") or not is_same(sources[index],source) or not row is Dictionary or not row.get("index") is int or int(row.index)!=index or not row.get("id") is int or int(row.id)!=int(source.id):return false
	return true
