#pragma once
// Private pure-storage experiment: handles are indexes, never scene pointers or
// owning references. All scene/lease checks remain the caller's responsibility.
#include <atomic>
#include <cstdint>
#include <limits>
#include <type_traits>
#include <unordered_map>
#include <utility>
#include <vector>

namespace nwn_endpoint_slots {
inline std::atomic<std::uint64_t> identities{0};
inline std::uint64_t next_identity() noexcept {
 auto prior=identities.load(std::memory_order_relaxed);
 while(prior!=std::numeric_limits<std::uint64_t>::max()){
  if(identities.compare_exchange_weak(prior,prior+1,std::memory_order_relaxed))return prior+1;
 }
 return 0; // Never allow a newly created cache to reuse an old identity.
}
struct Handle {
 std::uint64_t cache=0,index=0,generation=0,id=0;
 void clear() noexcept {*this={};}
};
template<class Value>struct Slots {
 static_assert(std::is_trivially_copyable_v<Value>&&std::is_trivially_destructible_v<Value>,"Endpoint slots own only callback-free native pose rows");
 struct Slot {Value value{};std::uint64_t id=0,generation=1;bool active=false;};
 std::unordered_map<std::uint64_t,std::size_t> index;
 std::vector<Slot> arena;
 std::vector<std::size_t> free;
 std::uint64_t identity=next_identity(),direct_hits=0,lookups=0,misses=0;
 bool handles_enabled=identity!=0;
 Slots()=default;
 Slots(const Slots&)=delete;
 Slots& operator=(const Slots&)=delete;
 Slots(Slots&&)=delete;
 Slots& operator=(Slots&&)=delete;
 void reserve(std::size_t count){index.reserve(count);arena.reserve(count);free.reserve(count);}
 std::size_t size()const noexcept{return index.size();}
 void reset_counts()noexcept{direct_hits=lookups=misses=0;}
 bool accepts(std::uint64_t id,const Handle& handle)const noexcept {
  if(!handles_enabled||handle.cache!=identity||handle.id!=id||handle.index>=arena.size())return false;
  const auto& slot=arena[static_cast<std::size_t>(handle.index)];
  return slot.active&&slot.id==id&&slot.generation==handle.generation;
 }
 void bind(std::uint64_t id,std::size_t slot,Handle* handle)const noexcept {
  if(!handle)return;
  if(!handles_enabled){handle->clear();return;}
  *handle=Handle{identity,static_cast<std::uint64_t>(slot),arena[slot].generation,id};
 }
 Value* find(std::uint64_t id,Handle* handle=nullptr){
  if(handle&&accepts(id,*handle)){++direct_hits;return &arena[static_cast<std::size_t>(handle->index)].value;}
  ++lookups;const auto found=index.find(id);
  if(found==index.end()){++misses;if(handle)handle->clear();return nullptr;}
  bind(id,found->second,handle);return &arena[found->second].value;
 }
 void insert_or_assign(std::uint64_t id,Value value,Handle* handle=nullptr){
  const auto found=index.find(id);
  if(found!=index.end()){auto& slot=arena[found->second];slot.value=std::move(value);bind(id,found->second,handle);return;}
  const bool appended=free.empty();const auto at=appended?arena.size():free.back();
  if(appended)arena.emplace_back();
  try{index.emplace(id,at);}catch(...){if(appended)arena.pop_back();throw;}
  if(!appended)free.pop_back();
  auto& slot=arena[at];slot.value=std::move(value);slot.id=id;slot.active=true;
  bind(id,at,handle);
 }
 bool erase(std::uint64_t id){
  const auto found=index.find(id);if(found==index.end())return false;
  const auto at=found->second;auto& slot=arena[at];slot.active=false;
  if(slot.generation==std::numeric_limits<std::uint64_t>::max())handles_enabled=false;
  else ++slot.generation;
  // Reset payload before reusing the slot; handles retain no ownership of it.
  slot.value=Value{};slot.id=0;index.erase(found);free.push_back(at);return true;
 }
 void clear(){
  // Rotate before clearing payloads so a reentrant caller can never resolve an
  // old index. Payloads in this experiment are POD pose rows with no callbacks.
  identity=next_identity();handles_enabled=identity!=0;
  index.clear();arena.clear();free.clear();reset_counts();
 }
 std::size_t payload_bytes()const noexcept{return arena.capacity()*sizeof(Slot);}
 std::size_t free_bytes()const noexcept{return free.capacity()*sizeof(std::size_t);}
};
} // namespace nwn_endpoint_slots
