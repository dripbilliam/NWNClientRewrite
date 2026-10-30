// Loader-worker arithmetic only. The two API pointers are bound once before
// scripts/workers start. No shared Variant key map, scene objects or mutation.
namespace animation_keys {
GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst element=nullptr;
GDExtensionPtrBuiltInMethod size_method=nullptr;
struct Pool {
 alignas(8) uint8_t raw[16];
 explicit Pool(GDExtensionConstVariantPtr value){to[GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY](raw,const_cast<void*>(value));}
 ~Pool(){ptr_destructor(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY)(raw);}
 Pool(const Pool&)=delete;
};
bool valid(GDExtensionConstVariantPtr pool,int64_t times,int64_t first,int64_t rows,int64_t stride){
 if(get_type(pool)!=GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY)return false;
 Pool source(pool);GDExtensionInt count=0;size_method(source.raw,nullptr,&count,0);
 if(times<0||first<0||rows<0||rows>1000000||stride<1||stride>12||times>count||first>count||rows>count-times||rows>(count-first)/stride)return false;
 if(rows==0)return true;
 const float* values=element(source.raw,0);if(!values)return false;
 float previous=-1.0f;
 for(int64_t row=0;row<rows;++row){
  const float time=values[times+row];if(!std::isfinite(time)||time<0||time<previous)return false;previous=time;
 }
 const int64_t end=first+rows*stride;
 for(int64_t at=first;at<end;++at)if(!std::isfinite(values[at]))return false;
 return true;
}
void call(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;
 if(count!=5){error->error=count<5?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=5;new_nil(result);return;}
 bool accepted=false;
 try{Var times(args[1]),first(args[2]),rows(args[3]),stride(args[4]);accepted=valid(args[0],times.integer(),first.integer(),rows.integer(),stride.integer());}catch(const std::exception&){accepted=false;}
 auto value=Var::boolean(accepted);new_copy(result,value.data);
}
bool bind(GDExtensionInterfaceGetProcAddress address){
 element=reinterpret_cast<GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst>(address("packed_float32_array_operator_index_const"));
 Name size("size");size_method=builtin_method(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,size.data,3173160232);
 return element&&size_method;
}
template<class Property>void register_validation(const Name& name,Property property){
 Name method_name("animation_keys_valid"),empty(""),pool("values"),times("times"),first("first"),rows("rows"),stride("stride");
 auto ret=property(GDEXTENSION_VARIANT_TYPE_BOOL,empty);
 GDExtensionPropertyInfo arguments[]={property(GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY,pool),property(GDEXTENSION_VARIANT_TYPE_INT,times),property(GDEXTENSION_VARIANT_TYPE_INT,first),property(GDEXTENSION_VARIANT_TYPE_INT,rows),property(GDEXTENSION_VARIANT_TYPE_INT,stride)};
 GDExtensionClassMethodArgumentMetadata metadata[5]{};
 GDExtensionClassMethodInfo method{};method.name=method_name.data;method.call_func=call;method.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;method.has_return_value=true;method.return_value_info=&ret;method.argument_count=5;method.arguments_info=arguments;method.arguments_metadata=metadata;
 register_method(library,name.data,&method);
}
}
