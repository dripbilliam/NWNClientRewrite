// Standalone arithmetic bound for NWN-74. No Godot or rendering process is launched.
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <vector>
struct Key { uint64_t vertex; uint32_t framebuffer,cull,primitive,version,flags,p0,p1,p2,wireframe,ubershader; };
static inline uint32_t murmur32(uint32_t x,uint32_t h=0x7F07C65){x*=0xcc9e2d51; x=(x<<15)|(x>>17); x*=0x1b873593; h^=x; h=(h<<13)|(h>>19); return h*5+0xe6546b64;}
static inline uint32_t hash(const Key &k){uint32_t h=murmur32((uint32_t)k.vertex); h=murmur32((uint32_t)(k.vertex>>32),h); h=murmur32(k.framebuffer,h); h=murmur32(k.cull,h); h=murmur32(k.primitive,h); h=murmur32(k.version,h); h=murmur32(k.flags,h); h=murmur32(k.p0,h); h=murmur32(k.p1,h); h=murmur32(k.p2,h); h=murmur32(k.wireframe,h); h=murmur32(k.ubershader,h); h^=h>>16; h*=0x85ebca6b; h^=h>>13; h*=0xc2b2ae35; return h^(h>>16);}
static inline bool equal(const Key&a,const Key&b){return a.vertex==b.vertex&&a.framebuffer==b.framebuffer&&a.cull==b.cull&&a.primitive==b.primitive&&a.version==b.version&&a.flags==b.flags&&a.p0==b.p0&&a.p1==b.p1&&a.p2==b.p2&&a.wireframe==b.wireframe&&a.ubershader==b.ubershader;}
struct Draw { Key key; uint32_t shader; };
static volatile uint64_t sink;
static double run(const std::vector<Draw>&draws,bool candidate,int rounds){uint64_t checksum=0; auto start=std::chrono::steady_clock::now(); for(int r=0;r<rounds;r++){Key prevKey={}; uint32_t prevShader=~0u,prevHash=0; bool valid=false; for(const auto &d:draws){bool same=candidate&&valid&&d.shader==prevShader&&equal(d.key,prevKey); uint32_t h=same?prevHash:hash(d.key); if(d.shader!=prevShader||h!=prevHash){prevShader=d.shader;prevHash=h;if(candidate){prevKey=d.key;valid=true;} checksum+=h;} else checksum+=(h&1);}} sink=checksum; auto end=std::chrono::steady_clock::now(); return std::chrono::duration<double,std::nano>(end-start).count()/(draws.size()*rounds);}
int main(){for(int period: {16,2,1}){std::vector<Draw> d; d.reserve(3054); for(int i=0;i<3054;i++){int variant=i/period; Key k={uint64_t(variant+11),1,2,3,4,5,6,7,8,0,0}; d.push_back({k,0});} double oldBest=1e9,newBest=1e9; for(int x=0;x<5;x++){double a=run(d,false,1500),b=run(d,true,1500); if(a<oldBest)oldBest=a;if(b<newBest)newBest=b;} std::printf("period=%d draws=%zu old_ns=%.3f candidate_ns=%.3f ratio=%.3f\n",period,d.size(),oldBest,newBest,newBest/oldBest);} return 0;}
