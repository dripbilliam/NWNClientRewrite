extends StandardMaterial3D
const Publication=preload("res://tools/native_parity/ui/actor-alpha-publication.gd")
const AlphaState=preload("res://tools/native_parity/ui/actor-alpha-state.gd")
@export var actor_alpha_context: AlphaState:
	set(value):
		if actor_alpha_context!=null:actor_alpha_context.unregister_material(self)
		actor_alpha_context=value
		if value!=null:value.register_material(self)
@export var actor_alpha_endpoint: Resource
@export var actor_part_color:=Color.WHITE
@export var actor_part_emission:=Color.BLACK
@export var actor_part_emission_enabled:=false
@export var actor_part_blended:=false
@export var actor_base_transparency:=BaseMaterial3D.TRANSPARENCY_DISABLED
@export var actor_base_depth_draw:=BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
var actor_revision:=0
var actor_publishing:=false
var actor_again:=false
func publish_actor_part_pose(color_value: Color,emission_value: Color,blended: bool) -> void:
	actor_part_color=color_value;actor_part_emission=emission_value;actor_part_emission_enabled=emission_value.r!=0 or emission_value.g!=0 or emission_value.b!=0;actor_part_blended=blended;actor_revision+=1
	var context:=actor_alpha_context
	if not actor_publishing and context!=null and context.plain and not context.closed:
		actor_publishing=true;actor_again=false
		var generation:=context.revision;var local_revision:=actor_revision
		albedo_color=color_value;emission_enabled=actor_part_emission_enabled;emission=emission_value
		transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if blended or color_value.a<1 else actor_base_transparency
		depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED if blended or color_value.a<1 else actor_base_depth_draw
		if actor_alpha_context==context and context.revision==generation and actor_revision==local_revision and not actor_again and actor_alpha_endpoint!=null:actor_alpha_endpoint.publish(self,color_value.a>0)
		actor_publishing=false
		if actor_alpha_context!=context or context.revision!=generation or actor_revision!=local_revision or actor_again:refresh_actor_alpha()
		return
	refresh_actor_alpha()
func publish_native_pose(color_value: Color,emission_value: Color,blended: bool) -> void:
	publish_actor_part_pose(color_value,emission_value,blended)
func refresh_actor_alpha() -> void:Publication.refresh(self)
