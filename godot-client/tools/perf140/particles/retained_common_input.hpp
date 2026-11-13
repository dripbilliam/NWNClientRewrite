#pragma once
// One synchronous presentation call. Never retains a Dictionary, entity or
// cross-call value. The caller supplies the existing opaque-callback epoch.
#include <cstdint>
#include <utility>
namespace particle_common_input {
template<class Epoch> struct Cache {
 const Epoch* owner=nullptr;
 std::uint64_t epoch=0,reads=0,hits=0;
 bool cached=false,value=false;
 template<class Read> bool get(bool retain,const Epoch* active,bool profile,Read&& read){
  if(retain&&active&&!active->cache_forbidden&&cached&&owner==active&&epoch==active->value){if(profile)++hits;return value;}
  if(profile)++reads;
  // Convert before publishing. A failed truth conversion preserves the
  // ordinary exception and never installs a partially converted value.
  const bool next=std::forward<Read>(read)();
  if(retain&&active&&!active->cache_forbidden){owner=active;epoch=active->value;value=next;cached=true;}
  else cached=false;
  return next;
 }
};
} // namespace particle_common_input
