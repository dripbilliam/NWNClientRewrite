// Bounds-checked worker-local resource metadata parsing. No files, scenes,
// network, mutable shared keys or persistent instance state. Inputs and output
// layouts match archive_index.gd / nwsync_store.gd reference implementations.
#include "gdextension_interface.h"
#include <cstdint>
#include <cstring>
#include <string>
#include <string_view>
#include <stdexcept>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <limits>
namespace {
GDExtensionClassLibraryPtr library;
GDExtensionInterfaceVariantNewNil new_nil;
GDExtensionInterfaceVariantNewCopy new_copy;
GDExtensionInterfaceVariantDestroy destroy;
GDExtensionInterfaceVariantGetType get_type;
GDExtensionInterfaceVariantGetKeyed get_keyed;
GDExtensionInterfaceVariantSetKeyed set_keyed;
GDExtensionInterfaceVariantGetIndexed get_indexed;
GDExtensionInterfaceVariantCall variant_call;
GDExtensionInterfaceVariantConstruct construct;
GDExtensionInterfaceGetVariantFromTypeConstructor from_type;
GDExtensionInterfaceGetVariantToTypeConstructor to_type;
GDExtensionInterfaceVariantGetPtrDestructor destructor;
GDExtensionInterfaceVariantGetPtrBuiltinMethod builtin_method;
GDExtensionInterfacePackedByteArrayOperatorIndexConst const_element;
GDExtensionInterfaceStringNameNewWithUtf8Chars name_new;
GDExtensionInterfaceStringNewWithUtf8Chars string_new;
GDExtensionInterfaceStringToUtf8Chars string_utf8;
GDExtensionInterfaceClassdbRegisterExtensionClass6 register_class;
GDExtensionInterfaceClassdbRegisterExtensionClassMethod register_method;
GDExtensionInterfaceClassdbUnregisterExtensionClass unregister_class;
GDExtensionVariantFromTypeConstructorFunc from[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX];
GDExtensionTypeFromVariantConstructorFunc to[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX];
GDExtensionPtrBuiltInMethod byte_size;
GDExtensionInterfaceVariantIterInit iter_init;
GDExtensionInterfaceVariantIterNext iter_next;
GDExtensionInterfaceVariantIterGet iter_get;
GDExtensionInterfaceArrayOperatorIndexConst array_at;
GDExtensionInterfaceDictionaryOperatorIndexConst dictionary_at;
GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst float32_at;
GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst float64_at;
GDExtensionInterfacePackedInt32ArrayOperatorIndexConst int32_at;
GDExtensionInterfacePackedInt64ArrayOperatorIndexConst int64_at;
GDExtensionInterfacePackedStringArrayOperatorIndexConst strings_at;
GDExtensionInterfacePackedVector2ArrayOperatorIndexConst vector2_at;
GDExtensionInterfacePackedVector3ArrayOperatorIndexConst vector3_at;
GDExtensionInterfacePackedVector4ArrayOperatorIndexConst vector4_at;
GDExtensionInterfacePackedColorArrayOperatorIndexConst colors_at;
GDExtensionPtrBuiltInMethod lengths[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};
GDExtensionInterfaceStringOperatorIndexConst string_at;
GDExtensionInterfaceStringNewWithUtf32CharsAndLen string_new32;
GDExtensionInterfaceArrayOperatorIndex array_mutable;
struct Name{
 alignas(8) uint8_t data[8];explicit Name(const char* value){name_new(data,value);}~Name(){destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME)(data);}Name(const Name&)=delete;
};
struct Var{
 alignas(8) uint8_t data[24];Var(){new_nil(data);}explicit Var(GDExtensionConstVariantPtr source){new_copy(data,source);}Var(const Var& other){new_copy(data,other.data);}Var(Var&& other)noexcept{new_copy(data,other.data);}~Var(){destroy(data);}
 Var& operator=(const Var& other){if(this!=&other){destroy(data);new_copy(data,other.data);}return *this;}
 static Var text(const std::string& value){alignas(8) uint8_t raw[8];string_new(raw,value.c_str());Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_STRING](v.data,raw);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(raw);return v;}
 static Var name(const char* value){Name raw(value);Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_STRING_NAME](v.data,raw.data);return v;}
 static Var integer(int64_t value){Var v;destroy(v.data);from[GDEXTENSION_VARIANT_TYPE_INT](v.data,&value);return v;}
 static Var container(GDExtensionVariantType type){Var v;destroy(v.data);GDExtensionCallError error{};construct(type,v.data,nullptr,0,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Native resource container construction failed");return v;}
 int64_t integer()const{if(get_type(data)!=GDEXTENSION_VARIANT_TYPE_INT)throw std::runtime_error("Native resource integer required");int64_t value;to[GDEXTENSION_VARIANT_TYPE_INT](&value,const_cast<uint8_t*>(data));return value;}
 std::string text()const{if(get_type(data)!=GDEXTENSION_VARIANT_TYPE_STRING)throw std::runtime_error("Native resource string required");alignas(8) uint8_t raw[8];to[GDEXTENSION_VARIANT_TYPE_STRING](raw,const_cast<uint8_t*>(data));const auto length=string_utf8(raw,nullptr,0);std::string value(static_cast<size_t>(length),'\0');string_utf8(raw,value.data(),length);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(raw);return value;}
};
void put(Var& dict,const Var& key,const Var& value){GDExtensionBool valid=0;set_keyed(dict.data,key.data,value.data,&valid);if(!valid)throw std::runtime_error("Native resource dictionary assignment failed");}
Var get(const Var& dict,const Var& key){Var result;destroy(result.data);GDExtensionBool valid=0;get_keyed(dict.data,key.data,result.data,&valid);if(!valid)throw std::runtime_error("Native resource option is missing");return result;}
Var indexed(const Var& array,size_t index){Var result;destroy(result.data);GDExtensionBool valid=0,oob=0;get_indexed(array.data,static_cast<int64_t>(index),result.data,&valid,&oob);if(!valid||oob)throw std::runtime_error("KEY references a missing BIF");return result;}
void append(Var& array,const Var& value){Name method("append");GDExtensionConstVariantPtr args[]={value.data};Var result;destroy(result.data);GDExtensionCallError error{};variant_call(array.data,method.data,args,1,result.data,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("Native resource array append failed");}
struct Bytes{
 alignas(8) uint8_t raw[16];size_t length=0;
 explicit Bytes(const Var& value){if(get_type(value.data)!=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)throw std::runtime_error("Native resource byte table required");to[GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY](raw,const_cast<uint8_t*>(value.data));GDExtensionInt count=0;byte_size(raw,nullptr,&count,0);length=static_cast<size_t>(count);}
 ~Bytes(){destructor(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY)(raw);}Bytes(const Bytes&)=delete;
 const uint8_t* at(size_t offset,size_t count)const{if(offset>length||count>length-offset)throw std::runtime_error("Native resource table exceeds bounds");return count?const_element(raw,static_cast<GDExtensionInt>(offset)):nullptr;}
 uint32_t u16(size_t at_)const{const auto* p=at(at_,2);return uint32_t(p[0])|(uint32_t(p[1])<<8);}
 uint32_t u32(size_t at_)const{const auto* p=at(at_,4);return uint32_t(p[0])|(uint32_t(p[1])<<8)|(uint32_t(p[2])<<16)|(uint32_t(p[3])<<24);}
};
// Use only documented read-only element pointers as per-call storage identities.
// No private Godot container layout, pointers between calls, content hashing,
// data serialization, or global identity/ownership table is involved.
struct Raw{
 alignas(8) uint8_t data[64];GDExtensionVariantType type;
 Raw(GDExtensionConstVariantPtr value,GDExtensionVariantType t):type(t){to[t](data,const_cast<void*>(value));}
 ~Raw(){destructor(type)(data);}Raw(const Raw&)=delete;
 int64_t size()const{GDExtensionInt n=0;lengths[type](const_cast<uint8_t*>(data),nullptr,&n,0);return n;}
};
#include "two_da_parser.hpp"
struct Cost{
 uint64_t bytes=0,nodes=0,shared=0;uint64_t limit;bool bounded=false;
 std::unordered_map<const void*,uint64_t> seen;
 std::unordered_set<std::string> names;
 explicit Cost(uint64_t maximum):limit(maximum){}
 void add(uint64_t n){if(n>limit-bytes){bytes=limit+1;bounded=true;}else bytes+=n;}
 bool first(const void* identity,GDExtensionVariantType type){const auto bit=uint64_t(1)<<type;auto& mask=seen[identity];if(mask&bit){++shared;return false;}mask|=bit;return true;}
 void visit(GDExtensionConstVariantPtr value,unsigned depth=0){
  if(bounded)return;if(depth>128||++nodes>4000000)throw std::runtime_error("Native resource accounting traversal bound exceeded");
  const auto type=get_type(value);
  if(type==GDEXTENSION_VARIANT_TYPE_OBJECT||type==GDEXTENSION_VARIANT_TYPE_CALLABLE||type==GDEXTENSION_VARIANT_TYPE_SIGNAL||type==GDEXTENSION_VARIANT_TYPE_RID)throw std::runtime_error("Native resource accounting accepts data only");
  if(type==GDEXTENSION_VARIANT_TYPE_STRING){Raw raw(value,type);const auto length=raw.size();if(length>0&&!first(string_at(raw.data,0),type))return;add(length>0?96+static_cast<uint64_t>(length)*8:32);return;}
  if(type==GDEXTENSION_VARIANT_TYPE_STRING_NAME){
   // StringName is globally interned. Compare its text, not an undocumented
   // internal pointer or an address belonging to a temporary conversion.
   Var converted;destroy(converted.data);GDExtensionCallError error{};GDExtensionConstVariantPtr args[]={value};construct(GDEXTENSION_VARIANT_TYPE_STRING,converted.data,args,1,&error);if(error.error!=GDEXTENSION_CALL_OK)throw std::runtime_error("StringName accounting conversion failed");const auto name=converted.text();if(!names.emplace(name).second){++shared;return;}add(96+name.size()*8);return;
  }
  if(type==GDEXTENSION_VARIANT_TYPE_ARRAY){
   Raw raw(value,type);const auto count=raw.size();if(count<0)throw std::runtime_error("Invalid array accounting length");
   if(count&&!first(array_at(raw.data,0),type))return;add(96+static_cast<uint64_t>(count)*48);
   for(int64_t index=0;index<count&&!bounded;++index)visit(array_at(raw.data,index),depth+1);return;
  }
  if(type==GDEXTENSION_VARIANT_TYPE_DICTIONARY){
   Raw raw(value,type);const auto count=raw.size();if(count<0)throw std::runtime_error("Invalid dictionary accounting length");
   Var iterator;destroy(iterator.data);GDExtensionBool valid=0;bool more=iter_init(value,iterator.data,&valid)!=0;if(!valid)throw std::runtime_error("Dictionary accounting iteration failed");
   bool initialized=false;
   while(more&&!bounded){Var key;destroy(key.data);iter_get(value,iterator.data,key.data,&valid);if(!valid)throw std::runtime_error("Dictionary accounting key failed");const auto* child=dictionary_at(raw.data,key.data);if(!child)throw std::runtime_error("Dictionary accounting value disappeared");
    if(!initialized){if(!first(child,type))return;add(160+static_cast<uint64_t>(count)*192);initialized=true;}
    visit(key.data,depth+1);visit(child,depth+1);more=iter_next(value,iterator.data,&valid)!=0;if(!valid)throw std::runtime_error("Dictionary accounting iteration changed");
   }if(!initialized)add(160);return;
  }
  if(type>=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY&&type<=GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR4_ARRAY){
   Raw raw(value,type);const auto count=raw.size();if(count<0)throw std::runtime_error("Invalid packed accounting length");const void* identity=nullptr;uint64_t stride=0;
   if(count)switch(type){
    case GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY:identity=const_element(raw.data,0);stride=1;break;
    case GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY:identity=int32_at(raw.data,0);stride=4;break;
    case GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY:identity=int64_at(raw.data,0);stride=8;break;
    case GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY:identity=float32_at(raw.data,0);stride=4;break;
    case GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY:identity=float64_at(raw.data,0);stride=8;break;
    case GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY:identity=strings_at(raw.data,0);stride=8;break;
    case GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY:identity=vector2_at(raw.data,0);stride=8;break;
    case GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY:identity=vector3_at(raw.data,0);stride=12;break;
    case GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY:identity=colors_at(raw.data,0);stride=16;break;
    case GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR4_ARRAY:identity=vector4_at(raw.data,0);stride=16;break;
    default:break;
   }
   if(identity&&!first(identity,type))return;add(96+static_cast<uint64_t>(count)*stride*2);
   if(type==GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY)for(int64_t index=0;index<count&&!bounded;++index){auto* string=strings_at(raw.data,index);GDExtensionInt length=0;lengths[GDEXTENSION_VARIANT_TYPE_STRING](string,nullptr,&length,0);if(length>0&&!first(string_at(string,0),GDEXTENSION_VARIANT_TYPE_STRING))continue;add(length>0?96+static_cast<uint64_t>(length)*8:32);}return;
  }
  // The parent already charges Variant slots. Indirect math values can own
  // extra storage; deliberately conservative for both float/double layouts.
  if(type==GDEXTENSION_VARIANT_TYPE_TRANSFORM2D||type==GDEXTENSION_VARIANT_TYPE_AABB||type==GDEXTENSION_VARIANT_TYPE_BASIS||type==GDEXTENSION_VARIANT_TYPE_TRANSFORM3D||type==GDEXTENSION_VARIANT_TYPE_PROJECTION)add(128);
 }
};
void call_cost(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=2){error->error=count<2?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=2;new_nil(result);return;}
 try{Var maximum(args[1]);const auto limit=maximum.integer();if(limit<1||limit>int64_t(1)<<40)throw std::runtime_error("Invalid resource accounting budget");Cost cost(static_cast<uint64_t>(limit));cost.add(96);cost.visit(args[0]);auto out=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(out,Var::text("estimated_bytes"),Var::integer(static_cast<int64_t>(cost.bytes)));put(out,Var::text("visited"),Var::integer(static_cast<int64_t>(cost.nodes)));put(out,Var::text("shared"),Var::integer(static_cast<int64_t>(cost.shared)));put(out,Var::text("bounded"),Var::integer(cost.bounded?1:0));new_copy(result,out.data);}catch(const std::exception& failure){auto out=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(out,Var::text("error"),Var::text(failure.what()));new_copy(result,out.data);}
}
constexpr uint32_t high[]={0x20ac,0x81,0x201a,0x192,0x201e,0x2026,0x2020,0x2021,0x2c6,0x2030,0x160,0x2039,0x152,0x8d,0x17d,0x8f,0x90,0x2018,0x2019,0x201c,0x201d,0x2022,0x2013,0x2014,0x2dc,0x2122,0x161,0x203a,0x153,0x9d,0x17e,0x178};
std::string text(const Bytes& bytes,size_t offset,size_t count,bool strict=false){
 const auto* p=bytes.at(offset,count);std::string out;
 for(size_t i=0;i<count&&p[i];++i){uint32_t c=p[i];if(strict&&(c<32||c=='/'||c=='\\'||c==':'))throw std::runtime_error("Invalid native NWSync resource reference");if(c>=128&&c<160)c=high[c-128];if((c>='A'&&c<='Z')||(c>=0xc0&&c<=0xde&&c!=0xd7))c+=32;else if(c==0x178)c=0xff;else if(c==0x152||c==0x160||c==0x17d)c++;
  if(c<128)out.push_back(static_cast<char>(c));else if(c<2048){out.push_back(static_cast<char>(0xc0|(c>>6)));out.push_back(static_cast<char>(0x80|(c&63)));}else{out.push_back(static_cast<char>(0xe0|(c>>12)));out.push_back(static_cast<char>(0x80|((c>>6)&63)));out.push_back(static_cast<char>(0x80|(c&63)));}
 }if(strict&&out.empty())throw std::runtime_error("Invalid native NWSync resource reference");return out;
}
std::string hex(const Bytes& b,size_t offset,size_t count){static constexpr char digits[]="0123456789abcdef";const auto* p=b.at(offset,count);std::string out(count*2,'0');for(size_t i=0;i<count;++i){out[i*2]=digits[p[i]>>4];out[i*2+1]=digits[p[i]&15];}return out;}
struct Fields{
 Var entries=Var::text("entries"),offset=Var::text("offset"),size=Var::text("size"),type=Var::text("type"),bif=Var::text("bif"),slot=Var::text("slot"),name=Var::text("name"),hash=Var::name("hash");
};
Var parse(const std::string& kind,const Bytes& table,const Bytes& other,const Var& options){
 Fields f;auto result=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);auto entries=Var::container(kind=="bif"?GDEXTENSION_VARIANT_TYPE_ARRAY:GDEXTENSION_VARIANT_TYPE_DICTIONARY);
 const auto option=[&](const char* key){return get(options,Var::text(key)).integer();};
 if(kind=="erf"||kind=="key"||kind=="bif"){
  const auto count=option("count"),stride=option("stride");if(count<0||count>1000000||stride<1||stride>40||table.length!=static_cast<uint64_t>(count)*stride)throw std::runtime_error("Invalid native archive table length");
  const auto name_size=kind=="erf"?option("name_size"):16;const auto source_size=kind=="key"?0:option("size");
  if(kind=="erf"&&((stride!=24&&stride!=40)||(name_size!=16&&name_size!=32)||stride!=name_size+8||other.length!=static_cast<uint64_t>(count)*8))throw std::runtime_error("Invalid ERF table layout");
  if(kind=="key"&&stride!=22&&stride!=26)throw std::runtime_error("Invalid KEY table layout");
  if(kind=="bif"&&stride!=16&&stride!=20)throw std::runtime_error("Invalid BIF table layout");
  Var files;if(kind=="key")files=get(options,Var::text("filenames"));
  for(int64_t index=0;index<count;++index){const auto at=static_cast<size_t>(index*stride);auto row=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);uint32_t type=0;
   if(kind=="key"){type=table.u16(at+16);const auto id=table.u32(at+18),bif=(stride==26?table.u32(at+22):id)>>20;put(row,f.bif,indexed(files,bif));put(row,f.slot,Var::integer(id&0xfffff));}
   else{const auto cursor=kind=="erf"?static_cast<size_t>(index)*8:at+(stride==20?8:4);const auto& source=kind=="erf"?other:table;const auto offset=source.u32(cursor),size=source.u32(cursor+4);if(source_size<0||offset>static_cast<uint64_t>(source_size)||size>static_cast<uint64_t>(source_size)-offset)throw std::runtime_error(kind=="erf"?"ERF payload exceeds archive bounds":"BIF payload exceeds archive bounds");put(row,f.offset,Var::integer(offset));put(row,f.size,Var::integer(size));type=kind=="erf"?table.u16(at+static_cast<size_t>(name_size)+4):table.u32(cursor+8);}
   put(row,f.type,Var::integer(type));if(kind=="bif")append(entries,row);else put(entries,Var::text(text(table,at,static_cast<size_t>(name_size))+":"+std::to_string(type)),row);
  }
 }else if(kind=="installed-manifest"||kind=="manifest"){
  const bool installed=kind=="installed-manifest";const auto count=table.u32(installed?0:8),aliases=installed?0:table.u32(12);if(count<1||uint64_t(count)+aliases>1000000||table.length!=(installed?4+uint64_t(count)*58:16+uint64_t(count)*42+uint64_t(aliases)*22))throw std::runtime_error("Invalid native NWSync manifest length");
  // GDScript's row.hash / row.size insert StringName keys, whereas its
  // literal name/type and archive fields use String. Preserve serialization
  // identity as well as equivalent dictionary lookup/value semantics.
  const auto size_key=Var::name("size");std::vector<Var> base;std::unordered_map<std::string,uint32_t> sizes;std::unordered_map<std::string,bool> seen;
  if(!installed)base.reserve(count);seen.reserve(static_cast<size_t>(count)+aliases);
  for(uint32_t index=0;index<count+aliases;++index){size_t offset=installed?4+static_cast<size_t>(index)*58:16+(index<count?static_cast<size_t>(index)*42:static_cast<size_t>(count)*42+static_cast<size_t>(index-count)*22);size_t name_offset=installed?offset:offset+(index<count?24:4);const auto name=text(table,name_offset,16,true);const auto type=table.u16(name_offset+16);auto row=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(row,f.name,Var::text(name));put(row,f.type,Var::integer(type));
   if(installed){const auto* bytes=table.at(offset+18,40);std::string hash(reinterpret_cast<const char*>(bytes),40);for(const auto c:hash)if(!((c>='0'&&c<='9')||(c>='a'&&c<='f')))throw std::runtime_error("Invalid installed NWSync reference");put(row,f.hash,Var::text(hash));put(row,size_key,Var::integer(-1));}
   else if(index<count){const auto hash=hex(table,offset,20);const auto size=table.u32(offset+20);const auto old=sizes.find(hash);if(size>256*1024*1024||(old!=sizes.end()&&old->second!=size))throw std::runtime_error("Invalid native NWSync resource size");sizes[hash]=size;put(row,f.hash,Var::text(hash));put(row,size_key,Var::integer(size));}
   else{const auto source=table.u32(offset);if(source>=count)throw std::runtime_error("Invalid native NWSync alias");put(row,f.hash,get(base[source],f.hash));put(row,size_key,get(base[source],size_key));}
   const auto key=name+":"+std::to_string(type);if(!seen.emplace(key,true).second)throw std::runtime_error("Duplicate native NWSync reference");put(entries,Var::text(key),row);if(!installed&&index<count)base.push_back(row);
  }
 }else throw std::runtime_error("Unsupported native resource index kind");
 put(result,f.entries,entries);return result;
}
void call_parse(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=4){error->error=count<4?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=4;new_nil(result);return;}
 try{Var kind(args[0]),one(args[1]),two(args[2]),options(args[3]);Bytes table(one),other(two);auto out=parse(kind.text(),table,other,options);new_copy(result,out.data);}catch(const std::exception& failure){auto out=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(out,Var::text("error"),Var::text(failure.what()));new_copy(result,out.data);}
}
void free_instance(void*,GDExtensionClassInstancePtr){}
void initialize(void*,GDExtensionInitializationLevel level){
 if(level!=GDEXTENSION_INITIALIZATION_SCENE)return;
 Name name("NwnResourceIndex"),base("RefCounted"),method("entries"),empty(""),kind("kind"),table("table"),other("other"),options("options");alignas(8)uint8_t hint[8];string_new(hint,"");
 GDExtensionClassCreationInfo6 info{};info.is_abstract=true;info.is_exposed=true;info.is_runtime=true;info.free_instance_func=free_instance;register_class(library,name.data,base.data,&info);
 const auto property=[&](GDExtensionVariantType type,Name& n){GDExtensionPropertyInfo p{};p.type=type;p.name=n.data;p.class_name=empty.data;p.hint_string=hint;p.usage=6;return p;};
 auto ret=property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,empty);GDExtensionPropertyInfo args[]={property(GDEXTENSION_VARIANT_TYPE_STRING,kind),property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,table),property(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,other),property(GDEXTENSION_VARIANT_TYPE_DICTIONARY,options)};GDExtensionClassMethodArgumentMetadata metadata[4]{};
 GDExtensionClassMethodInfo m{};m.name=method.data;m.call_func=call_parse;m.method_flags=GDEXTENSION_METHOD_FLAG_NORMAL|GDEXTENSION_METHOD_FLAG_STATIC;m.has_return_value=true;m.return_value_info=&ret;m.argument_count=4;m.arguments_info=args;m.arguments_metadata=metadata;register_method(library,name.data,&m);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
 Name cost_method("retained_cost"),value("value"),maximum("maximum_bytes");string_new(hint,"");GDExtensionPropertyInfo cost_args[]={property(GDEXTENSION_VARIANT_TYPE_NIL,value),property(GDEXTENSION_VARIANT_TYPE_INT,maximum)};cost_args[0].usage|=131072;/* PROPERTY_USAGE_NIL_IS_VARIANT in pinned API dump */GDExtensionClassMethodArgumentMetadata cost_metadata[2]{};m.name=cost_method.data;m.call_func=call_cost;m.argument_count=2;m.arguments_info=cost_args;m.arguments_metadata=cost_metadata;register_method(library,name.data,&m);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
 Name table_method("two_da"),source("source");string_new(hint,"");GDExtensionPropertyInfo table_args[]={property(GDEXTENSION_VARIANT_TYPE_STRING,source)};GDExtensionClassMethodArgumentMetadata table_metadata[1]{};m.name=table_method.data;m.call_func=call_two_da;m.argument_count=1;m.arguments_info=table_args;m.arguments_metadata=table_metadata;register_method(library,name.data,&m);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
}
void deinitialize(void*,GDExtensionInitializationLevel level){if(level==GDEXTENSION_INITIALIZATION_SCENE){Name name("NwnResourceIndex");unregister_class(library,name.data);}}
}
extern "C" __declspec(dllexport) GDExtensionBool nwn_resource_index_init(GDExtensionInterfaceGetProcAddress api,GDExtensionClassLibraryPtr lib,GDExtensionInitialization* init){
 library=lib;
#define API(var,type,symbol) var=reinterpret_cast<type>(api(symbol));if(!var)return false
 API(new_nil,GDExtensionInterfaceVariantNewNil,"variant_new_nil");API(new_copy,GDExtensionInterfaceVariantNewCopy,"variant_new_copy");API(destroy,GDExtensionInterfaceVariantDestroy,"variant_destroy");API(get_type,GDExtensionInterfaceVariantGetType,"variant_get_type");API(get_keyed,GDExtensionInterfaceVariantGetKeyed,"variant_get_keyed");API(set_keyed,GDExtensionInterfaceVariantSetKeyed,"variant_set_keyed");API(get_indexed,GDExtensionInterfaceVariantGetIndexed,"variant_get_indexed");API(variant_call,GDExtensionInterfaceVariantCall,"variant_call");API(construct,GDExtensionInterfaceVariantConstruct,"variant_construct");API(from_type,GDExtensionInterfaceGetVariantFromTypeConstructor,"get_variant_from_type_constructor");API(to_type,GDExtensionInterfaceGetVariantToTypeConstructor,"get_variant_to_type_constructor");API(destructor,GDExtensionInterfaceVariantGetPtrDestructor,"variant_get_ptr_destructor");API(builtin_method,GDExtensionInterfaceVariantGetPtrBuiltinMethod,"variant_get_ptr_builtin_method");API(const_element,GDExtensionInterfacePackedByteArrayOperatorIndexConst,"packed_byte_array_operator_index_const");API(name_new,GDExtensionInterfaceStringNameNewWithUtf8Chars,"string_name_new_with_utf8_chars");API(string_new,GDExtensionInterfaceStringNewWithUtf8Chars,"string_new_with_utf8_chars");API(string_utf8,GDExtensionInterfaceStringToUtf8Chars,"string_to_utf8_chars");API(register_class,GDExtensionInterfaceClassdbRegisterExtensionClass6,"classdb_register_extension_class6");API(register_method,GDExtensionInterfaceClassdbRegisterExtensionClassMethod,"classdb_register_extension_class_method");API(unregister_class,GDExtensionInterfaceClassdbUnregisterExtensionClass,"classdb_unregister_extension_class");
#undef API
 for(int t=1;t<GDEXTENSION_VARIANT_TYPE_VARIANT_MAX;++t){from[t]=from_type(static_cast<GDExtensionVariantType>(t));to[t]=to_type(static_cast<GDExtensionVariantType>(t));}
 {Name size("size");byte_size=builtin_method(GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY,size.data,3173160232);if(!byte_size)return false;}
 #define EXTRA(var,type,symbol) var=reinterpret_cast<type>(api(symbol));if(!var)return false
 EXTRA(iter_init,GDExtensionInterfaceVariantIterInit,"variant_iter_init");EXTRA(iter_next,GDExtensionInterfaceVariantIterNext,"variant_iter_next");EXTRA(iter_get,GDExtensionInterfaceVariantIterGet,"variant_iter_get");EXTRA(array_at,GDExtensionInterfaceArrayOperatorIndexConst,"array_operator_index_const");EXTRA(dictionary_at,GDExtensionInterfaceDictionaryOperatorIndexConst,"dictionary_operator_index_const");
 EXTRA(float32_at,GDExtensionInterfacePackedFloat32ArrayOperatorIndexConst,"packed_float32_array_operator_index_const");EXTRA(float64_at,GDExtensionInterfacePackedFloat64ArrayOperatorIndexConst,"packed_float64_array_operator_index_const");EXTRA(int32_at,GDExtensionInterfacePackedInt32ArrayOperatorIndexConst,"packed_int32_array_operator_index_const");EXTRA(int64_at,GDExtensionInterfacePackedInt64ArrayOperatorIndexConst,"packed_int64_array_operator_index_const");EXTRA(strings_at,GDExtensionInterfacePackedStringArrayOperatorIndexConst,"packed_string_array_operator_index_const");EXTRA(vector2_at,GDExtensionInterfacePackedVector2ArrayOperatorIndexConst,"packed_vector2_array_operator_index_const");EXTRA(vector3_at,GDExtensionInterfacePackedVector3ArrayOperatorIndexConst,"packed_vector3_array_operator_index_const");EXTRA(vector4_at,GDExtensionInterfacePackedVector4ArrayOperatorIndexConst,"packed_vector4_array_operator_index_const");EXTRA(colors_at,GDExtensionInterfacePackedColorArrayOperatorIndexConst,"packed_color_array_operator_index_const");
 EXTRA(string_at,GDExtensionInterfaceStringOperatorIndexConst,"string_operator_index_const");
 EXTRA(string_new32,GDExtensionInterfaceStringNewWithUtf32CharsAndLen,"string_new_with_utf32_chars_and_len");EXTRA(array_mutable,GDExtensionInterfaceArrayOperatorIndex,"array_operator_index");
 #undef EXTRA
 for(int t=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY;t<=GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR4_ARRAY;++t){Name size("size");lengths[t]=builtin_method(static_cast<GDExtensionVariantType>(t),size.data,3173160232);if(!lengths[t])return false;}
 for(const auto t:{GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_DICTIONARY}){Name size("size");lengths[t]=builtin_method(t,size.data,3173160232);if(!lengths[t])return false;}
 for(const auto t:{GDEXTENSION_VARIANT_TYPE_STRING,GDEXTENSION_VARIANT_TYPE_STRING_NAME}){Name length("length");lengths[t]=builtin_method(t,length.data,3173160232);if(!lengths[t])return false;}
 init->minimum_initialization_level=GDEXTENSION_INITIALIZATION_SCENE;init->initialize=initialize;init->deinitialize=deinitialize;init->userdata=nullptr;return true;
}
