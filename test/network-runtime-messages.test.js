import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import {EventEmitter} from 'node:events';
import {NativeMessageWriter,NativeMessageReader} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {deviceEchoResponse,loginWaypointResponse} from '../src/network_runtime_messages.js';
import {decodeGffText} from '../src/gff_text.js';
import {NetworkWorld} from '../src/network_world.js';import {NetworkText} from '../src/network_text.js';import {NetworkGameSession} from '../electron/network_game_session.mjs';
import {NetworkQuickbarView} from '../src/network_quickbar_view.js';import {parse2da} from '../src/area.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-runtime-message-observations.json',import.meta.url))),build={number:8193,revision:37,postfix:17},decode=p=>decodeServerGameMessage(p,{clientBuild:build}),bytes=h=>Uint8Array.from(Buffer.from(h,'hex'));
const equalDefined=(actual,expected)=>{actual=Uint8Array.from(actual);expected=Uint8Array.from(expected);const used=expected.at(-1)>>>5;if(used){const mask=(255<<(8-used))&255;actual[actual.length-1]&=mask;expected[expected.length-1]&=mask;}assert.deepEqual(actual,expected);};
function packet(major,minor,write){const w=new NativeMessageWriter(1);w.create(32,0xffffffff,1);write(w);w.setPrefix(Uint8Array.of(80,major,minor));return Uint8Array.from(w.getWriteMessage().data);}
function session(options={}){const sent=[],diagnostics=[],peer=new EventEmitter();peer.sendGameMessage=async p=>sent.push(Uint8Array.from(p));peer.disconnect=async()=>{};const s=new NetworkGameSession({peer,identity:{dispose(){}},build:{build,dispose(){}},resources:{talkString:async ref=>({text:ref===0xffffffff?'':'Base '+ref})},onDiagnostic:d=>diagnostics.push(d),...options});return{s,peer,sent,diagnostics};}

test('54 complete native runtime sender cases and real opaque readers agree with supported fields',()=>{
 assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,54);
 for(const row of oracle.cases){
  if(row.kind.startsWith('echo')){
   assert.equal(row.decodedHex,row.dataHex);assert.equal(row.overflow,0);assert.equal(row.underflow,0);
   const data=bytes(row.dataHex),w=new NativeMessageWriter(row.format);w.create(data.length+4,0xffffffff,1);w.writeDword(data.length);w.writeOpaqueBytes(data);w.setPrefix(bytes(row.packet).subarray(0,3));equalDefined(w.getWriteMessage().data,bytes(row.packet));
   const r=new NativeMessageReader(row.format),p=bytes(row.packet);r.setReadMessage(p.subarray(3),p.length-3,0xffffffff,1);const length=r.readDword();assert.deepEqual(r.readOpaqueBytes(length),data);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);
   if(row.format===1&&row.kind==='echo-server')assert.deepEqual(decode(p).data,data);
   if(row.kind==='echo-client'){equalDefined(deviceEchoResponse(data,row.format),p);assert.equal(row.serverAccepted,1);assert.deepEqual(row.serverEcho,[{dataHex:row.dataHex,length:data.length}]);}
  }else if(row.kind.startsWith('tlk')&&row.format===1){const v=decode(bytes(row.packet));assert.deepEqual(v.entries,row.entries.map(e=>({strRef:e.strRef,text:decodeGffText(bytes(e.textHex))})));assert.deepEqual(row.applied,row.entries);}
  else if(row.kind==='waypoint'&&row.format===1&&row.textHex)equalDefined(loginWaypointResponse(decodeGffText(bytes(row.textHex))),bytes(row.packet));
 }
 assert.equal(loginWaypointResponse(''),null);assert.throws(()=>loginWaypointResponse('bad\0tag'));
});

test('echo and override messages reject truncated, oversized and trailing fields',()=>{
 for(const row of oracle.cases.filter(r=>r.format===1&&r.kind!=='waypoint')){const p=bytes(row.packet);if(row.kind==='echo-client')continue;for(let n=3;n<p.length;n++)assert.throws(()=>decode(p.subarray(0,n)),row.kind+' '+n);assert.throws(()=>decode(Uint8Array.from([...p,0,0])));}
 assert.throws(()=>decode(packet(54,2,w=>w.writeDword(0xffffffff))));assert.throws(()=>decode(packet(52,3,w=>w.writeDword(0xffffffff))));assert.equal(decode(Uint8Array.of(80,2,12)).kind,'login-waypoint-request');assert.throws(()=>decode(Uint8Array.of(80,2,12,0)));
});

test('server TLK list merges sequential overrides; empty text removes and connection reset clears',()=>{
 const w=new NetworkWorld(),originalObjects=[...w.registry.objects];w.apply({kind:'tlk-overrides',entries:[{strRef:1,text:'old'},{strRef:0xffffffff,text:'high'}]});w.apply({kind:'tlk-overrides',entries:[{strRef:2,text:'other'},{strRef:1,text:''},{strRef:2,text:'last'}]});assert.deepEqual([...w.tlkOverrides],[[0xffffffff,'high'],[2,'last']]);w.apply({kind:'tlk-overrides',entries:[]});assert.equal(w.tlkOverrides.size,2);assert.deepEqual([...w.registry.objects],originalObjects);w.reset();assert.equal(w.tlkOverrides.size,0);
});

test('server override changes and removals invalidate cached base strings, including high STRREFs',async()=>{
 const world=new NetworkWorld();let fetches=0;const text=new NetworkText({world,talkString:async ref=>{fetches++;return{text:'Base '+ref};}}),v={strRef:0x80000001};assert.equal(await text.raw(v),'Base 2147483649');assert.equal(await text.raw(v),'Base 2147483649');assert.equal(fetches,1);world.apply({kind:'tlk-overrides',entries:[{strRef:v.strRef,text:'Server €é'}]});assert.equal(await text.raw(v),'Server €é');assert.equal(await text.raw({...v,gender:1}),'Server €é');world.apply({kind:'tlk-overrides',entries:[{strRef:v.strRef,text:''}]});assert.equal(await text.raw(v),'Base 2147483649');assert.equal(fetches,2);world.apply({kind:'tlk-overrides',entries:[{strRef:0xffffffff,text:'Invalid sentinel override'}]});assert.equal(await text.raw({strRef:0xffffffff}),'');
});

test('session echoes during startup, preserves exact bytes and does not forward opaque data or mutate world',async()=>{
 const h=session(),events=[];h.s.on('message',e=>events.push(e));const data=Uint8Array.of(0,255,128,1),p=packet(54,2,w=>{w.writeDword(data.length);w.writeOpaqueBytes(data);}),before=h.s.world.snapshot();await h.s.receive(p);assert.equal(h.sent.length,1);equalDefined(h.sent[0],deviceEchoResponse(data));assert.equal(h.s.state().deviceEchoReplies,1);assert.deepEqual(events,[]);assert.deepEqual(h.s.world.snapshot(),before);assert.deepEqual(h.diagnostics,[]);await h.s.receive(Uint8Array.of(80,2,12));assert.equal(h.s.state().loginWaypointRequests,1);assert.equal(h.sent.length,1);await h.s.disconnect();await h.s.receive(p);assert.equal(h.sent.length,1);
});

test('configured login waypoint sends native text only when explicitly configured; backend TLK uses authoritative overrides',async()=>{
 const h=session({loginWaypoint:'ModuleSpawn'});await h.s.receive(Uint8Array.of(80,2,12));equalDefined(h.sent[0],loginWaypointResponse('ModuleSpawn'));await h.s.receive(Uint8Array.of(80,2,12));assert.equal(h.sent.length,1);h.s.resourceResult={ready:true,resolved:[]};const p=packet(52,2,w=>{w.writeInt(-2147483647);w.writeStringBytes(Uint8Array.of(83,101,114,118,101,114));});await h.s.receive(p);assert.equal((await h.s.talkString(0x80000001)).text,'Server');await h.s.receive(packet(52,2,w=>{w.writeInt(-2147483647);w.writeStringBytes(new Uint8Array());}));assert.equal((await h.s.talkString(0x80000001)).text,'Base 2147483649');
});

test('cached quickbar rule names follow server TLK updates and removals without changing the active rule row',async()=>{
 const world=new NetworkWorld(),text=new NetworkText({world,talkString:async ref=>({text:'Base '+ref})}),tables={spells:parse2da('2DA V2.0\n\nName\n0 123')},view={world:()=>world,labels:new Map(),tables,resolve:v=>text.raw(v)};assert.equal(await NetworkQuickbarView.prototype.ruleName.call(view,'spells',0),'Base 123');world.apply({kind:'tlk-overrides',entries:[{strRef:123,text:'Server spell name'}]});assert.equal(await NetworkQuickbarView.prototype.ruleName.call(view,'spells',0),'Server spell name');world.apply({kind:'tlk-overrides',entries:[{strRef:123,text:''}]});assert.equal(await NetworkQuickbarView.prototype.ruleName.call(view,'spells',0),'Base 123');assert.equal(tables.spells.rows.get(0).Name,'123');
});

test('sealed live startup packets decode to the verified native runtime handlers',()=>{
 const c=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-runtime-captured-v1.json',import.meta.url)));let echo=0;for(const h of c.packets){if(h.startsWith('50120b'))continue;const v=decode(bytes(h));if(h.startsWith('503602')){assert.equal(v.kind,'device-echo-request');assert.equal(v.data.length,0);echo++;}else if(h.startsWith('503403'))assert.deepEqual(v.entries,[]);else assert.equal(v.kind,'login-waypoint-request');}assert.ok(echo>3);
});
