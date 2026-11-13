#pragma once
// Private synchronous geometry math. No Godot object/scene/callback access.
// World poses are the public single-precision Transform3D ROW carrier.
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <vector>
namespace nwn_highlight {
struct V3 {float x=0,y=0,z=0;};
inline V3 add(V3 a,V3 b){return {a.x+b.x,a.y+b.y,a.z+b.z};}
inline V3 sub(V3 a,V3 b){return {a.x-b.x,a.y-b.y,a.z-b.z};}
inline V3 mul(V3 a,float b){return {a.x*b,a.y*b,a.z*b};}
inline float dot(V3 a,V3 b){return (a.x*b.x+a.y*b.y)+a.z*b.z;}
inline V3 cross(V3 a,V3 b){return {a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};}
inline bool finite(V3 a){return std::isfinite(a.x)&&std::isfinite(a.y)&&std::isfinite(a.z);}
inline V3 normalize(V3 a){const float square=dot(a,a);if(square==0)return {1,0,0};if(square>=0.99999f&&square<=1.00001f)return a;const float length=std::sqrt(square);return {a.x/length,a.y/length,a.z/length};}
inline V3 to_godot(V3 a){return {a.x,a.z,-a.y};}
inline V3 to_native(V3 a){return {a.x,-a.z,a.y};}
struct Part {std::array<float,6> shape{};std::array<float,12> pose{};std::array<float,4> color{};float alpha=1;bool enabled=true;};
inline V3 transform(const std::array<float,12>& p,V3 a){return {((p[0]*a.x+p[1]*a.y)+p[2]*a.z)+p[9],((p[3]*a.x+p[4]*a.y)+p[5]*a.z)+p[10],((p[6]*a.x+p[7]*a.y)+p[8]*a.z)+p[11]};}
struct Frame {std::vector<uint8_t> positions,attributes;V3 minimum{},maximum{};bool bounds=false;uint32_t available=0,unavailable=0;};
inline void word(std::vector<uint8_t>& data,size_t at,uint32_t value){std::memcpy(data.data()+at,&value,4);}
inline void scalar(std::vector<uint8_t>& data,size_t at,float value){std::memcpy(data.data()+at,&value,4);}
inline int64_t truncation(float a){if(!std::isfinite(a)||double(a)<=double(std::numeric_limits<int64_t>::min())||double(a)>=double(std::numeric_limits<int64_t>::max()))throw std::runtime_error("Highlight packed channel outside finite integer domain");return static_cast<int64_t>(a);}
inline bool emit(const Part& part,V3 camera,float pulse,float intensity,size_t index,Frame& out){
 if(!part.enabled)return false;
 for(float a:part.shape)if(!std::isfinite(a))return false;
 for(float a:part.pose)if(!std::isfinite(a))return false;
 for(float a:part.color)if(!std::isfinite(a))return false;
 if(!std::isfinite(part.alpha))return false;
 for(size_t axis=0;axis<3;axis++)if(part.shape[axis]>part.shape[axis+3])return false;
 const auto& p=part.pose;const V3 x{p[0],p[3],p[6]},y{p[1],p[4],p[7]},z{p[2],p[5],p[8]};float scale=std::sqrt(dot(x,x));
 if(scale<0.0000001f||std::abs(std::sqrt(dot(y,y))-scale)>scale*0.00001f||std::abs(std::sqrt(dot(z,z))-scale)>scale*0.00001f)return false;
 if(std::abs(dot(x,y))>scale*scale*0.00001f||std::abs(dot(x,z))>scale*scale*0.00001f||std::abs(dot(y,z))>scale*scale*0.00001f)return false;
 if(dot(x,cross(y,z))<0)scale=-scale;
 std::array<float,3> c{},l{},h{};
 for(size_t axis=0;axis<3;axis++){c[axis]=(part.shape[axis+3]+part.shape[axis])*0.5f;l[axis]=(part.shape[axis]-c[axis])*pulse+c[axis];h[axis]=(part.shape[axis+3]-c[axis])*pulse+c[axis];}
 const V3 center{c[0],c[1],c[2]},lo{l[0],l[1],l[2]},hi{h[0],h[1],h[2]};
 const V3 origin{p[9],p[10],p[11]};const V3 direction=normalize(to_native(sub(camera,origin)));const float inverse_bias=static_cast<float>(0.001/double(scale));const V3 biased=sub(center,mul(direction,inverse_bias));
 const std::array<std::array<V3,4>,3> planes{{{{{biased.x,lo.y,lo.z},{biased.x,hi.y,lo.z},{biased.x,hi.y,hi.z},{biased.x,lo.y,hi.z}}},{{{lo.x,biased.y,lo.z},{hi.x,biased.y,lo.z},{hi.x,biased.y,hi.z},{lo.x,biased.y,hi.z}}},{{{lo.x,lo.y,biased.z},{hi.x,lo.y,biased.z},{hi.x,hi.y,biased.z},{lo.x,hi.y,biased.z}}}}};
 V3 tint{part.color[0],part.color[1],part.color[2]};if(part.alpha<0.4f)tint=mul(tint,part.alpha/0.4f);
 const uint32_t red=static_cast<uint32_t>(truncation(tint.x*255.0f)),green=static_cast<uint32_t>(truncation(tint.y*255.0f)),blue=static_cast<uint32_t>(truncation(tint.z*255.0f));
 constexpr std::array<size_t,6> order{{0,1,3,3,1,2}};constexpr std::array<std::array<float,2>,6> uv{{{{0,0}},{{1,0}},{{0,1}},{{0,1}},{{1,0}},{{1,1}}}};
 for(size_t plane=0;plane<3;plane++){
  std::array<V3,4> transformed{};for(size_t vertex=0;vertex<4;vertex++)transformed[vertex]=transform(p,to_godot(planes[plane][vertex]));
  const V3 normal=normalize(cross(sub(transformed[1],transformed[0]),sub(transformed[2],transformed[0]))),camera_direction=to_godot(direction);
  const float facing=std::abs((normal.y*camera_direction.y+normal.x*camera_direction.x)+normal.z*camera_direction.z);
  const uint32_t alpha=static_cast<uint32_t>(truncation(((facing*facing)*intensity)*255.0f));const uint32_t rgba=(alpha<<24)|(blue<<16)|(green<<8)|red;
  for(size_t corner=0;corner<6;corner++){
   const size_t at=index*18+plane*6+corner;const V3 v=transformed[order[corner]];
   scalar(out.positions,at*12,v.x);scalar(out.positions,at*12+4,v.y);scalar(out.positions,at*12+8,v.z);
   word(out.attributes,at*12,rgba);scalar(out.attributes,at*12+4,uv[corner][0]);scalar(out.attributes,at*12+8,uv[corner][1]);
   if(!out.bounds){out.minimum=v;out.maximum=v;out.bounds=true;}else{out.minimum={std::fmin(out.minimum.x,v.x),std::fmin(out.minimum.y,v.y),std::fmin(out.minimum.z,v.z)};out.maximum={std::fmax(out.maximum.x,v.x),std::fmax(out.maximum.y,v.y),std::fmax(out.maximum.z,v.z)};}
  }
 }
 return true;
}
inline Frame generate(const std::vector<Part>& parts,V3 camera,float pulse,float intensity){
 if(parts.size()>65536||!finite(camera)||!std::isfinite(pulse)||pulse<=0||!std::isfinite(intensity)||intensity<0)throw std::runtime_error("Invalid highlight batch domain");
 Frame out;out.positions.resize(parts.size()*18*12,0);out.attributes.resize(parts.size()*18*12,0);
 for(size_t index=0;index<parts.size();index++){if(emit(parts[index],camera,pulse,intensity,index,out))out.available++;else out.unavailable++;}
 return out;
}
}
