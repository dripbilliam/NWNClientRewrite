#pragma once

#include <array>
#include <cmath>
#include <cstddef>
#include <limits>

namespace particle_frustum {
// All radii use the same center, planes and rounding. Keep distances already
// evaluated while proceeding from the center to the authored and live bounds.
class Separation {
 const std::array<float,24>& planes_;
 const std::array<float,3>& center_;
 std::size_t next_ = 0;
 float maximum_ = -std::numeric_limits<float>::infinity();
public:
 Separation(const std::array<float,24>& planes, const std::array<float,3>& center) : planes_(planes), center_(center) {}
 std::size_t planes_evaluated() const { return next_ / 4; }
 bool outside(float radius) {
  if (!std::isfinite(radius) || radius < 0.0f) return false;
  const float limit = radius + 0.001f;
  if (maximum_ > limit) return true;
  while (next_ < planes_.size()) {
   const auto at = next_;
   next_ += 4;
   const float distance = (planes_[at]*center_[0] + planes_[at+1]*center_[1]) + planes_[at+2]*center_[2] - planes_[at+3];
   if (distance > maximum_) maximum_ = distance;
   if (distance > limit) return true;
  }
  return false;
 }
};
}
