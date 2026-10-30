extends Node
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
func configure(ui,preview,service) -> void:
	owner_ui=ui; view=preview; assets=service; assets.completed.connect(prepared)
func refresh(rules) -> void:
	if dead or not view.active: stop(); return
	var d: Dictionary=rules.draft; var next:=JSON.stringify([d.raceId,d.gender,d.phenotype,d.head,d.clothes,d.skin,d.hair,d.tattoo1,d.tattoo2])
	if signature==next: return
	stop(); signature=next; view.message.text="Preparing native appearance…"
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
	stream=Stream.new(); view.pivot.add_child(stream); view.model=stream
	stream.configure(owner_ui.catalog,pool,[object],0,assets.cache_directory,1)
func _process(_delta: float) -> void:
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
func stop() -> void:
	pending=-1; signature=""
	if is_instance_valid(stream):
		if view.model==stream: view.release_model()
		else: stream.close(); stream.queue_free()
	stream=null; diagnostics.clear()
func close() -> void: stop(); dead=true
