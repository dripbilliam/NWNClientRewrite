extends Node3D
# CNWCArea::AddPlaceableObjectLight1407d8ed0 / CNWCPlaceable::LoadLight140870cc0.
# The area packet's light list is independent of the ordinary static geometry.
const Assets=preload("res://systems/native_data/asset_service.gd")
const OriginalModel=preload("res://systems/native_render/effect_model.gd")
const Objects=preload("res://systems/native_render/object_stream.gd")
var assets
var world
var pool
var tables: Dictionary={}
var requests: Dictionary={}
var bundle: Dictionary={}
var area_records: Dictionary={}
var objects: Dictionary={}
var instances: Dictionary={}
var configurations: Dictionary={}
var errors: Array=[]
var closed:=false
var dirty:=false
var created:=0
var removed:=0
var failed: Dictionary={}
static func row(table: Dictionary,index: int) -> Dictionary:
	var rows: Array=table.get("orderedRows",[])
	return rows[index] if index>=0 and index<rows.size() else {}
static func number(source: Dictionary,key: String,fallback: float) -> float:
	var text:=str(source.get(key,"****"))
	return float(text) if text.is_valid_float() else fallback
static func definition(placeables: Dictionary,colours: Dictionary,appearance: int) -> Dictionary:
	var source:=row(placeables,appearance&65535)
	var colour:=str(source.get("LightColor","****"))
	# A successful numeric zero is a colour-table row, never an off flag.
	if not colour.is_valid_int(): return {}
	var rgb:=row(colours,int(colour))
	return {"appearance":appearance&65535,"colour_row":int(colour),"color":[number(rgb,"RED",0),number(rgb,"GREEN",0),number(rgb,"BLUE",0)],"offset":[number(source,"LightOffsetX",0),number(source,"LightOffsetY",0),number(source,"LightOffsetZ",3)]}
func configure(owner,source,shared_pool,cache_path: String,area_lights: Array) -> void:
	world=owner; pool=shared_pool
	assets=Assets.new(); add_child(assets); assets.maximum_workers=2; assets.configure(source); assets.cache_directory=cache_path; assets.completed.connect(prepared)
	for name in ["placeables","lightcolor"]: requests[assets.request(name,2017,"2da")]=name
	requests[assets.request("fx_placeable01",2002,"actor-model")]="fx_placeable01"
	world.instance_ready.connect(instance_ready); world.instance_removed.connect(instance_removed)
	receive_area(area_lights)
func receive_area(lights: Array) -> void:
	if closed:return
	var next: Dictionary={}
	for light in lights:
		if light is Dictionary and light.has_all(["id","appearance","position"]): next[int(light.id)]=light
	if next!=area_records: area_records=next.duplicate(true); dirty=true
func receive(values: Array,deleted: Array=[],full: bool=false) -> void:
	if closed:return
	if full: objects.clear()
	for id in deleted: objects.erase(int(id))
	for object in values:
		var id:=int(object.get("id",-1))
		if int(object.get("areaId",-1))!=world.area_id or int(object.get("objectType",0))!=9 or object.get("replicationRemoved",false): objects.erase(id); continue
		if object.get("replicated",{}).has("lightOn"):objects[id]=object
		else:objects.erase(id)
	dirty=true
func instance_ready(_id: int,_source: Dictionary,_instance) -> void: dirty=true
func instance_removed(id: int) -> void:
	if instances.has(id): instances[id].detach()
	dirty=true
func prepared(id: int,result: Dictionary) -> void:
	if closed or not requests.has(id):return
	var name: String=requests[id]; requests.erase(id)
	if not str(result.get("error","")).is_empty(): errors.append({"resource":name,"error":result.error}); return
	if name=="fx_placeable01": bundle=result
	else: tables[name]=result.value
	dirty=true
func plans() -> Dictionary:
	var result: Dictionary={}
	for id in area_records:
		var light: Dictionary=area_records[id]
		var plan:=definition(tables.get("placeables",{}),tables.get("lightcolor",{}),int(light.appearance))
		if plan.is_empty():continue
		plan.position=light.position; plan.dynamic=false; result[id]=plan
	for id in objects:
		var object: Dictionary=objects[id]; var state: Dictionary=object.get("replicated",{})
		if not state.has("lightOn"):continue
		# Original placeable add/update BOOL explicitly creates/removes this Gob.
		if not state.lightOn: result.erase(id); continue
		var fixed: Dictionary=object.get("staticState",object.get("lightState",{}))
		var plan:=definition(tables.get("placeables",{}),tables.get("lightcolor",{}),int(state.get("appearance",fixed.get("appearance",-1))))
		var pose:=Objects.pose(object)
		if plan.is_empty() or pose.is_empty():result.erase(id);continue
		plan.position=[pose.position.x,-pose.position.z,pose.position.y]; plan.dynamic=true; result[id]=plan
	return result
func anchor(id: int) -> Node3D:
	var instance: Node=world.instances.get(id)
	if not is_instance_valid(instance):return null
	if instance.has_method("node_for"):return instance.node_for(id,"root")
	var parts: Variant=instance.get("parts")
	if parts is Array:
		for part in parts:
			if is_instance_valid(part) and int(part.get_meta("native_part_parent",-2))==-1:return part
	return null
func install_light(id: int,plan: Dictionary) -> bool:
	var model:=OriginalModel.new(); add_child(model)
	if not model.load_model(bundle,pool):
		errors.append({"id":id,"error":model.failure});model.retire();failed[id]=true;return false
	var part: Node3D=model.node_for(0,"auroralight01")
	var lights: Array=[] if part==null else part.get_children().filter(func(node):return node is OmniLight3D)
	if lights.is_empty():
		errors.append({"id":id,"error":"Original fx_placeable01 has no auroralight01 light Part"});model.retire();failed[id]=true;return false
	model.set_meta("native_model_name","fx_placeable01"); model.set_meta("native_generated_placeable_id",id)
	instances[id]=model;created+=1
	return apply(id,plan)
func apply(id: int,plan: Dictionary) -> bool:
	var model: Node3D=instances[id]
	if configurations.get(id,{})!=plan:
		var part: Node3D=model.node_for(0,"auroralight01")
		for light in part.get_children():
			if not light is OmniLight3D:continue
			var properties: Dictionary=light.get_meta("native_model_light_properties",{}).duplicate(true)
			properties.color=plan.color; light.configure(properties)
		var root_part: Node3D=model.node_for(0,"root")
		var initial: Array=bundle.value.nodes[0].position; var offset: Array=plan.offset
		var p: Array=[initial[0]+offset[0],initial[1]+offset[1],initial[2]+offset[2]]
		var q:=root_part.quaternion
		# set_part_local_pose uses native [w,x,y,z] quaternion representation.
		model.set_part_local_pose("root",p,[q.w,q.x,-q.z,q.y])
		configurations[id]=plan.duplicate(true)
	var target:=anchor(id) if plan.dynamic else null
	if is_instance_valid(target):model.attach_to(target)
	else:
		model.detach(); model.rotation=Vector3.ZERO; model.position=Vector3(plan.position[0],plan.position[2],-plan.position[1])
	return true
func erase(id: int) -> void:
	if instances.has(id):instances[id].retire();instances.erase(id);removed+=1
	configurations.erase(id);failed.erase(id)
func _process(_delta: float) -> void:
	if closed or not dirty or not requests.is_empty() or not tables.has_all(["placeables","lightcolor"]) or bundle.is_empty():return
	dirty=false
	var desired:=plans()
	for id in instances.keys():
		if not desired.has(id):erase(id)
	var began:=Time.get_ticks_usec();var count:=0
	for id in desired:
		if failed.has(id):continue
		var plan: Dictionary=desired[id]
		if plan.dynamic and not is_instance_valid(anchor(id)):
			# Keep the area-owned light until the actual body is ready to take it.
			continue
		if instances.has(id):apply(id,plan);continue
		if count>=8 or Time.get_ticks_usec()-began>=3000:dirty=true;break
		install_light(id,plan);count+=1
func snapshot() -> Dictionary:
	var lights: Array=[]
	for id in instances:
		var plan: Dictionary=configurations.get(id,{})
		lights.append({"id":id,"appearance":plan.get("appearance"),"color":plan.get("color"),"offset":plan.get("offset"),"dynamic":plan.get("dynamic",false)})
	return {"count":instances.size(),"created":created,"removed":removed,"pending":requests.size(),"errors":errors.duplicate(true),"lights":lights}
func close() -> void:
	if closed:return
	closed=true;set_process(false)
	if is_instance_valid(assets):assets.close()
	for id in instances.keys():erase(id)
	area_records.clear();objects.clear();bundle={};tables.clear();world=null;pool=null
func _exit_tree() -> void:close()
