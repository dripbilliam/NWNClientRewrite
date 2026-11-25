// Authored typed particle state, not an overlay of the proprietary ABI.
// Included inside the native kernel's private namespace. No engine Variant,
// string, map, reference count or separately allocated vector per sprite.
namespace compact_particle {
bool preparation_reuse=false;

struct Particle {
 V3 position10{};float rotation1c=0,inheritedSpeed20=0;
 V3 inheritedDirection24{};Q4 quaternion34{1,0,0,0};
 int32_t frame44=0;float field48=0;
 V3 direction4c{},velocity58{},trail64{};
 uint32_t stopped70=0;float age=0;
};
static_assert(sizeof(Particle)==100,"Compact particle layout grew");
struct Instance {bool present=false;float fade=1,height50=0,opacity70=1;};
struct Source {bool present=false;V3 position{};Q4 quaternion{1,0,0,0};float adjustedScale=1,opacity108=1;Instance instance;};
struct CxTargetMotion {
 uint64_t identity=0;
 V3 position{}, previous_bolt_origin{}, previous_bolt_span{};
 Q4 orientation{1,0,0,0};
 float bezier2=0,bezier3=0,combine_time=0,drag=0,gravity=0,threshold=0;
 float bolt_delay=0,bolt_radius=0,zigzag=0,part_scale=1,bolt_elapsed=0;
 bool bolt_ready=false;
};
struct Emitter {
 uint32_t flags=0,spawnType=0;int32_t renderMode1a8=0,loop=0,xGrid=0,yGrid=0,ageMode1cc=1,initialized208=0,detonate108=0,enabled23c=0;
 float birthRate=0,lifeExp=0,particleRot=0,blurLength=1,velocity=0,randomVelocity=0,frameStart=0,frameEnd=0,xSize=0,ySize=0,spread=0,mass=0,bounceCoefficient=0;
 float sizeStart=0,sizeEnd=0,sizeStartY=0,sizeEndY=0,alphaStart=0,alphaEnd=0,fps=0,deadspace=0,blastRadius=0,blastLength=0,elevationThreshold=5;
 float accumulator198=0,blastLatch1c8=0;V3 remaining164{},position1e0{},previous19c{},reference10c{};
 Q4 quaternion1d0{1,0,0,0},previousQuaternion178{1,0,0,0},referenceQuaternion118{1,0,0,0};
 std::array<float,9> basis140{1,0,0,0,1,0,0,0,1};V3 colorStart{},colorEnd{};
 Q4 prepared_basis_orientation{};
 Source source;Instance instance;bool chunk=false,prepared_basis_valid=false;
 CxTargetMotion target;
};
struct Pool {
 std::vector<std::unique_ptr<Particle>> owned;
 std::vector<Particle*> active,free;
 int64_t active_capacity=0,free_capacity=0;
 Particle* create(){auto value=std::make_unique<Particle>();auto pointer=value.get();owned.push_back(std::move(value));return pointer;}
 static void grow(std::vector<Particle*>& values,int64_t& capacity){
  if(values.size()!=static_cast<size_t>(capacity))return;
  const auto next=capacity==0?16:capacity*2;
  if(next<=capacity||next>2147483647)throw std::runtime_error("Native compact particle list overflow");
  values.reserve(static_cast<size_t>(next));capacity=next;
 }
 void append(Particle* value){if(active.size()>=32768)throw std::runtime_error("Native compact particle allocation limit");grow(active,active_capacity);active.push_back(value);}
 void retire(size_t index){auto value=active.at(index);active.erase(active.begin()+static_cast<ptrdiff_t>(index));grow(free,free_capacity);free.push_back(value);}
 void destroy(Particle* value){auto found=std::find_if(owned.begin(),owned.end(),[&](const auto& item){return item.get()==value;});if(found==owned.end())throw std::runtime_error("Unknown compact particle retirement");owned.erase(found);}
};
// The few actual scene services remain explicit boundaries, just as the
// original calls its RNG, scene, and private child models. No per-field calls.
struct Services {
 virtual ~Services()=default;
 virtual int64_t random()=0;
 virtual V3 camera()=0;
 virtual double cosine(double angle)=0;
 virtual V3 wind(const V3& position,float delta)=0;
 virtual bool collide(Particle* particle,const V3& start,V3& end,V3& normal)=0;
 virtual void clear_hit()=0;
 virtual void point_wind(const V3& position,float radius,float length)=0;
 virtual void created(Particle*)=0;
 virtual void initialized(Particle*,float)=0;
 virtual void detached(Particle*)=0;
 virtual void destroyed(Particle*,int)=0;
};
int64_t remainder(int64_t value,int64_t count){if(!count||(value==INT64_MIN&&count==-1))throw std::runtime_error("Original compact particle remainder invalid");return value%count;}
void inherit_velocity(Particle& part,const Emitter& e,float delta){
 const auto direction=axis_z(e.previousQuaternion178);const float inverse=delta>0?1.0f/delta:0.009999999776482582f;
 V3 d{},velocity{};for(size_t j=0;j<3;++j)d[j]=e.position1e0[j]-part.position10[j];
 const float length=std::sqrt((d[1]*d[1]+d[0]*d[0])+d[2]*d[2]);
 for(size_t j=0;j<3;++j){const float rotational=(length*(e.basis140[6+j]-direction[j]))*inverse,translation=(e.position1e0[j]-e.previous19c[j])*inverse;velocity[j]=j==0?rotational+translation:translation+rotational;}
 const float magnitude=std::sqrt((velocity[0]*velocity[0]+velocity[1]*velocity[1])+velocity[2]*velocity[2]),scale=magnitude==0?0:1.0f/magnitude;
 part.inheritedSpeed20=magnitude;part.inheritedDirection24={};if(magnitude!=0)for(size_t j=0;j<3;++j)part.inheritedDirection24[j]=velocity[j]*scale;
}
Q4 rotation(V3 axis,float angle){axis=resident::normalize(axis);const float cosine=trig(angle,true),sine=trig(angle,false);return {cosine,axis[0]*sine,axis[1]*sine,axis[2]*sine};}
void random_direction(Particle& part,const Emitter& e,Services& service){
 const auto camera=resident::normalize(resident::subtract(part.position10,service.camera()));const float spread=e.spread*0.5f;const int64_t count=1-static_cast<int64_t>(cvtt(spread*-100.0f));
 const float first=(static_cast<float>(remainder(service.random(),count))*0.009999999776482582f)*0.5f;
 auto q=multiply(rotation(V3{e.basis140[0],e.basis140[1],e.basis140[2]},first),part.quaternion34);part.quaternion34=q;
 const float second=(static_cast<float>(remainder(service.random(),628))*0.009999999776482582f)*0.5f;
 q=multiply(rotation(V3{e.basis140[6],e.basis140[7],e.basis140[8]},second),q);part.quaternion34=q;if(e.deadspace==0)return;
 const auto original=q;const auto direction=axis_y(original);float dot=(direction[1]*camera[1]+direction[0]*camera[0])+direction[2]*camera[2];int iterations=0;
 while(std::abs(dot)<service.cosine(1.57079632-static_cast<double>(e.deadspace))){
  if(++iterations>4096)throw std::runtime_error("Original compact particle dead-space failed to converge");
  const float angle=dot>=0?static_cast<float>(static_cast<float>(dot-1.5707963705062866)+e.deadspace):static_cast<float>(static_cast<float>(e.deadspace+1.5707963705062866)-dot);
  q=multiply(rotation(cross(camera,direction),angle*0.5f),original);const auto y=axis_y(q);dot=std::abs((camera[0]*y[0]+camera[1]*y[1])+camera[2]*y[2]);
 }
 part.quaternion34=q;
}
V3 spawn_position(const Emitter& e,float factor,Services& service){
 const auto x_size=cvtt((e.xSize*100.0f)*factor),y_size=cvtt((e.ySize*100.0f)*factor);
 if(x_size==0&&y_size==0)return e.position1e0;
 auto x=x_size>3?remainder(service.random(),cvtt(static_cast<float>(x_size)*0.5f)):0;
 auto y=y_size>3?remainder(service.random(),cvtt(static_cast<float>(y_size)*0.5f)):0;
 const auto flip_x=service.random()%2,flip_y=service.random()%2;if(flip_x>0)x=-x;if(flip_y>0)y=-y;
 const float xf=static_cast<float>(x)*0.00009999999747378752f,yf=static_cast<float>(y)*0.00009999999747378752f;
 V3 position{};
 for(size_t j=0;j<3;++j)position[j]=(xf*e.basis140[j]+e.position1e0[j])+yf*e.basis140[j+3];
 return position;
}
void initialize(Particle& part,const Emitter& e,float delta,float factor,Services& service){
 part.stopped70=0;part.rotation1c=0;part.field48=0;part.age=0;part.quaternion34=e.quaternion1d0;part.inheritedSpeed20=0;part.inheritedDirection24={};part.frame44=cvtt(e.frameStart);
 int64_t jitter=0;if(e.randomVelocity>0.01){jitter=remainder(service.random(),cvtt(e.randomVelocity*100.0f));if(service.random()%2>0)jitter=-jitter;}
 part.position10=spawn_position(e,factor,service);
 part.trail64=part.position10;if(e.flags&128)inherit_velocity(part,e,delta);if(e.spread!=0)random_direction(part,e,service);
 auto direction=axis_z(part.quaternion34);part.direction4c=direction;const float speed=static_cast<float>(jitter)*0.009999999776482582f+e.velocity;
 for(auto& value:direction)value=speed*value;part.velocity58=direction;
}
void randomize(Particle& part,const Emitter& e,Services& service){if(!(e.flags&32))return;const int64_t difference=cvtt(e.frameEnd-e.frameStart),plus=difference+1,count=plus>=0?plus:~difference;if(count)part.frame44=cvtt(static_cast<float>(remainder(service.random(),count))+e.frameStart);}
void rotate(Particle& part,const Emitter& e,float delta){float angle=delta*e.particleRot+part.rotation1c;if(angle>6.2831854820251465f)angle=angle-6.2831854820251465f;else if(angle<-6.2831854820251465f)angle=angle+6.2831854820251465f;part.rotation1c=angle;}
void blur(Particle& part,float blend){const float remain=static_cast<float>(1.0-static_cast<double>(blend));for(size_t j=0;j<3;++j)part.trail64[j]=blend*part.position10[j]+remain*part.trail64[j];}

bool age_particle(Particle& part,const Emitter& emitter,float delta){
 if(emitter.lifeExp>=0&&part.age>=emitter.lifeExp)return false;
 const float age=delta+part.age;part.age=age;
 if(age<0){part.age=0;part.field48=0;}
 return true;
}

void check_life(Emitter& e,Pool& pool,float delta,Services& service){
 for(size_t n=pool.active.size();n>0;--n){auto& part=*pool.active[n-1];
  if(!(e.lifeExp>=0)||!(part.age>=e.lifeExp)){const float age=delta+part.age;part.age=age;if(age<0){part.age=0;part.field48=0;}}
  else{pool.retire(n-1);if(e.chunk)service.detached(&part);}
 }
}

enum class PreparationSchedule { Fountain, Explosion };

void prepare_particles(Emitter& emitter,Pool& pool,float delta,Services& service,PreparationSchedule schedule){
 const bool motion=emitter.renderMode1a8==6;
 const float length=motion?emitter.blurLength:1;
 // Retire separately when retirement can allocate, detach a chunk, or
 // change state before a malformed blur operation throws.
 const auto active_size=pool.active.size();
 const bool retirement_fits=pool.free_capacity-static_cast<int64_t>(pool.free.size())>=static_cast<int64_t>(active_size)&&
     pool.free.capacity()-pool.free.size()>=active_size;
 const bool fuse_life=!emitter.chunk&&(!motion||length!=0)&&(!(emitter.lifeExp>=0)||retirement_fits);
 if(!fuse_life)check_life(emitter,pool,delta,service);
 const bool explosion=schedule==PreparationSchedule::Explosion;
 if(motion&&length==0)throw std::runtime_error(explosion?"Original compact blur length is zero":"Original compact particle blur length is zero");
 const float blend=motion?(explosion?(delta>length?length:delta):(delta<=length?delta:length))/length:0;
 for(size_t n=pool.active.size();n>0;--n){
  auto& part=*pool.active[n-1];
  if(fuse_life&&!age_particle(part,emitter,delta)){pool.retire(n-1);continue;}
  if(motion)blur(part,blend);
  rotate(part,emitter,delta);
 }
}

V3 carry(Particle& particle,const Emitter& emitter,const Q4& turn){
 const auto flags=emitter.flags;
 auto position=particle.position10;
 if(flags&64){
  position=resident::add(resident::rotate(turn,resident::subtract(position,emitter.previous19c)),emitter.position1e0);
  particle.velocity58=resident::rotate(turn,particle.velocity58);
 }
 if((flags&256)&&!(flags&64)&&emitter.source.present){
  const auto shift=resident::subtract(emitter.source.position,emitter.reference10c);
  position=resident::add(position,shift);particle.trail64=resident::add(particle.trail64,shift);
 }
 if(flags&1024){
  const auto shift=resident::subtract(emitter.position1e0,emitter.reference10c);
  position=resident::add(position,shift);particle.trail64=resident::add(particle.trail64,shift);
 }
 return position;
}
void remember_reference(Emitter& emitter){
 if(emitter.source.present&&(emitter.flags&256)){
  emitter.reference10c=emitter.source.position;emitter.referenceQuaternion118=emitter.source.quaternion;
 }else if(emitter.flags&1024){emitter.reference10c=emitter.position1e0;emitter.referenceQuaternion118=emitter.quaternion1d0;}
}
void standard(Emitter& e,Pool& pool,float delta,Services& service){
 if(pool.active.empty())return;const auto flags=e.flags;const bool bounce=(flags&16)!=0;
 const bool clear_each_particle=bounce||(flags&4)!=0;bool cleared_hit=false;
 auto previous=e.previousQuaternion178;previous[0]=previous[0]*-1.0f;const auto turn=multiply(e.quaternion1d0,previous);
 for(auto pointer:pool.active){auto& part=*pointer;if(part.stopped70!=0)continue;const auto old=part.position10;const auto position=carry(part,e,turn);
  const float inherited=part.inheritedSpeed20;V3 moved{};
  for(size_t j=0;j<3;++j){const float travel=delta*part.velocity58[j],carried=(inherited*part.inheritedDirection24[j])*delta;moved[j]=j==0?(travel+position[j])+carried:carried+(travel+position[j]);}
  if(flags&4)moved=resident::add(moved,service.wind(position,delta));part.position10=moved;
  const float damped=static_cast<float>(1.0-static_cast<double>(delta))*part.inheritedSpeed20;part.inheritedSpeed20=damped;part.velocity58[2]=part.velocity58[2]-(e.mass*9.8100004196167f)*delta;if(damped<0)part.inheritedSpeed20=damped*-1.0f;
  // With no wind or bounce, no scene service can observe the repeated clears.
  if(clear_each_particle||!cleared_hit){service.clear_hit();cleared_hit=true;}
  if(!bounce)continue;V3 normal{};
  if(!service.collide(&part,old,part.position10,normal))continue;
  float squared=0;if(e.bounceCoefficient==0)part.velocity58={};else{
   const auto before=part.velocity58;const float dot=(before[0]*normal[0]+before[1]*normal[1])+before[2]*normal[2];V3 reflected{};
   for(size_t j=0;j<3;++j)reflected[j]=((normal[j]*-2.0f)*dot+before[j])*0.75f;
   const float damp=std::max(0.5f,std::min(1.0f,delta!=0?0.032999999821186066f/delta:INFINITY));reflected[2]=(reflected[2]*e.bounceCoefficient)*damp;part.velocity58=reflected;squared=(reflected[0]*reflected[0]+reflected[1]*reflected[1])+reflected[2]*reflected[2];
  }
  if(squared<0.5f){part.stopped70=1;part.quaternion34=resident::rotation_arc(V3{0,0,1},normal);part.direction4c=normal;auto offset=normal;for(auto& value:offset)value=value*0.019999999552965164f;part.position10=resident::add(part.position10,offset);if(e.chunk){offset=normal;for(auto& value:offset)value=e.sizeStart*value;part.position10=resident::add(part.position10,offset);}}
 }
 remember_reference(e);
}
Particle* create(Emitter& e,Pool& pool,float delta,Services& service){auto part=pool.create();initialize(*part,e,delta,1,service);service.created(part);return part;}
Particle* spawn(Emitter& e,Pool& pool,float delta,float factor,Services& service){
 Particle* part;if(pool.free.empty())part=create(e,pool,delta,service);else{part=pool.free.back();pool.free.pop_back();}
 initialize(*part,e,delta,e.chunk?1:factor,service);service.initialized(part,factor);pool.append(part);randomize(*part,e,service);return part;
}
#include "cx_particle_target_motion.hpp"
void fountain(Emitter& e,Pool& pool,float delta,Services& service){
 const float rate=e.birthRate;e.enabled23c=!(0>=rate);const float factor=e.source.present?e.source.adjustedScale:1;
 if(preparation_reuse)prepare_particles(e,pool,delta,service,PreparationSchedule::Fountain);
 else{
  check_life(e,pool,delta,service);
  if(e.renderMode1a8==6){const float length=e.blurLength;if(length==0)throw std::runtime_error("Original compact particle blur length is zero");const float blend=(delta<=length?delta:length)/length;for(size_t n=pool.active.size();n>0;--n)blur(*pool.active[n-1],blend);}
  for(size_t n=pool.active.size();n>0;--n)rotate(*pool.active[n-1],e,delta);
 }
 cx_motion::move(e,pool,delta,service);const auto rate_int=cvtt(rate);if(rate_int<=0)return;const float interval=1.0f/rate;
 if(e.spawnType==0){e.accumulator198=delta+e.accumulator198;if(!(e.accumulator198>=interval))return;int64_t n=0;while(n<remainder(cvtt(rate*e.accumulator198),static_cast<int64_t>(rate_int)+1)){if(n>=32768)throw std::runtime_error("Compact particle birth limit");spawn(e,pool,delta,factor,service);++n;}e.accumulator198=0;return;}
 V3 displacement{},direction{};for(size_t j=0;j<3;++j)displacement[j]=(e.position1e0[j]-e.previous19c[j])+e.remaining164[j];const float length=std::sqrt((displacement[1]*displacement[1]+displacement[0]*displacement[0])+displacement[2]*displacement[2]),inverse=length>0?1.0f/length:0;for(size_t j=0;j<3;++j)direction[j]=displacement[j]*inverse;
 const auto count=e.enabled23c!=0?cvtt(length*rate):0;if(count>32768)throw std::runtime_error("Compact spatial particle birth limit");
 for(int64_t n=0;n<count;++n){auto part=spawn(e,pool,delta,factor,service);for(size_t j=0;j<3;++j)part->position10[j]=pool.active.size()<2?e.position1e0[j]-direction[j]*length:(e.previous19c[j]-e.remaining164[j])+direction[j]*(static_cast<float>(n+1)*interval);}
 const float emitted=static_cast<float>(count)*interval;for(size_t j=0;j<3;++j)e.remaining164[j]=e.enabled23c!=0?displacement[j]-direction[j]*emitted:0;
}
void explosion(Emitter& e,Pool& pool,float delta,Services& service){
 const auto count=cvtt(e.birthRate);const float factor=e.source.present?e.source.adjustedScale:1;
 if(preparation_reuse)prepare_particles(e,pool,delta,service,PreparationSchedule::Explosion);
 else{
  check_life(e,pool,delta,service);
  const bool motion=e.renderMode1a8==6;const float length=motion?e.blurLength:1;if(motion&&length==0)throw std::runtime_error("Original compact blur length is zero");const float blend=motion?(delta>length?length:delta)/length:0;
  for(size_t n=pool.active.size();n>0;--n){auto& part=*pool.active[n-1];if(motion)blur(part,blend);rotate(part,e,delta);}
 }
 cx_motion::move(e,pool,delta,service);
 if(count!=0&&e.detonate108!=0&&1>e.blastLatch1c8){if(e.blastRadius!=0)service.point_wind(e.position1e0,e.blastRadius,e.blastLength);if(count>32768)throw std::runtime_error("Compact explosion birth limit");
  for(int64_t n=0;n<std::max(0,count);++n){const bool reuse=!pool.free.empty();Particle* part;if(reuse){part=pool.free.back();pool.free.pop_back();}else part=create(e,pool,delta,service);const float scale=reuse?1:factor;initialize(*part,e,delta,e.chunk?1:scale,service);service.initialized(part,scale);pool.append(part);randomize(*part,e,service);}
 }
 e.blastLatch1c8=e.detonate108!=0?1.0f:0.0f;e.detonate108=0;
}
void single(Emitter& e,Pool& pool,float delta,Services& service){
 if(cvtt(e.birthRate)==0){if(!pool.active.empty()){auto part=pool.active.front();pool.active.erase(pool.active.begin());service.destroyed(part,1);pool.destroy(part);}return;}
 if(pool.active.empty()){auto part=create(e,pool,delta,service);pool.append(part);randomize(*part,e,service);return;}
 auto& part=*pool.active.front();const float age=delta+part.age,life=e.lifeExp;part.age=age;if(!(life>0)){if(age<0)part.age=0;}else if(age>life&&e.loop!=0)part.age=0;rotate(part,e,delta);
 if(e.renderMode1a8==6){const float length=e.blurLength;if(length==0)throw std::runtime_error("Original compact blur length is zero");blur(part,(delta>length?length:delta)/length);}cx_motion::move(e,pool,delta,service);
}
void animate(Emitter& e,Pool& pool,float delta,const V3& position,const Q4& quaternion,int kind,Services& service){
 delta=std::min(0.5f,delta);if(e.source.present&&e.source.instance.present&&1>e.source.instance.fade)return;if(e.instance.present&&1>e.instance.fade)return;
 V3 shift{};if((e.flags&256)&&e.source.present&&e.initialized208!=0)shift=resident::subtract(e.source.position,e.reference10c);
 if(e.initialized208==0){e.position1e0=position;e.quaternion1d0=quaternion;if(e.source.present&&(e.flags&0x500)){e.reference10c=e.source.position;e.referenceQuaternion118=e.source.quaternion;}if(e.flags&1024){e.reference10c=e.position1e0;e.referenceQuaternion118=e.quaternion1d0;}e.initialized208=1;}
 e.previous19c=(e.flags&256)?resident::add(shift,e.position1e0):e.position1e0;e.previousQuaternion178=e.quaternion1d0;if(e.source.present){e.position1e0=position;e.quaternion1d0=quaternion;}
 const bool reuse_basis=preparation_reuse&&e.prepared_basis_valid&&
     std::memcmp(e.prepared_basis_orientation.data(),e.quaternion1d0.data(),sizeof(float)*e.quaternion1d0.size())==0;
 if(!reuse_basis){
  const auto x=axis_x(e.quaternion1d0),y=axis_y(e.quaternion1d0),z=axis_z(e.quaternion1d0);
  e.basis140={x[0],x[1],x[2],y[0],y[1],y[2],z[0],z[1],z[2]};
  if(preparation_reuse){
   e.prepared_basis_orientation=e.quaternion1d0;
   e.prepared_basis_valid=std::all_of(e.quaternion1d0.begin(),e.quaternion1d0.end(),[](float value){return std::isfinite(value);});
  }
 }
 if(kind==0)fountain(e,pool,delta,service);else if(kind==1)explosion(e,pool,delta,service);else if(kind==2)single(e,pool,delta,service);else if(kind==3)cx_motion::lightning(e,pool,delta,service);else throw std::runtime_error("Unknown compact particle schedule");
}
} // namespace compact_particle
