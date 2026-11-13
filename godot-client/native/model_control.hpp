// Main-thread bulk Part arithmetic. Input controller/key dictionaries stay
// immutable; stack floats replace per-operation script arrays. No scene access,
// events, hierarchy reordering, retained worker data or motion-run callbacks.
namespace model_control {
struct Allocations {int64_t arrays=0,bytes=0,result_dictionaries=0;};
struct Pool {
 Var source;std::optional<animation_keys::Pool> packed;const float* direct=nullptr;int64_t length=0;
 explicit Pool(const Var& node):source(get(node,"values88")){
  if(source.type()==GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY){packed.emplace(source.data);GDExtensionInt n=0;animation_keys::size_method(packed->raw,nullptr,&n,0);length=n;if(n)direct=animation_keys::element(packed->raw,0);}
  else if(source.type()==GDEXTENSION_VARIANT_TYPE_ARRAY)length=size(source);
  else throw std::runtime_error("Model controller keys must be an Array or PackedFloat32Array");
 }
 float value(int64_t index)const{
  if(index<0||index>=length)throw std::runtime_error("Model controller key index is outside its immutable pool");
  return direct?direct[index]:static_cast<float>(at(source,index).number());
 }
};
struct Controller {
 int64_t rows,flags,times,first,offset;
 explicit Controller(const Var& c):rows(i(c,"rows4")&65535),flags(i(c,"columnsA")&255),times(i(c,"timeIndex6")&65535),first(i(c,"valueIndex8")&65535),offset(i(c,"displacement0")){}
 Controller(int64_t r,int64_t f,int64_t t,int64_t a,int64_t o):rows(r),flags(f),times(t),first(a),offset(o){}
};
struct Interval {int64_t index;float t;};
template<class Keys>Interval interval(const Controller& c,float time,const Keys& pool){
 int64_t index=0;float t=1.0f;
 while(index<c.rows){if(!(time>pool.value(c.times+index)))break;++index;}
 if(index!=0&&index!=c.rows)t=(time-pool.value(c.times+index-1))/(pool.value(c.times+index)-pool.value(c.times+index-1));
 return {index,t};
}
float bezier(float a,float b,float c,float d,float t){
 const float u=1.0f-t;
 const float middle=u*c+d*t;
 const float left=((u*a+c*t)*u)+middle*t;
 const float right=((u*d+b*t)*t)+middle*u;
 return left*u+right*t;
}
template<class Keys>float scalar(const Controller& c,float time,const Keys& pool){
 const auto range=interval(c,time,pool);const auto index=range.index;const float t=range.t;
 if(index==0)return pool.value(c.first);
 if(index==c.rows){
  if((c.flags&240)==16){const auto at=((index-1)*3+c.first)&65535;return bezier(pool.value(at),pool.value(at+3),pool.value(at+2),pool.value(at+4),time);}
  return pool.value(c.first+c.rows-1);
 }
 if((c.flags&240)==16){const auto at=((index-1)*3+c.first)&65535;const float a=pool.value(at),d=pool.value(at+2);return bezier(a,a+pool.value(at+3),d,d+pool.value(at+4),t);}
 return (1.0f-t)*pool.value(c.first+index-1)+t*pool.value(c.first+index);
}
template<class Keys>V3 vector(const Controller& c,float time,const Keys& pool,float position_scale){
 const auto range=interval(c,time,pool);const auto index=range.index;const float t=range.t,scale=c.offset==16?position_scale:1.0f;V3 result{};
 for(int64_t axis=0;axis<3;++axis){
  if(index==0)result[static_cast<size_t>(axis)]=pool.value((c.first+axis)&65535)*scale;
  else if((c.flags&240)==16){const auto at=((index-1)*9+c.first)&65535;const float a=pool.value(at+axis),b=pool.value(at+9+axis);result[static_cast<size_t>(axis)]=bezier(a,b,a+pool.value(at+6+axis),b+pool.value(at+12+axis),t)*scale;}
  else{const auto at=((index-1)*3+c.first)&65535;const float a=pool.value((at+axis)&65535);result[static_cast<size_t>(axis)]=(index==c.rows?a:pool.value((at+axis+3)&65535)*t+(1.0f-t)*a)*scale;}
 }
 return result;
}
float dot(const Q4& left,const Q4& right){return ((right[0]*left[0]+right[1]*left[1])+right[2]*left[2])+right[3]*left[3];}
Q4 slerp(Q4 left,const Q4& right,float t){
 if(dot(left,right)<0.0f)for(auto& value:left)value=-value;
 const float cosine=dot(left,right);if(std::abs(cosine)>=1.0f)return left;
 const float angle=static_cast<float>(std::acos(static_cast<double>(cosine)));if(angle==0.0f)return left;
 const float scaled=angle*t,denominator=static_cast<float>(std::sin(static_cast<double>(angle)));
 const float b=static_cast<float>(std::sin(static_cast<double>(scaled)))/denominator;
 const float a=static_cast<float>(std::sin(static_cast<double>(angle-scaled)))/denominator;
 Q4 result{};for(size_t axis=0;axis<4;++axis)result[axis]=right[axis]*b+left[axis]*a;return result;
}
template<class Keys>Q4 quaternion_at(const Keys& pool,int64_t at){return {pool.value(at+3),pool.value(at),pool.value(at+1),pool.value(at+2)};}
template<class Keys>Q4 quaternion(const Controller& c,float time,const Keys& pool){
 const auto range=interval(c,time,pool);const auto index=range.index;
 if(index==0)return quaternion_at(pool,c.first);
 if(index==c.rows)return quaternion_at(pool,c.first+index*4-4);
 return slerp(quaternion_at(pool,c.first+index*4-4),quaternion_at(pool,c.first+index*4),range.t);
}
float read(const uint8_t* bytes,int64_t offset){float result;std::memcpy(&result,bytes+offset,4);return result;}
void write(uint8_t* bytes,int64_t offset,float value){std::memcpy(bytes+offset,&value,4);}
void field(const Var& fields,int64_t offset,int64_t components,size_t length){
 if(offset<0||static_cast<uint64_t>(offset)>length||static_cast<uint64_t>(components*4)>length-static_cast<size_t>(offset))throw std::runtime_error("Model controller Part field exceeds its private storage");
 const auto key_value=Var::integer(offset);Var result;destroy(result.data);GDExtensionBool valid=0;get_keyed(fields.data,key_value.data,result.data,&valid);
 if(!valid||result.number()!=static_cast<double>(components))throw std::runtime_error("Model controller Part field does not match its declared component width");
}
Var apply(const Var& node,const Var& bytes,const Var& fields,float time,float weight,float scale,Allocations* allocations=nullptr){
 if(fields.type()!=GDEXTENSION_VARIANT_TYPE_DICTIONARY||bytes.type()!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)throw std::runtime_error("Model controller Part fields/storage are invalid");
 auto controllers=get(node,"controllers78");const auto count=i(node,"controllerCount80");if(count>size(controllers))throw std::runtime_error("Model controller count exceeds its immutable records");
 Pool pool(node);raster_conversion::Bytes source(bytes.data);WritableBytes output(source.size());if(output.length)std::memcpy(output.data,source.data(),output.length);
 if(allocations){++allocations->arrays;allocations->bytes+=static_cast<int64_t>(output.length);}
 for(int64_t index=0;index<count;++index){
  const Controller c(at(controllers,index));const int64_t kind=c.flags&15;if(kind!=1&&kind!=3&&kind!=4)continue;field(fields,c.offset,kind,output.length);
  if(kind==1){const float sampled=scalar(c,time,pool);write(output.data,c.offset,(1.0f-weight)*read(output.data,c.offset)+sampled*weight);}
  else if(kind==3){const auto sampled=vector(c,time,pool,scale);for(size_t axis=0;axis<3;++axis){const auto offset=c.offset+static_cast<int64_t>(axis)*4;write(output.data,offset,(1.0f-weight)*read(output.data,offset)+sampled[axis]*weight);}}
  else{Q4 previous{};for(size_t axis=0;axis<4;++axis)previous[axis]=read(output.data,c.offset+static_cast<int64_t>(axis)*4);const auto value=slerp(previous,quaternion(c,time,pool),weight);for(size_t axis=0;axis<4;++axis)write(output.data,c.offset+static_cast<int64_t>(axis)*4,value[axis]);}
 }
 auto result=Var::dictionary();if(allocations)++allocations->result_dictionaries;set(result,"view",output.publish());return result;
}
void call_apply(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=6){error->error=count<6?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=6;new_nil(result);return;}
 try{const Var node(args[0]),bytes(args[1]),fields(args[2]),time(args[3]),weight(args[4]),scale(args[5]);const auto out=apply(node,bytes,fields,static_cast<float>(time.number()),static_cast<float>(weight.number()),static_cast<float>(scale.number()));new_copy(result,out.data);}
 catch(const std::exception& reason){auto out=Var::dictionary();set(out,"error",Var::text(reason.what()));new_copy(result,out.data);}
}
// Cold regression/inspection entry point. The production bulk path uses the
// same stack samplers, without constructing a result Array per controller.
void call_sample(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=5){error->error=count<5?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=5;new_nil(result);return;}
 try{const Var mode(args[0]),record(args[1]),node(args[2]),time_value(args[3]),scale_value(args[4]);const Controller c(record);const Pool pool(node);const auto kind=mode.integer();const float time=static_cast<float>(time_value.number()),scale=static_cast<float>(scale_value.number());auto out=Var::dictionary();const bool accepted=(c.flags&15)==kind&&(kind==1||kind==3||kind==4);set(out,"result",Var::integer(accepted?1:0));
  if(accepted){if(kind==1)set(out,"value",Var::number(scalar(c,time,pool)));else if(kind==3)set(out,"value",array(vector(c,time,pool,scale)));else set(out,"value",array(quaternion(c,time,pool)));}
  new_copy(result,out.data);
 }catch(const std::exception& reason){auto out=Var::dictionary();set(out,"error",Var::text(reason.what()));new_copy(result,out.data);}
}
template<class Property>void register_methods(const Name& name,Property property){
 Name apply_name("model_control"),sample_name("model_sample"),empty(""),node("node"),view("view"),fields("fields"),time("time"),weight("weight"),scale("position_scale"),mode("kind"),controller("controller");auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);
 GDExtensionPropertyInfo apply_args[]={property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,node),property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,view),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,fields),property(GDEXTENSION_VARIANT_TYPE_FLOAT,time),property(GDEXTENSION_VARIANT_TYPE_FLOAT,weight),property(GDEXTENSION_VARIANT_TYPE_FLOAT,scale)};
 GDExtensionClassMethodArgumentMetadata metadata[6]{};GDExtensionClassMethodInfo method{};method.name=apply_name.data;method.call_func=call_apply;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=6;method.arguments_info=apply_args;method.arguments_metadata=metadata;register_method(library,name.data,&method);
 GDExtensionPropertyInfo sample_args[]={property(GDEXTENSION_VARIANT_TYPE_INT,mode),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,controller),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,node),property(GDEXTENSION_VARIANT_TYPE_FLOAT,time),property(GDEXTENSION_VARIANT_TYPE_FLOAT,scale)};
 method.name=sample_name.data;method.call_func=call_sample;method.argument_count=5;method.arguments_info=sample_args;register_method(library,name.data,&method);
}
}
