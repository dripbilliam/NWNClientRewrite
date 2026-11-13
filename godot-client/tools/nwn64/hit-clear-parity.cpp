// Pure data regression, using extracted unchanged resident storage helpers and
// both frozen full compact headers. No Godot/client/renderer process or FPS.
#include "../../.cache/nwn64/unit-support.hpp"
namespace old=original::compact_particle;
namespace next=candidate::compact_particle;
static int checks=0,failures=0;
static void check(bool value,const char* message){++checks;if(!value){++failures;std::cerr<<message<<'\n';}}
template<class Base,class Particle>struct Probe final:Base{
 resident::Var hit=resident::Var::dictionary();bool allow=true,throw_clear=false;uint64_t clears=0;std::vector<int> events;std::function<void()> observer;
 Probe(){resident::set(hit,particle_field::normal,resident::array(V3{1.0f,-0.0f,0.5f}));}
 bool can_coalesce_hit_clears()const{return allow&&!observer&&!throw_clear&&bridge_can_coalesce(hit);}
 void clear_hit()override{++clears;events.push_back(1);if(throw_clear)throw std::runtime_error("authored clear failure");resident::set(hit,particle_field::normal,resident::array(V3{}));if(observer)observer();}
 int64_t random()override{events.push_back(2);return 1234;}
 V3 camera()override{return {2,3,4};}
 double cosine(double v)override{return std::cos(v);}
 V3 wind(const V3& p,float delta)override{events.push_back(3);return {p[1]*delta,-0.2f*delta,0.1f*delta};}
 bool collide(Particle*,const V3&,V3& end,V3& normal)override{events.push_back(4);normal={0,0,1};if(end[2]>=0)return false;end[2]=0;return true;}
 void point_wind(const V3&,float,float)override{events.push_back(5);}
 void created(Particle*)override{events.push_back(6);}
 void initialized(Particle*,float)override{events.push_back(7);}
 void detached(Particle*)override{events.push_back(8);}
 void destroyed(Particle*,int)override{events.push_back(9);}
};
using OldProbe=Probe<old::Services,old::Particle>;
using NewProbe=Probe<next::Services,next::Particle>;
static void compare_case(size_t count,uint32_t flags,bool chunk,bool stopped,int shape,float delta){
 old::Emitter a{};a.flags=flags;a.chunk=chunk;a.mass=0.3f;a.bounceCoefficient=0.4f;a.sizeStart=0.1f;a.source.present=true;a.source.position={0.1f,-0.3f,0.7f};a.reference10c={0.2f,0.3f,-0.1f};a.position1e0={0.4f,0.1f,-0.2f};a.previous19c={0.1f,-0.4f,0.3f};a.quaternion1d0={0.5f,0.5f,0.5f,0.5f};
 next::Emitter b;static_assert(sizeof(a)==sizeof(b));static_assert(std::is_trivially_copyable_v<old::Emitter>&&std::is_trivially_copyable_v<next::Emitter>);std::memcpy(&b,&a,sizeof(a));
 old::Pool ap;next::Pool bp;
 for(size_t i=0;i<count;++i){auto* p=ap.create();p->position10={float(i)*0.03f,-0.5f,float(i%3)*-0.2f};p->trail64={0.1f,0.2f,0.3f};p->velocity58={0.4f,-0.3f,0.7f};p->inheritedSpeed20=0.13f;p->inheritedDirection24={0.2f,0.3f,-0.1f};p->stopped70=stopped||i%7==6;ap.append(p);auto* q=bp.create();static_assert(sizeof(*p)==sizeof(*q));std::memcpy(q,p,sizeof(*p));bp.append(q);}
 OldProbe before;NewProbe after;resident::Var alias_a,alias_b;
 if(shape==1){alias_a=resident::get(before.hit,particle_field::normal);alias_b=resident::get(after.hit,particle_field::normal);check(!bridge_can_coalesce(after.hit),"Aliased normal must keep scalar clear path");}
 if(shape==2){auto p=resident::field_value(before.hit,particle_field::normal);resident::generic_array(*p->container);auto q=resident::field_value(after.hit,particle_field::normal);resident::generic_array(*q->container);check(!bridge_can_coalesce(after.hit),"Generic normal must keep scalar clear path");}
 if(shape==3){before.hit=resident::Var::integer(17);after.hit=resident::Var::integer(17);check(!bridge_can_coalesce(after.hit),"Malformed hit record must keep original failure boundary");}
 if(shape==4){before.allow=false;after.allow=false;before.observer=[&](){a.mass+=0.01f;};after.observer=[&](){b.mass+=0.01f;};}
 if(shape==5){before.allow=false;after.allow=false;before.throw_clear=true;after.throw_clear=true;}
 bool failed_a=false,failed_b=false;try{old::standard(a,ap,delta,before);}catch(const std::exception&){failed_a=true;}try{next::standard(b,bp,delta,after);}catch(const std::exception&){failed_b=true;}
 check(failed_a==failed_b,"Matching failure result");check(std::memcmp(&a,&b,sizeof(a))==0,"Exact emitter state bytes");
 check(ap.active.size()==bp.active.size()&&ap.free.size()==bp.free.size(),"Pool cardinality unchanged");
 for(size_t i=0;i<count;++i)check(std::memcmp(ap.owned[i].get(),bp.owned[i].get(),sizeof(old::Particle))==0,"Exact particle bytes including exception/early return");
 const bool coalesced=count>=4&&(flags&(4|16))==0&&!chunk&&shape==0&&!stopped;
 check(after.clears==(coalesced?1:before.clears),"Exact private-clear reduction or preserved general calls");
 if(!coalesced)check(before.events==after.events,"General service observer order remains exact");
 if(shape==1){const auto av=resident::values<3>(alias_a),bv=resident::values<3>(alias_b);check(std::memcmp(av.data(),bv.data(),sizeof(V3))==0,"Published resident alias retains original bytes");check(av[0]==1.0f&&std::signbit(av[1]),"COW alias is not cleared or sign-normalized");}
 if(shape!=3){const auto av=resident::values<3>(resident::get(before.hit,particle_field::normal)),bv=resident::values<3>(resident::get(after.hit,particle_field::normal));check(std::memcmp(av.data(),bv.data(),sizeof(V3))==0,"Exact private hit normal bytes");}
}
int main(){
 for(const size_t count:{0U,1U,3U,4U,16U,64U})for(const uint32_t flags:{0U,32U,64U,256U,1024U,64U|256U,128U|32U|256U,4U,16U,4U|16U})for(const bool chunk:{false,true})for(const bool stopped:{false,true})for(int shape=0;shape<6;++shape)for(float delta:{0.0f,1.0f/60.0f,-0.002f,0.5f})compare_case(count,flags,chunk,stopped,shape,delta);
 std::cout<<"{\"success\":"<<(failures?"false":"true")<<",\"checks\":"<<checks<<",\"failures\":"<<failures<<",\"scope\":\"Exact frozen compact arithmetic and real resident alias/COW shape guards; custom service observations and first-clear failures; no engine/FPS acceptance\"}\n";return failures?1:0;
}
