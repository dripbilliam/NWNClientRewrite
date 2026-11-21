// Reusable presentation-thread staging. Returned Godot arrays own immutable
// copies so a later frame cannot mutate a queued RenderingServer command.
struct ParticleStreams {
 std::vector<uint8_t> positions,attributes;
 // A scene presentation pass may supply one exact, active-only slice of its
 // uniquely owned frame buffer. No per-emitter packed arrays or tail clears.
 struct DirectRange {uint8_t* data=nullptr;int64_t vertices=0,written=0;bool instances=false;};
 DirectRange* direct=nullptr;
 struct DirectScope {ParticleStreams& owner;DirectRange* prior;DirectScope(ParticleStreams& value,DirectRange& range):owner(value),prior(value.direct){owner.direct=&range;}~DirectScope(){owner.direct=prior;}};
 // Experimental instance records retain all four exact corners. The shader
 // selects them; it does not recompute or approximate the original geometry.
 std::optional<WritableBytes> instance_bytes;
 bool instances=false;
 struct PacketScope {ParticleStreams* owner;~PacketScope(){if(owner)owner->instance_bytes.reset();}};
 struct FormatScope {ParticleStreams* owner;bool prior;explicit FormatScope(ParticleStreams* value):owner(value),prior(value->instances){}~FormatScope(){owner->instances=prior;}};
 V3 minimum{},maximum{};
 int64_t capacity=0;
 bool first=true;
 void begin(int64_t count,int64_t retained){
  if(direct){if(count<0||count%6||count!=direct->vertices||(count&&!direct->data))throw std::runtime_error("Particle shared range count mismatch");capacity=count;first=true;minimum={};maximum={};return;}
  if(retained<0||retained>196608||retained%6)throw std::runtime_error("Invalid retained particle surface capacity");
  capacity=retained;if(count>capacity)capacity=std::min<int64_t>(196608,std::max<int64_t>(96,std::max<int64_t>(capacity*2,count)));
  if(instances){if(count<0||count%6||count>capacity)throw std::runtime_error("Invalid active particle instance count");instance_bytes.emplace(static_cast<size_t>(count/6)*80);first=true;minimum={};maximum={};return;}
  positions.resize(static_cast<size_t>(capacity)*12);attributes.resize(static_cast<size_t>(capacity)*12);
  // Clear the unused capacity as well: ArrayMesh draws its allocated surface.
  std::fill(positions.begin(),positions.end(),uint8_t{0});std::fill(attributes.begin(),attributes.end(),uint8_t{0});first=true;minimum={};maximum={};
 }
 void write(int64_t index,uint32_t color,const V3& original,float u,float v){
  const V3 point{original[0],original[2],-original[1]};
  if(!std::isfinite(point[0])||!std::isfinite(point[1])||!std::isfinite(point[2])||!std::isfinite(u)||!std::isfinite(v))throw std::runtime_error("Native particle surface has non-finite coordinates");
  if(direct&&!direct->instances){
   if(index<0||index>=direct->vertices)throw std::runtime_error("Particle shared write outside active range");
   auto* target=direct->data+static_cast<size_t>(index)*24;std::memcpy(target,&color,4);std::memcpy(target+4,point.data(),12);std::memcpy(target+16,&u,4);std::memcpy(target+20,&v,4);
  }else if(instances||(direct&&direct->instances)){
   const auto corner=index%6;if(corner==3||corner==4)return;
   const auto offset=static_cast<size_t>(index/6)*80;const auto column=corner==5?3:corner;
   auto* output=direct?direct->data:(instance_bytes?instance_bytes->data:nullptr);const auto length=direct?static_cast<size_t>(direct->vertices/6)*80:(instance_bytes?instance_bytes->length:0);
   if(!output||offset+80>length)throw std::runtime_error("Particle instance write outside owned packet");
   const auto put=[&](size_t field,float value){std::memcpy(output+offset+field*4,&value,4);};
   // MultiMesh's packed transform is three rows of four floats. MODEL_MATRIX
   // therefore exposes the four authored corner positions as its columns.
   for(size_t axis=0;axis<3;++axis)put(axis*4+static_cast<size_t>(column),point[axis]);
   if(corner==0){put(12,static_cast<float>(color&1023));put(13,static_cast<float>((color>>10)&1023));put(14,static_cast<float>((color>>20)&1023));put(15,static_cast<float>(color>>30));put(17,u);put(19,v);}
   else if(corner==1)put(16,u);
   else if(corner==2){float upper;std::memcpy(&upper,output+offset+60,4);put(15,upper+static_cast<float>((color>>24)<<2));put(18,v);}
  }else{
   const auto offset=static_cast<size_t>(index)*12;std::memcpy(positions.data()+offset,point.data(),12);std::memcpy(attributes.data()+offset,&color,4);std::memcpy(attributes.data()+offset+4,&u,4);std::memcpy(attributes.data()+offset+8,&v,4);
  }
  if(first){minimum=maximum=point;first=false;}else for(size_t j=0;j<3;++j){minimum[j]=std::min(minimum[j],point[j]);maximum[j]=std::max(maximum[j],point[j]);}
 }
 Var finish(int64_t count){
  if(direct){if(count!=direct->vertices)throw std::runtime_error("Particle shared range publication mismatch");direct->written=count;return {};}
  auto out=Var::dictionary();set(out,"count",Var::integer(count));set(out,"capacity",Var::integer(capacity));if(instances){if(!instance_bytes||instance_bytes->length!=static_cast<size_t>(count/6)*80)throw std::runtime_error("Particle packet count mismatch");set(out,"instances",instance_bytes->publish());instance_bytes.reset();}else{set(out,"positions",byte_array(positions));set(out,"attributes",byte_array(attributes));}
  set(out,"bounds",array(std::array<float,6>{minimum[0],minimum[1],minimum[2],maximum[0]-minimum[0],maximum[1]-minimum[1],maximum[2]-minimum[2]}));return out;
 }
};
