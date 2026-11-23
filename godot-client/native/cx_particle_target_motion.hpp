namespace cx_motion {
using resident::add;
using resident::subtract;

V3 scaled(const V3& v,float factor){return {v[0]*factor,v[1]*factor,v[2]*factor};}
float dot(const V3& a,const V3& b){return (a[0]*b[0]+a[1]*b[1])+a[2]*b[2];}
V3 unit(const V3& v){
 const auto squared=dot(v,v);
 return squared>0?scaled(v,1.0f/std::sqrt(squared)):V3{};
}
V3 nearest_on_segment(const V3& a,const V3& b,const V3& point){
 const auto span=subtract(b,a);
 const auto squared=dot(span,span);
 return squared>0?add(a,scaled(span,std::clamp(dot(subtract(point,a),span)/squared,0.0f,1.0f))):a;
}
void finish_move(Particle& particle,const V3& next,float gravity,float delta){
 particle.position10=add(next,scaled(particle.inheritedDirection24,particle.inheritedSpeed20*delta));
 particle.velocity58[2]+=gravity;
 particle.inheritedSpeed20=std::abs((1.0f-delta)*particle.inheritedSpeed20);
}
void move(Emitter& emitter,Pool& pool,float delta,Services& services){
 if(!(emitter.flags&1)){standard(emitter,pool,delta,services);return;}
 const auto& target=emitter.target;
 if(!target.identity||pool.active.empty())return;
 auto previous=emitter.previousQuaternion178;
 previous[0]=-previous[0];
 const auto turn=multiply(emitter.quaternion1d0,previous);
 const float gravity=emitter.mass*-9.81f*delta;
 const bool wind=(emitter.flags&4)!=0;
 if(emitter.flags&2){
  const auto origin=emitter.position1e0;
  const auto first=add(origin,scaled(axis_z(emitter.quaternion1d0),target.bezier2));
  const auto second=add(target.position,scaled(axis_z(target.orientation),target.bezier3));
  for(auto* particle:pool.active){
   if(particle->stopped70)continue;
   const auto start=carry(*particle,emitter,turn);
   auto ballistic=add(start,scaled(particle->velocity58,delta));
   if(wind)ballistic=add(ballistic,services.wind(ballistic,delta));
   const float t=emitter.lifeExp>0?std::clamp(particle->age/emitter.lifeExp,0.0f,1.0f):1.0f;
   const float u=1.0f-t,tt=t*t;
   const auto curve=add(add(scaled(origin,u*u*u),scaled(first,3.0f*t*u*u)),
                        add(scaled(second,3.0f*tt*u),scaled(target.position,tt*t)));
   const auto weight=std::pow(tt*t,target.combine_time);
   finish_move(*particle,add(scaled(curve,weight),scaled(ballistic,1.0f-weight)),gravity,delta);
  }
 }else{
  const float arrival=target.threshold*target.threshold;
  const float keep=std::pow(std::max(0.0f,target.drag),delta);
  for(auto* particle:pool.active){
   if(particle->stopped70)continue;
   const auto start=carry(*particle,emitter,turn);
   auto next=add(start,scaled(particle->velocity58,delta));
   if(wind)next=add(next,services.wind(next,delta));
   const auto to_target=subtract(target.position,start);
   if(dot(to_target,to_target)<=arrival){particle->age=emitter.lifeExp;continue;}
   const auto push=scaled(unit(to_target),target.gravity*delta);
   next=add(next,scaled(push,delta));
   particle->velocity58=add(scaled(particle->velocity58,keep),push);
   const auto moved=subtract(next,start);
   if(dot(moved,moved)>0)particle->direction4c=unit(moved);
   const auto miss=subtract(target.position,nearest_on_segment(start,next,target.position));
   if(dot(miss,miss)<=arrival)particle->age=emitter.lifeExp;
   finish_move(*particle,next,gravity,delta);
  }
 }
 remember_reference(emitter);
}

V3 perpendicular(const V3& v){
 const auto x=std::abs(v[0]),y=std::abs(v[1]),z=std::abs(v[2]);
 const V3 axis=x<=y&&x<=z?V3{1,0,0}:y<=z?V3{0,1,0}:V3{0,0,1};
 return unit(cross(v,axis));
}
Q4 arc(const V3& previous_direction,const V3& current_direction){
 const auto cosine=dot(previous_direction,current_direction);
 if(cosine>=1.0f-1e-6f)return {1,0,0,0};
 if(cosine<=-1.0f+1e-6f){
  const auto axis=perpendicular(previous_direction);
  return {0,axis[0],axis[1],axis[2]};
 }
 const auto axis=cross(previous_direction,current_direction);
 const float scale=std::sqrt(2.0f*(1.0f+cosine));
 return {scale*0.5f,axis[0]/scale,axis[1]/scale,axis[2]/scale};
}
float jitter(float radius,Services& services){
 const auto range=cvtt(radius*100.0f);
 if(range<=0)return 0.0f;
 const auto sign=(services.random()&1)!=0?1.0f:-1.0f;
 return sign*static_cast<float>(remainder(services.random(),range))*0.01f;
}
void displace_bolt(Pool& pool,size_t lo,size_t hi,const V3& first,const V3& second,float radius,float scale,Services& services){
 // Use the actual inclusive endpoints. For even populations, a symmetric
 // index/span pair can point one past the last particle.
 if(hi-lo<=1)return;
 const size_t middle=lo+(hi-lo)/2;
 auto position=scaled(add(pool.active[lo]->position10,pool.active[hi]->position10),0.5f);
 if(radius>=0.01f){
  position=add(position,scaled(first,jitter(radius,services)*scale));
  position=add(position,scaled(second,jitter(radius,services)*scale));
 }
 pool.active[middle]->position10=position;
 displace_bolt(pool,lo,middle,first,second,radius,scale,services);
 displace_bolt(pool,middle,hi,first,second,radius,scale,services);
}
void seal_bolt(Emitter& emitter,const V3& span){
 auto& target=emitter.target;
 target.previous_bolt_origin=emitter.position1e0;
 target.previous_bolt_span=span;
 target.bolt_ready=true;
}
void lightning(Emitter& emitter,Pool& pool,float delta,Services& services){
 auto& target=emitter.target;
 const auto want=target.identity?std::max(0,cvtt(emitter.birthRate)):0;
 const auto count=static_cast<size_t>(want);
 const bool count_changed=count!=pool.active.size();
 while(pool.active.size()>count){
  auto* particle=pool.active.back();
  pool.retire(pool.active.size()-1);
  if(emitter.chunk)services.detached(particle);
 }
 if(!count){target.bolt_ready=false;target.bolt_elapsed=0;return;}
 while(pool.active.size()<count){
  Particle* particle;
  if(pool.free.empty()){
   particle=pool.create();
   services.created(particle);
  }else{particle=pool.free.back();pool.free.pop_back();}
  *particle=Particle{};
  particle->position10=particle->trail64=emitter.position1e0;
  particle->quaternion34=emitter.quaternion1d0;
  particle->direction4c=axis_z(emitter.quaternion1d0);
  particle->frame44=cvtt(emitter.frameStart);
  if(emitter.chunk)services.initialized(particle,emitter.source.adjustedScale);
  pool.append(particle);
 }
 for(auto* particle:pool.active){
  if(particle->age==particle->field48){particle->age=0;particle->field48=0;}
  particle->age+=delta;
  if(emitter.renderMode1a8==6&&emitter.blurLength>0)blur(*particle,std::min(delta,emitter.blurLength)/emitter.blurLength);
 }
 target.bolt_elapsed+=delta;
 const auto span=subtract(target.position,emitter.position1e0);
 const auto length=std::sqrt(dot(span,span));
 const auto old_length=std::sqrt(dot(target.previous_bolt_span,target.previous_bolt_span));
 if(target.bolt_ready&&!count_changed&&target.bolt_elapsed<=target.bolt_delay&&old_length>0&&length>0){
  const auto direction=scaled(span,1.0f/length);
  const auto turn=arc(scaled(target.previous_bolt_span,1.0f/old_length),direction);
  // Rotate about the previous origin, stretching just the component along
  // the bolt so its endpoint stays attached as the target moves nearer/farther.
  for(auto* particle:pool.active){
   const auto relative=resident::rotate(turn,subtract(particle->position10,target.previous_bolt_origin));
   const auto stretch=scaled(direction,dot(relative,direction)*(length/old_length-1.0f));
   particle->position10=add(emitter.position1e0,add(relative,stretch));
  }
  pool.active.back()->position10=target.position;
  seal_bolt(emitter,span);
  return;
 }
 target.bolt_elapsed=0;
 for(auto* particle:pool.active)particle->position10=emitter.position1e0;
 pool.active.front()->position10=spawn_position(emitter,emitter.source.adjustedScale,services);
 pool.active.back()->position10=target.position;
 const auto axis=unit(subtract(pool.active.front()->position10,target.position));
 if(count>2&&dot(axis,axis)>0){
  const auto first=perpendicular(axis);
  const auto second=cross(axis,first);
  displace_bolt(pool,0,count-1,first,second,target.bolt_radius,emitter.source.adjustedScale,services);
  const auto spacing=length/static_cast<float>(count)*0.5f;
  for(size_t n=1;n+1<count&&spacing>=0.01f;++n)
   pool.active[n]->position10=add(pool.active[n]->position10,scaled(first,jitter(spacing,services)*target.part_scale*target.zigzag));
 }
 seal_bolt(emitter,span);
}
} // namespace cx_motion
