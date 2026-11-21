// Independent resource-index trial. Stage/build/finalize only in a granted CPU
// window. No shared source, output, launcher or native library is changed.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {digest} from './processor-graph.mjs';import {buildDescriptor} from './processor-descriptor.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2],mode=process.argv[3]??'stage';
if(!/^combined-loading-accounting-[a-z0-9-]+$/.test(label??'')||!['stage','finalize'].includes(mode))throw Error('Fresh accounting candidate and stage/finalize mode required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label),draftFile=path.join(stage,'draft.json'),manifestFile=path.join(stage,'manifest.json');
if(mode==='stage'){
 if(fs.existsSync(stage))throw Error('Existing evidence preserved');
 const parentFile=path.join(project,'.cache/native-140fps/loading-agent/combined-loading-runtime-v1/manifest.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);
 if(digest(parentBytes)!=='1f0fd6a94d4132ad8c14c822fefa69d7720ba7fadd7ab32a536ac709401d92f9')throw Error('Frozen parent differs');
 const copy=path.join(stage,'project'),pins=new Map(),changes=[];fs.mkdirSync(copy,{recursive:true});
 for(const pin of parent.pins){const bytes=fs.readFileSync(path.join(parent.project,pin.relative));if(digest(bytes)!==pin.sha256)throw Error('Frozen parent differs: '+pin.relative);const target=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);pins.set(pin.relative,pin.sha256);}
 function patch(relative,fn){const target=path.join(copy,relative),before=pins.get(relative),raw=fs.readFileSync(target,'utf8'),crlf=raw.includes('\r\n');let text=raw.replaceAll('\r\n','\n');text=fn(text);if(crlf)text=text.replaceAll('\n','\r\n');fs.writeFileSync(target,text);const after=digest(Buffer.from(text));pins.set(relative,after);changes.push({relative,before,after});}
 function once(text,from,to){if(text.split(from).length!==2)throw Error('Pinned native source seam differs: '+from.slice(0,100));return text.replace(from,to);}
 patch('native/resource_index.cpp',text=>{
  text=once(text,'GDExtensionPtrBuiltInMethod lengths[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};', 'GDExtensionPtrBuiltInMethod lengths[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};\nGDExtensionVariantGetInternalPtrFunc accounting_internal[GDEXTENSION_VARIANT_TYPE_VARIANT_MAX]{};');
  text=once(text,`struct Raw{
 alignas(8) uint8_t data[64];GDExtensionVariantType type;
 Raw(GDExtensionConstVariantPtr value,GDExtensionVariantType t):type(t){to[t](data,const_cast<void*>(value));}
 ~Raw(){destructor(type)(data);}Raw(const Raw&)=delete;
 int64_t size()const{GDExtensionInt n=0;lengths[type](const_cast<uint8_t*>(data),nullptr,&n,0);return n;}
};`, `struct Raw{
 // The held, type-checked Variant owns this storage for this call. Never write
 // through the pointer or retain it after this wrapper/call. Unsupported API
 // getters use the exact original conversion/destructor path.
 alignas(8) uint8_t owned[64];uint8_t* data=nullptr;GDExtensionVariantType type;bool borrowed=false;
 Raw(GDExtensionConstVariantPtr value,GDExtensionVariantType t,bool allow_borrow=false):type(t){
  if(allow_borrow&&accounting_internal[t]){if(get_type(value)!=t)throw std::runtime_error("Native resource accounting type changed");data=static_cast<uint8_t*>(accounting_internal[t](const_cast<void*>(value)));borrowed=data!=nullptr;}
  if(!borrowed){data=owned;to[t](data,const_cast<void*>(value));}
 }
 ~Raw(){if(!borrowed)destructor(type)(data);}Raw(const Raw&)=delete;
 int64_t size()const{GDExtensionInt n=0;lengths[type](data,nullptr,&n,0);return n;}
};`);
  text=once(text,'uint64_t bytes=0,nodes=0,shared=0;uint64_t limit;bool bounded=false;', 'uint64_t bytes=0,nodes=0,shared=0;uint64_t limit;bool bounded=false;bool allow_borrow=false;uint64_t borrowed_reads=0,copied_reads=0;');
  text=once(text,'explicit Cost(uint64_t maximum):limit(maximum){}','explicit Cost(uint64_t maximum,bool borrow=false):limit(maximum),allow_borrow(borrow){}');
  const old='Raw raw(value,type);',fresh='Raw raw(value,type,allow_borrow);if(raw.borrowed)++borrowed_reads;else ++copied_reads;';
  if(text.split(old).length!==5)throw Error('Exactly four accountant Raw sites expected');text=text.replaceAll(old,fresh);
  const marker='constexpr uint32_t high[]=';
  const callback=`void call_cost_access(void*,GDExtensionClassInstancePtr,const GDExtensionConstVariantPtr* args,GDExtensionInt count,GDExtensionVariantPtr result,GDExtensionCallError* error){
 error->error=GDEXTENSION_CALL_OK;if(count!=3){error->error=count<3?GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS:GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;error->expected=3;new_nil(result);return;}
 try{Var maximum(args[1]);const auto limit=maximum.integer();if(limit<1||limit>int64_t(1)<<40)throw std::runtime_error("Invalid resource accounting budget");if(get_type(args[2])!=GDEXTENSION_VARIANT_TYPE_BOOL)throw std::runtime_error("Native resource accounting borrow flag must be Boolean");GDExtensionBool allow=0;to[GDEXTENSION_VARIANT_TYPE_BOOL](&allow,const_cast<void*>(args[2]));Cost cost(static_cast<uint64_t>(limit),allow!=0);cost.add(96);cost.visit(args[0]);auto out=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(out,Var::text("estimated_bytes"),Var::integer(static_cast<int64_t>(cost.bytes)));put(out,Var::text("visited"),Var::integer(static_cast<int64_t>(cost.nodes)));put(out,Var::text("shared"),Var::integer(static_cast<int64_t>(cost.shared)));put(out,Var::text("bounded"),Var::integer(cost.bounded?1:0));put(out,Var::text("borrowed_reads"),Var::integer(static_cast<int64_t>(cost.borrowed_reads)));put(out,Var::text("copied_reads"),Var::integer(static_cast<int64_t>(cost.copied_reads)));new_copy(result,out.data);}catch(const std::exception& failure){auto out=Var::container(GDEXTENSION_VARIANT_TYPE_DICTIONARY);put(out,Var::text("error"),Var::text(failure.what()));new_copy(result,out.data);}
}
`;
  text=once(text,marker,callback+marker);
  const before=' Name table_method("two_da"),source("source");';
  text=once(text,before,` Name access_method("retained_cost_access"),allow_borrow("allow_borrow");string_new(hint,"");GDExtensionPropertyInfo access_args[]={property(GDEXTENSION_VARIANT_TYPE_NIL,value),property(GDEXTENSION_VARIANT_TYPE_INT,maximum),property(GDEXTENSION_VARIANT_TYPE_BOOL,allow_borrow)};access_args[0].usage|=131072;GDExtensionClassMethodArgumentMetadata access_metadata[3]{};m.name=access_method.data;m.call_func=call_cost_access;m.argument_count=3;m.arguments_info=access_args;m.arguments_metadata=access_metadata;register_method(library,name.data,&m);destructor(GDEXTENSION_VARIANT_TYPE_STRING)(hint);
`+before);
  text=once(text,' #define EXTRA(var,type,symbol)',` // Optional documented Godot 4.4+ API, cached only for the exact builtin
 // types used by Raw. No undocumented container layout is read.
 if(const auto getters=reinterpret_cast<GDExtensionInterfaceGetVariantGetInternalPtrFunc>(api("variant_get_ptr_internal_getter"))){
  for(const auto t:{GDEXTENSION_VARIANT_TYPE_STRING,GDEXTENSION_VARIANT_TYPE_ARRAY,GDEXTENSION_VARIANT_TYPE_DICTIONARY})accounting_internal[t]=getters(t);
  for(int t=GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY;t<=GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR4_ARRAY;++t)accounting_internal[t]=getters(static_cast<GDExtensionVariantType>(t));
 }
 #define EXTRA(var,type,symbol)`);
  return text;
 });
 patch('systems/native_data/resource_index_backend.gd',text=>once(text,'\treturn ClassDB.class_call_static(&"NwnResourceIndex",&"retained_cost",value,maximum_bytes)', '\tif OS.get_cmdline_user_args().has("--resource-accounting-access=borrowed") and ClassDB.class_has_method(&"NwnResourceIndex",&"retained_cost_access"):\n\t\treturn ClassDB.class_call_static(&"NwnResourceIndex",&"retained_cost_access",value,maximum_bytes,true)\n\treturn ClassDB.class_call_static(&"NwnResourceIndex",&"retained_cost",value,maximum_bytes)'));
 fs.writeFileSync(draftFile,JSON.stringify({version:1,label,stage,project:copy,candidate:copy,parent:{file:parentFile,sha256:digest(parentBytes)},changes,pins:[...pins].map(([relative,sha256])=>({relative,sha256})),baseBinary:parent.pins.find(v=>v.relative==='.cache/native-resource-index/nwn-resource-index.dll').sha256},null,2)+'\n');
 console.log(JSON.stringify({draftFile,changes}));
}else{
 if(!fs.existsSync(draftFile)||fs.existsSync(manifestFile))throw Error('Fresh draft required; finalized evidence is immutable');
 const draftBytes=fs.readFileSync(draftFile),draft=JSON.parse(draftBytes),copy=draft.project,pins=new Map(draft.pins.map(v=>[v.relative,v.sha256])),changes=[...draft.changes];
 const buildFile=path.join(stage,'build-output/build-proof.json'),build=JSON.parse(fs.readFileSync(buildFile));
 if(build.success!==true||build.project!==copy||build.sourceSha256!==pins.get('native/resource_index.cpp'))throw Error('Private build proof differs');
 const sourceBinary=path.join(stage,'build-output/nwn-resource-index.dll'),binary=fs.readFileSync(sourceBinary);if(digest(binary)!==build.binarySha256||build.binarySha256===draft.baseBinary)throw Error('Fresh private candidate DLL proof required');
 const relative='.cache/native-resource-index/nwn-resource-index.dll',old=fs.readFileSync(path.join(copy,relative));if(digest(old)!==draft.baseBinary)throw Error('Private baseline DLL was replaced before guarded finalization');
 const backup=path.join(stage,'originals',relative);fs.mkdirSync(path.dirname(backup),{recursive:true});fs.writeFileSync(backup,old);fs.writeFileSync(path.join(copy,relative),binary);changes.push({relative,before:draft.baseBinary,after:digest(binary)});pins.set(relative,digest(binary));
 const graph='systems/native_data/scoped_processor_graph.json',before=pins.get(graph),descriptor=Buffer.from(JSON.stringify(buildDescriptor(copy).descriptor,null,2)+'\n');fs.writeFileSync(path.join(copy,graph),descriptor);pins.set(graph,digest(descriptor));changes.push({relative:graph,before,after:digest(descriptor),generatedFromFinalCohort:true});
 for(const [relative,sha256]of pins)if(digest(fs.readFileSync(path.join(copy,relative)))!==sha256)throw Error('Final candidate pin differs: '+relative);
 const manifest={...draft,draft:{file:draftFile,sha256:digest(draftBytes)},build:{file:buildFile,sha256:digest(fs.readFileSync(buildFile))},changes,changed:[],pins:[...pins].map(([relative,sha256])=>({relative,sha256})),flags:['--resource-accounting-access=borrowed'],scope:'Independent optional data-accounting builtin access only. Original retained_cost/default API stays conversion based; new access API can read exact supported Variant-held builtins with documented 4.4+ getter or force original conversion fallback. Identical traversal/charge/sharing/bounds/errors; no retained pointer or new cache tier. No copied-publication gate.',graphics:0,serverConnections:0,sharedNativeBuilds:0};
 fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({file:manifestFile,sha256:digest(fs.readFileSync(manifestFile)),binarySha256:digest(binary),changes}));
}
