extends SceneTree
# Authored protocol-shaped rows through the actual signature, receive/delta and
# preparation planners. No asset workers, models, meshes or renderers are opened.
const World=preload("res://systems/native_render/live_world.gd")
const Creatures=preload("res://systems/native_render/creature_stream.gd")
const Statics=preload("res://systems/native_render/object_stream.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Lifetime=preload("res://systems/native_data/entity_presentation_lifetime.gd")
const ID=0x80000042
class Rigs:
	extends RefCounted
	func clip_length(_id: int,_animation: int) -> float:return 1.0
class Body:
	extends Node3D
	var rigs=Rigs.new()
	var retired:=false
	func set_animation(_code: int,_speed: float) -> void:pass
	func retire() -> void:retired=true
class CombatSpy:
	extends Node
	var forgotten: Array=[]
	var synchronized: Array=[]
	func forget(id: int,removed: bool=false) -> void:forgotten.append([id,removed])
	func sync(id: int,source: Dictionary,_instance) -> void:synchronized.append({"id":id,"source":source.duplicate(true)})
	func base_frame(_id: int,_code: int,_speed: float,_remaining: Variant) -> void:pass
	func movement_cue(_id: int,_cue: Dictionary) -> void:pass
	func visual_animation(_id: int,code: int) -> int:return code
	func close() -> void:pass
class Catalog:
	extends RefCounted
	var requested: Array=[]
	func has_resource(name: String,type: int) -> bool:
		requested.append([name,type])
		return type==2002 and name in ["pmh0","pmh0_head001","pmh0_head002","pmh0_rfoot001"]
var checks:=0
var failures: Array=[]
var observations: Dictionary={}
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL: ",label)
static func digest(value: Variant) -> String:return Cache.digest(var_to_bytes(value))
static func creature() -> Dictionary:
	return {"id":ID,"objectType":5,"areaId":91,"nativeLifetime":12,"appearance":{"appearance":0,"head":1,"phenotype":0,"gender":0,"skin":1,"hair":2,"tattoo1":3,"tattoo2":4,"bodyParts":[{"index":0,"value":1}],"equipment":[],"name":{"text":"Before"}},"replicated":{"position":[1.0,2.0,0.0],"orientation":{"yaw":0},"animation":0,"stats":{"racialType":0}}}
static func tables() -> Dictionary:
	return {"appearance":{"orderedRows":[{"RACE":"h","MODELTYPE":"P","SIZECATEGORY":"3","WEAPONSCALE":"1","WALKDIST":"1","RUNDIST":"2"}]},"racialtypes":{"orderedRows":[{"Label":"Authored Human"}]},"gender":{"orderedRows":[{"GENDER":"m"}]},"phenotype":{"orderedRows":[{"DefaultPhenoType":"0"}]},"capart":{"orderedRows":[{"MDLNAME":"rfoot","NODENAME":"foot_r"}]}}
func prepared(source: Dictionary) -> Dictionary:
	var owner=Creatures.new()
	var catalog=Catalog.new()
	owner.catalog=catalog;owner.tables=tables();owner.objects=[source.duplicate(true)]
	owner.build_plans()
	check(owner.stats.errors.is_empty() and owner.plans.size()==1,"Actual CreatureStream builds one complete CPU preparation plan")
	var result:={"plans":owner.plans.duplicate(true),"model_specs":owner.model_specs.duplicate(true),"requests":catalog.requested.duplicate(true)}
	owner.close();owner.free()
	return result
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	# The World stays outside the SceneTree: its actual update methods run, but
	# _enter_tree/open cannot create environmental/asset/worker/render services.
	var world=World.new();world.area_id=91;world.controlled_id=ID
	var body=Body.new();var combat=CombatSpy.new();world.combat=combat
	var source:=creature();var original_bytes:=digest(source);var key: String=world.signature(source)
	var names: Array=[{"text":"After"},{"text":""},{"firstName":{"strRef":10,"gender":0},"lastName":{"strRef":11,"gender":1}},{"firstName":{"strings":[{"language":0,"text":"First"}]},"lastName":{"strings":[]}},{"text":"<CUSTOM0>"}]
	var variants: Array=[]
	for name in names:
		var changed: Dictionary=source.duplicate(true);changed.appearance.name=name;variants.append(changed)
	var absent: Dictionary=source.duplicate(true);absent.appearance.erase("name");variants.append(absent)
	var equal_keys:=0
	for changed in variants:
		var same: bool=world.signature(changed)==key
		if same:equal_keys+=1
		check(same,"Creature name-only variation keeps the model signature: "+JSON.stringify(changed.appearance.get("name")))
	observations.name_variants=variants.size();observations.equal_name_keys=equal_keys
	var metadata: Dictionary=source.duplicate(true);metadata.nativeActorNameState={"revision":22};metadata.replicated.name={"text":"Party U"}
	check(world.signature(metadata)==key,"Actor-name metadata and U-party labels remain outside model identity")
	world.receive([source],ID);world.instances[ID]=body;world.installed[ID]=key
	var notifications: Array=[]
	world.instance_state_changed.connect(func(id,value):notifications.append({"id":id,"source":value.duplicate(true)}))
	var renamed: Dictionary=variants[0]
	world.receive_delta([renamed],[],ID)
	check(world.instances.get(ID)==body and not body.retired,"Name-only delta retains the same visual instance")
	check(world.installed.get(ID)==key and world.desired[ID].key==key,"Name-only delta retains installed/current model identity")
	check(combat.forgotten.is_empty() and combat.synchronized.size()==1,"Name-only delta synchronizes combat without forgetting its owner")
	check(world.pending_plan({}).actors.is_empty(),"Name-only delta schedules no replacement preparation")
	check(notifications.size()==1 and notifications[0].source.appearance.name.text=="After" and world.desired[ID].object.appearance.name.text=="After","Fresh source and name notification still reach current presentation owners")
	combat.forgotten.clear();combat.synchronized.clear();notifications.clear()
	world.receive([renamed],ID)
	check(world.instances.get(ID)==body and world.desired[ID].key==key and combat.forgotten.is_empty(),"Full registry publication also preserves the current model on a name-only update")
	check(notifications.size()==1 and notifications[0].source.appearance.name.text=="After","Full registry still signals the fresh source")
	world.instances.clear();world.installed.clear()
	world.desired[ID]={"object":source,"key":key}
	world.receive_delta([renamed],[],ID)
	var inflight: Dictionary={}
	if world.desired[ID].key==key:inflight[ID]=true
	check(world.desired[ID].key==key and world.pending_plan(inflight).actors.is_empty(),"Name-only publication preserves exact in-flight preparation binding")
	world.failed_objects[ID]={"key":key,"error":"Authored model failure"}
	world.receive_delta([renamed],[],ID)
	check(world.failed_objects.has(ID) and world.failed_objects[ID].key==key,"Name-only delta does not erase a known model failure and trigger a false retry")
	world.failed_objects.clear()
	# Every non-name member remains opaque in the creature signature. No broad
	# appearance whitelist or pruning of nested item/controller data is tested.
	var changes: Array=[]
	for field in ["appearance","head","phenotype","gender","skin","hair","tattoo1","tattoo2","fieldAA4","fieldAA8"]:
		var changed: Dictionary=source.duplicate(true);changed.appearance[field]=int(changed.appearance.get(field,0))+1;changes.append({"label":field,"object":changed})
	var part: Dictionary=source.duplicate(true);part.appearance.bodyParts[0].value=2;changes.append({"label":"bodyParts","object":part})
	var equipped: Dictionary=source.duplicate(true);equipped.appearance.equipment=[{"slot":16,"item":{"baseItem":0,"parts":[1],"visualTransform":{"entries":[],"keys":[]}}}];changes.append({"label":"equipment","object":equipped})
	var transformed: Dictionary=equipped.duplicate(true);transformed.appearance.equipment[0].item.visualTransform={"entries":[{"key":0,"value":{"channels":[{"value":2,"duration":0}]}}],"keys":[0]}
	check(world.signature(equipped)!=world.signature(transformed),"Nested equipped-item visual-transform bytes keep their existing invalidation")
	for entry in changes:
		world.installed[ID]=key;world.desired[ID]={"object":source,"key":key};world.receive_delta([entry.object],[],ID)
		check(world.desired[ID].key!=key and world.pending_plan({}).actors.size()==1,"Genuine model/equipment change still queues the controlled actor: "+entry.label)
	check(digest(source)==original_bytes,"Signature and received operations never mutate the input appearance/name")
	var original_plan:=prepared(source)
	for changed in variants:check(digest(prepared(changed))==digest(original_plan),"Actual model/parts/palette/animation preparation is name-independent")
	var new_head: Dictionary=source.duplicate(true);new_head.appearance.head=2
	check(digest(prepared(new_head))!=digest(original_plan),"Actual preparation still responds to changed head geometry")
	var new_color: Dictionary=source.duplicate(true);new_color.appearance.skin=9
	check(digest(prepared(new_color))!=digest(original_plan),"Actual preparation still responds to changed palette data")
	# The proposed fix is type5 only; type6/9/10 hashing must remain exactly the
	# original appearance tuple, including opaque fields not consumed by current
	# planners. Current keys also prefix presentation lifetime and the animated
	# placeable bit; these authored rows have no animated-placeable state.
	for kind in [6,9,10]:
		var object: Dictionary={"id":ID+kind,"objectType":kind,"areaId":91,"appearance":{"name":{"text":"Retained opaque field"}},"item":{"baseItem":0,"parts":[1],"visualTransform":{"entries":[],"keys":[]}},"replicated":{"appearance":0,"doorType":1,"genericType":0,"position":[0,0,0]}}
		var state: Dictionary=object.replicated
		check(world.signature(object)==digest([Lifetime.token(object),false,kind,object.appearance,object.item,state.appearance,state.doorType,state.genericType]),"Type "+str(kind)+" preserves its complete existing signature tuple")
		for field in ["appearance","doorType","genericType"]:
			var changed: Dictionary=object.duplicate(true);changed.replicated[field]=int(changed.replicated[field])+1
			check(world.signature(changed)!=world.signature(object),"Type "+str(kind)+" retains "+field+" invalidation")
		var item_transform: Dictionary=object.duplicate(true);item_transform.item.visualTransform.keys=[0]
		check(world.signature(item_transform)!=world.signature(object),"Type "+str(kind)+" retains nested item visual-transform invalidation")
		for opaque in [null,17,["opaque",{"retained":true}]]:
			var opaque_object: Dictionary=object.duplicate(true);opaque_object.appearance=opaque
			check(world.signature(opaque_object)==digest([Lifetime.token(opaque_object),false,kind,opaque,object.item,state.appearance,state.doorType,state.genericType]),"Type "+str(kind)+" preserves the legacy non-Dictionary appearance tuple: "+JSON.stringify(opaque))
	var statics=Statics.new();statics.area_id=91;statics.tables={"placeables":{"orderedRows":[{"ModelName":"authored_placeable"},{"ModelName":"authored_placeable_changed"}]},"doortypes":{"orderedRows":[{}, {"ModelName":"authored_door","VisibleModel":"1"}]}}
	statics.snapshot_objects=[{"id":9,"objectType":9,"areaId":91,"replicated":{"position":[0,0,0],"appearance":0}},{"id":10,"objectType":10,"areaId":91,"replicated":{"position":[0,0,0],"doorType":1}}];statics.plan_objects()
	check(statics.groups.has("authored_placeable") and statics.groups.has("authored_door") and statics.stats.planned==2,"Actual static planner selects placeable/door resources from their existing fields")
	statics.close();statics.free()
	# Existing unsupported root controller maps are observed, never promoted to
	# passing geometry coverage by this narrowly scoped name correction.
	var root_transform: Dictionary=source.duplicate(true);root_transform.replicated.visualTransform={"keys":[0],"entries":[]}
	observations.replicated_visual_transform_affects_current_signature=world.signature(root_transform)!=key
	observations.root_visual_transform_coverage="Existing separate gap: not a signature/preparation consumer in this fixture"
	world.instances.clear();world.installed.clear();world.close();world.combat=null;world.free();combat.free();body.free()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"scope":"Actual LiveWorld signature/receive/delta/scheduling and CreatureStream/ObjectStream CPU plan behavior with authored data. No original asset decoding, real scene publication, pixels, GPU, network or performance acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE)
	if file==null:quit(2);return
	file.store_string(JSON.stringify(result,"\t"));file.close();print("NATIVE_LIVE_WORLD_NAME_SIGNATURE ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
