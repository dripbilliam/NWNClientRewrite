#pragma once

#include <array>

namespace nwn_stock_shadow {

using Position = std::array<float, 3>;

// In-view owners are supplied in world draw order. These fields describe the
// source model and attachment behavior, independent of GPU mesh resources.
struct Caster {
	Position adjusted_position{};
	const Caster *attachment_target = nullptr; // Resolved acyclic attachment chain for this scene view.
	bool shadow_enabled = false;
	bool has_geometry = false;
	bool has_primary_model = false;
	bool character_model = false;
	bool attached = false;
};

struct ShadowLight {
	Position position{};
	float radius = 0;
	float shadow_radius = 0;
	float vertical_displacement = 0;

	float projection_radius() const { return shadow_radius > 0 ? shadow_radius : radius; }
	Position projection_source() const {
		return {position[0], position[1], position[2] + vertical_displacement};
	}
};

struct SceneAdmission {
	Position focus{};
	float maximum_distance = 0;
	const Caster *only_model = nullptr;
	bool allow_non_characters = false;
};

#if defined(_MSC_VER)
#pragma float_control(precise, on, push)
#pragma fp_contract(off)
#endif

// Scene::DoGobShadows (0x1400c7f90). Compare in NWN's Z-up space, in the
// same arithmetic order as the native focus and light-radius checks.
inline float caster_distance_squared(const Position &a, const Position &b) {
	const float dy = a[1] - b[1];
	const float dx = a[0] - b[0];
	const float dz = a[2] - b[2];
	return (dy * dy + dx * dx) + dz * dz;
}

inline bool admits_moving_caster(const SceneAdmission &scene, const ShadowLight &light, const Caster &caster) {
	if (!caster.shadow_enabled || !caster.has_geometry) {
		return false;
	}
	if (scene.only_model != nullptr && scene.only_model != &caster) {
		const Caster *target = caster.attachment_target;
		while (target != nullptr && target != scene.only_model) {
			target = target->attachment_target;
		}
		if (target == nullptr) {
			return false;
		}
	}
	const float limit = scene.maximum_distance;
	if (!(caster_distance_squared(scene.focus, caster.adjusted_position) <= limit * limit)) {
		return false;
	}
	if (!scene.allow_non_characters && caster.has_primary_model && !caster.character_model && !caster.attached) {
		return false;
	}
	const float radius = light.projection_radius();
	return caster_distance_squared(light.projection_source(), caster.adjusted_position) < radius * radius;
}

// PartTriMesh::GetProjectsShadows (0x14008f5f0) after the authored flags.
// The cutoff and whether to multiply Gob alpha are independent live states.
inline bool admits_mesh_projection(bool shadow, bool beaming, const Caster *owner,
		bool test_alpha, bool attached_to_owned_part, bool multiply_owner_alpha,
		float mesh_alpha, float owner_alpha, float cutoff) {
	if (!shadow && !beaming) {
		return false;
	}
	if (owner == nullptr || owner->character_model || !test_alpha || attached_to_owned_part) {
		return true;
	}
	const float alpha = multiply_owner_alpha ? mesh_alpha * owner_alpha : mesh_alpha;
	return alpha >= cutoff;
}

#if defined(_MSC_VER)
#pragma float_control(pop)
#endif

} // namespace nwn_stock_shadow
