#pragma once
#include <cstdint>

// Versioned private engine/extension POD contract. No Godot containers,
// retained scene pointers, function-address integers or script memory access.
namespace nwn_particle_scene_direct_v1 {
constexpr uint64_t fingerprint(uint32_t pointer_bytes,uint32_t real_bytes,uint32_t transform_bytes) {
 return UINT64_C(0x4e57010000000000)|(uint64_t(pointer_bytes)<<24)|(uint64_t(real_bytes)<<16)|transform_bytes;
}
constexpr uint64_t expected_fingerprint=fingerprint(8,4,48);
constexpr const char* abi_name="nwn_particle_scene_direct_abi_v1";
constexpr const char* eligibility_name="nwn_particle_scene_direct_eligibility_v1";
constexpr const char* transform_name="nwn_particle_scene_direct_transform_v1";
enum Flags : uint64_t { EXISTS=1,NODE3D=2,INSIDE=4,VISIBLE=8,PROCESSABLE=16,SOURCE_EXISTS=32,UNSUPPORTED=UINT64_C(1)<<30 };
enum Status : int32_t { OK=0,ABSENT=1,WRONG_TYPE=2,UNSUPPORTED_THREAD=3,UNSUPPORTED_PRECISION=4,BAD_DESTINATION=5 };
using Abi=uint64_t (*)();
// Source ID is inspected only when check_source!=0 AND eligibility succeeds.
using Eligibility=uint64_t (*)(uint64_t id,uint64_t source_id,uint32_t check_source);
// Exactly one current getter, copied into caller-owned 12-float storage.
using Transform=int32_t (*)(uint64_t id,float* destination,uint32_t capacity);
}
