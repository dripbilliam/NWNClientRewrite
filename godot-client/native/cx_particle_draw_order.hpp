namespace cx_particle {
using particle_presentation::Material;
using particle_presentation::Range;

// This layout is owned by the render thread. The packet's record addresses
// stay with their emitters, even when indices from one draw interleave.
struct DrawOrder {
 static constexpr size_t no_span=SIZE_MAX;
 struct Group {
  std::shared_ptr<const Material> material;
  size_t first=no_span,last=no_span;
 };
 struct Span {uint32_t first,count;size_t next=no_span;};
 struct DepthKey {float distance;uint32_t index;};
 std::array<std::vector<Group>,3> groups;
 std::array<std::unordered_map<uint64_t,size_t>,4> commutative_materials;
 std::vector<Span> spans;
 std::vector<DepthKey> depth_keys;
 std::vector<uint32_t> indices;
 std::vector<Range> draws;
 int64_t generation=-1;
 V3 eye{};
 size_t sorted_groups=0;

 static size_t blend_class(const Material& material){
  return material.punch_through?0:material.additive?2:1;
 }
 static bool same_material(const Material& a,const Material& b){
  return a.rid==b.rid&&a.two_sided==b.two_sided;
 }
 void append_span(Group& group,const Range& range){
  const size_t slot=spans.size();
  spans.push_back({static_cast<uint32_t>(range.first/6),static_cast<uint32_t>(range.count/6)});
  if(group.last==no_span)group.first=slot;
  else spans[group.last].next=slot;
  group.last=slot;
 }
 void append_draw(const Group& group,const uint8_t* records,bool sort_depth){
  const auto first=indices.size();
  for(auto next=group.first;next!=no_span;next=spans[next].next){
   const auto& span=spans[next];
   for(uint32_t n=0;n<span.count;++n)indices.push_back(span.first+n);
  }
  const auto count=indices.size()-first;
  if(sort_depth&&count>1){
   depth_keys.clear();depth_keys.reserve(count);
   for(size_t n=first;n<indices.size();++n){
    const auto index=indices[n];
    V3 center;
    std::memcpy(center.data(),records+static_cast<size_t>(index)*sizeof(Record)+offsetof(Record,center),sizeof(center));
    const auto x=center[0]-eye[0],y=center[1]-eye[1],z=center[2]-eye[2];
    depth_keys.push_back({(x*x+y*y)+z*z,index});
   }
   std::sort(depth_keys.begin(),depth_keys.end(),[](const DepthKey& a,const DepthKey& b){
    return a.distance==b.distance?a.index<b.index:a.distance>b.distance;
   });
   for(size_t n=0;n<count;++n)indices[first+n]=depth_keys[n].index;
   ++sorted_groups;
  }
  draws.push_back({0,static_cast<int64_t>(first*6),static_cast<int64_t>(count*6),0,{},{},false,group.material});
 }
 void build(const particle_presentation::Packet& frame,const V3& current_eye,bool batch){
  generation=frame.generation;eye=current_eye;sorted_groups=0;
  for(auto& list:groups)list.clear();
  for(auto& lookup:commutative_materials)lookup.clear();
  spans.clear();indices.clear();draws.clear();
  bool last_alpha=false;
  const auto records=particle_presentation::SceneBytes(frame.vertices);
  if(records.size()!=static_cast<int64_t>(frame.raster_bytes(frame.count)))
   throw std::runtime_error("CX particle record packet length differs");
  const auto* record_data=records.data();
  for(const auto& range:frame.ranges){
   if(!range.count)continue;
   if(range.first<0||range.count<0||range.first%6||range.count%6||range.first+range.count>frame.count)
    throw std::runtime_error("CX particle range lies outside its record packet");
   const auto& material=*range.material;
   const auto cls=blend_class(material);
   if(!batch){
    Group group{range.material};
    append_span(group,range);
    append_draw(group,record_data,cls==1);
    continue;
   }
   auto& list=groups[cls];
   if(cls==1){
    if(!last_alpha||!same_material(*list.back().material,material))list.push_back({range.material});
    append_span(list.back(),range);
   }else{
    const auto cache=(cls==0?0:2)+(material.two_sided?1:0);
    auto [entry,inserted]=commutative_materials[cache].try_emplace(material.rid,list.size());
    if(inserted)list.push_back({range.material});
    append_span(list[entry->second],range);
   }
   last_alpha=cls==1;
  }
  for(size_t cls=0;cls<groups.size();++cls)
   for(const auto& group:groups[cls])append_draw(group,record_data,cls==1);
  if(indices.size()*6!=static_cast<size_t>(frame.visible_vertices))
   throw std::runtime_error("CX particle order did not cover every visible record");
 }
};
} // namespace cx_particle
