extends Node
# Run in the isolated test project with the actual ClientAPI autoload configured.
const Motion=preload("res://systems/network_motion.gd")
var checks:=0
var failures: Array=[]
var source: Dictionary={}
var motion:=Motion.new()
var updates: Array=[]
var lookups:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func _ready() -> void: call_deferred("run")
func run() -> void:
	check(is_instance_valid(ClientAPI) and ClientAPI.name=="ClientAPI","Literal ClientAPI autoload is available to consumer scripts")
	var provider: RefCounted=ClientAPI.entities
	check(not ClientAPI.is_processing() and not ClientAPI.is_physics_processing(),"API has no per-frame process callbacks")
	var binding: RefCounted=ClientAPI.bind_native(func(id):lookups+=1; return source.get(id),func(id):return motion.objects.get(id))
	provider.entity_updated.connect(func(event):updates.append(event))
	var row: Dictionary=JSON.parse_string('{"id":2147483650,"objectType":5,"areaId":2147483651,"nativeLifetime":12,"replicated":{"position":[1,2,0],"orientation":[1,0,0],"animation":0,"walkRate":2,"runRate":4,"stats":{"classes":[{"id":1,"level":2}]}}}')
	var id:=int(row.id); var area:=int(row.areaId)
	source[id]=row
	check(binding.commit(1,1,area,{"controlledId":id,"objects":[row]}),"Actual JSON transport number representation is accepted")
	check(provider.list_references({"object_type":5,"current_area":true}).size()==1 and provider.get_by_id(id).identity.type_name=="creature","JSON numeric IDs/types/areas normalize only for identity/filter bookkeeping")
	check(not provider.get_by_id(id).presentation.available,"Entity exists before actual movement owner initialization")
	motion.observe(id,row.replicated,true,row.replicated)
	var before: Dictionary=provider.get_by_id(id)
	check(before.presentation.available and before.presentation.value.position==Vector3(1,2,0),"Actual network_motion owner is sampled on demand without a visual instance")
	var ref: Dictionary=provider.get_reference(id)
	var received_position: Array=before.replicated.value.position.duplicate()
	motion.preview(id,{"animation":2,"facing":Vector3(1,0,0),"factor":1.0},Vector3(3,2,0))
	motion.update(0.1)
	var predicted: Dictionary=provider.resolve(ref)
	check(predicted.presentation.value.position!=Vector3(1,2,0) and predicted.replicated.value.position==received_position,"Real native prediction advances presentation while received state remains unchanged")
	check(updates.is_empty(),"Native per-frame prediction does not copy/publish the entity registry")
	var changes:={"position":[2,2,0],"animation":0}
	motion.observe(id,changes,false,row.replicated)
	binding.presentation_records(1,1,area,[{"id":id,"revision":1,"changes":changes}])
	check(updates.size()==1 and updates[0].source=="presentation_input","Accepted movement boundary publishes one compact update")
	var reads_before:=lookups
	for iteration in 30: motion.update(0.016)
	check(lookups==reads_before and updates.size()==1,"Thirty actual native motion frames perform no API canonical lookups or extra events")
	check(provider.resolve(ref).replicated.value.position==received_position,"Movement input is not relabeled as a raw snapshot update")
	row=JSON.parse_string(JSON.stringify(row)); row.replicated.position=[2,2,0]; source[id]=row
	binding.commit(1,1,area,{"bridgeMode":"delta","controlledId":id,"objects":[row]})
	check(provider.resolve(ref).replicated.value.position==[2,2,0],"Next actual raw owner publication refreshes received state")
	check(not binding.commit(1,1,area,{"bridgeMode":"broken","objects":[row]}),"Invalid publication mode fails without mutation")
	check(not binding.commit(1,1,area,{"objects":{}}),"Invalid object container fails without mutation")
	row=JSON.parse_string(JSON.stringify(row)); row.nativeLifetime=13; source[id]=row
	check(provider.resolve(ref)==null,"Canonical token mismatch cannot resolve during a source replacement before commit")
	binding.commit(1,1,area,{"bridgeMode":"delta","controlledId":id,"objects":[row]})
	check(provider.resolve(ref)==null and provider.get_reference(id)!=ref,"New identity invalidates the old lifetime after publication")
	var snapshot: Dictionary=provider.get_by_id(id,false)
	check(not snapshot.presentation.available and snapshot.presentation.reason=="not_requested","Consumers can omit presentation sampling")
	binding.reset("fixture_end")
	check(not provider.get_scope().active,"Binding reset retires the autoload provider scope")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Isolated literal ClientAPI autoload plus real existing network_motion.gd; canonical raw object/source boundaries are authored fixtures. No shared session hooks or live-client/server acceptance."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var file:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			if file!=null: file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	print("ENTITY_API_BINDING_RESULT ",JSON.stringify(report)); get_tree().quit(0 if failures.is_empty() else 1)
