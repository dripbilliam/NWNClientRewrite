extends "res://systems/native_render/standard_keyhole_material.gd"
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
@export_storage var albedo_color:=Color.WHITE
@export_storage var emission:=Color.BLACK
@export_storage var emission_enabled:=false
@export_storage var transparency:=BaseMaterial3D.TRANSPARENCY_DISABLED
var actor_revision:=0
var actor_publishing:=false
var actor_again:=false

func configure(source: StandardMaterial3D,with_keyhole: bool=true) -> bool:
	if not super.configure(source,with_keyhole):return false
	transparency=source.transparency
	return true

func publish_actor_part_pose(color_value: Color,emission_value: Color,blended: bool) -> void:
	actor_part_color=color_value
	actor_part_emission=emission_value
	actor_part_emission_enabled=emission_value.r!=0 or emission_value.g!=0 or emission_value.b!=0
	actor_part_blended=blended
	actor_revision+=1
	refresh_actor_alpha()

func publish_native_pose(color_value: Color,emission_value: Color,blended: bool) -> void:
	publish_actor_part_pose(color_value,emission_value,blended)

func publish_actor_standard_material(color_value: Color,emission_value: Color,emission_active: bool,alpha_mode: int) -> void:
	if transparency!=alpha_mode:
		transparency=alpha_mode
		_bind_standard_shader(alpha_mode)
	albedo_color=color_value
	emission=emission_value
	emission_enabled=emission_active
	_publish_standard_values(color_value,emission_value,emission_active)

func refresh_actor_alpha() -> void:Publication.refresh(self)
