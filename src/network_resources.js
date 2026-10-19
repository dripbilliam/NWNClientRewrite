import {decodeGffText} from './gff_text.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
const diagnostic=({code,reason,...context})=>runtimeDiagnostics.record(code,reason,context,'warning');

const string=reader=>{const value=reader.readCExoString();return value.bytes?decodeGffText(value.bytes):'';};
// Hash::SHA1 parsing and Advertisement::ReadFromNetwork1b3320 preserve an empty
// hash for invalid/all-zero strings; that is distinct from a usable manifest.
const sha1=value=>{const prefix=value.match(/^[0-9a-f]*/i)[0];return prefix.length===40&&!/^0{40}$/.test(prefix)?prefix.toLowerCase():null;};
export function readResourceAdvertisement(reader){
 if(!reader.readBool())return null;
 const hash=sha1(string(reader)),version=reader.readByte(),url=string(reader),count=reader.readByte(),manifests=[];
 for(let i=0;i<count;i++)manifests.push({hash:sha1(string(reader)),flags:reader.readByte(),language:reader.readByte()});
 return{hash,version,url,manifests};
}
// Native Manifest::ShouldLoadOnClient1b3c10. null language means the original
// talk-table/language provider is unavailable; only language255 is universal.
export const shouldLoadManifest=(manifest,language=null)=>manifest.language===255||(language!==null&&manifest.language===language);

// Status4df850 -> PackModuleResources483040. Native load/save field evidence:
// Mod_CustomTlk at+88 and Mod_NWMResName at+450. HAK order is wire order.
export function readServerResourceRequirements(reader){
 const reserved=string(reader),advertisement=readResourceAdvertisement(reader),customTlk=string(reader),nwmResourceName=string(reader),count=reader.readByte(),haks=[];
 for(let i=0;i<count;i++){
  const bytes=reader.readCResRef(),end=bytes.indexOf(0);haks.push(decodeGffText(end<0?bytes:bytes.subarray(0,end)));
 }
 return{reserved,advertisement,customTlk,nwmResourceName,haks};
}

// Resolution is provided by the application's installed-resource/NWSync owner.
// This gate must finish before character admission; missing providers cannot
// silently turn a server's requirements into locally simulated content.
export async function resolveServerResources(requirements,{language=null,findFile,findManifest,onDiagnostic=diagnostic}){
 const resolved=[],missing=[];
 const need=async(kind,name,lookup)=>{
  let value=null;try{value=lookup?await lookup(name):null;}catch{onDiagnostic({code:'network.resource-resolution-failed',reason:'Required server resource lookup failed',kind,name});}
  if(value)resolved.push({kind,name,resource:value});else{missing.push({kind,name});onDiagnostic({code:'network.resource-unavailable',reason:'Required server resource is unavailable',kind,name});}
 };
 const ad=requirements.advertisement;
 if(ad){
  if(ad.hash)await need('nwsync',ad.hash,findManifest);else{missing.push({kind:'nwsync',name:null});onDiagnostic({code:'network.resource-invalid',reason:'Primary NWSync manifest hash is empty or invalid'});}
  for(const manifest of ad.manifests)if(shouldLoadManifest(manifest,language)){
   if(manifest.hash)await need('nwsync',manifest.hash,findManifest);else{missing.push({kind:'nwsync',name:null});onDiagnostic({code:'network.resource-invalid',reason:'Required additional NWSync manifest hash is empty or invalid'});}
  }
 }
 for(const [kind,name,extension]of [['tlk',requirements.customTlk,'tlk'],['nwm',requirements.nwmResourceName,'nwm'],...requirements.haks.map(name=>['hak',name,'hak'])]){
  if(name)await need(kind,name,findFile?value=>findFile(kind,value,extension):null);
  else if(kind==='hak'){missing.push({kind,name});onDiagnostic({code:'network.resource-invalid',reason:'Required HAK resource reference is empty'});}
 }
 return{ready:missing.length===0,resolved,missing};
}
