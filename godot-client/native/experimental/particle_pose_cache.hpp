#pragma once
// Exact-input conversion reuse. Cache conversion, never the live scene read.
// The caller must resolve/validate its Node3D and fetch its current Transform3D
// on EVERY use, including cache hits. No Node pointer or scene ownership lives
// here; each emitter endpoint keeps its own cache and retires it with its owner.
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <utility>

namespace particle_pose_cache {
using Transform=std::array<float,12>;
template<class Pose> class Conversion {
 bool valid_=false;
 std::uint64_t identity_=0;
 Transform input_{};
 Pose output_{};
public:
 std::uint64_t hits=0,conversions=0;
 template<class Convert> Pose read(std::uint64_t identity,const Transform& current,Convert&& convert){
  static_assert(sizeof(Transform)==48,"Expected single-precision Godot Transform3D words");
  if(valid_&&identity_==identity&&std::memcmp(input_.data(),current.data(),sizeof(current))==0){++hits;return output_;}
  // Convert first: a thrown conversion must not install a partially updated
  // cache. Nonfinite transforms keep the old diagnostic/conversion path live.
  auto result=std::forward<Convert>(convert)(current);
  bool finite=true;for(float word:current)finite=finite&&std::isfinite(word);
  input_=current;output_=result;identity_=identity;valid_=finite;++conversions;
  return result;
 }
 void reset(){valid_=false;identity_=0;}
 bool valid()const{return valid_;}
};
} // namespace particle_pose_cache
