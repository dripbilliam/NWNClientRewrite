// Reusable presentation-thread staging. Returned Godot arrays own immutable
// copies so a later frame cannot mutate a queued RenderingServer command.
struct ParticleStreams {
 std::vector<uint8_t> positions,attributes;
 V3 minimum{},maximum{};
 int64_t capacity=0;
 bool first=true;
 void begin(int64_t count,int64_t retained){
  if(retained<0||retained>196608||retained%6)throw std::runtime_error("Invalid retained particle surface capacity");
  capacity=retained;if(count>capacity)capacity=std::min<int64_t>(196608,std::max<int64_t>(96,std::max<int64_t>(capacity*2,count)));
  positions.resize(static_cast<size_t>(capacity)*12);attributes.resize(static_cast<size_t>(capacity)*12);
  // Clear the unused capacity as well: ArrayMesh draws its allocated surface.
  std::fill(positions.begin(),positions.end(),uint8_t{0});std::fill(attributes.begin(),attributes.end(),uint8_t{0});first=true;minimum={};maximum={};
 }
 void write(int64_t index,uint32_t color,const V3& original,float u,float v){
  const V3 point{original[0],original[2],-original[1]};
  if(!std::isfinite(point[0])||!std::isfinite(point[1])||!std::isfinite(point[2])||!std::isfinite(u)||!std::isfinite(v))throw std::runtime_error("Native particle surface has non-finite coordinates");
  const auto offset=static_cast<size_t>(index)*12;std::memcpy(positions.data()+offset,point.data(),12);std::memcpy(attributes.data()+offset,&color,4);std::memcpy(attributes.data()+offset+4,&u,4);std::memcpy(attributes.data()+offset+8,&v,4);
  if(first){minimum=maximum=point;first=false;}else for(size_t j=0;j<3;++j){minimum[j]=std::min(minimum[j],point[j]);maximum[j]=std::max(maximum[j],point[j]);}
 }
 Var finish(int64_t count){
  auto out=Var::dictionary();set(out,"count",Var::integer(count));set(out,"capacity",Var::integer(capacity));set(out,"positions",byte_array(positions));set(out,"attributes",byte_array(attributes));
  set(out,"bounds",array(std::array<float,6>{minimum[0],minimum[1],minimum[2],maximum[0]-minimum[0],maximum[1]-minimum[1],maximum[2]-minimum[2]}));return out;
 }
};
