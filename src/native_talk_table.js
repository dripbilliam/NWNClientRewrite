import {encodeGffText} from './gff_text.js';
const u32=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native TLK ${n} is unavailable`);return v>>>0;};
const bytes=v=>{if(!(v instanceof Uint8Array))throw new Error('Native TLK string bytes are unavailable');return v;};
const assigned=v=>{v=bytes(v);return v[0]===0?new Uint8Array():Uint8Array.from(v);};
const resref=v=>{v=bytes(v).subarray(0,16);const n=v.indexOf(0);return Uint8Array.from(v.subarray(0,n<0?v.length:n));};
export const createTalkRecord=()=>({text:new Uint8Array(),sound:new Uint8Array(),durationBits:0});
export function assignTalkRecord(out,value){out.text=assigned(value.text);out.sound=resref(value.sound);out.durationBits=u32(value.durationBits,'duration bits');return out;}
const clear=out=>{out.text=new Uint8Array();out.sound=new Uint8Array();};

// FetchInternal140198c60..1994b7. Hash containers/file I/O/token parsing are
// lower providers; successful ordinary records and caches retain native bytes.
function* fetchTalkRecordSteps(state,ref,out,parse){
 ref>>>=0;parse|=0;const gender=u32(state.gender,'gender')&255;
 if(ref===0xffffffff||gender>1){clear(out);if(gender>1)yield['warning',0x17f];return 1;}
 const override=yield['override',ref];
 if(override!==null){out.text=assigned(override);out.sound=new Uint8Array();yield['parse',state,out];return 1;}
 const custom=(ref&0x01000000)!==0,file=yield['file',custom,gender],index=custom?ref&0xffffff:ref;
 if(custom&&!file){out.text=encodeGffText(`BadStrRef(${ref|0})`);return 1;}
 if(!file){clear(out);yield['warning',0x1a6];return 0;}
 if(parse===0){const cached=yield['cached',file,index];if(cached!==null){assignTalkRecord(out,cached);return 1;}}
 const fallback=function*(line){if(gender===1){state.gender=0;return yield*fetchTalkRecordSteps(state,ref,out,parse);}yield['warning',line];return 0;};
 const size=u32(file.version14,'version')===0x302e3356?40:36,entryOffset=(Math.imul(index,size)+20)>>>0;
 if(index>=u32(file.count1c,'entry count')||entryOffset>u32(yield['size',file],'file size'))return yield*fallback(0x1d2);
 if(!(yield['seek',file,entryOffset]))return yield*fallback(0x1dd);
 const entry=new Uint8Array(40),read=yield['read',file,entry,size];
 if(read!==size)return yield*fallback(0x1eb);
 const view=new DataView(entry.buffer),flags=view.getUint32(0,true);out.durationBits=flags&4?view.getUint32(36,true):0;
 out.sound=flags&2?resref(entry.subarray(4,20)):new Uint8Array();
 if(!(flags&1)){out.text=new Uint8Array();return 1;}
 const offset=(u32(file.textOffset20,'text offset')+view.getUint32(28,true))>>>0,length=view.getUint32(32,true);
 const fail=function*(line){clear(out);yield['warning',line];return 0;};
 if(offset>u32(yield['size',file],'file size'))return yield*fail(0x219);
 if(!(yield['seek',file,offset]))return yield*fail(0x221);
 if(length===0)return yield*fail(0x22b);
 const storage=yield['allocate',length];if(!(storage?.bytes instanceof Uint8Array)||storage.bytes.length!==length||!(storage.defined instanceof Uint8Array)||storage.defined.length!==length)throw new Error('Native TLK allocation storage is unavailable');
 const actual=yield['read',file,storage.bytes,length];storage.defined.fill(1,0,actual);
 if(storage.defined.some(v=>v===0))throw new Error('Native TLK short text read leaves unknown allocated bytes');
 const text=createTalkRecord();text.text=assigned(storage.bytes);if(actual!==length)yield['warning',0x234];
 if(parse!==0)yield['parse',state,text];out.text=assigned(text.text);
 if(parse===0)yield['cache',file,index,assignTalkRecord(createTalkRecord(),out)];return 1;
}
export async function fetchTalkRecord(state,ref,out,parse,p){const steps=fetchTalkRecordSteps(state,ref,out,parse);let step=steps.next();while(!step.done){const[name,...args]=step.value;step=steps.next(await p[name](...args));}return step.value;}
export function fetchTalkRecordSync(state,ref,out,parse,p){const steps=fetchTalkRecordSteps(state,ref,out,parse);let step=steps.next();while(!step.done){const[name,...args]=step.value,value=p[name](...args);if(value&&typeof value.then==='function')throw new Error(`Native synchronous talk-table provider ${name} is unavailable`);step=steps.next(value);}return step.value;}

// ExecuteCommandGetStrByStrRef140530e20: transfer success body; gender write
// persists, including any female-to-male fallback performed by FetchInternal.
export async function scriptGetStringByStrRef(state,ref,gender=0,p){
 gender|=0;state.gender=gender===1?1:0;const out=createTalkRecord();await fetchTalkRecord(state,ref>>>0,out,0,p);return assigned(out.text);
}
export function scriptGetStringByStrRefSync(state,ref,gender=0,p){
 gender|=0;state.gender=gender===1?1:0;const out=createTalkRecord();fetchTalkRecordSync(state,ref>>>0,out,0,p);return assigned(out.text);
}
