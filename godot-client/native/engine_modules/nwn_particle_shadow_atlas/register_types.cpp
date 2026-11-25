#include "register_types.h"

#include "core/object/class_db.h"
#include "servers/rendering/renderer_rd/storage_rd/light_storage.h"
#include "servers/rendering/renderer_rd/storage_rd/render_data_rd.h"
#include "servers/rendering/rendering_server.h"

#include <cstring>

namespace {

// The bridge borrows the current viewport's atlas for its compositor callback.
// Each row identifies the original Light3D resource and describes the engine's
// dual-paraboloid projection from world space into that atlas.
struct OmniShadow {
	uint64_t light;
	float rect[4];
	float sample[4]; // Opposite hemisphere UV offset, inverse radius, depth bias.
	float world_to_light[3][4];
	float opacity;
	float reserved;
};
static_assert(sizeof(OmniShadow) == 96);

class NwnParticleShadowAtlas : public Object {
	GDCLASS(NwnParticleShadowAtlas, Object);

protected:
	static void _bind_methods() {
		ClassDB::bind_static_method("NwnParticleShadowAtlas", D_METHOD("snapshot", "render_data"), &NwnParticleShadowAtlas::snapshot);
	}

public:
	static Dictionary snapshot(RenderData *render_data) {
		ERR_FAIL_COND_V(!RenderingServer::get_singleton()->is_on_render_thread(), Dictionary());
		const auto *data = Object::cast_to<RenderDataRD>(render_data);
		auto *lights = RendererRD::LightStorage::get_singleton();
		if (!data || !data->lights || !data->scene_data || !lights || !lights->owns_shadow_atlas(data->shadow_atlas)) {
			return {};
		}
		const RID atlas = lights->shadow_atlas_get_texture(data->shadow_atlas);
		if (atlas.is_null()) {
			return {};
		}
		const Vector3 eye = data->scene_data->get_cam_transform().origin;
		LocalVector<OmniShadow> rows;
		for (uint32_t index = 0; index < data->lights->size(); index++) {
			const RID instance = (*data->lights)[index];
			if (!lights->owns_light_instance(instance) || lights->light_instance_get_type(instance) != RSE::LIGHT_OMNI ||
					!lights->shadow_atlas_owns_light_instance(data->shadow_atlas, instance)) {
				continue;
			}
			const RID light = lights->light_instance_get_base_light(instance);
			if (!lights->light_has_shadow(light)) {
				continue;
			}
			const Transform3D transform = lights->light_instance_get_base_transform(instance);
			float opacity = lights->light_get_param(light, RSE::LIGHT_PARAM_SHADOW_OPACITY);
			if (lights->light_is_distance_fade_enabled(light)) {
				const float start = lights->light_get_distance_fade_shadow(light);
				const float distance = eye.distance_to(transform.origin);
				if (distance > start) {
					const float length = lights->light_get_distance_fade_length(light);
					opacity *= length > 0.0f ? Math::smoothstep(0.0f, 1.0f, 1.0f - (distance - start) / length) : 0.0f;
				}
			}
			if (opacity <= 0.001f) {
				continue;
			}
			Vector2i shift;
			const Rect2 rect = lights->light_instance_get_shadow_atlas_rect(instance, data->shadow_atlas, shift);
			if (rect.size.x <= 0.0f || rect.size.y <= 0.0f) {
				continue;
			}
			const Transform3D inverse = transform.affine_inverse();
			OmniShadow row{};
			row.light = light.get_id();
			row.rect[0] = rect.position.x;
			row.rect[1] = rect.position.y;
			row.rect[2] = rect.size.x;
			row.rect[3] = rect.size.y;
			row.sample[0] = shift.x * rect.size.x;
			row.sample[1] = shift.y * rect.size.y;
			row.sample[2] = 1.0f / MAX(0.001f, lights->light_get_param(light, RSE::LIGHT_PARAM_RANGE));
			row.sample[3] = lights->light_get_param(light, RSE::LIGHT_PARAM_SHADOW_BIAS);
			row.opacity = opacity;
			for (int axis = 0; axis < 3; axis++) {
				for (int component = 0; component < 3; component++) {
					row.world_to_light[axis][component] = inverse.basis[axis][component];
				}
				row.world_to_light[axis][3] = inverse.origin[axis];
			}
			rows.push_back(row);
		}
		if (rows.is_empty()) {
			return {};
		}
		PackedByteArray bytes;
		bytes.resize(rows.size() * sizeof(OmniShadow));
		std::memcpy(bytes.ptrw(), rows.ptr(), bytes.size());
		Dictionary result;
		result["atlas"] = atlas;
		result["omni"] = bytes;
		return result;
	}
};

} // namespace

void initialize_nwn_particle_shadow_atlas_module(ModuleInitializationLevel level) {
	if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		GDREGISTER_CLASS(NwnParticleShadowAtlas);
	}
}

void uninitialize_nwn_particle_shadow_atlas_module(ModuleInitializationLevel) {}
