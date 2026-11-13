extends RefCounted
# Scoped interim material contract. Geometry collection remains the registry's
# responsibility; the native pass uses authored box planes, not skin triangles.
static func create(color: Color,opacity: float=0.28) -> StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.no_depth_test=false
	# Native Scene renders the highlight bucket after ordinary objects. A
	# separate priority avoids sorting the same mesh's base and overlay at0.
	material.render_priority=Material.RENDER_PRIORITY_MAX
	material.albedo_color=Color(color.r,color.g,color.b,opacity)
	return material
