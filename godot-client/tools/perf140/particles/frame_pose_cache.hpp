#pragma once
#include <array>
#include <cmath>
#include <cstdint>
#include <cstddef>
#include <unordered_map>
#include <utility>

// A transient, synchronous read scope. The engine owner still resolves/casts
// every ObjectID before calling read(). No Node pointer is retained here.
namespace nwn_frame_pose {
struct Epoch {
 uint64_t value=1,invalidations=0;bool wrapped=false;
 void invalidate(){++value;++invalidations;if(!value){value=1;wrapped=true;}}
};
inline thread_local Epoch* active_epoch=nullptr;
// Arbitrary script/services may move, reparent, hide or free any scene node.
// Suspend sharing during them and invalidate on both sides, including throws.
struct CallbackBarrier {
 Epoch* prior;
 CallbackBarrier():prior(active_epoch){if(prior)prior->invalidate();active_epoch=nullptr;}
 ~CallbackBarrier(){active_epoch=prior;if(prior)prior->invalidate();}
 CallbackBarrier(const CallbackBarrier&)=delete;
};
template<typename Pose>struct Cache {
 struct Row {uint64_t epoch=0;Pose pose;};
 Epoch epoch;
 std::unordered_map<uint64_t,Row> rows;
 uint64_t hits=0,reads=0,rejected=0;
 size_t reserved=0;
 void begin(size_t expected){
  // Object IDs in rows retire at presentation membership boundaries. Storage
  // survives frame boundaries; epoch prevents any prior-frame pose reuse.
  if(epoch.value==UINT64_MAX||epoch.wrapped){rows.clear();epoch.value=1;epoch.wrapped=false;}else epoch.invalidate();
  epoch.invalidations=0;hits=reads=rejected=0;
  if(expected>reserved){rows.reserve(expected);reserved=expected;}
 }
 void erase(uint64_t id){rows.erase(id);}
 void clear(){rows.clear();reserved=0;hits=reads=rejected=0;}
 template<typename Read,typename Convert>Pose read(uint64_t id,Read&& source,Convert&& convert){
  if(epoch.wrapped){rows.clear();epoch.wrapped=false;}
  const auto found=rows.find(id);
  if(found!=rows.end()&&found->second.epoch==epoch.value){++hits;return found->second.pose;}
  ++reads;const auto raw=source();
  // Preserve the ordinary conversion/error path, without retaining NaN/Inf.
  const auto value=convert(raw);
  bool finite=true;for(const auto word:raw)finite=finite&&std::isfinite(word);
  if(finite)rows.insert_or_assign(id,Row{epoch.value,value});
  else{++rejected;rows.erase(id);}
  return value;
 }
};
}
