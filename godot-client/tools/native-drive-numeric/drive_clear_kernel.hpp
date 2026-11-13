#pragma once
// Data-only triangle loops. Math supplies the actual engine Vector2 operations;
// scalar operations deliberately preserve the GDS double expression order.
#include <array>
#include <vector>
#include <cmath>
#include <cstddef>
#include <stdexcept>
namespace drive_clear_kernel {
using V2=std::array<float,2>;
using V3=std::array<float,3>;
inline double finite(double x){if(!std::isfinite(x))throw std::runtime_error("Unsupported nonfinite drive arithmetic");return x;}
inline V2 finite(V2 x){finite(x[0]);finite(x[1]);return x;}
inline double low(double a,double b){return a<b?a:b;}
inline double high(double a,double b){return a>b?a:b;}
inline double clamp(double x){return x<0.0?0.0:(x>1.0?1.0:x);}
inline double cross(const V2&a,const V2&b){const double x=static_cast<double>(a[0])*static_cast<double>(b[1]);const double y=static_cast<double>(a[1])*static_cast<double>(b[0]);return finite(x-y);}
struct Face{V3 a{},b{},c{},minimum{},maximum{};bool walk=false;};
struct FloorResult{bool blocked=false;std::vector<V2> intervals;};
struct Batch{
 std::vector<Face> faces;bool configured=false,tile=false;
 void clear(){configured=false;tile=false;std::vector<Face>().swap(faces);}
 size_t payload_bytes()const{return sizeof(Batch)+faces.capacity()*sizeof(Face);}
 static void validate(const Face& f){
  for(const auto* v:{&f.a,&f.b,&f.c,&f.minimum,&f.maximum})for(float x:*v)finite(x);
  for(size_t i=0;i<3;++i)if(f.minimum[i]>f.maximum[i])throw std::runtime_error("Invalid drive bounds");
 }
 void configure(std::vector<Face> next,bool tiles,size_t maximum){
  clear();if(next.size()>2000000||maximum<sizeof(Batch)||next.capacity()>(maximum-sizeof(Batch))/sizeof(Face))throw std::runtime_error("Drive batch exceeds payload bound");
  for(const auto&f:next)validate(f);faces.swap(next);tile=tiles;configured=true;
 }
 template<class Math>static V2 interval(const V2&from,const V2&to,const Face&tri,const Math&math){
  const std::array<V2,3> p={V2{tri.a[0],tri.a[1]},V2{tri.b[0],tri.b[1]},V2{tri.c[0],tri.c[1]}};
  const auto u=finite(math.sub(p[1],p[0])),v=finite(math.sub(p[2],p[0]));const auto area=cross(u,v);
  if(std::abs(area)<0.0000001)return {1.0f,-1.0f};
  double l=0.0,h=1.0;const double sign=area>0.0?1.0:-1.0;
  for(size_t i=0;i<3;++i){
   const auto edge=finite(math.sub(p[(i+1)%3],p[i]));const auto ap=finite(math.sub(from,p[i])),bp=finite(math.sub(to,p[i]));
   const double a=finite(sign*cross(edge,ap)),b=finite(sign*cross(edge,bp)),d=finite(b-a);
   if(std::abs(d)<0.0000001){if(a< -0.00001)return {1.0f,-1.0f};}
   else if(d>0.0)l=high(l,finite(-a/d));else h=low(h,finite(-a/d));
  }
  return finite(V2{static_cast<float>(l),static_cast<float>(h)});
 }
 template<class Math>static double point_distance(const V2&p,const V2&a,const V2&b,const Math&math){
  const auto delta=finite(math.sub(b,a));const auto length=finite(math.length_squared(delta));double t=0.0;
  if(length>0.0)t=clamp(finite(finite(math.dot(finite(math.sub(p,a)),delta))/length));
  const auto projected=finite(math.add(a,finite(math.mul(delta,t))));return finite(math.distance_squared(p,projected));
 }
 template<class Math>static double segment_distance(const V2&a,const V2&b,const V2&c,const V2&d,const Math&math){
  const auto ba=finite(math.sub(b,a)),dc=finite(math.sub(d,c));const auto den=cross(ba,dc);
  if(std::abs(den)>0.00000001){const auto ca=finite(math.sub(c,a));const double t=finite(cross(ca,dc)/den),u=finite(cross(ca,ba)/den);if(t>=0.0&&t<=1.0&&u>=0.0&&u<=1.0)return 0.0;}
  return low(low(point_distance(a,c,d,math),point_distance(b,c,d,math)),low(point_distance(c,a,b,math),point_distance(d,a,b,math)));
 }
 template<class Math>static bool hits(const V2&from,const V2&to,const Face&tri,double radius,double zlow,double zhigh,const Math&math){
  if(tri.maximum[2]<zlow||tri.minimum[2]>zhigh)return false;
  if(high(from[0],to[0])+radius<tri.minimum[0]||low(from[0],to[0])-radius>tri.maximum[0]||high(from[1],to[1])+radius<tri.minimum[1]||low(from[1],to[1])-radius>tri.maximum[1])return false;
  const auto span=interval(from,to,tri,math);if(span[0]<=span[1]&&span[1]>=0.0f&&span[0]<=1.0f)return true;
  const std::array<V2,3> p={V2{tri.a[0],tri.a[1]},V2{tri.b[0],tri.b[1]},V2{tri.c[0],tri.c[1]}};
  const double square=finite(radius*radius);for(size_t i=0;i<3;++i)if(segment_distance(from,to,p[i],p[(i+1)%3],math)<square)return true;return false;
 }
 static void query_valid(const V2&a,const V2&b,double radius,double zlow,double zhigh){finite(a);finite(b);finite(radius);finite(zlow);finite(zhigh);if(radius<0||zlow>zhigh)throw std::runtime_error("Unsupported drive query range");}
 template<class Math>FloorResult floor(const V2&a,const V2&b,double radius,double zlow,double zhigh,const Math&math)const{
  if(!configured||!tile)throw std::runtime_error("Drive floor batch unavailable");query_valid(a,b,radius,zlow,zhigh);FloorResult out;
  for(const auto&f:faces){if(f.walk){const auto span=interval(a,b,f,math);if(span[0]<=span[1])out.intervals.push_back(span);}else if(hits(a,b,f,radius,zlow,zhigh,math)){out.blocked=true;out.intervals.clear();return out;}}return out;
 }
 template<class Math>bool obstacle(const V2&a,const V2&b,double radius,double zlow,double zhigh,const Math&math)const{
  if(!configured||tile)throw std::runtime_error("Drive object batch unavailable");query_valid(a,b,radius,zlow,zhigh);for(const auto&f:faces)if(hits(a,b,f,radius,zlow,zhigh,math))return true;return false;
 }
};
}
