import {parseTalkTable} from '../src/talk_table.js';import {fetchTalkRecordSync,createTalkRecord} from '../src/native_talk_table.js';import {decodeGffText} from '../src/gff_text.js';
export class SceneReplayTalk {
 constructor(){this.tables=new WeakMap();}
 async read(resolver,ref,gender=0){
  if(!Number.isInteger(ref)||ref<0||ref>0xffffffff||![0,1].includes(gender))throw Error('Invalid offline talk string request');
  if(ref===0xffffffff)return{status:1,text:'',sound:'',durationBits:0,gender};
  const alias=ref&0x01000000?'__talk_custom':'__talk_main';
  let tables=this.tables.get(resolver);if(!tables){tables=new Map();this.tables.set(resolver,tables);}
  const load=name=>{if(!tables.has(name))tables.set(name,resolver.getResource(name,2018).then(b=>parseTalkTable(b).nativeFile));return tables.get(name);};
  const base=await load(alias),female=resolver.resourceRecord(alias+'_female',2018),pair=[base,female&&!female.missing?await load(alias+'_female'):base],state={gender},record=createTalkRecord();
  const status=fetchTalkRecordSync(state,ref,record,0,{override:()=>null,file:(_custom,g)=>pair[g],cached:(f,i)=>f.cache.get(i)??null,cache:(f,i,r)=>f.cache.set(i,r),warning:()=>{},parse:()=>{throw Error('Offline talk override parser is unavailable');},size:f=>f.bytes.length,seek:(f,o)=>{f.position=o;return Number(o<=f.bytes.length);},read:(f,out,n)=>{const b=f.bytes.subarray(f.position,f.position+n);out.set(b);f.position+=b.length;return b.length;},allocate:n=>{if(n>64*1024*1024)throw Error('Offline talk text exceeds supported size');return{bytes:new Uint8Array(n),defined:new Uint8Array(n)};}});
  return{status,text:decodeGffText(record.text),sound:decodeGffText(record.sound),durationBits:record.durationBits,gender:state.gender};
 }
}
