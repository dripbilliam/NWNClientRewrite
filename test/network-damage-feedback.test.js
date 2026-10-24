import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {presentDamageFeedback} from '../src/network_damage_feedback.js';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {scriptStringBytes} from '../src/script_string.js';
import {decodeGffText} from '../src/gff_text.js';
import {NetworkWorld} from '../src/network_world.js';import {NetworkText} from '../src/network_text.js';import {NetworkFeedbackView} from '../src/network_feedback_view.js';import {parse2da} from '../src/area.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-damage-feedback-observations.json',import.meta.url)));
const pretty=t=>'{'+Object.keys(t).sort().map(k=>JSON.stringify(k)+': '+JSON.stringify(t[k]).replace(/[\u007f-\uffff]/g,c=>'\\u'+c.charCodeAt(0).toString(16).padStart(4,'0'))).join(', ')+'}';
function packet({sourceId=0xffffffff,targetId=0xfffffffe,damage,debug=null}){const w=new NativeMessageWriter(1);w.create(14,0xffffffff,1);w.writeObjectIdClient(sourceId);w.writeObjectIdClient(targetId);for(const amount of damage){w.writeBool(amount!==-1);if(amount!==-1)w.writeWord(amount,14);}w.writeBool(debug!==null);if(debug!==null){const bytes=scriptStringBytes(debug);w.writeCExoString({bytes,length:bytes.length});}w.setPrefix(Uint8Array.of(80,18,3));return Uint8Array.from(w.getWriteMessage().data);}
test('2592 original CC3 cases match grouping, native templates/token order, colors, debug text and floating selection',async()=>{
 assert.equal(native.cases.length,2592);
 for(const row of native.cases){assert.equal(row.error,null);const c=row.case,tokens={1:'old1',2:'old2'},calls=[],outputs=[],floating=[],cells=new Map(row.calls.filter(v=>v[0]==='cell').map(v=>[v.slice(1,4).join(':'),v[4]]));
  await presentDamageFeedback({sourceId:0x80000063,targetId:0x80000064,damage:row.damage,debug:c.debug?'Debug':null},{
   typeRows:()=>c.typeRows,cell:(table,index,column)=>{const key=[table,index,column].join(':');assert.ok(cells.has(key));const value=cells.get(key);calls.push(['cell',table,index,column,value]);return{found:value!==null,value:value??0};},
   name:id=>{const found=Boolean(c.names>>(Number(id===0x80000064))&1);calls.push(['name',id,found]);return found?id===0x80000063?'Source':'Target':null;},player:()=>{calls.push(['player']);return c.player?{id:c.player===1?0x80000063:0x80000064}:null;},
   tlk:ref=>{calls.push(['tlk',ref]);return'T'+ref;},parse:ref=>{calls.push(['parse',ref]);return'P'+ref+pretty(tokens);},token:(id,value)=>{tokens[id]=value;calls.push(['token',id,value]);},display:(raw,flags)=>outputs.push({raw,flags}),
   options:()=>({enabled:c.floatMode!==0,total:c.floatMode===1,color:'<c\xfe\x01\x01>'}),target:id=>{calls.push(['target-object',id]);return c.target;},floating:v=>floating.push(v)
  });
  assert.deepEqual(outputs,row.outputs,JSON.stringify(c));assert.deepEqual(floating,row.floating);assert.deepEqual(tokens,row.tokens);assert.deepEqual(calls,row.calls.filter(v=>!['object','build','bool','word','overflow','number','debug'].includes(v[0])));
 }
});
test('damage wire decoding preserves canonical IDs, absent versus zero slots, 14-bit bounds, debug bytes and server build gates',()=>{
 for(const newBuild of[false,true])for(const debug of[null,'','Debug €']){const damage=Array.from({length:newBuild?32:13},(_,i)=>i%3===0?-1:i%3===1?0:16383),p=packet({damage,debug}),m=decodeServerGameMessage(p,{serverBuild:{number:8193,revision:newBuild?35:34,postfix:0}});
  assert.equal(m.kind,'damage-feedback');assert.equal(m.sourceId,0xffffffff);assert.equal(m.targetId,0xfffffffe);assert.deepEqual(m.damage,damage);assert.equal(m.debug,debug);
  for(let n=3;n<p.length;n++)assert.throws(()=>decodeServerGameMessage(p.subarray(0,n),{serverBuild:{number:8193,revision:newBuild?35:34,postfix:0}}));assert.throws(()=>decodeServerGameMessage(Uint8Array.from([...p,0,0]),{serverBuild:{number:8193,revision:newBuild?35:34,postfix:0}}));assert.throws(()=>decodeServerGameMessage(p));
 }
});
test('60 complete original damage writers with real codecs agree byte-for-byte except unowned final padding',()=>{
 const wire=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-damage-feedback-wire.json',import.meta.url)));assert.equal(wire.cases.length,60);
 for(const row of wire.cases){const c=row.case,expected=Uint8Array.from(Buffer.from(row.packet,'hex')),message=decodeServerGameMessage(expected,{serverBuild:{number:8193,revision:c.newBuild?35:34,postfix:0}}),external=id=>id===0x7f000000?id:(id|0x80000000)>>>0;
  assert.equal(message.sourceId,external(c.sourceId));assert.equal(message.targetId,external(c.targetId));assert.deepEqual(message.damage,row.inputDamage.slice(0,c.newBuild?32:13).map(v=>v<0?-1:v&16383));assert.equal(message.debug,row.debugHex===null?null:decodeGffText(Uint8Array.from(Buffer.from(row.debugHex,'hex'))));
  const actual=packet(message),fragmentOffset=new DataView(expected.buffer,expected.byteOffset,expected.byteLength).getUint32(3,true),used=expected[fragmentOffset]>>>5;if(used){const mask=(255<<(8-used))&255;expected[expected.length-1]&=mask;actual[actual.length-1]&=mask;}assert.deepEqual(actual,expected);
 }
});
test('sealed vanilla-server killing-blow capture contains the same24 damage reported by its attack animation',()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/local-network-renderer-v34.json',import.meta.url))),messages=capture.wireMessages.filter(h=>h.startsWith('501203')).map(h=>decodeServerGameMessage(Uint8Array.from(Buffer.from(h,'hex')),{serverBuild:{number:8193,revision:37,postfix:17}}));
 assert.equal(messages.length,1);assert.equal(messages[0].sourceId,0xffffffff);assert.equal(messages[0].targetId,0x80000012);assert.equal(messages[0].damage.filter(v=>v!==-1).reduce((a,b)=>a+b,0),24);
});
test('unavailable/invalid active group metadata is not guessed and presentation never writes canonical state',async()=>{
 await assert.rejects(presentDamageFeedback({damage:[1]}, {typeRows:()=>2}),/exceeds/);
 await assert.rejects(presentDamageFeedback({damage:[1]}, {typeRows:()=>1,cell:(_t,_r,c)=>c==='DamageTypeGroup'?{found:true,value:-1}:{found:false}}),/group index/);
});
test('network damage view resolves active group metadata, forwards native float events and preserves canonical HP',async()=>{
 const world=new NetworkWorld(),rows=[],floating=[],reports=[],tables={damagetypes:parse2da('2DA V2.0\n\nDamageTypeGroup\n0 0\n1 0\n'),damagetypegroups:parse2da('2DA V2.0\n\nColorR ColorG ColorB FeedbackStrref\n0 255 102 0 700\n')};world.areaId=0x80000001;world.localObjectId=0xffffffff;world.registry.addObjectAtPos(0xffffffff,{id:0xffffffff,objectType:5,areaId:world.areaId,replicated:{name:{firstName:{text:'Actor'}}},hp:77});const before=JSON.stringify([...world.registry.objects]);
 const text=new NetworkText({world,getResource:async()=>scriptStringBytes('2DA V2.0\n\nToken Default StrRef0\n'),talkString:async ref=>({text:ref===10466?'<CUSTOM0> damages <CUSTOM1>: <CUSTOM2>':ref===700?'<CUSTOM0> Physical':'Someone'}),diagnose:(...v)=>reports.push(v)}),view=new NetworkFeedbackView({world:()=>world,text:()=>text,tables:()=>tables,display:r=>rows.push(r),floating:e=>floating.push(e),report:(...v)=>reports.push(v)});
 await view.receive({kind:'damage-feedback',sourceId:0xffffffff,targetId:0xffffffff,damage:[2,3,...Array(30).fill(-1)],debug:'Native debug'});assert.equal(rows[0].text,'Actor damages Actor: 5 (5 Physical)');assert.equal(rows[1].text,'Native debug');assert.equal(rows[1].category,'damage-debug');assert.equal(floating[0].objectId,0xffffffff);assert.equal(floating[0].raw,'<c\xff\x66\x01>5</c>');assert.equal(JSON.stringify([...world.registry.objects]),before);assert.deepEqual(reports,[]);
});
