// Persistent C++ state. The shared simulation/draw bodies below run against
// these private native containers, never a Godot Dictionary per particle field.
// Engine values cross only configure/frame/explicit debug-snapshot boundaries.
// Containers preserve reference identity (active/free list recycling); scalar
// values are unboxed C++ doubles/integers. This is not the original ABI layout.
using EngineVar=Var;
GDExtensionInterfaceClassdbConstructObject3 construct_object;
GDExtensionInterfaceObjectSetInstance set_instance;
GDExtensionInterfaceStringToUtf8Chars string_utf8;
GDExtensionInterfaceObjectGetInstanceFromId instance_from_id;
GDExtensionInterfaceClassdbGetMethodBind class_method;
GDExtensionInterfaceObjectMethodBindPtrcall ptrcall;
GDExtensionInterfaceClassdbGetClassTag class_tag;
GDExtensionInterfaceObjectCastTo cast_object;
GDExtensionInterfaceVariantGetPtrGetter member_getter;
GDExtensionMethodBindPtr node_transform;
void* node_tag;
GDExtensionPtrBuiltInMethod basis_orthonormal,basis_quaternion,basis_scale;
GDExtensionPtrGetter transform_basis,transform_origin,basis_columns[3];
struct EnginePose {V3 position{};Q4 quaternion{};float scale=1,maximum_scale=1;};
EnginePose read_engine_pose(uint64_t id){
 auto object=instance_from_id(id);if(!object||!cast_object(object,node_tag))throw std::runtime_error("Native particle pose owner is absent or no longer Node3D");
 alignas(8) std::array<float,12> transform{};alignas(8) std::array<float,9> basis{},orthonormal{};alignas(8) V3 origin{},scale{};alignas(8) std::array<float,4> q{};
 ptrcall(node_transform,object,nullptr,transform.data());transform_basis(transform.data(),basis.data());transform_origin(transform.data(),origin.data());basis_orthonormal(basis.data(),nullptr,orthonormal.data(),0);basis_quaternion(orthonormal.data(),nullptr,q.data(),0);basis_scale(basis.data(),nullptr,scale.data(),0);
 EnginePose result;result.position={origin[0],-origin[2],origin[1]};result.quaternion={q[3],q[0],-q[2],q[1]};result.scale=scale[0];
 float maximum=0;for(auto getter:basis_columns){V3 column{};getter(basis.data(),column.data());maximum=std::max(maximum,std::sqrt((column[0]*column[0]+column[1]*column[1])+column[2]*column[2]));}result.maximum_scale=maximum;return result;
}
std::string engine_string(const EngineVar& value){
 if(value.type()==GDEXTENSION_VARIANT_TYPE_STRING_NAME){EngineVar text;destroy(text.data);const GDExtensionConstVariantPtr args[]={value.data};GDExtensionCallError error{};construct(GDEXTENSION_VARIANT_TYPE_STRING,text.data,args,1,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Native owner StringName conversion failed");return engine_string(text);}
 if(value.type()!=GDEXTENSION_VARIANT_TYPE_STRING)throw std::runtime_error("Native owner name must be String");
 alignas(8) uint8_t raw[8];to[GDEXTENSION_VARIANT_TYPE_STRING](raw,const_cast<uint8_t*>(value.data));
 const auto length=string_utf8(raw,nullptr,0);std::string text(static_cast<size_t>(length),'\0');if(length)string_utf8(raw,text.data(),length);ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING)(raw);return text;
}
namespace resident {
#include "particle_records.hpp"
struct Container;
struct Var {
 GDExtensionVariantType kind=GDEXTENSION_VARIANT_TYPE_NIL;
 double real=0;int64_t whole=0;std::string string;
 std::shared_ptr<Container> container;
 std::shared_ptr<EngineVar> engine;
 Var()=default;
 Var(const EngineVar& value,int depth=0);
 static Var number(double n){Var v;v.kind=GDEXTENSION_VARIANT_TYPE_FLOAT;v.real=n;return v;}
 static Var integer(int64_t n){Var v;v.kind=GDEXTENSION_VARIANT_TYPE_INT;v.whole=n;return v;}
 static Var boolean(bool n){Var v;v.kind=GDEXTENSION_VARIANT_TYPE_BOOL;v.whole=n?1:0;return v;}
 static Var text(const char* n){Var v;v.kind=GDEXTENSION_VARIANT_TYPE_STRING;v.string=n;return v;}
 static Var dictionary();
 static Var opaque(const EngineVar& value){Var out;out.kind=value.type();out.engine=std::make_shared<EngineVar>(value);return out;}
 GDExtensionVariantType type()const{return kind;}
 bool nil()const{return kind==GDEXTENSION_VARIANT_TYPE_NIL;}
 double number()const{if(kind==GDEXTENSION_VARIANT_TYPE_FLOAT)return real;if(kind==GDEXTENSION_VARIANT_TYPE_INT)return static_cast<double>(whole);throw std::runtime_error("Native owner numeric value required");}
 int64_t integer()const{if(kind!=GDEXTENSION_VARIANT_TYPE_INT)throw std::runtime_error("Native owner integer required");return whole;}
 bool boolean()const{return kind==GDEXTENSION_VARIANT_TYPE_BOOL?whole!=0:number()!=0;}
 EngineVar publish(int depth=0)const;
};
struct Slots {const RecordSchema* schema;std::vector<Var> values;uint64_t present=0;explicit Slots(const RecordSchema* value):schema(value),values(value->names.size()){if(values.size()>64)throw std::runtime_error("Native record schema exceeds slot mask");}};
struct Container {std::unordered_map<std::string,Var> fields;std::vector<Var> items;std::unique_ptr<Slots> slots;};
Var* field_value(const Var& v,const char* field,bool create=false){
 if(v.kind!=GDEXTENSION_VARIANT_TYPE_DICTIONARY)throw std::runtime_error("Native owner record required");auto& container=*v.container;const auto id=field_index(field);
 if(id>=0){
  if(!container.slots&&create)container.slots=std::make_unique<Slots>(primary_schema(id));
  if(container.slots){auto& slots=*container.slots;const auto offset=slots.schema->offsets[static_cast<size_t>(id)];if(offset>=0){const auto bit=uint64_t{1}<<offset;if(!(slots.present&bit)){if(!create)return nullptr;slots.present|=bit;}return &slots.values[static_cast<size_t>(offset)];}}
 }
 auto found=container.fields.find(field);if(found!=container.fields.end())return &found->second;return create?&container.fields[field]:nullptr;
}
const Var& field_ref(const Var& v,const char* field){const auto value=field_value(v,field);if(!value)throw std::runtime_error(std::string("Missing native owner field: ")+field);return *value;}
Var Var::dictionary(){Var v;v.kind=GDEXTENSION_VARIANT_TYPE_DICTIONARY;v.container=std::make_shared<Container>();return v;}
Var array_empty(){Var v;v.kind=GDEXTENSION_VARIANT_TYPE_ARRAY;v.container=std::make_shared<Container>();return v;}
Var key(const char* field){return Var::text(field);}
Var get(const Var& v,const char* field){return field_ref(v,field);}
void set(Var& v,const char* field,const Var& value){*field_value(v,field,true)=value;}
Var at(const Var& v,int64_t n){if(v.kind!=GDEXTENSION_VARIANT_TYPE_ARRAY||n<0||static_cast<uint64_t>(n)>=v.container->items.size())throw std::runtime_error("Native owner array index invalid");return v.container->items[static_cast<size_t>(n)];}
int64_t size(const Var& v){if(v.kind!=GDEXTENSION_VARIANT_TYPE_ARRAY)throw std::runtime_error("Native owner array required");return static_cast<int64_t>(v.container->items.size());}
void put_index(Var& v,int64_t n,const Var& value){if(n<0||n>=size(v))throw std::runtime_error("Native owner array write invalid");v.container->items[static_cast<size_t>(n)]=value;}
template<size_t N>struct NumericArray {
 std::array<float,N> values;
 operator Var()const{auto out=array_empty();out.container->items.reserve(N);for(auto value:values)out.container->items.push_back(Var::number(value));return out;}
};
template<size_t N>NumericArray<N> array(const std::array<float,N>& source){return {source};}
template<size_t N>void set(Var& record,const char* field,const NumericArray<N>& value){
 auto& destination=*field_value(record,field,true);
 // Reuse only exclusively owned storage. An aliased controller/record value
 // keeps replacement semantics, so cached channels and snapshots stay intact.
 if(destination.kind==GDEXTENSION_VARIANT_TYPE_ARRAY&&destination.container.use_count()==1&&destination.container->items.size()==N){for(size_t n=0;n<N;++n)destination.container->items[n]=Var::number(value.values[n]);}
 else destination=static_cast<Var>(value);
}
template<size_t N>std::array<float,N> values(const Var& v){if(size(v)<static_cast<int64_t>(N))throw std::runtime_error("Native owner vector is incomplete");std::array<float,N> out{};for(size_t n=0;n<N;++n)out[n]=static_cast<float>(v.container->items[n].number());return out;}
float f(const Var& v,const char* field){return static_cast<float>(field_ref(v,field).number());}
int64_t i(const Var& v,const char* field){const auto n=field_ref(v,field).number();if(!std::isfinite(n)||n<-2147483648.0||n>2147483647.0)throw std::runtime_error("Native owner signed field out of range");return static_cast<int64_t>(n);}
uint32_t word32(const Var& v,const char* field){const auto n=field_ref(v,field).number();if(!std::isfinite(n)||std::trunc(n)!=n||n<-2147483648.0||n>4294967295.0)throw std::runtime_error("Native owner word out of range");return static_cast<uint32_t>(static_cast<int64_t>(n));}
Var method(Var& object,const char* name,std::initializer_list<Var> arguments={}){
 const auto arg=[&](size_t n)->const Var&{if(n>=arguments.size())throw std::runtime_error("Native owner method argument absent");return *(arguments.begin()+n);};
 if(object.kind==GDEXTENSION_VARIANT_TYPE_STRING&&std::strcmp(name,"length")==0)return Var::integer(static_cast<int64_t>(object.string.size()));
 if(object.kind==GDEXTENSION_VARIANT_TYPE_DICTIONARY&&std::strcmp(name,"has")==0)return Var::boolean(field_value(object,arg(0).string.c_str())!=nullptr);
 if(object.kind!=GDEXTENSION_VARIANT_TYPE_ARRAY)throw std::runtime_error(std::string("Unsupported native owner method: ")+name);
 auto& list=object.container->items;
 if(std::strcmp(name,"size")==0)return Var::integer(static_cast<int64_t>(list.size()));
 if(std::strcmp(name,"resize")==0){const auto n=arg(0).integer();if(n<0||n>1048576)throw std::runtime_error("Native owner array capacity invalid");list.resize(static_cast<size_t>(n));return {};}
 if(std::strcmp(name,"append")==0){list.push_back(arg(0));return {};}
 if(std::strcmp(name,"remove_at")==0){const auto n=arg(0).integer();if(n<0||static_cast<uint64_t>(n)>=list.size())throw std::runtime_error("Native owner removal invalid");list.erase(list.begin()+n);return {};}
 if(std::strcmp(name,"pop_back")==0||std::strcmp(name,"pop_front")==0){if(list.empty())throw std::runtime_error("Native owner free list empty");const bool back=std::strcmp(name,"pop_back")==0;auto value=back?list.back():list.front();if(back)list.pop_back();else list.erase(list.begin());return value;}
 throw std::runtime_error(std::string("Unsupported native owner array method: ")+name);
}
Var::Var(const EngineVar& value,int depth){
 if(depth>128)throw std::runtime_error("Native owner import nesting exceeded");kind=value.type();
 if(kind==GDEXTENSION_VARIANT_TYPE_NIL)return;
 if(kind==GDEXTENSION_VARIANT_TYPE_INT){whole=value.integer();return;}
 if(kind==GDEXTENSION_VARIANT_TYPE_FLOAT){real=value.number();return;}
 if(kind==GDEXTENSION_VARIANT_TYPE_BOOL){whole=value.boolean()?1:0;return;}
 if(kind==GDEXTENSION_VARIANT_TYPE_STRING){string=engine_string(value);return;}
 if(kind==GDEXTENSION_VARIANT_TYPE_ARRAY){container=std::make_shared<Container>();auto copy=value;const auto count=::size(copy);if(count>1048576)throw std::runtime_error("Native owner import exceeds capacity");container->items.reserve(static_cast<size_t>(count));for(int64_t n=0;n<count;++n)container->items.emplace_back(::at(value,n),depth+1);return;}
 if(kind==GDEXTENSION_VARIANT_TYPE_DICTIONARY){container=std::make_shared<Container>();auto copy=value;auto names=::method(copy,"keys");const auto count=::size(names);for(int64_t n=0;n<count;++n){const auto name=engine_string(::at(names,n));set(*this,name.c_str(),Var(::get(value,name.c_str()),depth+1));}return;}
 engine=std::make_shared<EngineVar>(value);
}
EngineVar Var::publish(int depth)const{
 if(depth>128)throw std::runtime_error("Native owner snapshot nesting exceeded");
 if(engine)return *engine;
 switch(kind){
 case GDEXTENSION_VARIANT_TYPE_NIL:return {};
 case GDEXTENSION_VARIANT_TYPE_FLOAT:return EngineVar::number(real);
 case GDEXTENSION_VARIANT_TYPE_INT:return EngineVar::integer(whole);
 case GDEXTENSION_VARIANT_TYPE_BOOL:return EngineVar::boolean(whole!=0);
 case GDEXTENSION_VARIANT_TYPE_STRING:return EngineVar::text(string.c_str());
 case GDEXTENSION_VARIANT_TYPE_ARRAY:{auto out=::array_empty();for(const auto& value:container->items)::method(out,"append",{value.publish(depth+1)});return out;}
 case GDEXTENSION_VARIANT_TYPE_DICTIONARY:{auto out=EngineVar::dictionary();if(container->slots){const auto& slots=*container->slots;for(size_t n=0;n<slots.values.size();++n)if(slots.present&(uint64_t{1}<<n))::set(out,slots.schema->names[n],slots.values[n].publish(depth+1));}for(const auto& field:container->fields)::set(out,field.first.c_str(),field.second.publish(depth+1));return out;}
 default:if(engine)return *engine;throw std::runtime_error("Native owner export has no engine value");
 }
}
struct Context {Var* state=nullptr;const EngineVar* providers=nullptr;Var pose;int64_t* allocations=nullptr;const V3* camera=nullptr;bool direct_scene=false,profile=false;uint64_t terrain_index=0,static_index=0,direct_queries=0,direct_hits=0;double collision_ms=0;};
thread_local Context* context=nullptr;
struct ContextScope {Context* prior;explicit ContextScope(Context& next):prior(context){context=&next;}~ContextScope(){context=prior;}};
Var create_particle(const Var& e,float delta,const Var& p);
void initialize_particle(Var& part,const Var& e,float delta,float factor,const Var& p);
void randomize_frame(const Var& e,Var& part,const Var& p);
Var invoke(const Var& p,const char* name,std::initializer_list<Var> arguments={}){
 if(!context||!context->state||!context->providers)throw std::runtime_error("Native owner callback outside frame");
 const auto arg=[&](size_t n)->Var{if(n>=arguments.size())throw std::runtime_error("Native owner callback argument absent");return *(arguments.begin()+n);};
 if(std::strcmp(name,"sourceFactor")==0)return get(arg(0),"adjustedScale");
 if(std::strcmp(name,"globalTransform")==0)return context->pose;
 if(std::strcmp(name,"cameraPosition")==0&&context->camera)return array(*context->camera);
 if(std::strcmp(name,"createParticle")==0){if(arg(0).boolean())throw std::runtime_error("Native owner chunk service is unsupported");++*context->allocations;return create_particle(*context->state,static_cast<float>(arg(1).number()),p);}
 if(std::strcmp(name,"initializeParticle")==0){auto part=arg(0);initialize_particle(part,*context->state,static_cast<float>(arg(1).number()),static_cast<float>(arg(2).number()),p);return {};}
 if(std::strcmp(name,"randomizeParticle")==0){auto part=arg(1);randomize_frame(*context->state,part,p);return {};}
 if(std::strcmp(name,"reserveActive")==0||std::strcmp(name,"reserveFree")==0||std::strcmp(name,"destroyParticle")==0)return {};
 if(std::strcmp(name,"clearHit")==0){auto hit=arg(0);set(hit,"normal",array(V3{}));return {};}
 if(std::strcmp(name,"collide")==0&&context->direct_scene){
  using Clock=std::chrono::steady_clock;const auto began=context->profile?Clock::now():Clock::time_point{};
  const auto start=values<3>(arg(0));auto goal=values<3>(arg(1));V3 normal{};bool found=false;
  if(direct_scene_trace(context->terrain_index,context->static_index,start,goal,normal,found)){
   ++context->direct_queries;context->direct_hits+=found?1:0;
   if(found){auto point=arg(2),hit=arg(3);const auto converted=static_cast<Var>(array(goal));point.container->items=converted.container->items;set(hit,"normal",array(normal));}
   if(context->profile)context->collision_ms+=std::chrono::duration<double,std::milli>(Clock::now()-began).count();
   return Var::boolean(found);
  }
 }
 auto callable=::get(*context->providers,name);std::vector<EngineVar> exported;exported.reserve(arguments.size());for(const auto& value:arguments)exported.push_back(value.publish());std::vector<GDExtensionConstVariantPtr> args;for(const auto& value:exported)args.push_back(value.data);
 Name call("call");EngineVar out;destroy(out.data);GDExtensionCallError error{};variant_call(callable.data,call.data,args.data(),static_cast<GDExtensionInt>(args.size()),out.data,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error(std::string("Native owner external service failed: ")+name);
 // Scene collision has two output parameters. Import only those small values,
 // preserving private particle/list identity rather than exporting whole state.
 // Misses may still update CHitInfo; keep that mutation just like the GD owner.
 if(std::strcmp(name,"collide")==0){auto point=arg(2),hit=arg(3);Var position(exported[2]);point.container->items=position.container->items;set(hit,"normal",Var(::get(exported[3],"normal")));}
 return Var(out);
}
#define NWN_PARTICLE_RESIDENT
#include "particle_simulation.hpp"
#undef NWN_PARTICLE_RESIDENT
// The draw body returns this already-owned engine packet without importing and
// re-exporting its byte arrays/dictionary through native simulation containers.
struct ParticleStreams: ::ParticleStreams {Var finish(int64_t count){return Var::opaque(::ParticleStreams::finish(count));}};
#include "particle_vertices.hpp"
struct Channel {
 std::string property,target;std::vector<float> storage;
 uint16_t rows=0,time_base=0,value_base=0;uint8_t flags=0;int components=0;
 bool constant=false,cached=false;Var cached_value;
 Var* state_value=nullptr;Var* parameter_value=nullptr;
 float read(size_t index)const{if(index>=storage.size())throw std::runtime_error("Native emitter controller value storage absent");return storage[index];}
 static float bezier(float a,float b,float c,float d,float time){const float u=static_cast<float>(1.0-static_cast<double>(time));const float middle=u*c+d*time,left=((u*a+c*time)*u)+middle*time,right=((u*d+b*time)*time)+middle*u;return left*u+right*time;}
 Var sample(float time)const{
  if(!rows||!std::isfinite(time))throw std::runtime_error("Invalid native emitter sampling clock");size_t index=0;float t=1;
  while(index<rows&&time>read(static_cast<size_t>(time_base)+index))++index;
  if(index!=0&&index!=rows)t=(time-read(time_base+index-1))/(read(time_base+index)-read(time_base+index-1));
  const auto base=static_cast<size_t>(value_base);size_t highest=base+components-1;
  if(index>0)highest=(flags&16)?base+(index-1)*(components==1?3:9)+(components==1?4:14):base+(std::min<size_t>(index,rows-1)+1)*components-1;
  if(highest>=storage.size())throw std::runtime_error("Native emitter Bezier endpoint requires unavailable original value storage");
  if((flags&15)!=components)throw std::runtime_error("Native emitter component width mismatch");
  std::array<float,3> output{};
  for(int axis=0;axis<components;++axis){
   const auto offset=static_cast<size_t>(axis);
   if(index==0)output[offset]=read((base+offset)&65535);
   else if(components==1){
    if((flags&240)==16){const auto at=((index-1)*3+base)&65535;const auto a=read(at),c=read(at+2);output[0]=index==rows?bezier(a,read(at+3),c,read(at+4),time):bezier(a,a+read(at+3),c,c+read(at+4),t);}
    else output[0]=index==rows?read(base+rows-1):(1.0f-t)*read(base+index-1)+t*read(base+index);
   }else if((flags&240)==16){const auto at=((index-1)*9+base)&65535;const auto a=read(at+offset),b=read(at+9+offset);output[offset]=bezier(a,b,a+read(at+6+offset),b+read(at+12+offset),t);}
   else{const auto at=((index-1)*3+base)&65535;const auto a=read((at+offset)&65535);output[offset]=index==rows?a:read((at+offset+3)&65535)*t+(1.0f-t)*a;}
  }
  if(property.rfind("percent",0)==0||property=="detonate"){uint32_t bits;std::memcpy(&bits,output.data(),4);return Var::integer(bits&255);}
  return components==1?Var::number(output[0]):array(output);
 }
};
std::vector<float> float_storage(EngineVar pool){
 if(pool.type()==GDEXTENSION_VARIANT_TYPE_ARRAY){std::vector<float> out;const auto count=::size(pool);if(count>1048576)throw std::runtime_error("Native controller pool too large");out.reserve(static_cast<size_t>(count));for(int64_t n=0;n<count;++n)out.push_back(static_cast<float>(::at(pool,n).number()));return out;}
 if(pool.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY)throw std::runtime_error("Native controller pool must be float32");
 auto bytes=::method(pool,"to_byte_array");alignas(8) uint8_t raw[16];to[GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY](raw,bytes.data);const auto length=::method(bytes,"size").integer();std::vector<float> out(static_cast<size_t>(length)/4);if(length)std::memcpy(out.data(),packed_index(raw,0),static_cast<size_t>(length));ptr_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(raw);return out;
}
struct Owner {
 Var state,parameters=Var::dictionary();std::unordered_map<std::string,std::vector<Channel>> clips;
 ParticleStreams staging;int kind=-1;int64_t allocations=0,constant_hits=0,sampled_channels=0;bool configured=false,use_parameters=false,cache_constants=true;
 uint64_t pose_id=0,source_id=0;
 struct View {int64_t stamp=-1;std::array<float,24> planes{};V3 position{};Q4 camera{};};
 static const View& view(const EngineVar& packet){
  static thread_local View cached;const auto stamp=::get(packet,"stamp").integer();if(stamp==cached.stamp)return cached;
  View next;next.stamp=stamp;next.position=::values<3>(::get(packet,"position"));next.camera=::values<4>(::get(packet,"camera"));
  auto bytes=::get(packet,"planes");if(bytes.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY||::method(bytes,"size").integer()!=96)throw std::runtime_error("Native view requires six complete planes");
  alignas(8) uint8_t raw[16];to[GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY](raw,bytes.data);std::memcpy(next.planes.data(),packed_index(raw,0),96);ptr_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(raw);
  for(auto number:next.planes)if(!std::isfinite(number))throw std::runtime_error("Native view plane is non-finite");cached=next;return cached;
 }
 bool outside(const View& camera,const V3& center,float radius)const{
  if(!std::isfinite(radius)||radius<0)return false;for(size_t n=0;n<6;++n){const auto at=n*4;const float distance=(camera.planes[at]*center[0]+camera.planes[at+1]*center[1])+camera.planes[at+2]*center[2]-camera.planes[at+3];if(distance>radius+0.001f)return true;}return false;
 }
 float radius(int64_t flags)const{
  if(flags&1)return 1000;const float life=f(state,"lifeExp"),acceleration=std::abs(static_cast<float>(static_cast<double>(f(state,"mass"))*-9.81));
  const float travel=(f(state,"velocity")+f(state,"randomVelocity"))*life+((acceleration*0.5f)*life)*life;
  const auto mid=[&](const char* name){return has(parameters,name)?f(parameters,name):0.0f;};
  const float x=std::max(std::max(f(state,"sizeStart"),f(state,"sizeEnd")),mid("sizemid"))*0.5f;
  float y=std::max(std::max(f(state,"sizeStartY"),f(state,"sizeEndY")),mid("sizemid_y"))*0.5f;if(y<=0)y=x;return std::sqrt(x*x+y*y)+travel;
 }
 bool culled(const View& camera,const Var& pose,int64_t source_flags,float scale,float& result_radius)const{
  const auto origin=values<3>(get(pose,"position"));const V3 center{origin[0],origin[2],-origin[1]};
  if(!outside(camera,center,0)){result_radius=0;return false;}
  float bound=radius(source_flags)*scale;result_radius=bound;if(f(state,"lifeExp")<0||!outside(camera,center,bound))return false;
  const auto mid=[&](const char* name){return has(parameters,name)?std::abs(f(parameters,name)):0.0f;};
  const float padding=std::max({std::abs(f(state,"sizeStart")),std::abs(f(state,"sizeEnd")),mid("sizemid"),std::abs(f(state,"sizeStartY")),std::abs(f(state,"sizeEndY")),mid("sizemid_y")})*scale*2.0f;
  bound+=padding+std::max(std::abs(f(state,"xSize")),std::abs(f(state,"ySize")))*0.02f;
  const auto distance=[&](const V3& point){const auto delta=subtract(origin,point);return std::sqrt((delta[0]*delta[0]+delta[1]*delta[1])+delta[2]*delta[2])+padding;};
  const auto active=get(get(state,"active188"),"records");for(const auto& part:active.container->items){bound=std::max(bound,distance(values<3>(get(part,"position10"))));if(i(state,"renderMode1a8")==6)bound=std::max(bound,distance(values<3>(get(part,"trail64"))));}
  result_radius=bound;return outside(camera,center,bound);
 }
 void configure(const EngineVar& config){
  if(configured)throw std::runtime_error("Native particle owner already configured");
  state=Var(::get(config,"state"));const auto update=engine_string(::get(config,"update"));kind=update=="fountain"?0:update=="explosion"?1:update=="single"?2:-1;
  if(::has(config,"poseId")){pose_id=static_cast<uint64_t>(::get(config,"poseId").integer());source_id=static_cast<uint64_t>(::get(config,"sourceId").integer());if(!pose_id||!source_id)throw std::runtime_error("Native particle pose identity is invalid");read_engine_pose(pose_id);read_engine_pose(source_id);}
  if(kind<0||nonempty_text(get(state,"chunkName"))||(i(state,"flags")&5))throw std::runtime_error("Native particle owner requires sprite emitter without wind/point-to-point movement");
  use_parameters=::has(config,"parameters");if(use_parameters){parameters=Var(::get(config,"parameters"));prepare_parameters(state,parameters);}
  cache_constants=!::has(config,"cacheConstants")||::get(config,"cacheConstants").boolean();
  if(::has(config,"clips")){
   auto source_clips=::get(config,"clips"),names=::method(source_clips,"keys");
   for(int64_t n=0;n<::size(names);++n){const auto name=engine_string(::at(names,n));auto source_clip=::get(source_clips,name.c_str()),source_channels=::get(source_clip,"channels");auto& target=clips[name];
    for(int64_t j=0;j<::size(source_channels);++j){auto source_channel=::at(source_channels,j),control=::get(source_channel,"controller");Channel channel;channel.property=engine_string(::get(source_channel,"property"));channel.target=binding(channel.property);channel.rows=static_cast<uint16_t>(::i(control,"rows4"));channel.time_base=static_cast<uint16_t>(::i(control,"timeIndex6"));channel.value_base=static_cast<uint16_t>(::i(control,"valueIndex8"));channel.flags=static_cast<uint8_t>(::i(control,"columnsA"));channel.components=static_cast<int>(::i(source_channel,"components"));if(channel.components!=1&&channel.components!=3)throw std::runtime_error("Unsupported native controller component width");channel.storage=float_storage(::get(::get(source_channel,"storage"),"values88"));channel.constant=channel.rows==1&&(channel.flags&240)!=16&&(channel.flags&15)==channel.components;target.push_back(std::move(channel));}
   }
  }
  configured=true;
 }
 static std::string binding(const std::string& name){
  static const std::unordered_map<std::string,std::string> fields={{"birthrate","birthRate"},{"lifeexp","lifeExp"},{"particlerot","particleRot"},{"blurlength","blurLength"},{"velocity","velocity"},{"randvel","randomVelocity"},{"framestart","frameStart"},{"frameend","frameEnd"},{"xsize","xSize"},{"ysize","ySize"},{"spread","spread"},{"mass","mass"},{"bounce_co","bounceCoefficient"},{"sizestart","sizeStart"},{"sizeend","sizeEnd"},{"sizestart_y","sizeStartY"},{"sizeend_y","sizeEndY"},{"alphastart","alphaStart"},{"alphaend","alphaEnd"},{"fps","fps"},{"deadspace","deadspace"},{"blastradius","blastRadius"},{"blastlength","blastLength"},{"lightningdelay","lightningDelay"},{"lightningradius","lightningRadius"},{"lightningscale","lightningScale"},{"colorstart","colorStart"},{"colorend","colorEnd"}};
  auto found=fields.find(name);return found==fields.end()?"":found->second;
 }
 void sample(const std::string& clip,float time){
  auto found=clips.find(clip);if(found!=clips.end())for(auto& channel:found->second){
   if(!std::isfinite(time))throw std::runtime_error("Invalid native emitter sampling clock");
   Var value;
   if(cache_constants&&channel.constant&&channel.cached){value=channel.cached_value;++constant_hits;}
   else{value=channel.sample(time);++sampled_channels;if(cache_constants&&channel.constant){channel.cached_value=value;channel.cached=true;}}
   // Fixed slots and fallback map elements retain their addresses. Bindings
   // remain private to this owner and expire before its parameter/state maps.
   if(!channel.parameter_value)channel.parameter_value=field_value(parameters,channel.property.c_str(),true);
   *channel.parameter_value=value;
   if(!channel.target.empty()){
    if(!channel.state_value)channel.state_value=field_value(state,channel.target.c_str(),true);
    *channel.state_value=value;
   }
  }
 }
 EngineVar frame(const EngineVar& input,const EngineVar& providers){
  if(!configured)throw std::runtime_error("Native particle owner is not configured");
  const bool profile=::has(input,"profile")&&::get(input,"profile").boolean();using Clock=std::chrono::steady_clock;auto phase=profile?Clock::now():Clock::time_point{};double controls_ms=0,channels_ms=0,admission_ms=0,simulation_ms=0,vertices_ms=0;
  const auto finish=[&](double& duration){if(profile){const auto now=Clock::now();duration=std::chrono::duration<double,std::milli>(now-phase).count();phase=now;}};
  sample(engine_string(::get(input,"clip")),::f(input,"time"));finish(controls_ms);
  if(::has(input,"patch")){auto patch=::get(input,"patch"),names=::method(patch,"keys");for(int64_t n=0;n<::size(names);++n){const auto name=engine_string(::at(names,n));set(state,name.c_str(),Var(::get(patch,name.c_str())));}}
  if(use_parameters&&has(parameters,"detonate")&&i(parameters,"detonate")!=0){set(state,"detonate108",get(parameters,"detonate"));set_int(parameters,"detonate",0);}
  if(::has(input,"detonate")&&::get(input,"detonate").boolean())set_int(state,"detonate108",1);
  Var frame_pose;float frame_scale=1;
  if(pose_id){
   const auto pose=read_engine_pose(pose_id),source=source_id==pose_id?pose:read_engine_pose(source_id);
   frame_pose=Var::dictionary();set(frame_pose,"position",array(pose.position));set(frame_pose,"quaternion",array(pose.quaternion));frame_scale=pose.maximum_scale;
   auto owner=get(state,"source50");set(owner,"position",array(source.position));set(owner,"quaternion",array(source.quaternion));set_num(owner,"adjustedScale",source.scale);
  }else{set(state,"source50",Var(::get(input,"source")));frame_pose=Var(::get(input,"pose"));frame_scale=::has(input,"scale")?::f(input,"scale"):1;}
  if(std::abs(f(state,"birthRate"))>32768||allocations>32768)throw std::runtime_error("Native particle instance exceeds explicit allocation limit");
  const View* camera=::has(input,"view")?&view(::get(input,"view")):nullptr;
  Context ctx{&state,&providers,frame_pose,&allocations,camera?&camera->position:nullptr};ContextScope scope(ctx);finish(channels_ms);channels_ms+=controls_ms;
  ctx.profile=profile;
  if(::has(input,"scene_indices")){auto indices=::get(input,"scene_indices");if(::size(indices)!=2)throw std::runtime_error("Native particle scene requires two group identities");ctx.terrain_index=static_cast<uint64_t>(::at(indices,0).integer());ctx.static_index=static_cast<uint64_t>(::at(indices,1).integer());ctx.direct_scene=true;}
  float admission_radius=0;const bool checked=camera&&::has(input,"culling")&&::get(input,"culling").boolean()&&::i(input,"source_flags")>=0;
  const bool rejected=checked&&culled(*camera,ctx.pose,::i(input,"source_flags"),std::max(1.0f,frame_scale),admission_radius);finish(admission_ms);
  auto streams=EngineVar::dictionary();
  if(!rejected){auto p=Var::dictionary();animate(state,::f(input,"delta"),p,kind);finish(simulation_ms);
   Var draw_input;if(camera){draw_input=Var::dictionary();set(draw_input,"factor",get(get(state,"source50"),"adjustedScale"));set(draw_input,"camera",array(camera->camera));set(draw_input,"tint",array(V3{1,1,1}));}else draw_input=Var(::get(input,"draw"));
   if(!::has(input,"draw_enabled")||::get(input,"draw_enabled").boolean())streams=build(state,draw_input,false,&staging,::i(input,"capacity")).publish();
   else{staging.begin(0,::i(input,"capacity"));streams=staging.finish(0).publish();}finish(vertices_ms);
  }
  ::set(streams,"culled",EngineVar::boolean(rejected));::set(streams,"culling_checked",EngineVar::boolean(checked));::set(streams,"radius",EngineVar::number(admission_radius));
  if(profile){auto times=EngineVar::dictionary();::set(times,"native_particle_resident_controls",EngineVar::number(controls_ms));::set(times,"native_particle_channels_pose",EngineVar::number(channels_ms));::set(times,"native_particle_admission",EngineVar::number(admission_ms));::set(times,"native_particle_simulation",EngineVar::number(simulation_ms));::set(times,"native_particle_vertices",EngineVar::number(vertices_ms));if(ctx.direct_queries){::set(times,"native_particle_scene_collision",EngineVar::number(ctx.collision_ms));::set(times,"count_particle_direct_scene_queries",EngineVar::number(static_cast<double>(ctx.direct_queries)));::set(times,"count_particle_direct_scene_hits",EngineVar::number(static_cast<double>(ctx.direct_hits)));}::set(streams,"phases",times);}
  ::set(streams,"direct_scene_queries",EngineVar::integer(static_cast<int64_t>(ctx.direct_queries)));::set(streams,"direct_scene_hits",EngineVar::integer(static_cast<int64_t>(ctx.direct_hits)));
  ::set(streams,"active",EngineVar::integer(size(get(get(state,"active188"),"records"))));::set(streams,"free",EngineVar::integer(size(get(get(state,"free130"),"records"))));::set(streams,"allocated",EngineVar::integer(allocations));::set(streams,"constant_hits",EngineVar::integer(constant_hits));::set(streams,"sampled_channels",EngineVar::integer(sampled_channels));return streams;
 }
};
} // namespace resident
GDExtensionObjectPtr resident_create(void*,GDExtensionBool notify){
 Name base("RefCounted"),name("NwnParticleOwner");auto object=construct_object(base.data);auto owner=new resident::Owner();set_instance(object,name.data,owner);
 if(notify){EngineVar value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{EngineVar::integer(0)});}return object;
}
void resident_free(void*,GDExtensionClassInstancePtr instance){delete static_cast<resident::Owner*>(instance);}
void resident_call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=3){error->error=count<3?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=3;new_nil(result);return;}
 try{auto& owner=*static_cast<resident::Owner*>(instance);EngineVar operation(args[0]),input(args[1]),providers(args[2]);auto out=EngineVar::dictionary();switch(operation.integer()){case 0:owner.configure(input);break;case 1:out=owner.frame(input,providers);break;case 2:if(!owner.configured)throw std::runtime_error("Native owner snapshot before configure");out=owner.state.publish();break;case 3:out=owner.parameters.publish();break;case 4:owner.sample(engine_string(get(input,"clip")),f(input,"time"));out=owner.parameters.publish();break;default:throw std::runtime_error("Unknown native owner operation");}new_copy(result,out.data);}catch(const std::exception& err){auto out=EngineVar::dictionary();set(out,"error",EngineVar::text(err.what()));new_copy(result,out.data);}
}
template<typename Property>void register_resident(const Property& property){
 Name name("NwnParticleOwner"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input"),providers("providers");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=resident_create;info.free_instance_func=resident_free;register_class(library,name.data,base.data,&info);
 auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,providers)};GDExtensionClassMethodArgumentMetadata metadata[3]{};GDExtensionClassMethodInfo m{};m.name=method_name.data;m.call_func=resident_call;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=3;m.arguments_info=args;m.arguments_metadata=metadata;register_method(library,name.data,&m);
}
