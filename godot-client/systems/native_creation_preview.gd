extends Node
signal retirement_drained
# Same native model, texture, palette and animation pipeline as the live world.
const Stream=preload("res://systems/native_render/creature_stream.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
var owner_ui
var view
var assets
var pool:=Pool.new()
var signature:=""
var pending:=-1
var dead:=false
var stream
var diagnostics: Dictionary={}
var retiring: Array=[]
var pending_model: Dictionary={}
var retirement_stats: Dictionary={"maximumRetired":0,"maximumPending":0,"coalesced":0,"pendingDiscarded":0,"retired":0,"maximumDrainUsec":0,"maximumProcessUsec":0,"drainSamples":[]}
func configure(ui,preview,service) -> void:
	owner_ui=ui; view=preview; assets=service; assets.completed.connect(prepared)
func refresh(rules) -> void:
	if dead or not view.active: stop(); return
	var d: Dictionary=rules.draft; var next:=JSON.stringify([d.raceId,d.gender,d.phenotype,d.head,d.clothes,d.skin,d.hair,d.tattoo1,d.tattoo2])
	if signature==next: return
	stop(true); signature=next; view.message.text="Preparing native appearance…"
	var clothing:=str(rules.cell(rules.row("chargenclothes",int(d.clothes)),"ItemResRef",""))
	diagnostics={"draft":d.duplicate(true),"appearance":rules.num(rules.race(),"Appearance")}
	pending=assets.request(clothing,2025,"gff")
	if pending<0: view.message.text=assets.failure
func prepared(id: int,result: Dictionary) -> void:
	if dead or id!=pending: return
	pending=-1
	if not str(result.error).is_empty(): view.message.text=str(result.error); return
	var d: Dictionary=diagnostics.draft; var armor: Dictionary=result.value.root; var parts: Array=[]; var colors: Array=[]
	for material in Appearance.MATERIALS: colors.append(int(armor.get(material+"Color",0)))
	for label in Appearance.BODY: parts.append(int(armor.get(label.replace("BodyPart_","ArmorPart_"),1 if label in ["ArmorPart_RFoot","BodyPart_LFoot","BodyPart_RShin","BodyPart_LShin","BodyPart_LThigh","BodyPart_RThigh","BodyPart_Pelvis","BodyPart_Torso","BodyPart_Neck","BodyPart_RFArm","BodyPart_LFArm","BodyPart_RBicep","BodyPart_LBicep","BodyPart_RHand","BodyPart_LHand"] else 0)))
	var object:={"id":1,"areaId":0,"objectType":5,"appearance":{"appearance":int(diagnostics.appearance),"gender":int(d.gender),"phenotype":int(d.phenotype),"head":int(d.head),"skin":int(d.skin),"hair":int(d.hair),"tattoo1":int(d.tattoo1),"tattoo2":int(d.tattoo2),"equipment":[{"slot":2,"item":{"modelType":3,"parts":parts,"colors":colors}}]},"replicated":{"position":[0,0,0],"orientation":[0,1,0],"animation":0,"stats":{"racialType":int(d.raceId)}}}
	if result.value.get("field_types",{}).get(0,{}).get("BaseItem")==5 and armor.get("BaseItem") is int:object.appearance.equipment[0].item.baseItem=armor.BaseItem
	queue_model(object,diagnostics)
static func source_object(race_id: int,appearance_id: int,value: Dictionary,document: Dictionary) -> Dictionary:
	var body: Array=[]
	for index in 19:body.append({"index":index,"value":int(value.skinParts[index])})
	var object:={"id":1,"areaId":0,"objectType":5,"appearance":{"appearance":appearance_id,"gender":int(value.gender),"phenotype":int(value.phenotype),"head":int(value.head),"skin":int(value.skin),"hair":int(value.hair),"tattoo1":int(value.tattoo1),"tattoo2":int(value.tattoo2),"bodyParts":body,"equipment":[{"slot":2,"item":{"modelType":3,"parts":value.bodyParts.duplicate(),"colors":value.materialColors.duplicate()}}]},"replicated":{"position":[0,0,0],"orientation":[0,1,0],"animation":0,"stats":{"racialType":race_id}}}
	if document.get("field_types",{}).get(0,{}).get("BaseItem")==5 and document.get("root",{}).get("BaseItem") is int:object.appearance.equipment[0].item.baseItem=document.root.BaseItem
	return object
func refresh_source(race_id: int,appearance_id: int,value: Dictionary,document: Dictionary,scope: Array) -> void:
	if dead or not view.active:return
	var next:=preload("res://systems/native_data/prepared_cache.gd").digest(var_to_bytes([scope,race_id,appearance_id,value,document]))
	if signature==next:return
	stop(true);signature=next;view.message.text="Preparing native appearance…"
	var object:=source_object(race_id,appearance_id,value,document)
	diagnostics={"sourceScope":scope.duplicate(),"object":object.duplicate(true),"signature":next}
	queue_model(object,diagnostics)
func queue_model(object: Dictionary,details: Dictionary) -> void:
	if not pending_model.is_empty():retirement_stats.coalesced+=1
	pending_model={"object":object,"diagnostics":details,"signature":signature}
	retirement_stats.maximumPending=maxi(int(retirement_stats.maximumPending),1)
	if retiring.is_empty():install_pending()
func install_pending() -> void:
	if pending_model.is_empty() or not retiring.is_empty():return
	var value:=pending_model;pending_model={}
	if dead or not view.active or value.signature!=signature:return
	diagnostics=value.diagnostics
	stream=Stream.new();view.pivot.add_child(stream);view.model=stream
	stream.configure(owner_ui.catalog,pool,[value.object],0,assets.cache_directory,1)
func drain_retired(wait: bool=false) -> void:
	if retiring.is_empty():return
	var prior: Dictionary=retiring[0]
	# The stream owns these task IDs. A forced close must let its asset
	# service join them once; an external join would invalidate its IDs.
	if not wait and prior.tasks.any(func(task):return not WorkerThreadPool.is_task_completed(int(task))):return
	var began:=Time.get_ticks_usec();prior.stream.close();prior.stream.queue_free();retiring.clear();retirement_stats.retired+=1
	var elapsed:=Time.get_ticks_usec()-began;retirement_stats.maximumDrainUsec=maxi(int(retirement_stats.maximumDrainUsec),elapsed);retirement_stats.drainSamples.append(elapsed)
	if retirement_stats.drainSamples.size()>64:retirement_stats.drainSamples.pop_front()
	retirement_drained.emit()
func _process(_delta: float) -> void:
	var began:=Time.get_ticks_usec();process_preview();retirement_stats.maximumProcessUsec=maxi(int(retirement_stats.maximumProcessUsec),Time.get_ticks_usec()-began)
func process_preview() -> void:
	drain_retired()
	if retiring.is_empty() and not pending_model.is_empty():install_pending()
	if dead or not is_instance_valid(stream) or not stream.done or diagnostics.has("ready"): return
	diagnostics.ready=stream.actors.has(1); diagnostics.errors=stream.stats.errors.duplicate(true)
	if not diagnostics.ready: view.message.text=JSON.stringify(diagnostics.errors); return
	var actor=stream.actors[1]; var bounds:=AABB(); var found:=false
	for mesh in actor.meshes:
		var box: AABB=(stream.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
		bounds=bounds.merge(box) if found else box; found=true
	if found:
		stream.position=-bounds.get_center(); view.base_distance=maxf(0.5,maxf(bounds.size.y*1.8,bounds.size.x*2.5)); view._camera()
	diagnostics.models=actor.model_names.duplicate(); diagnostics.meshes=actor.meshes.size(); diagnostics.native=true
	view.message.text=""; view.installs+=1; view.last={"state":"ready","native":true,"models":diagnostics.models,"meshes":diagnostics.meshes}
func stop(replacing: bool=false) -> void:
	if not pending_model.is_empty():
		if replacing:retirement_stats.coalesced+=1
		else:retirement_stats.pendingDiscarded+=1
	pending=-1; signature="";pending_model={}
	if is_instance_valid(stream):
		# Scene/input callbacks never join a worker. This private stream remains
		# in its viewport until its captured data jobs finish; only one latest
		# replacement can wait, and it cannot start another stream meanwhile.
		stream.hide();stream.process_mode=Node.PROCESS_MODE_DISABLED
		if view.model==stream:view.model=null;view.retired+=1
		var tasks: Array=[]
		if is_instance_valid(stream.assets):stream.assets.retire_scope();tasks=stream.assets.running.values().duplicate()
		retiring.append({"stream":stream,"tasks":tasks})
		retirement_stats.maximumRetired=maxi(int(retirement_stats.maximumRetired),retiring.size())
	stream=null; diagnostics.clear()
func close() -> void: dead=true;stop();drain_retired(true)
