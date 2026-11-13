extends "res://tools/nwn62/drive_collision_indexed_before_reindex.gd"

# Private exact-work hypothesis. Only the immutable placeables 2DA model-name
# lookup is reused within one synchronous reindex. Per-object state remains new.
var _reindex_name_cache: Dictionary={}
var _reindex_name_cache_active:=false
func reindex_sources()->void:
	_reindex_name_cache={};_reindex_name_cache_active=true
	super.reindex_sources()
	_reindex_name_cache_active=false;_reindex_name_cache={}
func descriptor(object: Dictionary)->Dictionary:
	if not _reindex_name_cache_active or int(object.objectType)!=9:return super.descriptor(object)
	var state: Dictionary=object.get("replicated",{})
	var fixed: Dictionary=object.get("staticState",object.get("lightState",{}))
	var appearance:=int(state.get("appearance",fixed.get("appearance",-1)))
	if not _reindex_name_cache.has(appearance):
		var data: Dictionary=row("placeables",appearance)
		_reindex_name_cache[appearance]=str(Rules.cell(data,"ModelName",Rules.cell(data,"Model",""))).to_lower()
	var name: String=_reindex_name_cache[appearance]
	if name in ["","****"]:return {}
	return {"model":name,"door":false,"state":int(state.get("doorOpenState",0))}
