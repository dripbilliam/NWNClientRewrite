#pragma once
// SOURCE-ONLY prototype. No SceneGeometry, renderer, registry or server hook.
// Compile with /fp:strict (or an independently verified equivalent); actual
// Godot conversion/edge/plane bit oracles are required before integration.
#include <array>
#include <vector>
#include <limits>
#include <cmath>
#include <cstddef>
#include <stdexcept>
namespace drive_height_kernel {
using Point=std::array<double,2>;
using FPoint=std::array<float,2>;
struct Unsupported:std::runtime_error{using std::runtime_error::runtime_error;};
inline double finite(double value){if(!std::isfinite(value))throw Unsupported("Height arithmetic is not finite");return value;}
inline float narrow(double value){finite(value);const float out=static_cast<float>(value);if(!std::isfinite(out))throw Unsupported("Height narrowing overflows f32");return out;}
inline double f(double value){return static_cast<double>(narrow(value));}
inline float exact_source(double value){const float out=narrow(value);if(static_cast<double>(out)!=value||std::signbit(out)!=std::signbit(value))throw Unsupported("Height source is not exactly f32-valued");return out;}
struct SourceFace {
 // Source physical index order is retained. Height never reads vertex Z, so
 // the preparation interface deliberately accepts only XY for each corner.
 std::array<Point,3> points{};
 std::array<double,3> normal{};
 double constant=0;
 bool walkable=false; // Classified by the authoritative GDS surface table.
};
struct Face {
 std::array<FPoint,3> points{};
 std::array<float,3> normal{};
 float constant=0;
 bool walkable=false;
};
struct Result {
 bool found=false;
 double height=0.0; // Valid no-hit result is +0; unsupported throws instead.
 size_t physical_face=std::numeric_limits<size_t>::max();
 bool walkable=false;
};
inline double edge(const FPoint&a,const FPoint&b,double x,double y){
 const double dy=f(y-static_cast<double>(a[1]));
 const double dx=f(static_cast<double>(b[0])-static_cast<double>(a[0]));
 const double ayby=f(static_cast<double>(a[1])-static_cast<double>(b[1]));
 const double xa=f(x-static_cast<double>(a[0]));
 const double left=f(dy*dx),right=f(ayby*xa);
 return f(left+right);
}
inline double plane(const Face&face,double x,double y){
 // This ternary is the original positive-zero result, even for n.z == -0.
 if(face.normal[2]==0.0f)return 0.0;
 const double nyy=f(static_cast<double>(face.normal[1])*y);
 const double nxx=f(static_cast<double>(face.normal[0])*x);
 const double constant=f(static_cast<double>(face.constant));
 const double xpart=f(nxx+constant);
 const double sum=f(nyy+xpart);
 return f(-f(sum)/static_cast<double>(face.normal[2]));
}
class Batch {
 std::vector<Face> faces_;
 bool configured_=false;
public:
 static constexpr size_t maximum_faces=2000000;
 bool configured()const{return configured_;}
 size_t size()const{return faces_.size();}
 size_t payload_bytes()const{return sizeof(Batch)+faces_.capacity()*sizeof(Face);}
 void clear(){configured_=false;std::vector<Face>().swap(faces_);}
 void configure(const std::vector<SourceFace>&source,size_t maximum_bytes){
  clear();
  if(!std::numeric_limits<float>::is_iec559||!std::numeric_limits<double>::is_iec559||sizeof(float)!=4||sizeof(double)!=8)throw Unsupported("Height floating ABI is unsupported");
  if(source.size()>maximum_faces||maximum_bytes<sizeof(Batch)||source.size()>(maximum_bytes-sizeof(Batch))/sizeof(Face))throw Unsupported("Height calculation exceeds payload bound");
  std::vector<Face> next;next.reserve(source.size());
  if(next.capacity()>(maximum_bytes-sizeof(Batch))/sizeof(Face))throw Unsupported("Height allocation exceeds payload bound");
  for(const auto&raw:source){Face value;
   for(size_t corner=0;corner<3;++corner)for(size_t axis=0;axis<2;++axis)value.points[corner][axis]=exact_source(raw.points[corner][axis]);
   for(size_t axis=0;axis<3;++axis)value.normal[axis]=exact_source(raw.normal[axis]);
   // The source expression explicitly narrows a constant before using it;
   // unlike vertex XY/normal fields it need not already be f32-valued.
   value.constant=narrow(raw.constant);value.walkable=raw.walkable;next.push_back(value);
  }
  faces_.swap(next);configured_=true;
 }
 Result height(double source_x,double source_y)const{
  if(!configured_)throw Unsupported("Height query has no live typed source");
  const double x=f(source_x),y=f(source_y);
  for(const bool allowed:{true,false}){
   for(size_t index=0;index<faces_.size();++index){const auto&face=faces_[index];
    if(face.walkable!=allowed)continue;
    if(edge(face.points[0],face.points[1],x,y)>=0.0&&edge(face.points[1],face.points[2],x,y)>=0.0&&edge(face.points[2],face.points[0],x,y)>=0.0)return {true,plane(face,x,y),index,allowed};
   }
  }
  return {};
 }
};
}
