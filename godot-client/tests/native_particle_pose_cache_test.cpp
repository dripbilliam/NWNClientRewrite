// Pure C++ candidate primitive test. Does not prove Godot object/pose integration
// or a rendering speedup. Compile separately; never links the live extension.
#include "../native/experimental/particle_pose_cache.hpp"
#include <cstdio>
#include <limits>
#include <stdexcept>

using Transform=particle_pose_cache::Transform;
using Pose=std::array<float,16>;
std::uint64_t checks=0,failures=0;
void check(bool value,const char* label){++checks;if(!value){++failures;std::fprintf(stderr,"FAIL: %s\n",label);}}
Pose convert(const Transform& raw){
 Pose value{};for(std::size_t n=0;n<raw.size();++n)value[n]=raw[n];
 value[12]=(raw[0]*raw[0]+raw[1]*raw[1])+raw[2]*raw[2];
 value[13]=(raw[3]*raw[3]+raw[4]*raw[4])+raw[5]*raw[5];
 value[14]=(raw[6]*raw[6]+raw[7]*raw[7])+raw[8]*raw[8];
 value[15]=(raw[9]+raw[10])+raw[11];return value;
}
bool same(const Pose& a,const Pose& b){return std::memcmp(a.data(),b.data(),sizeof(a))==0;}
int main(){
 particle_pose_cache::Conversion<Pose> cache;
 Transform raw{1,0,0,0,1,0,0,0,1,8,16,32};
 std::uint64_t calls=0;
 const auto sample=[&](std::uint64_t id,const Transform& input){return cache.read(id,input,[&](const Transform& actual){++calls;return convert(actual);});};
 check(same(sample(7,raw),convert(raw)),"First conversion matches reference words");
 for(int n=0;n<120;++n)check(same(sample(7,raw),convert(raw)),"Unchanged input preserves every output word");
 check(calls==1&&cache.hits==120&&cache.conversions==1,"Unchanged input converts once");
 for(std::size_t n=0;n<raw.size();++n){
  Transform changed=raw;changed[n]=std::nextafter(changed[n],std::numeric_limits<float>::infinity());
  const auto before=calls;check(same(sample(7,changed),convert(changed)),"Any changed transform word matches fresh conversion");
  check(calls==before+1,"Every one of twelve transform words invalidates");
  check(same(sample(7,raw),convert(raw)),"Returning to prior transform does not retain changed output");
 }
 Transform negative=raw;negative[1]=-0.0f;const auto before_zero=calls;
 check(same(sample(7,negative),convert(negative)),"Negative-zero bit is retained");
 check(calls==before_zero+1,"Negative zero invalidates positive-zero cache");
 sample(8,negative);check(calls==before_zero+2,"Same transform under a different identity converts");
 cache.reset();sample(8,negative);check(calls==before_zero+3,"Explicit lifetime reset forces conversion");
 for(float invalid:{std::numeric_limits<float>::infinity(),-std::numeric_limits<float>::infinity(),std::numeric_limits<float>::quiet_NaN()}){
  Transform changed=raw;changed[11]=invalid;const auto before=calls;
  sample(8,changed);sample(8,changed);
  check(calls==before+2&&!cache.valid(),"Nonfinite transforms always execute conversion/diagnostics");
 }
 sample(8,raw);const auto before_throw=calls;
 Transform changed=raw;changed[10]=7;
 volatile bool throw_now=true;
 try{cache.read(8,changed,[&](const Transform& input)->Pose{if(throw_now)throw std::runtime_error("authored conversion error");return convert(input);});check(false,"Authored conversion must throw");}catch(const std::runtime_error&){}
 check(same(sample(8,raw),convert(raw))&&calls==before_throw,"Thrown conversion does not poison prior valid cache");
 std::uint32_t state=0x31e5a67u;
 for(int frame=0;frame<10000;++frame){
  state=state*1664525u+1013904223u;
  const auto id=static_cast<std::uint64_t>(1+(state%8));
  if(frame%3==0){state=state*1664525u+1013904223u;raw[(state>>12)%12]=static_cast<float>(static_cast<int>(state%2049)-1024)/16.0f;}
  check(same(sample(id,raw),convert(raw)),"Random identity/pose stream remains bit-equivalent");
 }
 std::printf("{\"success\":%s,\"checks\":%llu,\"failures\":%llu,\"conversions\":%llu,\"hits\":%llu}\n",failures?"false":"true",static_cast<unsigned long long>(checks),static_cast<unsigned long long>(failures),static_cast<unsigned long long>(cache.conversions),static_cast<unsigned long long>(cache.hits));
 return failures?1:0;
}
