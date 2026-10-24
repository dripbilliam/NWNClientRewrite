// NSYM v3: the native content catalog, not a list of HAK filenames.
// Beamdog/nwsync and neverwinter.nim's nwsync.nim describe the public format.
const decoder=new TextDecoder('windows-1252');
export function parseNWSyncManifest(input,{maxEntries=1_000_000,maxResourceBytes=256*1024*1024}={}){
 const bytes=input instanceof Uint8Array?input:new Uint8Array(input),v=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 if(bytes.length<16||decoder.decode(bytes.subarray(0,4))!=='NSYM')throw new Error('Invalid NWSync manifest header');
 const version=v.getUint32(4,true),count=v.getUint32(8,true),mappings=v.getUint32(12,true);
 if(version!==3)throw new Error(`Unsupported NWSync manifest version ${version}`);
 if(!count||count+mappings>maxEntries||16+count*42+mappings*22!==bytes.length)throw new Error('Invalid NWSync manifest entry count or length');
 const entries=[],catalog=new Map(),sizes=new Map();let offset=16;
 const reference=()=>{const raw=bytes.subarray(offset,offset+16),end=raw.indexOf(0),name=decoder.decode(end<0?raw:raw.subarray(0,end)).toLowerCase();offset+=16;const type=v.getUint16(offset,true);offset+=2;
  // ResRefs are fixed archive keys. Real manifests include trailing spaces;
  // preserve them exactly rather than applying filesystem-name restrictions.
  // Only content hashes become private cache paths.
  if(!name||/[\x00-\x1f/\\:]/.test(name)||!type)throw new Error('Invalid NWSync resource reference');return{name,type};};
 const add=entry=>{const key=`${entry.name}:${entry.type}`;if(catalog.has(key))throw new Error('Duplicate NWSync resource reference');catalog.set(key,entry);entries.push(entry);};
 for(let i=0;i<count;i++){
  const hash=Array.from(bytes.subarray(offset,offset+20),n=>n.toString(16).padStart(2,'0')).join('');offset+=20;const size=v.getUint32(offset,true);offset+=4;
  if(size>maxResourceBytes)throw new Error('NWSync resource exceeds the supported size');if(sizes.has(hash)&&sizes.get(hash)!==size)throw new Error('NWSync hash has inconsistent resource sizes');sizes.set(hash,size);add({hash,size,...reference()});
 }
 for(let i=0;i<mappings;i++){
  const index=v.getUint32(offset,true);offset+=4;if(index>=count)throw new Error('NWSync mapping references an unavailable entry');const {hash,size}=entries[index];add({hash,size,...reference()});
 }
 return{version,entries,catalog};
}
