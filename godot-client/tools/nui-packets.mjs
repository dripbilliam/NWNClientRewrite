import {createHash} from 'node:crypto';
export const NUI_FRAME_BYTES=60000,NUI_PAYLOAD_BYTES=16*1024*1024,NUI_PART_CHARS=48000;
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const serial=v=>Number.isSafeInteger(v)&&v>=0;
const outputKinds=new Set(['nui-frame','nui-nodes','nui-skin','nui-notice']);
export function nuiPackets(message,transferId){
 const bytes=Buffer.from(JSON.stringify(message));
 if(bytes.length<NUI_FRAME_BYTES)return[message];
 if(bytes.length>NUI_PAYLOAD_BYTES)throw Error('NUI payload exceeds 16 MiB capacity');
 const input=message.kind==='nui-input';
 if(!input&&!outputKinds.has(message.kind)||input&&message.operation==='fragment')throw Error('Unsupported fragmented NUI message');
 const data=bytes.toString('base64'),parts=Math.ceil(data.length/NUI_PART_CHARS),base={connection:message.connection,transferId,...(input?{kind:'nui-input',operation:'fragment',windowId:message.windowId}:{})};
 const packet=(phase,fields={})=>({...base,...(input?{phase}:{kind:'nui-json-'+phase}),...fields});
 return[packet('begin',{bytes:bytes.length,parts,sha256:digest(bytes)}),...Array.from({length:parts},(_,part)=>packet('part',{part,data:data.slice(part*NUI_PART_CHARS,(part+1)*NUI_PART_CHARS)})),packet('end')];
}
export class NuiPacketReceiver{
 constructor(){this.pending=null;}
 reset(){this.pending=null;}
 receive(message,connection){
  try{
   if(message.kind!=='nui-input'||message.operation!=='fragment'||message.connection!==connection||!serial(message.transferId)||!serial(message.windowId))throw Error('Invalid NUI fragment owner');
   const phase=message.phase;
   if(phase==='begin'){
    if(this.pending||!Number.isSafeInteger(message.bytes)||message.bytes<0||message.bytes>NUI_PAYLOAD_BYTES||!Number.isSafeInteger(message.parts)||message.parts<1||message.parts>Math.ceil(NUI_PAYLOAD_BYTES*4/3/NUI_PART_CHARS)||!/^[a-f0-9]{64}$/.test(message.sha256??''))throw Error('Invalid NUI fragment size');
    this.pending={...message,chunks:[],characters:0};return null;
   }
   const p=this.pending;
   if(!p||p.transferId!==message.transferId||p.windowId!==message.windowId||p.connection!==connection)throw Error('Unknown NUI fragment transfer');
   if(phase==='part'){
    if(message.part!==p.chunks.length||p.chunks.length>=p.parts||typeof message.data!=='string'||message.data.length>NUI_PART_CHARS||!/^[a-zA-Z0-9+/]*={0,2}$/.test(message.data)||p.characters+message.data.length>Math.ceil(p.bytes/3)*4)throw Error('Invalid NUI fragment sequence');
    p.chunks.push(message.data);p.characters+=message.data.length;return null;
   }
   this.reset();
   if(phase!=='end'||p.chunks.length!==p.parts)throw Error('Truncated NUI fragment transfer');
   const bytes=Buffer.from(p.chunks.join(''),'base64');
   if(bytes.length!==p.bytes||digest(bytes)!==p.sha256)throw Error('NUI payload digest mismatch');
   const value=JSON.parse(new TextDecoder('utf8',{fatal:true}).decode(bytes));
   if(!value||value.kind!=='nui-input'||value.operation==='fragment'||value.connection!==connection||value.windowId!==p.windowId)throw Error('Invalid reconstructed NUI owner');
   return value;
  }catch(error){this.reset();throw error;}
 }
}
