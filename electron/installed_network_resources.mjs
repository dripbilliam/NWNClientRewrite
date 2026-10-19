import fs from 'node:fs/promises';
import path from 'node:path';
import {parseTalkTable} from '../src/talk_table.js';
import {fetchTalkRecordSync,createTalkRecord} from '../src/native_talk_table.js';
import {decodeGffText} from '../src/gff_text.js';

// Read-only installed/profile content lookup. Names are matched against a
// directory inventory, never joined to a server-supplied filesystem path.
export function installedNetworkResources({install,userDirectory=null,language='en'}){
 const roots={
  nwm:[...(userDirectory?[path.join(userDirectory,'nwm')]:[]),path.join(install,'data/nwm')],
  hak:[...(userDirectory?[path.join(userDirectory,'hak')]:[]),path.join(install,'data/hk'),path.join(install,'data/hak')],
  tlk:[...(userDirectory?[path.join(userDirectory,'tlk')]:[]),path.join(install,'data/tlk'),path.join(install,'lang',language,'data/tlk')]
 };
 const cache=new Map(),tables=new Map();
 const table=file=>{if(!tables.has(file))tables.set(file,fs.readFile(file).then(bytes=>parseTalkTable(bytes).nativeFile));return tables.get(file);};
 async function index(directory){
  if(!cache.has(directory))cache.set(directory,(async()=>{
   let entries;try{entries=await fs.readdir(directory,{withFileTypes:true});}catch(error){if(error.code==='ENOENT')return new Map();throw error;}
   return new Map(entries.filter(e=>e.isFile()).map(e=>[e.name.toLowerCase(),path.join(directory,e.name)]));
  })());return cache.get(directory);
 }
 return{async talkString(ref,gender,resolved,diagnose){
  const primary=ref&0x01000000?resolved.find(r=>r.kind==='tlk')?.resource:path.join(install,'lang',language,'data/dialog.tlk');
  let pair=[null,null];
  if(primary){const male=await table(primary),femaleName=path.basename(primary).replace(/\.tlk$/i,'f.tlk'),female=(await index(path.dirname(primary))).get(femaleName.toLowerCase());pair=[male,female?await table(female):male];}
  const state={gender},record=createTalkRecord(),providers={override:()=>null,file:(_custom,g)=>pair[g],cached:(f,i)=>f.cache.get(i)??null,cache:(f,i,r)=>f.cache.set(i,r),warning:line=>diagnose({code:'network.talk-table-warning',reason:'Native talk-table lookup warning',line,strRef:ref}),parse:()=>{throw new Error('Network talk token override is unavailable');},size:f=>f.bytes.length,seek:(f,o)=>{f.position=o;return Number(o<=f.bytes.length);},read:(f,out,n)=>{const b=f.bytes.subarray(f.position,f.position+n);out.set(b);f.position+=b.length;return b.length;},allocate:n=>{if(n>64*1024*1024)throw new Error('Native talk-table text exceeds supported size');return{bytes:new Uint8Array(n),defined:new Uint8Array(n)};}};
  const status=fetchTalkRecordSync(state,ref,record,0,providers);if(pair[0]&&![0,1,2,3,4].includes(pair[0].language))diagnose({code:'network.talk-table-encoding-unhandled',reason:'Non-Western network talk-table display encoding is not connected',language:pair[0].language});
  return{status,text:decodeGffText(record.text),sound:decodeGffText(record.sound),durationBits:record.durationBits,gender:state.gender};
 },async languageId(){
  const file=await fs.open(path.join(install,'lang',language,'data/dialog.tlk'),'r');
  try{const header=Buffer.alloc(12),{bytesRead}=await file.read(header,0,12,0);if(bytesRead!==12||header.subarray(0,8).toString('ascii')!=='TLK V3.0')throw new Error('Native talk-table language is unavailable');return header.readUInt32LE(8);}
  finally{await file.close();}
 },async findFile(kind,name,extension){
  if(!roots[kind]||typeof name!=='string'||typeof extension!=='string')return null;
  const filename=(name.toLowerCase().endsWith('.'+extension)?name:name+'.'+extension).toLowerCase();
  for(const directory of roots[kind]){const found=(await index(directory)).get(filename);if(found)return found;}
  return null;
 }};
}
