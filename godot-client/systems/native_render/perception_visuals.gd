extends RefCounted
# Observer-specific presentation latch. Canonical entity/PlayerInfo data stays
# in World. Only one small latch and owned visual ID per observed lifetime.
const Controller=preload("res://tools/native_parity/visibility/perception_controller.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
var _world: WeakRef
var _apply: Callable
var _remove: Callable
var _entries: Dictionary={}
var _controlled:=-1
var _closed:=false
var stats:={"observations":0,"applied":0,"removed":0,"unavailable":0,"retired":0}
func configure(world: Node,apply_visual: Callable,remove_visual: Callable) -> void:
	_world=weakref(world);_apply=apply_visual;_remove=remove_visual
func _retire(id: int) -> void:
	var entry: Dictionary=_entries[id]
	if int(entry.effect)>0 and _remove.is_valid():_remove.call(id,int(entry.effect))
	entry.controller.retire();_entries.erase(id);stats.retired+=1
func receive(objects: Array,controlled: int) -> void:
	var world: Node=_world.get_ref() if _world!=null else null
	if _closed or not is_instance_valid(world):return
	if controlled!=_controlled:
		for id in _entries.keys():_retire(int(id))
		_controlled=controlled
	for id in _entries.keys():
		if not world.desired.has(id) or _entries[id].lifetime!=Lifetime.token(world.desired[id].object):_retire(int(id))
	var observer: Dictionary=world.desired.get(controlled,{}).get("object",{})
	var visibility: Variant=observer.get("playerState",{}).get("visibility")
	if not visibility is Dictionary:return # Absent state is not a draw command.
	var candidates: Dictionary={}
	for object in objects:
		if int(object.get("objectType",-1))==5:candidates[int(object.id)]=true
		if int(object.id)==controlled:
			for key in visibility:
				var text:=str(key)
				if text.is_valid_int():candidates[text.to_int()]=true
	for id in candidates:
		if not world.desired.has(id):continue
		var source: Dictionary=world.desired[id].object
		if int(source.get("objectType",-1))!=5:continue
		var lifetime: Variant=source.get("nativeLifetime")
		if not (lifetime is int or lifetime is float) or not is_finite(float(lifetime)) or lifetime<0 or lifetime>4294967295 or float(lifetime)!=floor(float(lifetime)):stats.unavailable+=1;continue
		var flags: Variant=visibility.get(str(id),visibility.get(id))
		if flags==null:continue
		if not _entries.has(id):_entries[id]={"controller":Controller.new(),"lifetime":Lifetime.token(source),"effect":0}
		var entry: Dictionary=_entries[id]
		var scope:={"connection_epoch":"%s/observer/%s"%[world.get_instance_id(),controlled],"area_generation":world.generation,"area_id":world.area_id,"object_id":id,"entity_lifetime":str(entry.lifetime)}
		var transition: Dictionary=entry.controller.observe(scope,flags);stats.observations+=1
		if not transition.available:stats.unavailable+=1;continue
		match str(transition.action.kind):
			"apply6":
				entry.effect=int(_apply.call(id,int(lifetime),6)) if _apply.is_valid() else 0
				stats.applied+=1
			"remove6":
				if entry.effect>0 and _remove.is_valid():_remove.call(id,int(entry.effect))
				entry.effect=0;stats.removed+=1
func snapshot() -> Dictionary:
	return {"closed":_closed,"observer":_controlled,"entries":_entries.size(),"stats":stats.duplicate(),"input":"received PlayerInfo.visibility only; creature-update triple has distinct packing","fade_policy":"No guessed reveal/LOS fade triggered"}
func close() -> void:
	if _closed:return
	for id in _entries.keys():_retire(int(id))
	_closed=true;_world=null;_apply=Callable();_remove=Callable()
