#include "register_types.h"

#include "../../stock_shadow_projection.hpp"
#include "core/object/class_db.h"
#include "core/object/ref_counted.h"
#include "core/variant/dictionary.h"

namespace {

using namespace nwn_stock_shadow;

template <typename T>
PackedByteArray pack(const std::vector<T> &p_values) {
	PackedByteArray bytes;
	if (!p_values.empty()) {
		const size_t size = p_values.size() * sizeof(T);
		bytes.resize(size);
		memcpy(bytes.ptrw(), p_values.data(), size);
	}
	return bytes;
}

class NwnStockShadowMesh : public RefCounted {
	GDCLASS(NwnStockShadowMesh, RefCounted);

	std::optional<MeshTopology> topology;
	std::vector<ProjectionPosition> positions;
	ProjectionPosition origin{};
	Projector projector;
	nwn_stock_shadow::Projection projection;
	PackedByteArray dynamic_vertices;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("configure", "faces", "positions", "origin"), &NwnStockShadowMesh::configure);
		ClassDB::bind_method(D_METHOD("get_dynamic_vertices"), &NwnStockShadowMesh::get_dynamic_vertices);
		ClassDB::bind_method(D_METHOD("project_dynamic", "local_light"), &NwnStockShadowMesh::project_dynamic);
		ClassDB::bind_method(D_METHOD("project_static", "local_light"), &NwnStockShadowMesh::project_static);
	}

public:
	bool configure(const PackedByteArray &p_faces, const PackedFloat32Array &p_positions, const Vector3 &p_origin) {
		if (p_positions.is_empty() || p_positions.size() % 3 != 0 || p_positions.size() / 3 > UINT16_MAX) {
			return false;
		}
		const auto vertex_count = static_cast<uint16_t>(p_positions.size() / 3);
		auto decoded = MeshTopology::decode(p_faces.ptr(), p_faces.size(), vertex_count);
		if (!decoded.has_value()) {
			return false;
		}

		// Keep a single authored table and upload its paired vertices on first use.
		topology = std::move(decoded);
		positions.resize(vertex_count);
		const float *values = p_positions.ptr();
		for (uint16_t index = 0; index < vertex_count; ++index) {
			positions[index] = { values[3 * index], values[3 * index + 1], values[3 * index + 2] };
		}
		origin = { static_cast<float>(p_origin.x), static_cast<float>(p_origin.y), static_cast<float>(p_origin.z) };
		dynamic_vertices.clear();
		return true;
	}

	PackedByteArray get_dynamic_vertices() {
		if (topology.has_value() && dynamic_vertices.is_empty()) {
			std::vector<ProjectionVertex> vertices;
			build_vertex_pairs(positions, origin, nullptr, vertices);
			dynamic_vertices = pack(vertices);
		}
		return dynamic_vertices;
	}

	PackedByteArray project_dynamic(const Vector3 &p_local_light) {
		if (!topology.has_value()) {
			return {};
		}
		projector.project(*topology, light_position(p_local_light), Storage::dynamic_stream, projection);
		return pack(projection.indices);
	}

	Dictionary project_static(const Vector3 &p_local_light) {
		if (!topology.has_value()) {
			return {};
		}
		projector.project(*topology, light_position(p_local_light), Storage::static_projection, projection);
		if (projection.indices.empty()) {
			return {};
		}
		std::vector<ProjectionVertex> vertices;
		build_vertex_pairs(positions, origin, &projection.static_vertices, vertices);
		Dictionary result;
		result["vertices"] = pack(vertices);
		result["indices"] = pack(projection.indices);
		return result;
	}

private:
	static ProjectionPosition light_position(const Vector3 &p_light) {
		return { static_cast<float>(p_light.x), static_cast<float>(p_light.y), static_cast<float>(p_light.z) };
	}
};

} // namespace

void initialize_nwn_stock_shadow_module(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		GDREGISTER_CLASS(NwnStockShadowMesh);
	}
}

void uninitialize_nwn_stock_shadow_module(ModuleInitializationLevel p_level) {
}
