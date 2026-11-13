extends RefCounted
# Private source prototype. Explicit enrollment, no rate reduction or owner
# suppression. Unknown/general manual parts keep the original P/Q/S path.
var active:=false
var armed:=false
var reason:="not_enrolled"
var owner_ref: WeakRef
var publisher_ref: WeakRef
var rig_ref: WeakRef
var node_ref: WeakRef
var parent_ref: WeakRef
var node_id:=0
var index:=-1
var revision:=-1
var warm_signature:=PackedByteArray()
var original_publications:=0
var omitted_publications:=0
var warm_matches:=0

static func configured() -> bool:
	return OS.get_cmdline_user_args().has("--generated-light-manual=retained") or OS.get_environment("NWN_GENERATED_LIGHT_MANUAL")=="retained"

static func script_is(node: Object,expected: String) -> bool:
	if not is_instance_valid(node):return false
	var script: Script=node.get_script()
	return script!=null and script.resource_path==expected

static func bits(values: Array) -> PackedByteArray:
	return PackedFloat32Array(values).to_byte_array()

static func signature(node: Node3D) -> PackedByteArray:
	var t:=node.transform;var s:=node.scale
	var values: Array=[]
	for column in [t.basis.x,t.basis.y,t.basis.z,t.origin,s]:values.append_array([column.x,column.y,column.z])
	values.append(float(node.rotation_order))
	return bits(values)

static func create(rig: Node,entity: Dictionary,entity_id: int,owner: Node3D,publisher: Node) -> RefCounted:
	var token=load("res://systems/native_render/generated_light_manual_publication.gd").new()
	token.reason="disabled"
	if not configured():return token
	if not script_is(rig,"res://systems/model_rigs.gd"):
		token.reason="unproven_rig_writer";return token
	if not script_is(owner,"res://systems/native_render/effect_model.gd") or not script_is(publisher,"res://systems/native_render/placeable_lights.gd"):
		token.reason="not_canonical_owner";return token
	if owner.get_parent()!=publisher or owner.get("rigs")!=rig or bool(owner.get("retired")) or not bool(owner.get("installed")) or bool(publisher.get("closed")):
		token.reason="owner_lifetime";return token
	if not owner.has_meta("native_generated_placeable_id") or not owner.has_meta("native_model_name") or str(owner.get_meta("native_model_name"))!="fx_placeable01":
		token.reason="not_generated_light";return token
	var generated_id:=int(owner.get_meta("native_generated_placeable_id"))
	var instances: Dictionary=publisher.get("instances")
	var names: Array=owner.get("model_names")
	if instances.get(generated_id)!=owner or names.size()!=1 or str(names[0]).to_lower()!="fx_placeable01":
		token.reason="publisher_identity";return token
	if int(owner.get("anchor_flags"))!=0 or bool(owner.get("anchor_inherit_scale")):
		token.reason="unproven_follow_mode";return token
	var references: Array=owner.get("reference_graphs")
	# ActorInstance records one null placeholder for a model with no references.
	# A nonempty placeholder array is not itself a live reference graph.
	if references.any(func(graph):return graph!=null) or entity.get("models",[]).size()!=1 or not entity.get("animated_models",[]).is_empty() or not entity.get("attachments",[]).is_empty() or not entity.get("skins",[]).is_empty() or entity.get("manual_poses",{}).size()!=1:
		token.reason="nonexclusive_rig";return token
	var model: Dictionary=entity.models[0]
	if model.get("player")!=null or model.has("native_owner") or bool(model.get("particle_clock_shared",false)):
		token.reason="animated_or_native_owner";return token
	var chosen:=int(entity.manual_poses.keys()[0])
	var node: Node3D=rig.node_for(entity_id,0,"root")
	if not is_instance_valid(node) or chosen<0 or chosen>=entity.nodes.size() or entity.nodes[chosen]!=node or node.get_class()!="Node3D" or node.get_script()!=null:
		token.reason="unproven_part";return token
	var manual: Dictionary=entity.manual_poses[chosen]
	var p: Vector3=manual.position;var q: Quaternion=manual.quaternion;var s: Vector3=manual.scale
	if not p.is_finite() or bits([q.x,q.y,q.z,q.w])!=bits([0.0,0.0,0.0,1.0]) or bits([s.x,s.y,s.z])!=bits([1.0,1.0,1.0]):
		token.reason="nonidentity_manual_rotation_or_scale";return token
	# Initial enrollment deliberately excludes general quaternion/nonuniform
	# scale. Even identity requires two matching ORIGINAL publications, because
	# matrix equality by itself does not establish hidden setter-cache state.
	token.owner_ref=weakref(owner);token.publisher_ref=weakref(publisher);token.rig_ref=weakref(rig);token.node_ref=weakref(node);token.parent_ref=weakref(node.get_parent())
	token.node_id=node.get_instance_id();token.index=chosen;token.revision=int(entity.get("generated_manual_revision",0));token.reason="warming";token.active=true
	return token

func revoke(why: String) -> void:
	active=false;armed=false;reason=why

func same_owner(rig: Node,entity: Dictionary,owner: Node3D,publisher: Node) -> bool:
	return active and rig_ref.get_ref()==rig and owner_ref.get_ref()==owner and publisher_ref.get_ref()==publisher and revision==int(entity.get("generated_manual_revision",0))

func current(rig: Node,entity: Dictionary,part: int) -> bool:
	if not active or part!=index:return false
	var node: Node3D=node_ref.get_ref();var owner: Node3D=owner_ref.get_ref();var publisher: Node=publisher_ref.get_ref()
	if rig_ref.get_ref()!=rig or revision!=int(entity.get("generated_manual_revision",0)) or not is_instance_valid(node) or node.get_instance_id()!=node_id or not is_instance_valid(owner) or not is_instance_valid(publisher) or owner.get_parent()!=publisher or node.get_parent()!=parent_ref.get_ref():
		revoke("lifetime_revision_or_topology");return false
	return true

func omit(rig: Node,entity: Dictionary,part: int) -> bool:
	if not current(rig,entity,part) or not armed:return false
	omitted_publications+=1
	return true

func published(rig: Node,entity: Dictionary,part: int) -> void:
	if not current(rig,entity,part):return
	original_publications+=1
	var node: Node3D=node_ref.get_ref();var value:=signature(node)
	if not warm_signature.is_empty() and value==warm_signature:warm_matches+=1
	else:warm_matches=0
	warm_signature=value
	if warm_matches>=1:armed=true;reason="retained_identity_part"

func snapshot() -> Dictionary:
	return {"active":active,"armed":armed,"reason":reason,"node_id":node_id if node_id!=0 else null,"part":index if index>=0 else null,"revision":revision if revision>=0 else null,"original_publications":original_publications,"omitted_publications":omitted_publications,"warm_matches":warm_matches}
