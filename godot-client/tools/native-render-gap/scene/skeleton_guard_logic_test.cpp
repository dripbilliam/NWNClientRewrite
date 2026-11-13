#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <memory>
#include <vector>

using RID=int;
struct Vector3 { float words[3]{}; float &operator[](int i){return words[i];} const float &operator[](int i)const{return words[i];} float x=0,y=0,z=0; };
struct Basis {Vector3 rows[3];};
struct Transform3D {Basis basis;Vector3 origin;};
static int checks=0,failures=0;
static void check(bool okay,const char *label){++checks;if(!okay){++failures;std::cerr<<"FAIL "<<label<<"\n";}}
static bool exact(const std::vector<float>&a,const std::vector<float>&b){return a.size()==b.size()&&std::memcmp(a.data(),b.data(),a.size()*sizeof(float))==0;}
static float from_bits(std::uint32_t value){float f;std::memcpy(&f,&value,sizeof f);return f;}
static Transform3D matrix(const std::array<std::uint32_t,12>&values){Transform3D t;for(int r=0;r<3;++r){for(int c=0;c<3;++c)t.basis.rows[r][c]=from_bits(values[static_cast<std::size_t>(r*4+c)]);}t.origin.x=from_bits(values[3]);t.origin.y=from_bits(values[7]);t.origin.z=from_bits(values[11]);return t;}
struct FloatData:std::vector<float>{float*ptr(){return data();}};
struct Skeleton {int size=0;bool use_2d=false,dirty=false;FloatData data;std::vector<float>gpu;std::uint64_t uploads=0,versions=0,bytes=0;};
struct Owner {std::vector<std::unique_ptr<Skeleton>>items;Skeleton*get_or_null(int id){return id<0||static_cast<std::size_t>(id)>=items.size()?nullptr:items[static_cast<std::size_t>(id)].get();}};
struct Storage {
 Owner skeleton_owner;int errors=0;std::vector<Skeleton*>queue;
 int allocate(int bones,bool two_d=false){auto item=std::make_unique<Skeleton>();item->size=bones;item->use_2d=two_d;item->data.assign(static_cast<std::size_t>(bones*(two_d?8:12)),0.0f);item->gpu.assign(item->data.size(),from_bits(0xcdcdcdcdu));auto*p=item.get();skeleton_owner.items.push_back(std::move(item));if(bones)_skeleton_make_dirty(p);return static_cast<int>(skeleton_owner.items.size()-1);}
 void reallocate(int id,int bones){auto*s=skeleton_owner.get_or_null(id);s->size=bones;s->data.assign(static_cast<std::size_t>(bones*12),0.0f);s->gpu.assign(s->data.size(),from_bits(0xcdcdcdcdu));if(bones)_skeleton_make_dirty(s);}
 void _skeleton_make_dirty(Skeleton*s){if(!s->dirty){s->dirty=true;queue.push_back(s);}}
 void drain(){for(auto*s:queue){if(s->size){s->gpu=s->data;++s->uploads;s->bytes+=s->data.size()*sizeof(float);}++s->versions;s->dirty=false;}queue.clear();}
};
#define ERR_FAIL_NULL(s) do{if(!(s)){++errors;return;}}while(false)
#define ERR_FAIL_INDEX(i,n) do{if((i)<0||(i)>=(n)){++errors;return;}}while(false)
#define ERR_FAIL_COND(c) do{if(c){++errors;return;}}while(false)
struct BaselineStorage:Storage{void skeleton_bone_set_transform(RID,int,const Transform3D&);};
struct CandidateStorage:Storage{void skeleton_bone_set_transform(RID,int,const Transform3D&);};
struct NumericEqualityStorage:Storage{void skeleton_bone_set_transform(RID,int,const Transform3D&);};
#include "extracted-setters.inc"
struct Pair {
 BaselineStorage a;CandidateStorage b;
 int allocate(int n,bool two_d=false){int id=a.allocate(n,two_d);check(id==b.allocate(n,two_d),"Same allocation IDs");return id;}
 void same(){check(a.skeleton_owner.items.size()==b.skeleton_owner.items.size(),"Owner size");for(std::size_t i=0;i<a.skeleton_owner.items.size();++i)check(exact(a.skeleton_owner.items[i]->data,b.skeleton_owner.items[i]->data),"Exact CPU words");check(a.errors==b.errors,"Same validation errors");}
 void set(int id,int bone,const Transform3D&t){a.skeleton_bone_set_transform(id,bone,t);b.skeleton_bone_set_transform(id,bone,t);same();}
 void drain(){a.drain();b.drain();same();for(std::size_t i=0;i<a.skeleton_owner.items.size();++i){check(exact(a.skeleton_owner.items[i]->gpu,b.skeleton_owner.items[i]->gpu),"Exact GPU words after resource drain");check(!a.skeleton_owner.items[i]->dirty&&!b.skeleton_owner.items[i]->dirty,"Both dirty queues drained");}}
};
int main(){
 std::array<std::uint32_t,12>words{};auto zero=matrix(words);
 Pair p;const int id=p.allocate(65);p.set(id,0,zero);
 check(p.b.skeleton_owner.get_or_null(id)->dirty&&p.b.queue.size()==1,"Initial equal zero keeps allocated GPU upload dirty");p.drain();
 for(int bone=0;bone<65;++bone)p.set(id,bone,zero);
 check(p.b.queue.empty(),"Equal65bone buffer creates no new upload");p.drain();
 auto*as=p.a.skeleton_owner.get_or_null(id);auto*bs=p.b.skeleton_owner.get_or_null(id);
 check(as->uploads==2&&bs->uploads==1,"Unchanged buffer suppresses upload/version only below public callbacks");
 for(int i=0;i<12;++i){words[static_cast<std::size_t>(i)]=0x3f800000u+static_cast<std::uint32_t>(i);p.set(id,31,matrix(words));check(bs->dirty,"Every changed GPU word dirties");p.drain();}
 auto old_uploads=bs->uploads;p.set(id,31,matrix(words));p.drain();check(bs->uploads==old_uploads,"Identical changed matrix skips later upload");
 words[3]=0x80000000u;p.set(id,31,matrix(words));p.drain();check(std::signbit(bs->data[31*12+3]),"Negative zero stored exactly");
 words[3]=0;p.set(id,31,matrix(words));check(bs->dirty,"Positive zero differs bitwise");p.drain();
 for(auto payload:{0x7fc01234u,0x7fc01235u,0x7fa01234u,0x7f800000u,0xff800000u}){words[4]=payload;p.set(id,31,matrix(words));p.drain();old_uploads=bs->uploads;p.set(id,31,matrix(words));p.drain();check(bs->uploads==old_uploads,"Repeated exact NaN/Inf payload preserves words without new upload");}
 words[6]=0x40000000u;p.set(id,3,matrix(words));words[6]=0;p.set(id,3,matrix(words));check(bs->dirty&&p.b.queue.size()==1,"Changed then changed back preserves already queued upload");p.drain();
 check(bs->bytes==bs->uploads*65u*12u*sizeof(float),"One changed bone still uploads entire65bone buffer");
 p.a.reallocate(id,2);p.b.reallocate(id,2);p.set(id,0,zero);check(bs->dirty,"Reallocation equal zero keeps fresh buffer dirty");p.drain();
 p.set(-1,0,zero);p.set(id,-1,zero);p.set(id,2,zero);const int empty=p.allocate(0);p.set(empty,0,zero);const int two=p.allocate(2,true);p.set(two,0,zero);p.drain();check(p.a.errors==5,"Original RID/index/2D preconditions preserved");
 std::uint32_t rng=0x1400db32u;for(int sample=0;sample<4096;++sample){for(auto&w:words){rng^=rng<<13;rng^=rng>>17;rng^=rng<<5;w=rng;}p.set(id,sample%2,matrix(words));if(sample%3==0)p.set(id,sample%2,matrix(words));if(sample%7==0)p.drain();}p.drain();
 NumericEqualityStorage bad;const int bad_id=bad.allocate(1);bad.drain();std::array<std::uint32_t,12>signed_words{};signed_words[3]=0x80000000u;bad.skeleton_bone_set_transform(bad_id,0,matrix(signed_words));
 auto*bad_s=bad.skeleton_owner.get_or_null(bad_id);check(!std::signbit(bad_s->data[3])&&!bad_s->dirty,"Negative control detects numeric equality dropping signed-zero publication");
 std::cout<<"{\"success\":"<<(failures==0?"true":"false")<<",\"checks\":"<<checks<<",\"failures\":"<<failures<<",\"baselineUploads\":"<<as->uploads<<",\"candidateUploads\":"<<bs->uploads<<",\"gpu\":false,\"scope\":\"Actual extracted before/after RD setter bodies with allocation and resource-queue stubs; not engine/GPU/FPS acceptance\"}\n";
 return failures?1:0;
}
