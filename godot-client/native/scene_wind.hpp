// Original-derived scene wind arithmetic, held once per admitted world.
// Runtime vectors/noise/points stay native. Tokens never retain engine Nodes.
namespace scene_wind {
struct Point {V3 position;float radius,duration,remaining,strength;};
struct Cell {bool ready=false;float strength=0;Q4 rotation{};};
struct Owner;
std::unordered_map<uint64_t,Owner*> owners;uint64_t next_token=0;
struct Owner {
 uint64_t token=++next_token;bool configured=false,cache_enabled=true,retired=false;
 std::array<float,256> first{},second{};std::array<Cell,256> cells{};
 V3 wind{},step{};float deviation=130,pitch=0,timeout=.5f,elapsed=0,fraction=0;
 uint32_t seed=1;uint64_t draws=0,queries=0,cache_hits=0,cache_misses=0,refills=0;size_t capacity=0;
 std::vector<Point> points;
 Owner(){owners[token]=this;}~Owner(){owners.erase(token);}Owner(const Owner&)=delete;
 void invalidate(){for(auto& cell:cells)cell.ready=false;}
 int random(){seed=seed*0x343fdU+0x269ec3U;++draws;return static_cast<int>((seed>>16)&0x7fffU);}
 void fill(std::array<float,256>& field){
  field.fill(0);
  for(int width=16;width>0;width/=2)for(int x=0;x<16;x+=width)for(int y=0;y<16;y+=width){
   const float value=static_cast<float>(random()%(500/(16/width)))/1000.0f;
   for(int a=x;a<x+width;++a)for(int b=y;b<y+width;++b)field[static_cast<size_t>(a*16+b)]+=value;
  }
 }
 static void noise_input(const Var& input,const char* name,std::array<float,256>& field){auto value=get(input,name);if(size(value)!=256)throw std::runtime_error("Native wind noise field must contain 256 values");for(size_t n=0;n<256;++n)field[n]=static_cast<float>(at(value,static_cast<int64_t>(n)).number());}
 void parameters(const Var& input){
  if(retired)throw std::runtime_error("Native scene wind token is retired");
  if(has(input,"wind"))wind=values<3>(get(input,"wind"));
  if(has(input,"deviation"))deviation=f(input,"deviation");if(has(input,"pitch"))pitch=f(input,"pitch");if(has(input,"timeout"))timeout=f(input,"timeout");
  if(!std::isfinite(deviation)||!std::isfinite(pitch)||!std::isfinite(timeout)||timeout<=0)throw std::runtime_error("Native wind parameters require finite angles and positive timeout");
  for(auto value:wind)if(!std::isfinite(value))throw std::runtime_error("Native wind vector must be finite");invalidate();
 }
 void configure(const Var& input){
  if(retired)throw std::runtime_error("Native scene wind token is retired");
  if(configured)throw std::runtime_error("Native scene wind already configured");
  if(has(input,"seed"))seed=static_cast<uint32_t>(get(input,"seed").integer());
  if(has(input,"first")){noise_input(input,"first",first);noise_input(input,"second",second);}else{fill(first);fill(second);}
  parameters(input);if(has(input,"elapsed"))elapsed=f(input,"elapsed");if(has(input,"fraction"))fraction=f(input,"fraction");
  if(has(input,"cache"))cache_enabled=get(input,"cache").boolean();configured=true;
 }
 uint64_t advance(float delta,uint32_t input_seed){
  if(!configured||!std::isfinite(delta))throw std::runtime_error("Native scene wind requires configured finite frame time");
  seed=input_seed;const auto before=draws;elapsed=delta+elapsed;
  if(timeout<elapsed){std::swap(first,second);fill(second);elapsed=0;++refills;}
  const float next=elapsed/timeout;if(next!=fraction){fraction=next;invalidate();}else fraction=next;
  for(size_t j=0;j<3;++j)step[j]=delta*wind[j];
  points.erase(std::remove_if(points.begin(),points.end(),[&](Point& point){point.remaining-=delta;return point.remaining<0;}),points.end());
  return draws-before;
 }
 void add(const Var& input){
  if(!configured)throw std::runtime_error("Native scene wind is not configured");if(points.size()>=32768)throw std::runtime_error("Native point-wind source allocation exceeds explicit limit");
  if(points.size()==capacity){capacity=capacity==0?16:capacity*2;points.reserve(capacity);}
  const float duration=f(input,"duration");points.push_back({values<3>(get(input,"position")),f(input,"radius"),duration,duration,f(input,"strength")});
 }
 static size_t bucket(float value){const uint32_t shifted=static_cast<uint32_t>(cvtt(value))<<2;return static_cast<size_t>((shifted&0x80000000U?0U-shifted:shifted)&15U);}
 float interpolated(size_t x,size_t y)const{const auto index=x*16+y;return (1.0f-fraction)*first[index]+fraction*second[index];}
 Cell calculate(size_t x,size_t y)const{
  Cell cell;cell.ready=true;cell.strength=interpolated(x,y);Q4 yaw{1,0,0,0},tilt{1,0,0,0};
  if(deviation!=0){const float noise=interpolated((x+8)&15,(y+8)&15),factor=(1.0f-cell.strength)*deviation;const float angle=static_cast<float>(static_cast<double>(noise)*2.0-1.0)*factor;yaw={trig(angle,true),0,0,trig(angle,false)};}
  if(pitch!=0){const float noise=interpolated(y,x),angle=((noise+noise)*pitch)-pitch;tilt={trig(angle,true),trig(angle,false),0,0};}
  cell.rotation=multiply(yaw,tilt);return cell;
 }
 V3 point_vector(const V3& position)const{
  if(!configured)throw std::runtime_error("Native scene wind is not configured");
  V3 result{};
  for(const auto& point:points){
   const auto delta=subtract(position,point.position);const float radius=point.radius;
   if(std::abs(delta[0])>radius||std::abs(delta[1])>radius||std::abs(delta[2])>radius)continue;
   const float squared=(delta[1]*delta[1]+delta[0]*delta[0])+delta[2]*delta[2];if(!(squared<radius*radius))continue;
   const float distance=std::sqrt(squared);auto direction=delta;if(distance!=0){const float reciprocal=1.0f/distance;for(auto& value:direction)value*=reciprocal;}
   const auto unit=normalize(direction);const float scale=((radius-distance)*point.strength)/radius;
   for(size_t j=0;j<3;++j)result[j]+=scale*unit[j];
  }
  return result;
 }
 V3 sample(const V3& position,float factor){
  if(!configured)throw std::runtime_error("Native scene wind is not configured");++queries;
  const auto x=bucket(position[0]),y=bucket(position[1]),index=x*16+y;auto& saved=cells[index];Cell fresh;
  if(!cache_enabled){fresh=calculate(x,y);++cache_misses;}else if(!saved.ready){saved=calculate(x,y);++cache_misses;}else ++cache_hits;
  const auto& cell=cache_enabled?saved:fresh;auto result=point_vector(position);const float strength=cell.strength*factor;
  for(size_t j=0;j<3;++j)result[j]=strength*wind[j]+result[j];
  return rotate(cell.rotation,result);
 }
 float bound()const{float result=std::sqrt((wind[0]*wind[0]+wind[1]*wind[1])+wind[2]*wind[2]);for(const auto& point:points)result+=std::abs(point.strength);return result;}
 void retire(){owners.erase(token);configured=false;retired=true;points.clear();capacity=0;}
 Var summary()const{auto out=Var::dictionary();set(out,"seed",Var::integer(seed));set(out,"draws",Var::integer(static_cast<int64_t>(draws)));set(out,"refills",Var::integer(static_cast<int64_t>(refills)));set(out,"points",Var::integer(static_cast<int64_t>(points.size())));set(out,"queries",Var::integer(static_cast<int64_t>(queries)));set(out,"cache_hits",Var::integer(static_cast<int64_t>(cache_hits)));set(out,"cache_misses",Var::integer(static_cast<int64_t>(cache_misses)));return out;}
 Var snapshot()const{
  auto out=summary();set(out,"wind",array(wind));set(out,"step",array(step));set(out,"elapsed",Var::number(elapsed));set(out,"fraction",Var::number(fraction));set(out,"timeout",Var::number(timeout));set(out,"deviation",Var::number(deviation));set(out,"pitch",Var::number(pitch));set(out,"capacity",Var::integer(static_cast<int64_t>(capacity)));
  auto a=array_empty(),b=array_empty(),sources=array_empty();for(auto value:first)method(a,"append",{Var::number(value)});for(auto value:second)method(b,"append",{Var::number(value)});
  for(const auto& point:points){auto row=array_empty();for(auto value:point.position)method(row,"append",{Var::number(value)});for(auto value:{point.radius,point.duration,point.remaining,point.strength})method(row,"append",{Var::number(value)});method(sources,"append",{row});}
  set(out,"first",a);set(out,"second",b);set(out,"records",sources);return out;
 }
};
Owner& owner(uint64_t token){const auto found=owners.find(token);if(found==owners.end())throw std::runtime_error("Native scene wind token is retired");return *found->second;}
}
GDExtensionObjectPtr scene_wind_create(void*,GDExtensionBool notify){Name base("RefCounted"),name("NwnWindManager");auto object=construct_object(base.data);set_instance(object,name.data,new scene_wind::Owner());if(notify){Var value;destroy(value.data);from[GDEXTENSION_VARIANT_TYPE_OBJECT](value.data,&object);method(value,"notification",{Var::integer(0)});}return object;}
void scene_wind_free(void*,GDExtensionClassInstancePtr instance){delete static_cast<scene_wind::Owner*>(instance);}
void scene_wind_call(void*,GDExtensionClassInstancePtr instance,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=2){error->error=count<2?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=2;new_nil(result);return;}
 try{auto& owner=*static_cast<scene_wind::Owner*>(instance);Var op(args[0]),input(args[1]),out;switch(op.integer()){
 case 0:owner.configure(input);out=owner.summary();break;
 case 1:owner.advance(f(input,"delta"),static_cast<uint32_t>(get(input,"seed").integer()));out=owner.summary();break;
 case 2:out=array(owner.sample(values<3>(get(input,"position")),f(input,"factor")));break;
 case 3:owner.add(input);out=owner.summary();break;
 case 4:out=owner.snapshot();break;
 case 5:owner.parameters(input);break;
 case 6:out=Var::integer(static_cast<int64_t>(owner.token));break;
 case 7:out=owner.summary();break;
 case 8:out=array(owner.point_vector(values<3>(get(input,"position"))));break;
 case 9:owner.retire();break;
 default:throw std::runtime_error("Unknown native scene wind operation");}new_copy(result,out.data);
 }catch(const std::exception& err){auto out=Var::dictionary();set(out,"error",Var::text(err.what()));new_copy(result,out.data);}
}
template<typename Property>void register_scene_wind(const Property& property){Name name("NwnWindManager"),base("RefCounted"),method_name("dispatch"),empty(""),operation("operation"),input("input");GDExtensionClassCreationInfo6 info{};info.is_exposed=true;info.is_runtime=true;info.create_instance_func=scene_wind_create;info.free_instance_func=scene_wind_free;register_class(library,name.data,base.data,&info);auto ret=property(GDEXTENSION_VARIANT_TYPE_NIL,empty);ret.usage|=131072;GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_INT,operation),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,input)};GDExtensionClassMethodArgumentMetadata metadata[2]{};GDExtensionClassMethodInfo m{};m.name=method_name.data;m.call_func=scene_wind_call;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=2;m.arguments_info=args;m.arguments_metadata=metadata;register_method(library,name.data,&m);}
