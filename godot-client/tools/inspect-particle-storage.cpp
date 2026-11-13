// CPU-only allocation inspection of the actual compiled particle implementation.
// No Godot API is initialized, and no rendering/world connection is performed.
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <new>

namespace allocation_probe {
struct Bucket {size_t size=0,count=0;};
struct Stats {
 size_t allocations=0,frees=0,requested=0,live=0,peak=0;
 Bucket buckets[128]{};
};
struct alignas(std::max_align_t) Header {size_t size;bool tracked;};
bool enabled=false;
Stats stats;
void* allocate(size_t size){
 if(size>static_cast<size_t>(-1)-sizeof(Header))throw std::bad_alloc();
 auto header=static_cast<Header*>(std::malloc(sizeof(Header)+size));
 if(!header)throw std::bad_alloc();
 header->size=size;header->tracked=enabled;
 if(enabled){
  ++stats.allocations;stats.requested+=size;stats.live+=size;
  if(stats.live>stats.peak)stats.peak=stats.live;
  for(auto& bucket:stats.buckets)if(bucket.size==size||bucket.count==0){bucket.size=size;++bucket.count;break;}
 }
 return header+1;
}
void release(void* pointer)noexcept{
 if(!pointer)return;
 auto header=static_cast<Header*>(pointer)-1;
 if(header->tracked){++stats.frees;stats.live-=header->size;}
 std::free(header);
}
void start(){if(stats.live)throw std::bad_alloc();stats={};enabled=true;}
Stats stop(){enabled=false;return stats;}
void print(const char* name,const Stats& value){
 std::printf("\"%s\":{\"allocations\":%zu,\"frees\":%zu,\"requestedBytes\":%zu,\"retainedBytes\":%zu,\"peakBytes\":%zu,\"requestSizes\":[",name,value.allocations,value.frees,value.requested,value.live,value.peak);
 bool first=true;
 for(const auto& bucket:value.buckets)if(bucket.count){std::printf("%s{\"bytes\":%zu,\"count\":%zu}",first?"":",",bucket.size,bucket.count);first=false;}
 std::printf("]}");
}
}
void* operator new(size_t size){return allocation_probe::allocate(size);}
void* operator new[](size_t size){return allocation_probe::allocate(size);}
void operator delete(void* pointer)noexcept{allocation_probe::release(pointer);}
void operator delete[](void* pointer)noexcept{allocation_probe::release(pointer);}
void operator delete(void* pointer,size_t)noexcept{allocation_probe::release(pointer);}
void operator delete[](void* pointer,size_t)noexcept{allocation_probe::release(pointer);}

#include "../native/particle_kernel.cpp"

int main(){
 try{
  namespace r=resident;
  auto emitter=r::Var::dictionary(),providers=r::Var::dictionary();
  r::set(emitter,particle_field::flags,r::Var::integer(0));
  for(const auto field:{particle_field::frameStart,particle_field::randomVelocity,particle_field::xSize,particle_field::ySize,particle_field::spread,particle_field::deadspace,particle_field::velocity})r::set(emitter,field,r::Var::number(0));
  r::set(emitter,particle_field::position1e0,r::array(V3{1,2,3}));
  r::set(emitter,particle_field::quaternion1d0,r::array(Q4{1,0,0,0}));
  // Static schemas and the emitter are deliberately outside particle accounting.
  auto warm=r::create_particle(emitter,0.016f,providers);warm={};
  allocation_probe::Stats empty_container;
  {allocation_probe::start();r::Container unused;empty_container=allocation_probe::stop();}
  if(allocation_probe::stats.live!=0)throw std::runtime_error("Empty container retirement retained a tracked allocation");
  allocation_probe::start();auto particle=r::create_particle(emitter,0.016f,providers);
  const auto one=allocation_probe::stop();
  const auto slot_count=particle.container->slots->values.size();
  size_t vector_count=0;
  for(const auto& field:particle.container->slots->values)if(field.kind==GDEXTENSION_VARIANT_TYPE_ARRAY)++vector_count;
  particle={};if(allocation_probe::stats.live!=0)throw std::runtime_error("Particle retirement retained a tracked allocation");
  constexpr size_t count=4096;
  std::vector<r::Var> particles;particles.reserve(count);
  allocation_probe::start();for(size_t n=0;n<count;++n)particles.push_back(r::create_particle(emitter,0.016f,providers));
  const auto many=allocation_probe::stop();
  particles.clear();if(allocation_probe::stats.live!=0)throw std::runtime_error("Bulk retirement retained a tracked allocation");
  auto reused=r::create_particle(emitter,0.016f,providers);
  allocation_probe::start();for(size_t n=0;n<count;++n)r::initialize_particle(reused,emitter,0.016f,1,providers);
  const auto reset=allocation_probe::stop();
  if(slot_count!=12||vector_count!=6||reset.allocations!=0)throw std::runtime_error("Storage assumptions changed; inspect the source before interpreting results");
  r::compact_particle::Pool compact;compact.owned.reserve(count);
  allocation_probe::start();for(size_t n=0;n<count;++n)compact.create();
  const auto typed=allocation_probe::stop();compact.owned.clear();
  if(allocation_probe::stats.live!=0||typed.allocations!=count||typed.live!=count*sizeof(r::compact_particle::Particle))throw std::runtime_error("Compact storage allocation assumption changed");
  std::printf("{\"success\":true,\"compiler\":%d,\"iteratorDebugLevel\":%d,\"pointerBytes\":%zu,\"varBytes\":%zu,\"containerBytes\":%zu,\"slotsBytes\":%zu,\"particleSlots\":%zu,\"particleVectors\":%zu,\"bulkCount\":%zu,\"rootAndListExcluded\":true,\"heapMetadataExcluded\":true,",_MSC_VER,_ITERATOR_DEBUG_LEVEL,sizeof(void*),sizeof(r::Var),sizeof(r::Container),sizeof(r::Slots),slot_count,vector_count,count);
  allocation_probe::print("emptyContainer",empty_container);std::printf(",");allocation_probe::print("singleParticle",one);std::printf(",");allocation_probe::print("bulkParticles",many);std::printf(",");allocation_probe::print("reinitialize",reset);std::printf(",");allocation_probe::print("compactParticles",typed);std::printf(",\"compactParticleBytes\":%zu,\"compactEmitterBytes\":%zu}\n",sizeof(r::compact_particle::Particle),sizeof(r::compact_particle::Emitter));
  return 0;
 }catch(const std::exception& error){std::fprintf(stderr,"Storage inspection failed: %s\n",error.what());return 1;}
}
