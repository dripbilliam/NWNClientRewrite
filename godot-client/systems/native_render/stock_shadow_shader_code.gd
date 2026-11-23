extends RefCounted

# NWN coordinates are Z-up. The caller supplies Vulkan's projection and a
# view matrix whose input is in NWN world space.
const CAMERA := """
layout(set = 0, binding = 0, std140) uniform ShadowCamera {
	mat4 world_to_view;
	mat4 view_to_clip;
	vec4 clip; // near, far, max(camera.z, focus.z), inverse viewport height
	vec4 plane; // screen fade point, fog start, inverse fog range, unused
} camera;
"""

const VOLUME_VERTEX := """
layout(location = 0) in vec4 position_and_frontal;
layout(push_constant, std430) uniform ProjectionData {
	mat4 model_to_world;
	vec4 light;
	vec4 clip;
} volume;

void main() {
	vec3 world = (volume.model_to_world * vec4(position_and_frontal.xyz, 1.0)).xyz;
	vec3 away;
	float distance_to_project = 0.1;
	bool frontal = position_and_frontal.w > 0.0;
	if (volume.light.w < 0.0) {
		away = volume.light.xyz;
		if (!frontal) {
			distance_to_project = max(0.1, (volume.clip.x - world.z) / away.z);
		}
		distance_to_project = max(distance_to_project, (camera.clip.z - world.z) / away.z);
	} else {
		away = world - volume.light.xyz;
		if (frontal) {
			away = normalize(away);
		} else {
			float distance_from_light = length(away);
			distance_to_project = max(0.1, volume.light.w - distance_from_light);
			away /= distance_from_light;
		}
	}

	vec3 view_position = (camera.world_to_view * vec4(world, 1.0)).xyz;
	vec3 view_away = mat3(camera.world_to_view) * away;
	float projected_z = view_position.z + view_away.z * distance_to_project;
	float near_limit = -camera.clip.x - 0.001;
	float far_limit = -camera.clip.y + 0.001;
	if (view_away.z > 0.001 && projected_z > near_limit) {
		projected_z = near_limit;
	} else if (view_away.z < -0.001 && projected_z < far_limit) {
		distance_to_project = (far_limit - view_position.z) / view_away.z;
		projected_z = far_limit;
	}
	gl_Position = camera.view_to_clip * vec4(
		view_position.xy + distance_to_project * view_away.xy, projected_z, 1.0);
}
"""

const VOLUME_FRAGMENT := """
layout(location = 0) out vec4 unused_color;
void main() {
	unused_color = vec4(0.0);
}
"""

const RESET_VERTEX := """
void main() {
	vec2 corner = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
	gl_Position = vec4(corner * 2.0 - 1.0, 0.0, 1.0);
}
"""

const PLANE_VERTEX := """
layout(location = 0) in vec4 position_and_alpha;
layout(location = 0) out vec2 alpha_and_fog;

void main() {
	vec4 view_position = camera.world_to_view * vec4(position_and_alpha.xyz, 1.0);
	gl_Position = camera.view_to_clip * view_position;
	alpha_and_fog = vec2(position_and_alpha.w, (-view_position.z - camera.plane.y) * camera.plane.z);
}
"""

const PLANE_FRAGMENT := """
layout(location = 0) in vec2 alpha_and_fog;
layout(location = 0) out vec4 shadow;

void main() {
	float y_from_bottom = 1.0 - gl_FragCoord.y * camera.clip.w;
	float screen_fade = 1.1 * (camera.plane.x - y_from_bottom) / camera.plane.x - 0.1;
	float plane_alpha = alpha_and_fog.x * min(1.0, 1.0 - alpha_and_fog.y);
	shadow = vec4(0.0, 0.0, 0.0, clamp(min(screen_fade, plane_alpha), 0.0, 1.0));
}
"""
