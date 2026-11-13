// Protocol-only stored actor-name provenance. No TLK fetch, token expansion,
// renderer, or native construction inference from a proxy/lifetime number.
// Root's accepted NetworkWorld transaction owns typedOwner/historyComplete and
// the safe monotonic sequence. Partial-prefix imports must taint that history.
export const NATIVE_ACTOR_NAME_SLOT='nativeActorNameState';
export const NATIVE_ACTOR_NAME_SOURCE='native_actor_name_state_v1';
const own=(value,key)=>Object.hasOwn(value,key);
const object=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
const integer=(value,min,max)=>Number.isSafeInteger(value)&&value>=min&&value<=max;
const positive=value=>integer(value,1,Number.MAX_SAFE_INTEGER);
const uint=value=>integer(value,0,0xffffffff);
const fail=reason=>{throw new TypeError('Invalid native actor-name '+reason);};

function wire(value,partial=false){
 if(!object(value))fail('name declaration');
 const text=own(value,'text'),ref=own(value,'strRef');
 if(text){if(ref||typeof value.text!=='string')fail('literal');return{text:value.text};}
 if(ref){if(!uint(value.strRef)||!integer(value.gender,0,1))fail('localized reference');return{strRef:value.strRef,gender:value.gender};}
 if(own(value,'firstName')||own(value,'lastName')){
  if(!partial&&(!own(value,'firstName')||!own(value,'lastName')))fail('split declaration');
  const out={};for(const key of ['firstName','lastName'])if(own(value,key))out[key]=wire(value[key]);return out;
 }
 if(partial&&Object.keys(value).length===0)return{};
 fail('name declaration');
}
function parserContext(value){
 if(value===null)return null;
 if(!object(value))fail('parser context');
 const out={};
 for(const key of Object.keys(value))if(!['id','objectType','areaId','nativeLifetime','clientKnownLifetime','replicated','appearance'].includes(key))fail('parser context fields');
 for(const key of ['id','objectType','areaId','nativeLifetime','clientKnownLifetime'])if(own(value,key)){
  if(value[key]!==null&&!integer(value[key],0,Number.MAX_SAFE_INTEGER))fail('parser context identity');out[key]=value[key];
 }
 for(const section of ['replicated','appearance'])if(own(value,section)){
  const input=value[section];if(!object(input))fail('parser context section');const output={};
  for(const key of Object.keys(input))if(!['name','stats'].includes(key))fail('parser context section fields');
  if(own(input,'name'))output.name=wire(input.name,true);
  if(own(input,'stats')){
   if(!object(input.stats))fail('parser context stats');const stats={};
   for(const key of Object.keys(input.stats))if(!['race','racialType','classes'].includes(key))fail('parser context stat fields');
   for(const key of ['race','racialType'])if(own(input.stats,key)){if(!uint(input.stats[key]))fail('parser context stat');stats[key]=input.stats[key];}
   if(own(input.stats,'classes')){
    if(!Array.isArray(input.stats.classes)||input.stats.classes.length>8)fail('parser context classes');
    stats.classes=input.stats.classes.map(entry=>{if(!object(entry))fail('parser context class');const row={};for(const key of Object.keys(entry)){if(!['id','level'].includes(key)||!uint(entry[key]))fail('parser context class field');row[key]=entry[key];}return row;});
   }
   output.stats=stats;
  }
  out[section]=output;
 }
 return out;
}
function parserState(value){
 if(value===undefined)return{};
 if(!object(value))fail('parser state');const out={};
 for(const key of Object.keys(value))if(!['gender','nativeB8','nativeBC','context'].includes(key))fail('parser state fields');
 for(const key of ['gender','nativeB8','nativeBC'])if(own(value,key)){if(!uint(value[key]))fail('parser state value');out[key]=value[key];}
 if(own(value,'context'))out.context=parserContext(value.context);
 return out;
}
function selection(ref,overrides){
 // FetchInternal's invalid-reference guard precedes the override table lookup.
 if(ref===0xffffffff)return{known:true,present:false};
 if(overrides===undefined)return{known:false};
 if(!(overrides instanceof Map))fail('override owner');
 if(!overrides.has(ref))return{known:true,present:false};
 const text=overrides.get(ref);if(typeof text!=='string')fail('override text');return{known:true,present:true,text};
}
function descriptor(value,overrides){
 const input=wire(value);
 if(own(input,'text'))return{kind:'literal',text:input.text};
 if(!own(input,'strRef'))fail('component');
 return{kind:'reference',strRef:input.strRef,gender:input.gender,override:selection(input.strRef,overrides)};
}
function customRecords(input){
 if(input===undefined)return{known:false};
 if(!object(input)||!Array.isArray(input.records))fail('CUSTOM owner');
 let previous=-1;
 const records=input.records.map(record=>{
  if(!object(record)||!integer(record.id,0,0x7fffffff)||record.id<=previous)fail('CUSTOM record');previous=record.id;
  const bytes=record.bytes;if(!(bytes instanceof Uint8Array)&&!Array.isArray(bytes))fail('CUSTOM bytes');
  const copy=Array.from(bytes);if(copy.some(byte=>!integer(byte,0,255)))fail('CUSTOM byte');return{id:record.id,bytes:copy};
 });
 return{known:true,records};
}
function equalCustom(snapshot,input){
 if(!snapshot.known)return input===undefined;
 if(!object(input)||!Array.isArray(input.records)||input.records.length!==snapshot.records.length)return false;
 return snapshot.records.every((row,index)=>{const other=input.records[index];return object(other)&&row.id===other.id&&(other.bytes instanceof Uint8Array||Array.isArray(other.bytes))&&row.bytes.length===other.bytes.length&&row.bytes.every((byte,i)=>byte===other.bytes[i]);});
}
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const needsEnvironment=components=>components.some(value=>value.kind==='reference'&&(!value.override.known||value.override.present));

function validSelection(value){return object(value)&&typeof value.known==='boolean'&&(!value.known||typeof value.present==='boolean'&&(!value.present||typeof value.text==='string'));}
function validDescriptor(value){return object(value)&&(value.kind==='literal'&&typeof value.text==='string'||value.kind==='reference'&&uint(value.strRef)&&integer(value.gender,0,1)&&validSelection(value.override));}
function validCustom(value){
 if(!object(value)||typeof value.known!=='boolean')return false;
 if(!value.known)return true;
 if(!Array.isArray(value.records))return false;let previous=-1;
 for(const row of value.records){
  if(!object(row)||!integer(row.id,0,0x7fffffff)||row.id<=previous||!Array.isArray(row.bytes))return false;previous=row.id;
  for(const byte of row.bytes)if(!integer(byte,0,255))return false;
 }
 return true;
}
export function validNativeActorNameState(value){
 if(!object(value)||value.version!==1||value.source!==NATIVE_ACTOR_NAME_SOURCE||!uint(value.id)||!positive(value.revision)||!['present','removed','unknown'].includes(value.presence))return false;
 const c=value.construction,o=value.override,p=value.publication;
 if(!object(c)||!['new','retained','unknown'].includes(c.kind)||!['A/type5','preexisting'].includes(c.source)||!positive(c.sequence)||c.sequence>value.revision||!object(o)||typeof o.known!=='boolean'||own(o,'text')&&typeof o.text!=='string'||o.known&&!own(o,'text'))return false;
 if(p===null)return true;
 if(!object(p)||!positive(p.revision)||p.revision>value.revision||typeof p.current!=='boolean'||!validDescriptor(p.first)||!validDescriptor(p.last)||!object(p.environment)||!object(p.environment.customTokens)||!object(p.environment.parserState))return false;
 if(!validCustom(p.environment.customTokens))return false;
 try{if(!same(p.environment.parserState,parserState(p.environment.parserState)))return false;}catch{return false;}
 return true;
}
function sequence(boundary,current){
 if(!positive(boundary.sequence)||current&&boundary.sequence<=current.revision)fail('accepted sequence');return boundary.sequence;
}
function begin(id,revision,kind,source){return{version:1,source:NATIVE_ACTOR_NAME_SOURCE,id,revision,presence:'present',construction:{kind,source,sequence:revision},override:{known:false},publication:null};}

// Pure transaction staging: callers assign the returned value only on commit.
// A generic proxy, imported snapshot, nativeLifetime or disclosure token is NOT
// evidence for historyComplete/typedOwner. U/party names are deliberately ignored.
export function stageNativeActorName(current,record,boundary={},environment={}){
 if(current!==undefined&&current!==null&&!validNativeActorNameState(current))fail('current state');
 current??=null;
 if(!object(record)||!object(boundary)||!object(environment))fail('input');
 if(record.objectType!==5||!['create','delete','appearance'].includes(record.action))return current;
 if(!uint(record.id)||current&&current.id!==record.id)fail('source identity');
 if(record.action==='delete'){
  if(!current||current.presence==='removed')return current;
  return{...current,revision:sequence(boundary,current),presence:'removed'};
 }
 if(record.action==='create'){
  if(!['absent','present','unknown'].includes(boundary.typedOwner)||typeof boundary.historyComplete!=='boolean')fail('construction boundary');
  if(!current){
   const fresh=boundary.historyComplete&&boundary.typedOwner==='absent';
   const out=begin(record.id,sequence(boundary,null),fresh?'new':boundary.typedOwner==='present'?'retained':'unknown','A/type5');
   if(fresh)out.override={known:true,text:''};return out;
  }
  if(boundary.typedOwner==='present'&&current.presence==='present')return current;
  const revision=sequence(boundary,current);
  if(boundary.typedOwner==='present')return{...current,revision,presence:'present'};
  // No native hard-destruction clock is invented here. Preserve old bytes but
  // revoke their currentness when D+A could mean reuse OR reconstruction.
  const override=current.override.known&&current.override.text!==''?{...current.override,known:false}:current.override;
  const publication=current.publication?{...current.publication,current:false}:null;
  return{...current,revision,presence:'present',override,publication};
 }
 if(!uint(record.mask)||record.mask>0xffff)fail('appearance mask');
 const hasName=object(record.state)&&own(record.state,'name');
 if(!(record.mask&0x400)){if(hasName)fail('appearance name mask');return current;}
 if(!hasName)fail('appearance name');
 if(!['absent','present','unknown'].includes(boundary.typedOwner))fail('appearance boundary');
 if(boundary.typedOwner!=='present')return current;
 const name=wire(record.state.name),overrides=environment.overrides;
 const first=descriptor(own(name,'text')?name:name.firstName,overrides);
 const last=descriptor(own(name,'text')?{text:''}:name.lastName,overrides);
 const needed=needsEnvironment([first,last]);
 const parse=needed?parserState(environment.parserState):{};
 const prior=current?.publication;
 if(current?.presence==='present'&&prior?.current&&same(first,prior.first)&&same(last,prior.last)&&same(parse,prior.environment.parserState)&&(!needed||equalCustom(prior.environment.customTokens,environment.customTokens)))return current;
 const revision=sequence(boundary,current);
 const out=current?{...current,revision,presence:'present'}:begin(record.id,revision,'unknown','preexisting');
 out.publication={revision,current:true,first,last,environment:{customTokens:needed?customRecords(environment.customTokens):{known:false},parserState:parse}};
 return out;
}
