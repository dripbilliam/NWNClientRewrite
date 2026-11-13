#pragma once
#include <array>
#include <cmath>
#include <cstddef>
#include <vector>

// Private numeric prototype only. No Godot adapter, scene reads or retained cache.
// All fields are current-call values supplied by a future validated adapter.
// Margin preserves actual Godot4.7.2 parsed literal bits3ecfffffffffd1e2;
// C++ decimal spelling would round to a different value. Pin this compiler observation.
namespace coarse_static_prefix {
struct State { bool pending = false; bool radius_present = false; double radius = 0; };
struct Group {
 bool empty_bounds = false, model_exists = true, model_empty = false, model_error = false;
 std::array<double,4> bounds{}; // min_x,min_y,max_x,max_y; original dictionary scalar precision.
 std::vector<State> states;
};
struct Query { std::array<float,3> from{}, to{}; double radius = 0; };
struct Admission { std::size_t index; double expansion; bool pending; };
struct Result { bool ready = true; std::vector<Admission> rows; };
inline double minimum(double a, double b) { return a < b ? a : b; }
inline double maximum(double a, double b) { return a > b ? a : b; }
inline Result evaluate(const Query &query, const std::vector<Group> &groups) {
 Result result;
 const double min_x=minimum(query.from[0],query.to[0]),max_x=maximum(query.from[0],query.to[0]);
 const double min_y=minimum(query.from[1],query.to[1]),max_y=maximum(query.from[1],query.to[1]);
 for(std::size_t index=0;index<groups.size();++index) {
  const auto &group=groups[index];
  if(group.empty_bounds)continue;
  const bool pending=!group.model_exists||group.model_empty||group.model_error;
  double footprint=pending?12.0:0.0;
  if(!pending)for(const auto &state:group.states) {
   if(state.pending) {result.ready=false;return result;}
   footprint=maximum(footprint,state.radius_present?state.radius:0.0);
  }
  double expansion=footprint+(pending?0.0:query.radius);
  if(!pending) {
   double magnitude=maximum(1.0,footprint);
   for(const double value:group.bounds)magnitude=maximum(magnitude,std::fabs(value));
   expansion+=magnitude*0x1.fffffffffd1e2p-19;
  }
  if(group.bounds[0]>max_x+expansion||group.bounds[2]<min_x-expansion||group.bounds[1]>max_y+expansion||group.bounds[3]<min_y-expansion)continue;
  result.rows.push_back({index,expansion,pending});
 }
 return result;
}
}
