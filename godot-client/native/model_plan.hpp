// Private immutable animation-tree snapshot. It contains only numeric records
// and original binary32 key pools, never scene pointers, clocks or Part state.
// All dynamic Part/manual/lifetime decisions remain on the main-thread owner.
namespace model_plan {
constexpr uint32_t magic=0x4e574d50,version=1,header_bytes=64,record_limit=1000000,key_limit=16777216;
uint32_t read32(const uint8_t* p){uint32_t value;std::memcpy(&value,p,4);return value;}
void write32(uint8_t* p,uint32_t value){std::memcpy(p,&value,4);}
struct Node {int64_t id=0;uint32_t flags=0,child_first=0,child_count=0,control_first=0,control_count=0,pool=UINT32_MAX;};
struct Keys {
 const uint8_t* bytes;uint32_t length;
 float value(int64_t at)const{if(at<0||static_cast<uint64_t>(at)>=length)throw std::runtime_error("Prepared model key is outside its immutable pool");float v;std::memcpy(&v,bytes+static_cast<size_t>(at)*4,4);return v;}
};
struct View {
 raster_conversion::Bytes storage;const uint8_t* bytes;uint32_t nodes,controllers,pools,children,floats,node_at,control_at,pool_at,child_at,float_at;
 explicit View(const Var& input):storage(input.data),bytes(storage.data()){
  const auto size=storage.size();if(input.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY||size<header_bytes||read32(bytes)!=magic||read32(bytes+4)!=version)throw std::runtime_error("Prepared model plan header is invalid");
  nodes=read32(bytes+8);controllers=read32(bytes+12);pools=read32(bytes+16);children=read32(bytes+20);floats=read32(bytes+24);
  if(!nodes||nodes>record_limit||controllers>record_limit||pools>record_limit||children>record_limit||floats>key_limit)throw std::runtime_error("Prepared model plan exceeds its record limits");
  node_at=read32(bytes+28);control_at=read32(bytes+32);pool_at=read32(bytes+36);child_at=read32(bytes+40);float_at=read32(bytes+44);
  const uint64_t c=header_bytes+static_cast<uint64_t>(nodes)*32,p=c+static_cast<uint64_t>(controllers)*20,h=p+static_cast<uint64_t>(pools)*8,f=h+static_cast<uint64_t>(children)*4,end=f+static_cast<uint64_t>(floats)*4;
  if(node_at!=header_bytes||control_at!=c||pool_at!=p||child_at!=h||float_at!=f||end!=size||read32(bytes+48)!=size||read32(bytes+52)!=0||read32(bytes+56)!=0||read32(bytes+60)!=0)throw std::runtime_error("Prepared model plan table bounds are invalid");
 }
 Node node(uint32_t index)const{
  if(index>=nodes)throw std::runtime_error("Prepared model node is outside its table");const auto* p=bytes+node_at+static_cast<size_t>(index)*32;Node n;const uint64_t id=read32(p)|(static_cast<uint64_t>(read32(p+4))<<32);std::memcpy(&n.id,&id,8);
  n.flags=read32(p+8);n.child_first=read32(p+12);n.child_count=read32(p+16);n.control_first=read32(p+20);n.control_count=read32(p+24);n.pool=read32(p+28);
  if(n.child_first>children||n.child_count>children-n.child_first||n.control_first>controllers||n.control_count>controllers-n.control_first||(n.control_count&&n.pool>=pools))throw std::runtime_error("Prepared model node ranges are invalid");return n;
 }
 uint32_t child(uint32_t index)const{if(index>=children)throw std::runtime_error("Prepared model child index is invalid");const auto result=read32(bytes+child_at+static_cast<size_t>(index)*4);if(result>=nodes)throw std::runtime_error("Prepared model child identity is invalid");return result;}
 model_control::Controller controller(uint32_t index)const{
  if(index>=controllers)throw std::runtime_error("Prepared model controller index is invalid");const auto* p=bytes+control_at+static_cast<size_t>(index)*20;const auto rows=read32(p),flags=read32(p+4),times=read32(p+8),first=read32(p+12);int32_t offset;std::memcpy(&offset,p+16,4);
  if(rows>65535||flags>255||times>65535||first>65535)throw std::runtime_error("Prepared model controller fields are invalid");return {rows,flags,times,first,offset};
 }
 Keys keys(uint32_t index)const{
  if(index>=pools)throw std::runtime_error("Prepared model pool identity is invalid");const auto* p=bytes+pool_at+static_cast<size_t>(index)*8;const auto first=read32(p),count=read32(p+4);if(first>floats||count>floats-first)throw std::runtime_error("Prepared model pool bounds are invalid");return {bytes+float_at+static_cast<size_t>(first)*4,count};
 }
};
struct BuildPool {Var source;const float* identity=nullptr;std::vector<float> values;explicit BuildPool(const Var& v):source(v){}};
struct Builder {
 std::vector<Node> nodes;std::vector<model_control::Controller> controllers;std::vector<BuildPool> pools;std::vector<uint32_t> children;uint32_t total_keys=0;int64_t packed_pools=0,array_pools=0;
 uint32_t pool(const Var& node){
  model_control::Pool input(node);const auto& source=input.source;
  // Packed-array value equality must not merge distinct IEEE payloads (such
  // as +0/-0). Compare their retained backing identity during cold preparation.
  // No borrowed key pointer is serialized or retained after this Builder dies.
  for(size_t n=0;n<pools.size();++n){const auto& p=pools[n];if(p.source.type()!=source.type())continue;if(source.type()==GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY){if(p.identity==input.direct&&p.values.size()==static_cast<uint64_t>(input.length))return static_cast<uint32_t>(n);}else if(visual_selection::same(p.source,source))return static_cast<uint32_t>(n);}
  if(input.length<0||static_cast<uint64_t>(input.length)>key_limit-total_keys||pools.size()>=record_limit)throw std::runtime_error("Prepared model key pool exceeds allocation limit");
  BuildPool p(source);p.identity=input.direct;if(input.length){if(input.direct)p.values.assign(input.direct,input.direct+input.length);else{p.values.reserve(static_cast<size_t>(input.length));for(int64_t n=0;n<input.length;++n)p.values.push_back(input.value(n));}}
  total_keys+=static_cast<uint32_t>(input.length);if(source.type()==GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY)++packed_pools;else ++array_pools;pools.push_back(std::move(p));return static_cast<uint32_t>(pools.size()-1);
 }
 uint32_t visit(const Var& source,uint32_t depth){
  if(nodes.size()>=record_limit)throw std::runtime_error("Prepared model node count exceeds allocation limit");const auto index=static_cast<uint32_t>(nodes.size());nodes.emplace_back();Node node;
  const auto id=get(source,"id34").number();if(!std::isfinite(id)||std::trunc(id)!=id||id<INT32_MIN||id>UINT32_MAX)throw std::runtime_error("Prepared model node identity is outside the original dword schema");node.id=static_cast<int64_t>(id);node.flags=word32(source,"flags98");
  const auto count=(node.flags&128)?0:i(source,"controllerCount80");if(count<0||static_cast<uint64_t>(count)>record_limit-controllers.size())throw std::runtime_error("Prepared model controller count is invalid");node.control_first=static_cast<uint32_t>(controllers.size());node.control_count=static_cast<uint32_t>(count);
  if(count){auto records=get(source,"controllers78");if(count>size(records))throw std::runtime_error("Prepared model count exceeds its source controllers");node.pool=pool(source);for(int64_t n=0;n<count;++n)controllers.emplace_back(at(records,n));}
  std::vector<uint32_t> next;
  if(depth<1000){const auto child_count=i(source,"childCount70");if(child_count>0){auto values=get(source,"children68");if(child_count>size(values)||static_cast<uint64_t>(child_count)>record_limit-children.size())throw std::runtime_error("Prepared model child count is invalid");next.reserve(static_cast<size_t>(child_count));for(int64_t n=0;n<child_count;++n)next.push_back(visit(at(values,n),depth+1));}}
  if(next.size()>record_limit-children.size())throw std::runtime_error("Prepared model children exceed allocation limit");node.child_first=static_cast<uint32_t>(children.size());node.child_count=static_cast<uint32_t>(next.size());children.insert(children.end(),next.begin(),next.end());nodes[index]=node;return index;
 }
 Var publish()const{
  const uint32_t node_at=header_bytes,control_at=node_at+static_cast<uint32_t>(nodes.size())*32,pool_at=control_at+static_cast<uint32_t>(controllers.size())*20,child_at=pool_at+static_cast<uint32_t>(pools.size())*8,float_at=child_at+static_cast<uint32_t>(children.size())*4,total=float_at+total_keys*4;
  WritableBytes output(total);std::memset(output.data,0,header_bytes);const std::array<uint32_t,13> header{magic,version,static_cast<uint32_t>(nodes.size()),static_cast<uint32_t>(controllers.size()),static_cast<uint32_t>(pools.size()),static_cast<uint32_t>(children.size()),total_keys,node_at,control_at,pool_at,child_at,float_at,total};for(size_t n=0;n<header.size();++n)write32(output.data+n*4,header[n]);
  for(size_t n=0;n<nodes.size();++n){auto* p=output.data+node_at+n*32;const auto& node=nodes[n];uint64_t id;std::memcpy(&id,&node.id,8);const std::array<uint32_t,8> values{static_cast<uint32_t>(id),static_cast<uint32_t>(id>>32),node.flags,node.child_first,node.child_count,node.control_first,node.control_count,node.pool};for(size_t k=0;k<values.size();++k)write32(p+k*4,values[k]);}
  for(size_t n=0;n<controllers.size();++n){auto* p=output.data+control_at+n*20;const auto& c=controllers[n];const std::array<uint32_t,5> values{static_cast<uint32_t>(c.rows),static_cast<uint32_t>(c.flags),static_cast<uint32_t>(c.times),static_cast<uint32_t>(c.first),static_cast<uint32_t>(c.offset)};for(size_t k=0;k<values.size();++k)write32(p+k*4,values[k]);}
  uint32_t first=0;for(size_t n=0;n<pools.size();++n){auto* p=output.data+pool_at+n*8;const auto& values=pools[n].values;write32(p,first);write32(p+4,static_cast<uint32_t>(values.size()));if(!values.empty())std::memcpy(output.data+float_at+static_cast<size_t>(first)*4,values.data(),values.size()*4);first+=static_cast<uint32_t>(values.size());}
  for(size_t n=0;n<children.size();++n)write32(output.data+child_at+n*4,children[n]);return output.publish();
 }
};
template<class Validate>void update(const View& plan,const Node& node,uint8_t* output,float time,float weight,float scale,Validate validate){
 const auto pool=plan.keys(node.pool);
 for(uint32_t n=0;n<node.control_count;++n){const auto c=plan.controller(node.control_first+n);const auto kind=c.flags&15;if(kind!=1&&kind!=3&&kind!=4)continue;validate(c.offset,kind);
  if(kind==1){const auto value=model_control::scalar(c,time,pool);model_control::write(output,c.offset,(1.0f-weight)*model_control::read(output,c.offset)+value*weight);}
  else if(kind==3){const auto value=model_control::vector(c,time,pool,scale);for(size_t axis=0;axis<3;++axis){const auto offset=c.offset+static_cast<int64_t>(axis)*4;model_control::write(output,offset,(1.0f-weight)*model_control::read(output,offset)+value[axis]*weight);}}
  else{Q4 previous{};for(size_t axis=0;axis<4;++axis)previous[axis]=model_control::read(output,c.offset+static_cast<int64_t>(axis)*4);const auto value=model_control::slerp(previous,model_control::quaternion(c,time,pool),weight);for(size_t axis=0;axis<4;++axis)model_control::write(output,c.offset+static_cast<int64_t>(axis)*4,value[axis]);}
 }
}
Var apply(const View& plan,const Node& node,const Var& bytes,const Var& fields,float time,float weight,float scale,model_control::Allocations* allocations=nullptr){
 if(fields.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||bytes.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)throw std::runtime_error("Prepared model Part fields/storage are invalid");
 raster_conversion::Bytes source(bytes.data);WritableBytes output(source.size());if(output.length)std::memcpy(output.data,source.data(),output.length);
 if(allocations){++allocations->arrays;allocations->bytes+=static_cast<int64_t>(output.length);}
 update(plan,node,output.data,time,weight,scale,[&](int64_t offset,int64_t kind){model_control::field(fields,offset,kind,output.length);});return output.publish();
}
void call_prepare(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=1){error->error=count<1?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=1;new_nil(result);return;}
 try{const auto began=std::chrono::steady_clock::now();Builder builder;builder.visit(Var(args[0]),1);auto out=Var::dictionary();set(out,"plan",builder.publish());set(out,"nodes",Var::integer(static_cast<int64_t>(builder.nodes.size())));set(out,"controllers",Var::integer(static_cast<int64_t>(builder.controllers.size())));set(out,"pools",Var::integer(static_cast<int64_t>(builder.pools.size())));set(out,"key_floats",Var::integer(builder.total_keys));set(out,"packed_pools",Var::integer(builder.packed_pools));set(out,"array_pools",Var::integer(builder.array_pools));set(out,"prepare_ms",Var::number(std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-began).count()));new_copy(result,out.data);}
 catch(const std::exception& reason){auto out=Var::dictionary();set(out,"error",Var::text(reason.what()));new_copy(result,out.data);}
}
template<class Property>void register_method_info(const Name& name,Property property){Name method_name("model_prepare"),empty(""),source("source");auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);auto arg=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,source);GDExtensionClassMethodArgumentMetadata metadata{};GDExtensionClassMethodInfo method{};method.name=method_name.data;method.call_func=call_prepare;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=1;method.arguments_info=&arg;method.arguments_metadata=&metadata;register_method(library,name.data,&method);}
}
