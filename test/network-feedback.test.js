import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {NativeMessageWriter} from '../src/native_message.js';
import {readNetworkFeedback} from '../src/network_feedback_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {CLIENT_FEEDBACK_DESCRIPTORS} from '../src/client_feedback_descriptors.js';
import {formatClientFeedback,defaultFeedbackColor} from '../src/client_feedback_format.js';
import {nativeRichText} from '../src/native_rich_text.js';
import {NetworkFeedbackView} from '../src/network_feedback_view.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkText} from '../src/network_text.js';
import {scriptStringBytes} from '../src/script_string.js';
import {decodeGffText} from '../src/gff_text.js';
const load=name=>JSON.parse(fs.readFileSync(new URL('../backups/animations/'+name,import.meta.url)));
const layouts=load('native-client-feedback-layouts.json'),formats=load('native-client-feedback-format-observations.json');
const build=ok=>({number:8193,revision:ok?37:34,postfix:ok?17:0});
function packet(major,minor,write){const w=new NativeMessageWriter(1);w.create(128,0xffffffff,1);write(w);w.setPrefix(Uint8Array.of(80,major,minor));return Uint8Array.from(w.getWriteMessage().data);}
const normalize=data=>data?{...data,strings:Object.fromEntries(Object.entries(data.strings).map(([k,v])=>[k,v.baseItem!==undefined?'BaseItemName':v.text]))}:{integers:{},objects:{},strings:{}};

test('2096 bounded original receiver traces agree on field order, slot numbers, build gates and colors',()=>{
 assert.equal(layouts.cases.length,2096);assert.equal(layouts.target,formats.target);
 for(const row of layouts.cases){
  assert.equal(row.error,null);let at=0;
  const read=kind=>{const v=row.reads[at++];assert.equal(v?.kind,kind,'type '+row.type);return v.value;};
  const r={readWord:()=>row.type,readInt:()=>read('int'),readDword:()=>read('dword'),readByte:()=>read('byte'),readObjectIdClient:()=>read('object'),readBool:()=>row.reads[at]?.kind==='localized'?0:read('bool'),readCExoString:()=>{const kind=row.reads[at]?.kind,value=read(kind);assert.ok(['localized','string'].includes(kind));return{bytes:scriptStringBytes((kind==='localized'?'L':'S')+value)};}};
  const decoded=readNetworkFeedback(r,build(row.buildOk));assert.equal(at,row.reads.length);assert.deepEqual(normalize(decoded.data),row.outputs[0].data??{integers:{},objects:{},strings:{}});assert.equal(decoded.color,row.outputs[0].color);
 }
});

test('real wire codec round trips every native trace, with raw and localized name encodings',()=>{
 for(const row of layouts.cases){
  const bytes=packet(18,11,w=>{w.writeWord(row.type);for(const f of row.reads){
   if(f.kind==='object')w.writeObjectIdClient(f.value);else if(f.kind==='int')w.writeInt(f.value);else if(f.kind==='byte')w.writeByte(f.value);else if(f.kind==='dword')w.writeDword(f.value);else if(f.kind==='bool')w.writeBool(f.value);else{if(f.kind==='localized')w.writeBool(0);const b=scriptStringBytes((f.kind==='localized'?'L':'S')+f.value);w.writeCExoString({bytes:b,length:b.length});}
  }});
  const decoded=decodeServerGameMessage(bytes,{serverBuild:build(row.buildOk)});assert.deepEqual(normalize(decoded.data),row.outputs[0].data??{integers:{},objects:{},strings:{}});
 }
 const p=packet(18,11,w=>{w.writeWord(4);w.writeObjectIdClient(0xffffffff);w.writeBool(1);w.writeBool(1);w.writeBool(1);w.writeByte(1,1);w.writeDword(0xffffffff);});
 assert.deepEqual(decodeServerGameMessage(p,{serverBuild:build(1)}).data,{integers:{},objects:{0:0xffffffff},strings:{0:{gender:1,strRef:0xffffffff}}});
});

test('captured native startup feedback has two integers and no object; invalid streams fail closed',()=>{
 const p=Uint8Array.from(Buffer.from('50120b11000000470000000000000000006f','hex')),m=decodeServerGameMessage(p);
 assert.equal(m.type,71);assert.deepEqual(m.data,{integers:{0:0,1:0},objects:{},strings:{}});
 for(let n=3;n<p.length;n++)assert.throws(()=>decodeServerGameMessage(p.subarray(0,n)));
 assert.throws(()=>decodeServerGameMessage(Uint8Array.from([...p,0,0])));
 assert.throws(()=>decodeServerGameMessage(packet(18,11,w=>{w.writeWord(93);w.writeObjectIdClient(1);w.writeInt(2);})));
});

test('169 conservative formatter branches match every original varied profile, including preserved tokens and parse flags',async()=>{
 assert.equal(Object.keys(CLIENT_FEEDBACK_DESCRIPTORS).length,169);let checked=0;
 for(const row of formats.cases){if(!CLIENT_FEEDBACK_DESCRIPTORS[row.type])continue;
  assert.equal(row.error,null);const tokens={1:'old1',2:'old2'},writes=[],parses=[],data={integers:{},objects:{},strings:{}};
  for(const c of row.calls){if(c[0]==='integer')data.integers[c[1]]=c[2];else if(c[0]==='object')data.objects[c[1]]=0x80000063+c[1];else if(c[0]==='string')data.strings[c[1]]={text:'String'+c[1]};}
  const pretty=t=>'{'+Object.keys(t).sort().map(k=>JSON.stringify(k)+': '+JSON.stringify(t[k])).join(', ')+'}';
  const result=await formatClientFeedback({type:row.type,data,color:''},{tlk:ref=>'T'+ref,name:id=>row.names?'Name'+id:null,string:s=>s.text,token:(id,v)=>{tokens[id]=v;writes.push(['token',id,v]);},parse:(ref,options)=>{parses.push(['parse',ref,options]);return'P'+ref+pretty(tokens);}});
  assert.deepEqual(result,{...row.outputs[0],type:row.type},'type '+row.type+' profile '+row.profile);assert.deepEqual(tokens,row.tokens);assert.deepEqual(writes,row.calls.filter(c=>c[0]==='token'));assert.deepEqual(parses,row.calls.filter(c=>c[0]==='parse'));checked++;
 }
 assert.equal(checked,3380);
});

test('71 swaps native token slots, respects receiver colors, and unknown formatters stay explicit',async()=>{
 const tokens={},p={token:(id,v)=>tokens[id]=v,parse:()=>`Penalty ${tokens[0]} Failure ${tokens[1]}`};
 const result=await formatClientFeedback({type:71,data:{integers:{0:-12,1:37}},color:'<c\xcc\x77\xff>'},p);
 assert.equal(result.raw,'<c\xcc\x77\xff>Penalty 37 Failure -12</c>');
 assert.equal(await formatClientFeedback({type:8,data:{}},p),null);
 assert.equal((await formatClientFeedback({type:71,data:{integers:{}},color:''},{...p,parse:()=>''})).raw,'');
});

test('server custom tokens update sorted connection-owned text state without changing canonical objects',async()=>{
 const world=new NetworkWorld(),objects=JSON.stringify([...world.registry.objects]);
 const text=new NetworkText({world,getResource:async()=>scriptStringBytes('2DA V2.0\n\nToken Default StrRef0\n'),talkString:async()=>({text:'<CUSTOM12>/<CUSTOM0>'}),diagnose:()=>{}});
 for(const [id,value]of [[12,'Server'],[0,'Reserved'],[-1,'Ignored'],[12,'Changed']])world.apply(decodeServerGameMessage(packet(50,1,w=>{w.writeInt(id);const b=scriptStringBytes(value);w.writeCExoString({bytes:b,length:b.length});})));
 assert.deepEqual(world.customTokens.records.map(r=>r.id),[0,12]);assert.equal(await text.resolve({strRef:1},0x7f000000),'Changed/Reserved');assert.equal(JSON.stringify([...world.registry.objects]),objects);
 world.reset();assert.deepEqual(world.customTokens.records,[]);
});

test('rich text keeps byte RGB, restores nested color and treats markup as text',()=>{
 assert.deepEqual(nativeRichText(defaultFeedbackColor+'Outer <c\x8f\x7f\xff>Name</c> <img src=x></c>'),{text:'Outer Name <img src=x>',spans:[{text:'Outer ',color:'#ffff01'},{text:'Name',color:'#8f7fff'},{text:' <img src=x>',color:'#ffff01'}]});
 assert.equal(nativeRichText('<c\u{1f600}xx>literal').text,'<c\u{1f600}xx>literal');
});

test('feedback presentation reports unsupported owners, ignores stale output and never mutates gameplay state',async()=>{
 let world=new NetworkWorld(),released;const rows=[],reports=[],tokens=[];let pending=false;
 const text={raw:async v=>v.text??'Template',resolve:async()=>pending?new Promise(r=>released=r):'Formatted',token:(...v)=>tokens.push(v)};
 const view=new NetworkFeedbackView({world:()=>world,text:()=>text,tables:()=>null,display:r=>rows.push(r),report:(...v)=>reports.push(v)}),message={type:71,data:{integers:{0:12,1:34}}},before=JSON.stringify([...world.registry.objects]);
 await view.receive(message);assert.equal(rows[0].text,'Formatted');assert.equal(rows[0].richText[0].color,'#ffff01');assert.deepEqual(tokens,[[0,'34'],[1,'12']]);assert.equal(JSON.stringify([...world.registry.objects]),before);
 await view.receive({type:8,data:{}});assert.equal(reports.at(-1)[0],'network.feedback-format-unhandled');
 pending=true;const stale=view.receive(message);while(!released)await Promise.resolve();view.reset();world=new NetworkWorld();released('Late');await stale;assert.equal(rows.length,1);
});
