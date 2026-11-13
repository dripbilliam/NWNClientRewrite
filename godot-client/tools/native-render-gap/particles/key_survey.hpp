// Private counter probe. No timers, key resolution, allocation or strings in
// the sampled hot counters; names are copied only by the cold dispatch.
namespace particle_key_survey {
constexpr size_t key_capacity=2048,field_capacity=128;
constexpr uint64_t stride=120;
bool enabled=false;
struct State {uint64_t frames=0,samples=0,depth=0,global_overflow=0,field_overflow=0,unknown_fields=0,unknown_maps=0,clip_lookups=0,clip_hits=0;bool active=false;std::array<uint64_t,key_capacity> global{};std::array<uint64_t,field_capacity> fields{},maps{};};
thread_local State state;
struct Frame {
 bool entered=false;
 Frame(){if(!enabled)return;entered=true;auto& s=state;if(s.depth++==0){++s.frames;s.active=(s.frames-1)%stride==0;if(s.active)++s.samples;}}
 ~Frame(){if(entered&&--state.depth==0)state.active=false;}
};
void global(size_t id){if(!enabled||!state.active)return;if(id<key_capacity)++state.global[id];else ++state.global_overflow;}
void field(int id,bool map){if(!enabled||!state.active)return;auto& s=state;if(id<0){if(map)++s.unknown_maps;else ++s.unknown_fields;}else if(static_cast<size_t>(id)<field_capacity){if(map)++s.maps[static_cast<size_t>(id)];else ++s.fields[static_cast<size_t>(id)];}else ++s.field_overflow;}
void clip(bool found){if(!enabled||!state.active)return;++state.clip_lookups;if(found)++state.clip_hits;}
void bind();Var inspect(const Var& input);
}
