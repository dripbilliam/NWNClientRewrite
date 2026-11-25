shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, depth_test_disabled, depth_draw_never;

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 polygon[255];
uniform int vertex_count;
uniform float half_height;

float wedge(vec2 a, vec2 b) {
	return a.x * b.y - a.y * b.x;
}

void fragment() {
	float depth = texture(scene_depth, SCREEN_UV).x;
	if (depth <= 0.0) {
		discard;
	}
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec4 world_position = INV_VIEW_MATRIX * vec4(view_position.xyz / view_position.w, 1.0);
	vec3 surface = (inverse(MODEL_MATRIX) * world_position).xyz;

	// The stock stencil volume uses triangle-fan caps about the bounds center.
	// Signed coverage preserves concave cutouts where the fan overlaps itself.
	float coverage = 0.0;
	for (int i = 0; i < vertex_count; i++) {
		vec3 a = polygon[i];
		vec3 b = polygon[(i + 1) % vertex_count];
		float area = wedge(a.xz, b.xz);
		if (abs(area) > 0.000001) {
			float wa = wedge(surface.xz, b.xz) / area;
			float wb = wedge(a.xz, surface.xz) / area;
			float mapped_height = wa * a.y + wb * b.y;
			if (wa >= 0.0 && wb >= 0.0 && wa + wb <= 1.0 && abs(surface.y - mapped_height) <= half_height) {
				coverage += sign(area);
			}
		}
	}
	if (abs(coverage) < 0.5) {
		discard;
	}
	ALBEDO = vec3(0.0, 0.0, 1.0);
	ALPHA = 0.25;
}
