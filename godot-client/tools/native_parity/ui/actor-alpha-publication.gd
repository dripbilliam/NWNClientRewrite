extends RefCounted
const NativeLightPolicy=preload("res://systems/native_render/native_light_policy.gd")
static func compose(part_alpha: float,global_alpha: float,count: int) -> float:
	# Float32 source words multiply/round at each native MULSS boundary.
	var word:=PackedFloat32Array([part_alpha])
	for index in count:word[0]=word[0]*global_alpha
	return word[0]
static func refresh(material) -> void:
	if material.actor_publishing:material.actor_again=true;return
	material.actor_publishing=true
	while true:
		material.actor_again=false
		var context=material.actor_alpha_context
		if context==null or context.closed:break
		var generation: int=context.revision;var local_revision: int=material.actor_revision
		var color: Color=material.actor_part_color
		var vector: Vector3=context.selected_vector
		var alpha:=compose(color.a,context.alpha,context.multiplications)
		var draw: bool=context.presentation_draw_enabled and context.alpha>0.0 and alpha>0.0
		# Native GetIsOpaque tests Part and Gob alpha independently. A Part .5
		# with global2 remains blended even though its product equals1.
		var blend: bool=material.actor_part_blended or color.a<1.0 or context.colour_shift_active and context.alpha<1.0
		material.albedo_color=Color(color.r*vector.x,color.g*vector.y,color.b*vector.z,alpha)
		if changed(material,context,generation,local_revision):continue
		var addition: Vector3=context.selected_emission
		material.emission_enabled=material.actor_part_emission_enabled or addition!=Vector3.ZERO
		if changed(material,context,generation,local_revision):continue
		# RefreshHilite publishes the chosen vector twice: multiplicative diffuse
		# and additive selfillum. Preserve the Part input. Enhanced already uses
		# this inverse-transfer boundary in its ordinary emission setter; add in
		# that raw domain before its existing native light transfer, not after it.
		var emission: Color=material.actor_part_emission
		if addition==Vector3.ZERO:material.emission=emission
		else:
			var raw:=emission.linear_to_srgb()
			var sum:=Color(raw.r+addition.x,raw.g+addition.y,raw.b+addition.z)
			if material is StandardMaterial3D:material.emission=sum.srgb_to_linear()
			else:
				material.emission=emission
				if changed(material,context,generation,local_revision):continue
				material.set_shader_parameter("native_emission",NativeLightPolicy.linear_rgb([sum.r,sum.g,sum.b]))
		if changed(material,context,generation,local_revision):continue
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA if blend else material.actor_base_transparency
		if changed(material,context,generation,local_revision):continue
		if material is StandardMaterial3D:material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED if blend else material.actor_base_depth_draw
		if changed(material,context,generation,local_revision):continue
		if material.actor_alpha_endpoint!=null:material.actor_alpha_endpoint.publish(material,draw)
		if changed(material,context,generation,local_revision):continue
		break
	material.actor_publishing=false
static func changed(material,context,generation: int,local_revision: int) -> bool:
	return material.actor_again or material.actor_revision!=local_revision or material.actor_alpha_context!=context or context.revision!=generation
static func copy_storage(source: Material,target: Material) -> void:
	# Preserve shader/TXI/render state and share immutable texture/shader inputs.
	# The target Material is new and never enters ResourcePool.materials.
	for property in source.get_property_list():
		var name:=str(property.name)
		if (int(property.usage)&PROPERTY_USAGE_STORAGE)==0 or name in ["script","resource_path","resource_name"] or name.begins_with("actor_"):continue
		target.set(name,source.get(name))
