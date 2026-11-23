#pragma once

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <optional>
#include <vector>

namespace nwn_stock_shadow {

inline constexpr std::uint16_t boundary = 0xffff;
inline constexpr std::size_t face_stride = 32;
inline constexpr std::size_t face_limit = 0xfffe;
inline constexpr std::size_t edge_limit = 0x2aaa;

struct Face {
	std::array<float, 4> plane;
	std::array<std::uint16_t, 3> adjacent;
	std::array<std::uint16_t, 3> corners;
};

class MeshTopology {
	std::vector<Face> faces_;
	std::uint16_t vertex_count_ = 0;

	static std::uint16_t read_u16(const std::uint8_t *bytes) {
		return static_cast<std::uint16_t>(bytes[0] | (bytes[1] << 8));
	}

	static float read_f32(const std::uint8_t *bytes) {
		const std::uint32_t word = read_u16(bytes) | (std::uint32_t(read_u16(bytes + 2)) << 16);
		float value;
		std::memcpy(&value, &word, sizeof(value));
		return value;
	}

public:
	// The MDL face list carries the original plane and neighbors. The draw
	// index groups cannot recover them, particularly at split UV seams.
	static std::optional<MeshTopology> decode(const std::uint8_t *bytes, std::size_t size, std::uint16_t vertex_count) {
		if (size % face_stride != 0 || (size != 0 && bytes == nullptr)) {
			return std::nullopt;
		}
		MeshTopology mesh;
		mesh.vertex_count_ = vertex_count;
		const std::size_t count = size / face_stride;
		mesh.faces_.reserve(std::min(count, face_limit));
		for (std::size_t i = 0; i < std::min(count, face_limit); ++i) {
			const auto *record = bytes + i * face_stride;
			Face face{};
			for (std::size_t j = 0; j < face.plane.size(); ++j) {
				face.plane[j] = read_f32(record + 4 * j);
				if (!std::isfinite(face.plane[j])) {
					return std::nullopt;
				}
			}
			for (std::size_t j = 0; j < face.corners.size(); ++j) {
				face.adjacent[j] = read_u16(record + 20 + 2 * j);
				face.corners[j] = read_u16(record + 26 + 2 * j);
				if ((face.adjacent[j] != boundary && face.adjacent[j] >= count) || face.corners[j] >= vertex_count) {
					return std::nullopt;
				}
			}
			mesh.faces_.push_back(face);
		}
		return mesh;
	}

	const std::vector<Face> &faces() const { return faces_; }
	std::uint16_t vertex_count() const { return vertex_count_; }
};

enum class Storage { dynamic_stream, static_projection };

struct Projection {
	// Dynamic uses the model vertex table. Static compacts it by first use.
	std::vector<std::uint16_t> static_vertices;
	std::vector<std::uint16_t> indices;
	std::uint32_t origin_pair = 0;
};

using ProjectionVertex = std::array<float, 4>;
using ProjectionPosition = std::array<float, 3>;

// The GPU projects the w=0 copy. Static caches use the compact remap from
// Project; moving Parts keep their complete local vertex table for reuse.
inline bool build_vertex_pairs(const std::vector<ProjectionPosition> &positions, const ProjectionPosition &origin,
		const std::vector<std::uint16_t> *static_vertices, std::vector<ProjectionVertex> &out) {
	out.clear();
	if (static_vertices != nullptr &&
			std::any_of(static_vertices->begin(), static_vertices->end(), [&](auto vertex) { return vertex >= positions.size(); })) {
		return false;
	}
	const std::size_t count = static_vertices == nullptr ? positions.size() : static_vertices->size();
	out.reserve((count + 1) * 2);
	const auto append = [&](const ProjectionPosition &position) {
		out.push_back({position[0], position[1], position[2], 1.f});
		out.push_back({position[0], position[1], position[2], 0.f});
	};
	for (std::size_t i = 0; i < count; ++i) {
		append(positions[static_vertices == nullptr ? i : (*static_vertices)[i]]);
	}
	append(origin);
	return true;
}

#if defined(_MSC_VER)
#pragma float_control(precise, on, push)
#pragma fp_contract(off)
#endif

class Projector {
	std::vector<std::uint8_t> signs_;
	std::vector<std::array<std::uint16_t, 2>> edges_;
	std::vector<int> remap_;

public:
	// PartTriMesh::Project (0x1400a3770). The caller supplies the light in
	// the Part's NWN local frame after applying the Gob and Part transforms.
	void project(const MeshTopology &mesh, const std::array<float, 3> &light, Storage storage, Projection &out) {
		out.indices.clear();
		out.static_vertices.clear();
		out.origin_pair = 0;
		edges_.clear();
		const auto &faces = mesh.faces();
		signs_.resize(faces.size());
		for (std::size_t i = 0; i < faces.size(); ++i) {
			const auto &plane = faces[i].plane;
			const float side = ((light[0] * plane[0] + light[1] * plane[1]) + light[2] * plane[2]) + plane[3];
			// The binary tests the sign bit of the SSE result, including -0.
			signs_[i] = std::signbit(side);
		}
		for (std::size_t i = 0; i < faces.size() && edges_.size() < edge_limit; ++i) {
			if (signs_[i]) {
				continue;
			}
			const Face &face = faces[i];
			for (std::size_t edge = 0; edge < 3 && edges_.size() < edge_limit; ++edge) {
				const std::uint16_t neighbor = face.adjacent[edge];
				if (neighbor == boundary || (neighbor < signs_.size() && signs_[neighbor])) {
					edges_.push_back({face.corners[edge], face.corners[(edge + 1) % 3]});
				}
			}
		}
		if (edges_.empty()) {
			return;
		}
		if (storage == Storage::static_projection) {
			remap_.assign(mesh.vertex_count(), -1);
			for (auto &edge : edges_) {
				for (auto &corner : edge) {
					int &slot = remap_[corner];
					if (slot < 0) {
						slot = static_cast<int>(out.static_vertices.size());
						out.static_vertices.push_back(corner);
					}
					corner = static_cast<std::uint16_t>(slot);
				}
			}
		}
		const auto vertex_count = storage == Storage::static_projection ? out.static_vertices.size() : mesh.vertex_count();
		out.origin_pair = static_cast<std::uint32_t>(vertex_count * 2);
		const auto origin = static_cast<std::uint16_t>(out.origin_pair);
		const auto far_origin = static_cast<std::uint16_t>(origin + 1);
		out.indices.reserve(edges_.size() * 6);
		bool forward = true;
		for (const auto &edge : edges_) {
			const auto a = static_cast<std::uint16_t>(edge[0] * 2);
			const auto b = static_cast<std::uint16_t>(edge[1] * 2);
			const auto far_a = static_cast<std::uint16_t>(a + 1);
			const auto far_b = static_cast<std::uint16_t>(b + 1);
			if (forward) {
				out.indices.insert(out.indices.end(), {origin, a, b, far_a, far_b, far_origin});
			} else {
				out.indices.insert(out.indices.end(), {far_origin, far_b, far_a, b, a, origin});
			}
			forward = !forward;
		}
	}
};

#if defined(_MSC_VER)
#pragma float_control(pop)
#endif

} // namespace nwn_stock_shadow
