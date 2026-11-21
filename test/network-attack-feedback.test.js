import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {presentAttackFeedback} from '../src/network_attack_feedback.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';import {NativeMessageWriter} from '../src/native_message.js';
import {decodeGffText} from '../src/gff_text.js';import {scriptStringBytes} from '../src/script_string.js';
import {NetworkWorld} from '../src/network_world.js';import {NetworkText} from '../src/network_text.js';import {NetworkFeedbackView} from '../src/network_feedback_view.js';import {parse2da} from '../src/area.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-attack-feedback-observations.json',import.meta.url)));
const pretty=t=>'{'+Object.keys(t).sort().map(k=>JSON.stringify(k)+': '+JSON.stringify(t[k]).replace(/[\u007f-\uffff]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0'))).join(', ')+'}';
test('1650 original ordinary/special attack receivers match result text, flags, mode prefixes, tokens and floating owners',async()=>{
 assert.equal(native.cases.length,1650);
 for(const row of native.cases){assert.equal(row.error,null);const c=row.case,tokens={1:'old1',2:'old2'},calls=[],outputs=[],floating=[];
  await presentAttackFeedback({...c,sourceId:0x80000063,targetId:0x80000064,debug:c.debug?'Debug':null},{
   name:id=>{const found=Boolean(c.names>>(Number(id===0x80000064))&1);calls.push(['name',id,found]);return found?id===0x80000063?'Source':'Target':null;},
   player:()=>{calls.push(['player']);return c.player?{id:c.player===1?0x80000063:0x80000064}:null;},
   tlk:ref=>{calls.push(['tlk',ref]);return'T'+ref;},parse:ref=>{calls.push(['parse',ref]);return'P'+ref+pretty(tokens);},
   token:(id,value)=>{tokens[id]=value;calls.push(['token',id,value]);},display:(raw,flags)=>outputs.push({raw,flags}),
   options:()=>({enabled:!!c.floating}),creature:id=>{calls.push(['target-creature',id]);return c.target;},floating:v=>floating.push(v),
   warning:text=>calls.push(['warning',text]),feat:id=>{calls.push(['feat',id]);return c.featAvailable?{name:5001}:null;}
  });
  const context=JSON.stringify(c);assert.deepEqual(outputs,row.outputs,context);assert.deepEqual(floating,row.floating,context);assert.deepEqual(tokens,row.tokens,context);assert.deepEqual(calls,row.calls.filter(v=>!['object','char','byte','word','bool','overflow','number','debug'].includes(v[0])),context);
 }
});
function packet(m){const w=new NativeMessageWriter(1);w.create(12,0xffffffff,1);w.writeObjectIdClient(m.sourceId);w.writeObjectIdClient(m.targetId);w.writeType(4);w.raw(m.modifier,1);w.writeByte(m.roll,5);w.writeByte(m.result,4);if(m.minor===6)w.writeWord(m.attackType,16);w.writeByte(m.combatMode,4);for(const value of[m.offhand,m.sneakAttack,m.deathAttack,...(m.minor===5?[m.specialMinus534,m.coupDeGrace]:[]),m.threatened])w.writeBool(value);if(m.threatened)w.writeByte(m.confirmation,5);if(m.result===8||m.result===9)w.writeByte(m.concealmentChance,7);w.writeBool(m.debug!==null);if(m.debug!==null){const bytes=scriptStringBytes(m.debug);w.writeCExoString({bytes,length:bytes.length});}w.setPrefix(Uint8Array.of(80,18,m.minor));return Uint8Array.from(w.getWriteMessage().data);}
test('1152 complete original CC5/6 writer packets decode with canonical IDs and native width truncation',()=>{
 const wire=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-attack-feedback-wire.json',import.meta.url)));assert.equal(wire.cases.length,1152);
 for(const row of wire.cases){const c=row.case,expected=Uint8Array.from(Buffer.from(row.packet,'hex')),message=decodeServerGameMessage(expected),external=id=>id===0x7f000000?id:(id|0x80000000)>>>0;
  assert.deepEqual(message,{kind:'attack-feedback',major:18,minor:c.minor,sourceId:external(c.sourceId),targetId:external(c.targetId),modifier:(c.modifier<<24)>>24,roll:c.roll&31,result:c.result&15,attackType:c.minor===6?c.attackType:null,combatMode:c.combatMode&15,offhand:Number(c.weaponAttackType===2),sneakAttack:c.sneakAttack,deathAttack:c.deathAttack,specialMinus534:c.minor===5?Number(c.attackType===0xfdea):0,coupDeGrace:c.minor===5?c.coupDeGrace:0,threatened:c.threatened,confirmation:c.threatened?c.confirmation&31:null,concealmentChance:c.result===8||c.result===9?c.concealmentChance&127:0,debug:row.debugHex===null?null:decodeGffText(Uint8Array.from(Buffer.from(row.debugHex,'hex')))});
  const actual=packet(message),offset=new DataView(expected.buffer,expected.byteOffset,expected.byteLength).getUint32(3,true),used=expected[offset]>>>5;if(used){const mask=255<<(8-used)&255;expected[expected.length-1]&=mask;actual[actual.length-1]&=mask;}assert.deepEqual(actual,expected);
 }
 for(const row of wire.cases.filter((_,i)=>i%47===0)){const p=Uint8Array.from(Buffer.from(row.packet,'hex'));for(let n=3;n<p.length;n++)assert.throws(()=>decodeServerGameMessage(p.subarray(0,n)));assert.throws(()=>decodeServerGameMessage(Uint8Array.from([...p,0,0])));}
});
test('real sealed attack packet now produces feedback instead of unsupported without resolving a local strike',()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v34.json',import.meta.url))),messages=capture.wireMessages.filter(h=>h.startsWith('501205')).map(h=>decodeServerGameMessage(Uint8Array.from(Buffer.from(h,'hex'))));assert.ok(messages.length);assert.ok(messages.some(m=>m.sourceId===0xffffffff&&m.targetId===0x80000012));
});
test('active feat metadata, overrides and native parser flags flow to presentation without canonical mutations',async()=>{
 const world=new NetworkWorld(),rows=[],floating=[],reports=[];world.areaId=0x80000001;world.localObjectId=0xffffffff;world.registry.addObjectAtPos(0xffffffff,{id:0xffffffff,objectType:5,areaId:world.areaId,replicated:{name:{firstName:{text:'Actor'}}},hp:77});const before=JSON.stringify([...world.registry.objects]);
 const tables={feat:parse2da('2DA V2.0\n\nFeat\n0 700\n1 ****\n')};world.tlkOverrides.set(700,'Server attack name');
 const text=new NetworkText({world,getResource:async()=>scriptStringBytes('2DA V2.0\n\nToken Default StrRef0\n'),talkString:async ref=>({text:ref===10471?'<CUSTOM0> uses <CUSTOM1> on <CUSTOM2>: <CUSTOM3>':ref===511?'Hit':'Someone'}),diagnose:(...v)=>reports.push(v)}),view=new NetworkFeedbackView({world:()=>world,text:()=>text,tables:()=>tables,display:r=>rows.push(r),floating:e=>floating.push(e),report:(...v)=>reports.push(v)});
 await view.receive({kind:'attack-feedback',minor:6,sourceId:0xffffffff,targetId:0xffffffff,modifier:2,roll:17,result:1,combatMode:0,offhand:0,sneakAttack:0,deathAttack:0,attackType:0,threatened:0,debug:null});assert.equal(rows[0].text,'Actor uses  on Actor: Hit');
 tables.feat=parse2da('2DA V2.0\n\nFeat\n0 ****\n1 700\n');await view.receive({kind:'attack-feedback',minor:6,sourceId:0xffffffff,targetId:0xffffffff,modifier:2,roll:17,result:1,combatMode:0,offhand:0,sneakAttack:0,deathAttack:0,attackType:1,threatened:0,debug:null});assert.equal(rows[1].text,'Actor uses Server attack name on Actor: Hit');assert.equal(floating[1].font,'');assert.equal(floating[1].raw,'Server attack name: *Hit*');assert.equal(JSON.stringify([...world.registry.objects]),before);assert.deepEqual(reports,[]);
});
test('fresh vanilla-server practice/campaign capture preserves actual attack rolls, zero damage and five positive spell hits',()=>{
 const fixture=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-attack-feedback-captured-v119.json',import.meta.url))),proof=JSON.parse(fs.readFileSync(new URL('../backups/animations/network-attack-feedback-melee-v119.json',import.meta.url))),messages=fixture.packets.map(r=>decodeServerGameMessage(Uint8Array.from(Buffer.from(r.packet,'hex')),{serverBuild:fixture.source.serverBuild}));
 assert.equal(fixture.source.finalPhase,'closed');assert.equal(fixture.source.driverFailure,null);assert.match(fixture.source.sha256,/^[0-9a-f]{64}$/);
 const attacks=messages.filter(m=>m.kind==='attack-feedback'),damage=messages.filter(m=>m.kind==='damage-feedback'),total=m=>m.damage.reduce((sum,n)=>sum+(n<0?0:n),0);
 assert.equal(attacks.length,6);assert.ok(attacks.every(m=>m.sourceId===fixture.sourceId&&m.targetId===fixture.dummyId&&m.result===1));assert.ok(attacks.some(m=>m.threatened===1));
 for(const m of attacks)assert.ok(proof.attacks.some(r=>r.text.includes('('+m.roll+' '+(m.modifier<0?'-':'+')+' '+Math.abs(m.modifier)+' = '+(m.roll+m.modifier))));
 assert.deepEqual(damage.filter(m=>m.targetId===fixture.statueId).map(total),[5,3,2,3,4]);assert.ok(damage.filter(m=>m.targetId===fixture.dummyId).every(m=>total(m)===0));
 const world=new NetworkWorld();world.registry.addObjectAtPos(fixture.sourceId,{id:fixture.sourceId,objectType:5,hp:77});const before=JSON.stringify([...world.registry.objects]);for(const m of messages)world.apply(m);assert.equal(JSON.stringify([...world.registry.objects]),before);
});
