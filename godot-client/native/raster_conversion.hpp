// Worker-local byte conversion only. Read-only packed inputs, private output,
// no SceneTree/GPU/files/network and no shared Variant key-map access.
namespace raster_conversion {
constexpr size_t maximum_pixels=16777216;
GDExtensionInterfacePackedByteArrayOperatorIndexConst const_element=nullptr;
GDExtensionPtrBuiltInMethod size_method=nullptr;
struct Bytes {
 alignas(8) uint8_t raw[16];
 explicit Bytes(GDExtensionConstVariantPtr value){to[GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY](raw,const_cast<void*>(value));}
 ~Bytes(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(raw);}
 Bytes(const Bytes&)=delete;
 size_t size()const{GDExtensionInt count=0;size_method(const_cast<uint8_t*>(raw),nullptr,&count,0);return count>0?static_cast<size_t>(count):0;}
 const uint8_t* data()const{return size()?const_element(raw,0):nullptr;}
};
bool range(size_t length,size_t at,size_t count){return at<=length&&count<=length-at;}
uint32_t u16(const uint8_t* p){return static_cast<uint32_t>(p[0])|(static_cast<uint32_t>(p[1])<<8);}
uint32_t u32(const uint8_t* p){return u16(p)|(u16(p+2)<<16);}
bool dimensions(uint32_t w,uint32_t h){return w>0&&h>0&&w<32768&&h<32768&&static_cast<uint64_t>(w)*h<=maximum_pixels;}
std::vector<uint8_t> tga(const uint8_t* p,size_t length){
 if(!range(length,0,18))return {};
 const auto kind=p[2],bits=p[16];const auto w=u16(p+12),h=u16(p+14);
 const bool palette=kind==1||kind==9,grey=kind==3||kind==11,rle=kind==9||kind==10||kind==11;
 if(!(kind==1||kind==2||kind==3||kind==9||kind==10||kind==11)||!dimensions(w,h)||!(bits==8||bits==16||bits==24||bits==32))return {};
 const size_t palette_count=u16(p+5),stride=bits/8;
 if((palette&&(p[1]!=1||bits!=8||p[7]!=24||palette_count>256))||(!palette&&p[1]!=0)||(grey&&bits!=8&&bits!=16)||(!palette&&!grey&&bits==8))return {};
 size_t cursor=18+static_cast<size_t>(p[0]),palette_at=cursor;
 if(palette){const size_t size=palette_count*3;if(!range(length,cursor,size))return {};cursor+=size;}
 const size_t count=static_cast<size_t>(w)*h;std::vector<uint8_t> output(count*4);size_t done=0;
 while(done<count){
  size_t run=1;bool repeat=false;
  if(rle){if(!range(length,cursor,1))return {};const auto packet=p[cursor++];run=(packet&127)+1;repeat=(packet&128)!=0;}
  const size_t consumed=stride*(repeat?1:run);
  if(run>count-done||!range(length,cursor,consumed))return {};
  for(size_t item=0;item<run;++item){
   const uint8_t* source=p+cursor+(repeat?0:item*stride);uint8_t* dest=output.data()+(done+item)*4;
   if(palette){const size_t index=source[0];if(index>=palette_count)return {};const auto* entry=p+palette_at+index*3;dest[0]=entry[2];dest[1]=entry[1];dest[2]=entry[0];dest[3]=255;}
   else if(grey){dest[0]=dest[1]=dest[2]=source[0];dest[3]=bits==16?source[1]:255;}
   else if(bits==16){const auto value=u16(source);dest[0]=static_cast<uint8_t>((value&0x7c00)>>7);dest[1]=static_cast<uint8_t>((value&0x3e0)>>2);dest[2]=static_cast<uint8_t>((value&31)<<3);dest[3]=(value&0x8000)?0:255;}
   else{dest[0]=source[2];dest[1]=source[1];dest[2]=source[0];dest[3]=bits==32?source[3]:255;}
  }
  cursor+=consumed;done+=run;
 }
 return output; // Original CResTGA preserves stored order; descriptor is ignored.
}
std::vector<uint8_t> bgra(const uint8_t* p,size_t length,int64_t at,int64_t count,int64_t stride){
 if(at<0||count<1||count>static_cast<int64_t>(maximum_pixels)||(stride!=3&&stride!=4)||!range(length,static_cast<size_t>(at),static_cast<size_t>(count*stride)))return {};
 std::vector<uint8_t> output(static_cast<size_t>(count)*4);const auto* source=p+at;
 for(int64_t pixel=0;pixel<count;++pixel){const auto* s=source+pixel*stride;auto* d=output.data()+pixel*4;d[0]=s[2];d[1]=s[1];d[2]=s[0];d[3]=stride==4?s[3]:255;}
 return output;
}
size_t plt_count(const uint8_t* p,size_t length){
 if(!range(length,0,24)||std::memcmp(p,"PLT V1  ",8)!=0)return 0;
 // Original texture loading ignores header+8 for palette bounds. Declared11
 // is present in shipped inventory icons; pixel selectors still choose colors.
 const auto w=u32(p+16),h=u32(p+20);if(!dimensions(w,h))return 0;
 const size_t count=static_cast<size_t>(w)*h;return range(length,24,count*2)?count:0;
}
int64_t layer_mask(const uint8_t* p,size_t length){
 const size_t count=plt_count(p,length);int64_t mask=0;
 for(size_t pixel=0;pixel<count;++pixel)mask|=int64_t{1}<<std::min<uint8_t>(p[25+pixel*2],9);
 return mask;
}
int64_t layer_order(const uint8_t* p,size_t length){
 const size_t count=plt_count(p,length);int64_t order=0;uint32_t mask=0,shift=0;
 for(size_t pixel=0;pixel<count;++pixel){const auto layer=std::min<uint8_t>(p[25+pixel*2],9);const uint32_t bit=uint32_t{1}<<layer;if(mask&bit)continue;mask|=bit;order|=static_cast<int64_t>(layer+1)<<shift;shift+=4;if(mask==1023)break;}
 return order;
}
std::vector<uint8_t> colorize(const uint8_t* p,size_t length,const uint8_t* lookup,size_t lookup_length){
 const size_t count=plt_count(p,length);if(!count||lookup_length!=10*256*4)return {};
 std::vector<uint8_t> output(count*4);
 for(size_t pixel=0;pixel<count;++pixel){const size_t intensity=p[24+pixel*2],layer=std::min<uint8_t>(p[25+pixel*2],9);std::memcpy(output.data()+pixel*4,lookup+(layer*256+intensity)*4,4);}
 return output;
}
void call_tga(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;std::vector<uint8_t> output;
 if(count==1&&get_type(args[0])==GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY){try{Bytes bytes(args[0]);output=tga(bytes.data(),bytes.size());}catch(const std::exception&){output.clear();}}
 const auto value=byte_array(output);new_copy(result,value.data);
}
void call_bgra(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;std::vector<uint8_t> output;
 if(count==4&&get_type(args[0])==GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY){try{Bytes bytes(args[0]);Var at(args[1]),pixels(args[2]),stride(args[3]);output=bgra(bytes.data(),bytes.size(),at.integer(),pixels.integer(),stride.integer());}catch(const std::exception&){output.clear();}}
 const auto value=byte_array(output);new_copy(result,value.data);
}
void call_mask(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;int64_t mask=0;
 if(count==1&&get_type(args[0])==GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY){try{Bytes bytes(args[0]);mask=layer_mask(bytes.data(),bytes.size());}catch(const std::exception&){mask=0;}}
 const auto value=Var::integer(mask);new_copy(result,value.data);
}
void call_colorize(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;std::vector<uint8_t> output;
 if(count==2&&get_type(args[0])==GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY&&get_type(args[1])==GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY){try{Bytes bytes(args[0]),lookup(args[1]);output=colorize(bytes.data(),bytes.size(),lookup.data(),lookup.size());}catch(const std::exception&){output.clear();}}
 const auto value=byte_array(output);new_copy(result,value.data);
}
void call_order(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;int64_t order=0;
 if(count==1&&get_type(args[0])==GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY){try{Bytes bytes(args[0]);order=layer_order(bytes.data(),bytes.size());}catch(const std::exception&){order=0;}}
 const auto value=Var::integer(order);new_copy(result,value.data);
}
bool bind(GDExtensionInterfaceGetProcAddress address){
 const_element=reinterpret_cast<GDExtensionInterfacePackedByteArrayOperatorIndexConst>(address("packed_byte_array_operator_index_const"));
 Name size("size");size_method=builtin_method(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,size.data,3173160232);return const_element&&size_method;
}
template<class Property>void register_conversion(const Name& name,Property property){
 Name empty(""),bytes("bytes"),offset("offset"),count("count"),stride("stride"),lookup("lookup");
 auto ret=property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,empty);auto integer=property(GDEXTENSION_VARIANT_TYPE_INT,empty);
 GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,bytes),property(GDEXTENSION_VARIANT_TYPE_INT,offset),property(GDEXTENSION_VARIANT_TYPE_INT,count),property(GDEXTENSION_VARIANT_TYPE_INT,stride)};
 GDExtensionClassMethodArgumentMetadata metadata[4]{};GDExtensionClassMethodInfo method{};method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;method.has_return_value=true;method.return_value_info=&ret;method.arguments_info=args;method.arguments_metadata=metadata;
 {Name label("raster_tga");method.name=label.data;method.call_func=call_tga;method.argument_count=1;register_method(library,name.data,&method);}
 {Name label("raster_bgra");method.name=label.data;method.call_func=call_bgra;method.argument_count=4;register_method(library,name.data,&method);}
 {Name label("plt_layer_mask");method.name=label.data;method.call_func=call_mask;method.argument_count=1;method.return_value_info=&integer;register_method(library,name.data,&method);}
 {Name label("plt_layer_order");method.name=label.data;method.call_func=call_order;method.argument_count=1;method.return_value_info=&integer;register_method(library,name.data,&method);}
 {Name label("plt_colorize");args[1]=property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,lookup);method.name=label.data;method.call_func=call_colorize;method.argument_count=2;method.return_value_info=&ret;register_method(library,name.data,&method);}
}
}
