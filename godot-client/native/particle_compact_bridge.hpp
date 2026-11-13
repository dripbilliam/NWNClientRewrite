// Cold configure/frame/diagnostic and actual external-service boundaries.
// Compact simulation/vertices never import/export an individual field here.
namespace compact_particle {
#define COMPACT_FLOAT_FIELDS(X) X(birthRate) X(lifeExp) X(particleRot) X(blurLength) X(velocity) X(randomVelocity) X(frameStart) X(frameEnd) X(xSize) X(ySize) X(spread) X(mass) X(bounceCoefficient) X(sizeStart) X(sizeEnd) X(sizeStartY) X(sizeEndY) X(alphaStart) X(alphaEnd) X(fps) X(deadspace) X(blastRadius) X(blastLength) X(elevationThreshold) X(accumulator198) X(blastLatch1c8)
#define COMPACT_INT_FIELDS(X) X(renderMode1a8) X(loop) X(xGrid) X(yGrid) X(ageMode1cc) X(initialized208) X(detonate108) X(enabled23c)
#define COMPACT_V3_FIELDS(X) X(remaining164) X(position1e0) X(previous19c) X(reference10c) X(colorStart) X(colorEnd)
#define COMPACT_Q4_FIELDS(X) X(quaternion1d0) X(previousQuaternion178) X(referenceQuaternion118)
#define COMPACT_PARTICLE_V3(X) X(position10) X(inheritedDirection24) X(direction4c) X(velocity58) X(trail64)
#define COMPACT_PARTICLE_FLOAT(X) X(rotation1c) X(inheritedSpeed20) X(field48) X(age)
Instance instance_from(const Var& value){Instance out;if(value.nil())return out;out.present=true;
 if(has(value,particle_field::fade))out.fade=f(value,particle_field::fade);if(has(value,particle_field::height50))out.height50=f(value,particle_field::height50);if(has(value,particle_field::opacity70))out.opacity70=f(value,particle_field::opacity70);return out;}
Source source_from(const Var& value){Source out;out.present=!value.nil();if(out.present){out.position=values<3>(get(value,particle_field::position));out.quaternion=values<4>(get(value,particle_field::quaternion));out.adjustedScale=f(value,particle_field::adjustedScale);out.opacity108=f(value,particle_field::opacity108);out.instance=instance_from(get(value,particle_field::instance));}return out;}
void read_emitter(Emitter& out,const Var& value){
#define READ_FLOAT(name) if(has(value,particle_field::name))out.name=f(value,particle_field::name);
 COMPACT_FLOAT_FIELDS(READ_FLOAT)
#undef READ_FLOAT
#define READ_INT(name) if(has(value,particle_field::name))out.name=static_cast<int32_t>(i(value,particle_field::name));
 COMPACT_INT_FIELDS(READ_INT)
#undef READ_INT
#define READ_VECTOR(name) if(has(value,particle_field::name))out.name=values<3>(get(value,particle_field::name));
 COMPACT_V3_FIELDS(READ_VECTOR)
#undef READ_VECTOR
#define READ_QUAT(name) if(has(value,particle_field::name))out.name=values<4>(get(value,particle_field::name));
 COMPACT_Q4_FIELDS(READ_QUAT)
#undef READ_QUAT
 out.flags=static_cast<uint32_t>(i(value,particle_field::flags));out.spawnType=word32(value,particle_field::spawnType);
 if(has(value,particle_field::basis140))out.basis140=values<9>(get(value,particle_field::basis140));
 out.chunk=nonempty_text(get(value,particle_field::chunkName));out.instance=instance_from(get(value,particle_field::instance100));
 out.source=source_from(get(value,particle_field::source50));
}
// Configure imports the full emitter once. Runtime patches and sampled
// channels update exactly their addressed field, never re-import stale
// simulation state from the cold diagnostic/controller shadow.
void apply_emitter_field(Emitter& out,const Var& value,ParticleFieldKey field){
 switch(field.index){
#define APPLY_FLOAT(name) case particle_field::name.index:out.name=f(value,particle_field::name);return;
 COMPACT_FLOAT_FIELDS(APPLY_FLOAT)
#undef APPLY_FLOAT
#define APPLY_INT(name) case particle_field::name.index:out.name=static_cast<int32_t>(i(value,particle_field::name));return;
 COMPACT_INT_FIELDS(APPLY_INT)
#undef APPLY_INT
#define APPLY_VECTOR(name) case particle_field::name.index:out.name=values<3>(get(value,particle_field::name));return;
 COMPACT_V3_FIELDS(APPLY_VECTOR)
#undef APPLY_VECTOR
#define APPLY_QUAT(name) case particle_field::name.index:out.name=values<4>(get(value,particle_field::name));return;
 COMPACT_Q4_FIELDS(APPLY_QUAT)
#undef APPLY_QUAT
 case particle_field::flags.index:out.flags=static_cast<uint32_t>(i(value,particle_field::flags));return;
 case particle_field::spawnType.index:out.spawnType=word32(value,particle_field::spawnType);return;
 case particle_field::basis140.index:out.basis140=values<9>(get(value,particle_field::basis140));return;
 case particle_field::chunkName.index:out.chunk=nonempty_text(get(value,particle_field::chunkName));return;
 case particle_field::instance100.index:out.instance=instance_from(get(value,particle_field::instance100));return;
 case particle_field::source50.index:out.source=source_from(get(value,particle_field::source50));return;
 default:return; // Cold-only metadata remains in its original shadow field.
 }
}
void store_emitter(Var& value,const Emitter& e,bool write_enabled){
 // Only values modified by simulation. Sampled/static values keep their cold
 // source bindings; active/free records are published only on explicit request.
 set_int(value,particle_field::initialized208,e.initialized208);set_int(value,particle_field::detonate108,e.detonate108);if(write_enabled||has(value,particle_field::enabled23c))set_int(value,particle_field::enabled23c,e.enabled23c);
 set_num(value,particle_field::accumulator198,e.accumulator198);set_num(value,particle_field::blastLatch1c8,e.blastLatch1c8);
 set(value,particle_field::remaining164,array(e.remaining164));set(value,particle_field::position1e0,array(e.position1e0));set(value,particle_field::previous19c,array(e.previous19c));set(value,particle_field::reference10c,array(e.reference10c));
 set(value,particle_field::quaternion1d0,array(e.quaternion1d0));set(value,particle_field::previousQuaternion178,array(e.previousQuaternion178));set(value,particle_field::referenceQuaternion118,array(e.referenceQuaternion118));set(value,particle_field::basis140,array(e.basis140));
}
void publish_emitter(EngineVar& value,const Emitter& e,bool write_enabled){
 // Explicit diagnostic output is the only typed-frame publication of mutable
 // simulation fields. No hot-frame dictionary mirroring or vector allocation.
 ::set(value,particle_field::initialized208,EngineVar::integer(e.initialized208));::set(value,particle_field::detonate108,EngineVar::integer(e.detonate108));if(write_enabled||::has(value,particle_field::enabled23c))::set(value,particle_field::enabled23c,EngineVar::integer(e.enabled23c));
 ::set(value,particle_field::accumulator198,EngineVar::number(e.accumulator198));::set(value,particle_field::blastLatch1c8,EngineVar::number(e.blastLatch1c8));
 ::set(value,particle_field::remaining164,::array(e.remaining164));::set(value,particle_field::position1e0,::array(e.position1e0));::set(value,particle_field::previous19c,::array(e.previous19c));::set(value,particle_field::reference10c,::array(e.reference10c));
 ::set(value,particle_field::quaternion1d0,::array(e.quaternion1d0));::set(value,particle_field::previousQuaternion178,::array(e.previousQuaternion178));::set(value,particle_field::referenceQuaternion118,::array(e.referenceQuaternion118));::set(value,particle_field::basis140,::array(e.basis140));
}
Particle particle_from(const Var& value){Particle out;
#define READ_VECTOR(name) out.name=values<3>(get(value,particle_field::name));
 COMPACT_PARTICLE_V3(READ_VECTOR)
#undef READ_VECTOR
#define READ_FLOAT(name) out.name=f(value,particle_field::name);
 COMPACT_PARTICLE_FLOAT(READ_FLOAT)
#undef READ_FLOAT
 out.quaternion34=values<4>(get(value,particle_field::quaternion34));out.frame44=static_cast<int32_t>(i(value,particle_field::frame44));out.stopped70=static_cast<uint32_t>(i(value,particle_field::stopped70));return out;
}
EngineVar publish_particle(const Particle& part){auto out=EngineVar::dictionary();
#define PUBLISH_VECTOR(name) ::set(out,particle_field::name,::array(part.name));
 COMPACT_PARTICLE_V3(PUBLISH_VECTOR)
#undef PUBLISH_VECTOR
#define PUBLISH_FLOAT(name) ::set(out,particle_field::name,EngineVar::number(part.name));
 COMPACT_PARTICLE_FLOAT(PUBLISH_FLOAT)
#undef PUBLISH_FLOAT
 ::set(out,particle_field::quaternion34,::array(part.quaternion34));::set(out,particle_field::frame44,EngineVar::integer(part.frame44));::set(out,particle_field::stopped70,EngineVar::integer(part.stopped70));return out;
}
struct Bridge final:Services {
 Var providers,hit;Var* state;Context* ctx;const Var* resource;bool chunk;
 struct Extra {Var child;bool native_chunk=false;};
 std::unordered_map<Particle*,Extra>* extras;
 Bridge(Var& value,std::unordered_map<Particle*,Extra>& metadata):hit(get(value,particle_field::hit1f0)),state(&value),ctx(context),resource(&get(value,particle_field::chunkName)),chunk(nonempty_text(*resource)),extras(&metadata){if(!ctx)throw std::runtime_error("Compact particle frame context absent");}
 int64_t random()override{return invoke(providers,"random").integer();}
 V3 camera()override{return ctx->camera?*ctx->camera:values<3>(invoke(providers,"cameraPosition"));}
 double cosine(double angle)override{return invoke(providers,"cosineDouble",{Var::number(angle)}).number();}
 V3 wind(const V3& position,float delta)override{return scene_wind::owner(ctx->wind_token).sample(position,delta);}
 void clear_hit()override{set(hit,particle_field::normal,array(V3{}));}
 bool collide(Particle* part,const V3& start,V3& end,V3& normal)override{
  if(chunk){invoke(providers,"resetIgnoredHits",{hit});const auto found=extras->find(part);if(found!=extras->end()&&!found->second.child.nil())invoke(providers,"addIgnoredHit",{hit,found->second.child});}
  if(ctx->direct_scene){using Clock=std::chrono::steady_clock;const auto began=ctx->profile?Clock::now():Clock::time_point{};bool found=false;
   if(direct_scene_trace(ctx->terrain_index,ctx->static_index,start,end,normal,found)){++ctx->direct_queries;ctx->direct_hits+=found?1:0;if(found)set(hit,particle_field::normal,array(normal));if(ctx->profile)ctx->collision_ms+=std::chrono::duration<double,std::milli>(Clock::now()-began).count();return found;}
  }
  auto point=static_cast<Var>(array(end));const bool found=invoke(providers,"collide",{array(start),array(end),point,hit}).boolean();end=values<3>(point);normal=values<3>(get(hit,particle_field::normal));return found;
 }
 void point_wind(const V3& position,float radius,float length)override{invoke(providers,"addPointSourceWind",{array(position),Var::number(radius),Var::number(length),Var::integer(1)});}
 void created(Particle* part)override{
  ++*ctx->allocations;if(!chunk)return;
  auto& extra=(*extras)[part];extra.native_chunk=true;extra.child=invoke(providers,"createChunkModel",{*resource});
  if(!extra.child.nil())invoke(providers,"chunkScene",{extra.child,Var::boolean(true)});
  else if(ctx->missing_chunks){const auto& text=resource->string;const bool null_name=text.size()==4&&(text[0]|32)=='n'&&(text[1]|32)=='u'&&(text[2]|32)=='l'&&(text[3]|32)=='l';if(!null_name)++*ctx->missing_chunks;}
 }
 void initialized(Particle* part,float factor)override{auto found=extras->find(part);if(found==extras->end()||found->second.child.nil())return;const auto& child=found->second.child;invoke(providers,"chunkScene",{child,Var::boolean(true)});invoke(providers,"chunkScale",{child,Var::number(factor),Var::integer(0)});invoke(providers,"chunkPlay",{child,Var::text("impact"),Var::number(1),Var::integer(1),Var::number(0)});}
 void detached(Particle* part)override{auto found=extras->find(part);if(found!=extras->end()&&!found->second.child.nil())invoke(providers,"detachChunk",{found->second.child,Var::integer(0)});}
 void destroyed(Particle* part,int flag)override{auto found=extras->find(part);if(found!=extras->end()){if(!found->second.child.nil())invoke(providers,"destroyChunkModel",{found->second.child,Var::integer(flag)});extras->erase(found);}}
};
void import_pool(Pool& out,std::unordered_map<Particle*,Bridge::Extra>& extras,const Var& state){
 for(const auto name:{particle_field::active188,particle_field::free130}){const bool active=name.index==particle_field::active188.index;const auto owner=get(state,name),records=get(owner,particle_field::records);auto& target=active?out.active:out.free;auto& capacity=active?out.active_capacity:out.free_capacity;capacity=i(owner,particle_field::capacity);if(capacity<0||capacity>32768)throw std::runtime_error("Invalid compact imported particle capacity");target.reserve(static_cast<size_t>(capacity));
  for(int64_t n=0;n<size(records);++n){auto record=at(records,n);auto part=out.create();*part=particle_from(record);target.push_back(part);auto native=field_value(record,"nativeChunky"),child=field_value(record,"chunk78");if(native||child){auto& extra=extras[part];extra.native_chunk=native&&native->boolean();if(child)extra.child=*child;} }
 }
}
EngineVar publish_list(const std::vector<Particle*>& values,int64_t capacity,const std::unordered_map<Particle*,Bridge::Extra>& extras){auto list=EngineVar::dictionary(),records=::array_empty();for(auto part:values){auto record=publish_particle(*part);auto found=extras.find(part);if(found!=extras.end()){if(found->second.native_chunk)::set(record,"nativeChunky",EngineVar::boolean(true));::set(record,"chunk78",found->second.child.publish());}::method(records,"append",{record});}::set(list,particle_field::records,records);::set(list,particle_field::capacity,EngineVar::integer(capacity));return list;}
void render_chunks(const Emitter& e,const Pool& pool,Bridge& bridge){
 if((e.source.present&&e.source.instance.present&&e.source.instance.fade<1)||(e.instance.present&&e.instance.fade<1))return;
 for(auto part:pool.active){auto found=bridge.extras->find(part);if(found==bridge.extras->end()||found->second.child.nil())continue;const auto& child=found->second.child;invoke(bridge.providers,"chunkPosition",{child,array(part->position10)});if(e.particleRot==0||part->stopped70!=0)continue;const auto axis=resident::normalize(part->direction4c);const float angle=part->rotation1c*0.5f,cosine=trig(angle,true),sine=trig(angle,false);invoke(bridge.providers,"chunkOrientation",{child,array(Q4{cosine,axis[0]*sine,axis[1]*sine,axis[2]*sine})});}
}
#undef COMPACT_FLOAT_FIELDS
#undef COMPACT_INT_FIELDS
#undef COMPACT_V3_FIELDS
#undef COMPACT_Q4_FIELDS
#undef COMPACT_PARTICLE_V3
#undef COMPACT_PARTICLE_FLOAT
} // namespace compact_particle
