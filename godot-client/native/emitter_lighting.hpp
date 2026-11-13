// CPU GetEmitterLighting, distinct from enhanced fragment-light attenuation.
// Main-thread snapshot only: no SceneTree reads, render-thread queries or JS.
namespace emitter_lighting {
struct Light {V3 position{},color{};float radius=0,fade=1;bool excluded=false;};
struct Snapshot {
 std::vector<Light> lights;V3 head_diffuse{},head_ambient{},area[2]{};bool head=false,area_present[2]{};
 void load(const EngineVar& input){
  lights.clear();head=false;head_diffuse={};head_ambient={};area[0]={};area[1]={};area_present[0]=false;area_present[1]=false;
  if(::has(input,"lights")){auto rows=::get(input,"lights");const auto count=::size(rows);if(count>16384)throw std::runtime_error("Emitter lighting exceeds bounded physical light registry");lights.reserve(static_cast<size_t>(count));for(int64_t n=0;n<count;++n){auto row=::at(rows,n);Light value;value.position=::has(row,"position")?::values<3>(::get(row,"position")):V3{};value.color=::values<3>(::get(row,"color"));value.radius=::has(row,"radius")?static_cast<float>(::get(row,"radius").number()):0;value.fade=::has(row,"fade")?static_cast<float>(::get(row,"fade").number()):1;for(auto v:value.position)if(!std::isfinite(v))throw std::runtime_error("Nonfinite emitter light position");for(auto v:value.color)if(!std::isfinite(v))throw std::runtime_error("Nonfinite emitter light color");if(!std::isfinite(value.radius)||!std::isfinite(value.fade))throw std::runtime_error("Nonfinite emitter light shape");lights.push_back(value);}}
  if((!::has(input,"exclusion_list")||::get(input,"exclusion_list").boolean())&&::has(input,"excluded")){auto ids=::get(input,"excluded");for(int64_t n=0;n<::size(ids);++n){const auto index=::at(ids,n).number();if(!std::isfinite(index)||std::trunc(index)!=index)throw std::runtime_error("Emitter light exclusion index must be integral");if(index>=0&&index<static_cast<double>(lights.size()))lights[static_cast<size_t>(index)].excluded=true;}}
  head=::has(input,"headlight")&&::get(input,"headlight").boolean();if(head){if(::has(input,"headlight_diffuse"))head_diffuse=::values<3>(::get(input,"headlight_diffuse"));if(::has(input,"headlight_ambient"))head_ambient=::values<3>(::get(input,"headlight_ambient"));}
  for(int n=0;n<2;++n){const auto name=n==0?"ambient":"diffuse";if(!::has(input,name))continue;auto row=::get(input,name);if(row.nil())continue;const auto color=::values<3>(::get(row,"color"));const float fade=::has(row,"fade")?static_cast<float>(::get(row,"fade").number()):1;for(size_t axis=0;axis<3;++axis)area[n][axis]=color[axis]*fade;area_present[n]=true;}
 }
 V3 sample(const V3& point)const{
  V3 result{};
  for(const auto& light:lights){if(light.excluded)continue;const V3 delta{light.position[0]-point[0],light.position[1]-point[1],light.position[2]-point[2]};float distance=std::sqrt((delta[0]*delta[0]+delta[1]*delta[1])+delta[2]*delta[2]);if(distance==0)distance=.000001f;const float radius=light.radius==0?.01f:light.radius,attenuation=1.0f-distance/radius;if(attenuation>=0)for(size_t axis=0;axis<3;++axis)result[axis]+=(attenuation*light.color[axis])*light.fade;}
  if(head){for(size_t axis=0;axis<3;++axis)result[axis]+=head_diffuse[axis];for(size_t axis=0;axis<3;++axis)result[axis]+=head_ambient[axis];}
  // Native +a0 (ambient) precedes +98 (diffuse), preserving float addition.
  for(int n=0;n<2;++n)if(area_present[n])for(size_t axis=0;axis<3;++axis)result[axis]+=area[n][axis];
  for(auto& value:result)if(1.0f<=value)value=1.0f;return result;
 }
};
inline EngineVar inspect(const EngineVar& input){Snapshot data;data.load(input);const auto point=::values<3>(::get(input,"point"));const auto value=data.sample(point);auto out=EngineVar::dictionary();::set(out,"sample",::array(value));::set(out,"lights",EngineVar::integer(static_cast<int64_t>(data.lights.size())));return out;}
}
