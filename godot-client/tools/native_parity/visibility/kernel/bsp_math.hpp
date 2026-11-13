#pragma once
#include <array>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <vector>
namespace nwn_bsp {
constexpr int max_nodes=300000,max_callbacks=600000,max_planes=64,max_depth=128;
struct Input {const float* planes;const int32_t* topology;const float* vertices;const int32_t* ranges;const int64_t* tiles;int nodes,vertex_floats,root;std::array<float,3> camera;const float* frustum;int plane_count;uint32_t snapshot_low;};
struct Result {std::vector<int32_t> nodes,plane_counts,tile_nodes;std::vector<int64_t> tiles;uint32_t delta_word;};
inline float dot(const float* a,const float* b){const float x=a[0]*b[0],y=a[1]*b[1],z=a[2]*b[2];const float xy=x+y;return xy+z;}
inline float distance(const float* p,const float* v){return dot(p,v)+p[3];}
struct PlaneList {std::array<int,max_planes> indices{};int size=0;void add(int value){if(size>=max_planes)throw std::runtime_error("BSP plane-list bound");indices[static_cast<size_t>(size++)]=value;}};
class Collector {
 const Input& in;Result out;
 void graph(int node,std::vector<uint8_t>& active,int depth){
  if(node<0)return;if(depth>max_depth)throw std::runtime_error("BSP depth bound");
  if(active[static_cast<size_t>(node)]==1)throw std::runtime_error("BSP cycle");
  if(active[static_cast<size_t>(node)]==2)return;active[static_cast<size_t>(node)]=1;
  graph(in.topology[node*3+1],active,depth+1);graph(in.topology[node*3+2],active,depth+1);active[static_cast<size_t>(node)]=2;
 }
 void callback(int node,int planes){
  if(out.nodes.size()>=static_cast<size_t>(max_callbacks))throw std::runtime_error("BSP callback bound");out.nodes.push_back(node);out.plane_counts.push_back(planes);
  if(in.tiles[node]>=0){out.tiles.push_back(in.tiles[node]);out.tile_nodes.push_back(node);}
 }
 void ordered(int node,int depth){
  if(node<0)return;if(depth>max_depth)throw std::runtime_error("BSP traversal depth bound");callback(node,0);const bool negative=distance(in.planes+node*4,in.camera.data())<=0.f;
  ordered(in.topology[node*3+(negative?2:1)],depth+1);ordered(in.topology[node*3+(negative?1:2)],depth+1);
 }
 void volume(int node,const PlaneList& list,int depth){
  if(node<0)return;if(depth>max_depth)throw std::runtime_error("BSP traversal depth bound");callback(node,list.size);if(in.topology[node*3]!=0)return;
  PlaneList children[2];bool rejected[2]={false,false};const float* split=in.planes+node*4;
  for(int at=list.size-1;at>=0;--at){
   const int plane_id=list.indices[static_cast<size_t>(at)];const float* plane=in.frustum+plane_id*4;int mask=0;
   const int first=in.ranges[node*2],count=in.ranges[node*2+1];
   for(int index=0;index<count;++index){mask|=distance(plane,in.vertices+(first+index)*3)>=0.f?2:1;if(mask==3)break;}
   if(mask==3){children[0].add(plane_id);children[1].add(plane_id);}
   else if(mask==1){const int side=dot(plane,split)<=0.f?0:1;if(!rejected[side])children[side].add(plane_id);}
   else if(mask==2){const int side=dot(plane,split)<=0.f?0:1;rejected[side]=true;if(rejected[1-side])return;children[1-side].add(plane_id);}
  }
  const int near_side=distance(split,in.camera.data())<=0.f?0:1;
  for(int order=0;order<2;++order){const int side=order==0?near_side:1-near_side;if(rejected[side])continue;const int child=in.topology[node*3+1+side];if(children[side].size==0)ordered(child,depth+1);else volume(child,children[side],depth+1);}
 }
 public:
 explicit Collector(const Input& input):in(input){}
 Result collect(){
  if(in.nodes<1||in.nodes>max_nodes||in.root<0||in.root>=in.nodes||in.plane_count<0||in.plane_count>max_planes||in.vertex_floats<0||in.vertex_floats%3)throw std::runtime_error("BSP input bound");
  for(float v:in.camera)if(!std::isfinite(v))throw std::runtime_error("BSP camera nonfinite");
  for(int i=0;i<in.nodes*4;++i)if(!std::isfinite(in.planes[i]))throw std::runtime_error("BSP split nonfinite");
  for(int i=0;i<in.vertex_floats;++i)if(!std::isfinite(in.vertices[i]))throw std::runtime_error("BSP vertex nonfinite");
  for(int i=0;i<in.plane_count*4;++i)if(!std::isfinite(in.frustum[i]))throw std::runtime_error("BSP frustum nonfinite");
  for(int i=0;i<in.nodes;++i){const int leaf=in.topology[i*3],negative=in.topology[i*3+1],positive=in.topology[i*3+2],first=in.ranges[i*2],count=in.ranges[i*2+1];if(leaf<0||leaf>2||negative< -1||negative>=in.nodes||positive< -1||positive>=in.nodes||first<0||count<0||static_cast<int64_t>(first)+count>in.vertex_floats/3||in.tiles[i]< -1||in.tiles[i]>4294967295ll)throw std::runtime_error("BSP node shape");}
  std::vector<uint8_t> active(static_cast<size_t>(in.nodes),0);graph(in.root,active,0);out.nodes.reserve(static_cast<size_t>(in.nodes));out.plane_counts.reserve(static_cast<size_t>(in.nodes));
  PlaneList planes;for(int i=0;i<in.plane_count;++i)planes.add(i);volume(in.root,planes,0);
  const int64_t signed_low=in.snapshot_low>=0x80000000u?static_cast<int64_t>(in.snapshot_low)-4294967296ll:static_cast<int64_t>(in.snapshot_low);const float converted=static_cast<float>(signed_low);const float delta=converted/1000000.f;std::memcpy(&out.delta_word,&delta,4);return out;
 }
};
}
