'use strict';
// Compile the actual extracted PairInstances bodies and SelfList template with
// bounded synthetic BVH/provider classes. No source in the engine is edited.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {transform}=require('./pair-reuse.cjs');
const project=path.resolve(__dirname,'../../../..'),base=path.join(project,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/source'),sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const header=fs.readFileSync(path.join(base,'servers/rendering/renderer_scene_cull.h'),'utf8'),source=fs.readFileSync(path.join(base,'servers/rendering/renderer_scene_cull.cpp'),'utf8'),selfList=fs.readFileSync(path.join(base,'core/templates/self_list.h'),'utf8'),candidate=transform(header,source);
function extract(text,signature){const start=text.indexOf(signature);assert(start>=0);let i=text.indexOf('{',start),depth=1;for(i++;depth;i++){if(text[i]==='{')depth++;if(text[i]==='}')depth--;assert(i<text.length);}return text.slice(start,i+1);}
const pairRecord=extract(header,'\tstruct InstancePair {'),baselineBody=extract(header,'\tstruct PairInstances {'),candidateBody=extract(candidate.header,'\tstruct PairInstances {');
let cpp=`#include <array>
#include <cassert>
#include <cstdint>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>
#include <algorithm>
#define _FORCE_INLINE_ inline
#define DEV_ASSERT(x) assert(x)
#define ERR_FAIL_COND(x) do { assert(!(x)); } while (false)
template<class T> struct Comparator { bool operator()(const T &, const T &) const; };
template<class E,class P,P E::* S,E* E::* Prev,E* E::* Next,class C> class SortList { public: void sort(E*&,E*&); };
${selfList.replace(/^#pragma once\s*$/m,'').replace(/^#include .*$/gm,'')}
struct AABB { float lo=0,hi=2; bool intersects(const AABB &o) const {return lo<o.hi && o.lo<hi;} };
struct DynamicBVH {std::vector<void*> values; template<class C> void aabb_query(const AABB &,C &callback){for(void *value:values)callback(value);} };
template<class T> struct PagedAllocator {uint64_t allocated=0,freed=0;T *alloc(){allocated++;return new T;}void free(T *p){freed++;delete p;} };
`;
for(const[namespace,body,reuse]of[['baseline',baselineBody,false],['candidate',candidateBody,true]]){
 cpp+=`
namespace ${namespace} {
struct Cull {
 struct Instance;
 ${pairRecord}
 struct Instance { int id=0,base_type=0; Cull *owner=nullptr; AABB transformed_aabb; SelfList<InstancePair>::List pairs;uint64_t pair_check=0;bool visible=true;
 ${reuse?'uint64_t pair_reuse_pass=0; InstancePair *pair_reuse_candidate=nullptr;':''}
 };
 static void _instance_pair(Instance *a,Instance *b){a->owner->events.push_back("+"+std::to_string(a->id)+","+std::to_string(b->id));}
 static void _instance_unpair(Instance *a,Instance *b){a->owner->events.push_back("-"+std::to_string(a->id)+","+std::to_string(b->id));}
 ${body}
 std::array<Instance,10> nodes;PagedAllocator<InstancePair> allocator;std::vector<std::string> events;uint64_t pass=1,reused=0,fallbacks=0;bool wrapped=false;
 Cull(){for(int i=0;i<10;i++){nodes[i].id=i;nodes[i].owner=this;nodes[i].base_type=i<6?0:1;nodes[i].transformed_aabb={float(i%4),float(i%4+2)};}}
 ~Cull(){for(int i=0;i<10;i++)unpair(i);}
 Instance *other(InstancePair *p,Instance *n){return p->a==n?p->b:p->a;}
 void direct(int a,int b){auto*p=allocator.alloc();p->a=&nodes[a];p->b=&nodes[b];p->a->pairs.add(&p->list_a);p->b->pairs.add(&p->list_b);}
 void unpair(int id){auto*n=&nodes[id];while(n->pairs.first()){auto*p=n->pairs.first()->self();_instance_unpair(n,other(p,n));allocator.free(p);}}
 void repair(int id,const std::vector<int>&query){auto*n=&nodes[id];if(!n->visible)return;pass++;if(pass==0)wrapped=true;DynamicBVH first,second;for(size_t i=0;i<query.size();i++){auto*o=&nodes[query[i]];if(o->visible && o->base_type!=n->base_type)(i%2?second:first).values.push_back(o);}PairInstances pair;pair.instance=n;pair.pair_allocator=&allocator;pair.bvh=&first;pair.bvh2=&second;pair.pair_mask=3;pair.pair_pass=pass;
 ${reuse?'pair.reuse_records=!wrapped;':''}
 pair.pair();
 ${reuse?'reused+=pair.record_reused_count;fallbacks+=pair.reuse_fallback_count;':''}
 }
 std::string snapshot() const {std::ostringstream out;for(const auto&n:nodes){out<<n.id<<":"<<n.pair_check<<":";for(auto*e=n.pairs.first();e;e=e->next()){auto*p=e->self();assert(p->a==&n||p->b==&n);assert(p->list_a.in_list()&&p->list_b.in_list());out<<p->a->id<<","<<p->b->id<<"|";}out<<";";}return out.str();}
 void no_scratch() const {${reuse?'for(const auto&n:nodes){assert(n.pair_reuse_pass==0);assert(n.pair_reuse_candidate==nullptr);}':''}}
}; }
`;
}
cpp+=`
uint32_t state=0x6cf31e2d;uint32_t rnd(){state^=state<<13;state^=state>>17;state^=state<<5;return state;}
uint64_t comparisons=0,allocated_a=0,allocated_b=0,freed_a=0,freed_b=0,reused=0,fallbacks=0;
void equal(baseline::Cull&a,candidate::Cull&b){if(a.events!=b.events || a.snapshot()!=b.snapshot()){std::cerr<<"Mismatch at transition "<<comparisons<<"\\n"<<a.snapshot()<<"\\n"<<b.snapshot()<<"\\n";std::abort();}b.no_scratch();a.events.clear();b.events.clear();comparisons++;}
void account(baseline::Cull&a,candidate::Cull&b){allocated_a+=a.allocator.allocated;allocated_b+=b.allocator.allocated;freed_a+=a.allocator.freed;freed_b+=b.allocator.freed;reused+=b.reused;fallbacks+=b.fallbacks;}
int main(){
 for(int trial=0;trial<100;trial++){baseline::Cull a;candidate::Cull b;for(int step=0;step<150;step++){const int id=rnd()%10,op=rnd()%12;if(op<2){a.unpair(id);b.unpair(id);const bool visible=op==0?!a.nodes[id].visible:true;a.nodes[id].visible=b.nodes[id].visible=visible;}else if(op==2){a.unpair(id);b.unpair(id);}else{float lo=float(rnd()%100)/20,hi=lo+0.1f+float(rnd()%50)/20;a.nodes[id].transformed_aabb=b.nodes[id].transformed_aabb={lo,hi};}
 std::vector<int>query;for(int i=0;i<10;i++)query.push_back(i);for(int i=9;i>0;i--){int j=rnd()%(i+1);std::swap(query[i],query[j]);}if(rnd()%25==0){int value=query[rnd()%query.size()];query.insert(query.begin()+rnd()%query.size(),value);}a.repair(id,query);b.repair(id,query);equal(a,b);}account(a,b);}
 // Opposite A/B orientations, removed relations and repeated query multiplicity.
 for(int mode=0;mode<5;mode++){baseline::Cull a;candidate::Cull b;auto setup=[mode](auto&w){w.nodes[0].transformed_aabb={0,2};w.nodes[6].transformed_aabb={0,1};w.nodes[7].transformed_aabb={9,10};w.nodes[8].transformed_aabb={1,3};if(mode==0){w.direct(6,0);w.direct(0,7);w.direct(8,0);}if(mode==2)w.direct(6,0);if(mode==3){w.direct(0,6);w.direct(6,0);}if(mode==4){w.direct(0,6);w.pass=UINT64_MAX-2;}};setup(a);setup(b);const std::vector<int>q=mode==0?std::vector<int>{8,6,9,7}:std::vector<int>{6,6};for(int i=0;i<(mode==4?5:1);i++){a.repair(0,q);b.repair(0,q);equal(a,b);}account(a,b);}
 // Foreign scratch must survive the fail-closed baseline pass exactly.
 for(bool same:{false,true}){baseline::Cull a;candidate::Cull b;for(int id:{6,7}){a.direct(0,id);b.direct(0,id);a.nodes[id].transformed_aabb=b.nodes[id].transformed_aabb={0,1};}b.nodes[6].pair_reuse_pass=same?2:987;auto*foreign=reinterpret_cast<candidate::Cull::InstancePair*>(uintptr_t(0x1234));b.nodes[6].pair_reuse_candidate=foreign;a.repair(0,{6,7});b.repair(0,{6,7});assert(b.nodes[6].pair_reuse_pass==(same?2u:987u));assert(b.nodes[6].pair_reuse_candidate==foreign);b.nodes[6].pair_reuse_pass=0;b.nodes[6].pair_reuse_candidate=nullptr;equal(a,b);assert(b.fallbacks==1);account(a,b);}
 assert(reused>0&&allocated_b<allocated_a&&freed_b<freed_a);
 std::cout<<"{\\"success\\":true,\\"comparisons\\":"<<comparisons<<",\\"controlAllocated\\":"<<allocated_a<<",\\"candidateAllocated\\":"<<allocated_b<<",\\"controlFreed\\":"<<freed_a<<",\\"candidateFreed\\":"<<freed_b<<",\\"reused\\":"<<reused<<",\\"fallbacks\\":"<<fallbacks<<"}\\n";
}
`;
const label=process.argv[2]??'a';assert(/^[a-z0-9-]+$/.test(label));const out=path.join(project,'.cache/native-render-gap/original/bounds-repair/reuse-cpp-'+label);assert(!fs.existsSync(out),'Keep prior C++ oracle');fs.mkdirSync(out);const file=path.join(out,'pair-reuse-extracted.cpp');fs.writeFileSync(file,cpp,{flag:'wx'});const pins={version:1,scope:'Actual extracted original/patched PairInstances bodies and actual SelfList template; synthetic Instance/AABB/BVH/allocator providers; no full engine/GPU proof.',file,sha256:sha(cpp),source:{headerSha256:sha(header),sourceSha256:sha(source),selfListSha256:sha(selfList),baselinePairBodySha256:sha(baselineBody),candidatePairBodySha256:sha(candidateBody),pairRecordSha256:sha(pairRecord)}};fs.writeFileSync(path.join(out,'source-pins.json'),JSON.stringify(pins,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({out,file,sha256:pins.sha256}));
