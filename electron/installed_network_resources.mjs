import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {parseTalkTable} from '../src/talk_table.js';
import {fetchTalkRecordSync,createTalkRecord} from '../src/native_talk_table.js';
import {decodeGffText} from '../src/gff_text.js';
import {isNativeAudioResourceRef} from '../src/native_audio.js';
import {NWSyncContent} from './nwsync_content.mjs';
import {openServerResourceContext} from './server_resource_context.mjs';
import {workshopContent} from './workshop_content.mjs';

// Read-only installed/profile content lookup. Names are matched against a
// directory inventory, never joined to a server-supplied filesystem path.
export function installedNetworkResources({install,userDirectory=null,modsDirectory=null,disabledMods=[],language='en',cacheDirectory=null,reuseInstalledNWSync=true,onDiagnostic=()=>{},contentOptions={}}){
 if(typeof reuseInstalledNWSync!=='boolean')throw new Error('Invalid installed NWSync reuse setting');
 const roots={
  nwm:[...(userDirectory?[path.join(userDirectory,'nwm')]:[]),path.join(install,'data/nwm')],
  hak:[...(userDirectory?[path.join(userDirectory,'hak')]:[]),path.join(install,'data/hk'),path.join(install,'data/hak')],
  tlk:[...(userDirectory?[path.join(userDirectory,'tlk')]:[]),path.join(install,'lang',language,'data/tlk'),path.join(install,'data/tlk')]
  ,music:[...(userDirectory?[path.join(userDirectory,'music')]:[]),path.join(install,'data/mus')]
  ,ambient:[...(userDirectory?[path.join(userDirectory,'ambient')]:[]),path.join(install,'data/amb')]
 };
 const cache=new Map(),tables=new Map(),contexts=new WeakMap(),workshop=workshopContent(modsDirectory,{disabledMods}),directories=async kind=>[...roots[kind],...await workshop.directories(kind==='nwm'?'modules':kind)];
 let progress=()=>{};
 const content=new NWSyncContent({...contentOptions,directory:cacheDirectory??(userDirectory?path.join(userDirectory,'replacement-client','server-content'):path.join(os.homedir(),'.nwn-replacement','server-content')),nativeDirectory:reuseInstalledNWSync&&userDirectory?path.join(userDirectory,'nwsync'):null,onDiagnostic,onProgress:value=>progress(value)});
 const table=file=>{if(!tables.has(file))tables.set(file,(typeof file==='string'?fs.readFile(file):file.arrayBuffer()).then(bytes=>parseTalkTable(bytes).nativeFile));return tables.get(file);};
 const openContext=(module,resolved)=>{if(!contexts.has(resolved))contexts.set(resolved,openServerResourceContext({install,userDirectory,modsDirectory,disabledMods,language,module,resolved,hakPriority:file=>userDirectory&&path.dirname(file).toLowerCase()===path.join(userDirectory,'hak').toLowerCase()?31000000:30000000}));return contexts.get(resolved);};
 async function index(directory){
  if(!cache.has(directory))cache.set(directory,(async()=>{
   let entries;try{entries=await fs.readdir(directory,{withFileTypes:true});}catch(error){if(error.code==='ENOENT')return new Map();throw error;}
   return new Map(entries.filter(e=>e.isFile()).map(e=>[e.name.toLowerCase(),path.join(directory,e.name)]));
  })());return cache.get(directory);
 }
 return{sourcePolicy:{reuseInstalledNWSync},setProgress:callback=>{progress=callback;},close:()=>content.close(),findManifest:(...args)=>content.findManifest(...args),
 openModule:openContext,
 async waveResource(resolver,resref){
  if(!isNativeAudioResourceRef(resref))throw new Error('Invalid native WAV resource request');
  if(await resolver.hasResource(resref,4))return resolver.getResource(resref,4);
  const filename=(resref+'.wav').toLowerCase();for(const directory of await directories('ambient')){const file=(await index(directory)).get(filename);if(file){const data=await fs.readFile(file);return data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength);}}
  throw Object.assign(new Error('Native WAV resource is unavailable'),{code:'RESOURCE_NOT_FOUND',resref});
 },async audioResource(resolver,resref,requestedType){
  // Native streaming1df780 prefers BMU8 for a WAV4 request, whereas a
  // strict BMU request never falls back to WAV. Archive lookup retains its
  // existing module/HAK/KEY precedence. Loose audio is a bounded fallback.
  if(!isNativeAudioResourceRef(resref)||![4,8].includes(requestedType))throw new Error('Invalid native audio resource request');
  for(const type of requestedType===4?[8,4]:[8]){
   if(await resolver.hasResource(resref,type))return{type,bytes:await resolver.getResource(resref,type)};
   const filename=(resref+'.'+(type===8?'bmu':'wav')).toLowerCase();
   for(const directory of await directories(type===8?'music':'ambient')){const file=(await index(directory)).get(filename);if(file){const data=await fs.readFile(file);return{type,bytes:data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength)};}}
  }
  throw Object.assign(new Error('Native audio resource is unavailable'),{code:'RESOURCE_NOT_FOUND',resref,requestedType});
 },async talkTableData(custom,resolved){
  const primary=custom?resolved.find(r=>r.kind==='tlk')?.resource:path.join(install,'lang',language,'data/dialog.tlk');if(!primary)return null;const file=await table(primary);return file.bytes.slice().buffer;
 },async talkString(ref,gender,resolved,diagnose){
  const primary=ref&0x01000000?resolved.find(r=>r.kind==='tlk')?.resource:path.join(install,'lang',language,'data/dialog.tlk');
  let pair=[null,null];
  if(primary){const male=await table(primary),female=typeof primary==='string'?(await index(path.dirname(primary))).get(path.basename(primary).replace(/\.tlk$/i,'f.tlk').toLowerCase()):primary.female;pair=[male,female?await table(female):male];}
  const state={gender},record=createTalkRecord(),providers={override:()=>null,file:(_custom,g)=>pair[g],cached:(f,i)=>f.cache.get(i)??null,cache:(f,i,r)=>f.cache.set(i,r),warning:line=>diagnose({code:'network.talk-table-warning',reason:'Native talk-table lookup warning',line,strRef:ref}),parse:()=>{throw new Error('Network talk token override is unavailable');},size:f=>f.bytes.length,seek:(f,o)=>{f.position=o;return Number(o<=f.bytes.length);},read:(f,out,n)=>{const b=f.bytes.subarray(f.position,f.position+n);out.set(b);f.position+=b.length;return b.length;},allocate:n=>{if(n>64*1024*1024)throw new Error('Native talk-table text exceeds supported size');return{bytes:new Uint8Array(n),defined:new Uint8Array(n)};}};
  const status=fetchTalkRecordSync(state,ref,record,0,providers);if(pair[0]&&![0,1,2,3,4].includes(pair[0].language))diagnose({code:'network.talk-table-encoding-unhandled',reason:'Non-Western network talk-table display encoding is not connected',language:pair[0].language});
  return{status,text:decodeGffText(record.text),sound:decodeGffText(record.sound),durationBits:record.durationBits,gender:state.gender};
 },async languageId(){
  const file=await fs.open(path.join(install,'lang',language,'data/dialog.tlk'),'r');
  try{const header=Buffer.alloc(12),{bytesRead}=await file.read(header,0,12,0);if(bytesRead!==12||header.subarray(0,8).toString('ascii')!=='TLK V3.0')throw new Error('Native talk-table language is unavailable');return header.readUInt32LE(8);}
  finally{await file.close();}
 },async findFile(kind,name,extension,{resolved=[]}={}){
  if(!roots[kind]||typeof name!=='string'||typeof extension!=='string')return null;
  // OpenFile1995b0 tries CTlkResFile before the physical TLK path. All mounted
  // archives participate, not only NWSync. Validate the header before admission.
  if(kind==='tlk'){
   const ref=name.replace(/\.tlk$/i,'').toLowerCase(),resolver=await openContext(resolved.find(entry=>entry.kind==='nwm')?.resource??null,resolved);
   if(resolver.hasResource(ref,2018)){const femaleRef=ref+'f',resource={arrayBuffer:()=>resolver.getResource(ref,2018),female:resolver.hasResource(femaleRef,2018)?{arrayBuffer:()=>resolver.getResource(femaleRef,2018)}:(await index(roots.tlk[0])).get(femaleRef+'.tlk')??null};await table(resource);if(resource.female)await table(resource.female);return resource;}
  }
  const filename=(name.toLowerCase().endsWith('.'+extension)?name:name+'.'+extension).toLowerCase();
  for(const directory of await directories(kind)){const found=(await index(directory)).get(filename);if(found){if(kind==='tlk'){await table(found);const female=(await index(directory)).get(filename.replace(/\.tlk$/i,'f.tlk'));if(female)await table(female);}return found;}}
  return null;
 }};
}
