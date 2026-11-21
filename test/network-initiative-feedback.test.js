import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {readNetworkInitiativeFeedback,presentInitiativeFeedback} from '../src/network_initiative_feedback.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {NativeMessageReader} from '../src/native_message.js';
import {serverObjectIdForClient} from '../src/client_projectile_message.js';
import {NetworkFrontend} from '../src/network_frontend.js';
const wire=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-initiative-wire.json',import.meta.url)));
const client=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-initiative-observations.json',import.meta.url)));
test('all original CC14 writer cases agree on ID namespace, five-bit roll and signed-byte modifier',()=>{
 for(const {case:c,packet}of wire.cases){const bytes=Buffer.from(packet,'hex'),r=new NativeMessageReader(c.format);assert.ok(r.setReadMessage(bytes.subarray(3),bytes.length-3,0xffffffff,c.format));const m=readNetworkInitiativeFeedback(r);assert.equal(r.messageReadOverflow(),0);assert.equal(r.messageReadUnderflow(),0);assert.equal(m.sourceId,serverObjectIdForClient(c.sourceId));assert.equal(m.roll,c.roll&31);assert.equal(m.modifier,(c.modifier&255)<<24>>24);if(c.format===1)assert.deepEqual(decodeServerGameMessage(bytes),{...m,major:18,minor:14});}
});
test('truncated and trailing CC14 packets reject through the normal feedback envelope',()=>{
 const bytes=Buffer.from(wire.cases.find(c=>c.case.format===1).packet,'hex');for(let end=0;end<bytes.length;end++)assert.throws(()=>decodeServerGameMessage(bytes.subarray(0,end)));assert.throws(()=>decodeServerGameMessage(Buffer.concat([bytes,Buffer.from([0,0])])));
});
const asciiJSON=value=>JSON.stringify(value).replace(/[\u007f-\uffff]/g,ch=>'\\u'+ch.charCodeAt(0).toString(16).padStart(4,'0'));
const pythonObject=value=>'{'+Object.keys(value).sort().map(k=>asciiJSON(k)+': '+asciiJSON(value[k])).join(', ')+'}';
test('original client initiative arithmetic, token order, name fallback, colors and display flags agree',async()=>{
 for(const row of client.cases){const c=row.case;if(c.overflow){assert.deepEqual(row.outputs,[]);continue;}const calls=[],outputs=[],tokens={0:'old0',1:'old1'};
  await presentInitiativeFeedback(c,{name:id=>{calls.push(['name',id]);return c.names?'Source':null;},player:()=>{calls.push(['player']);return c.player?{id:c.player===1?c.sourceId:0x80000012}:null;},tlk:ref=>{calls.push(['tlk',ref]);return'T'+ref;},token:(id,value)=>{calls.push(['token',id,value]);tokens[id]=value;},parse:ref=>{calls.push(['parse',ref]);return'P'+ref+pythonObject(tokens);},display:(raw,flags)=>outputs.push({raw,flags})});
  assert.deepEqual(calls,row.calls.filter(c=>['name','player','tlk','token','parse'].includes(c[0])),JSON.stringify(c));assert.deepEqual(tokens,row.tokens);assert.deepEqual(outputs,row.outputs,JSON.stringify(c));
 }
});
test('frontend forwards initiative reports to HUD without creating objects or changing gameplay',async()=>{
 const calls=[],world={apply:()=>calls.push('apply'),presentationChanges:[],registry:{objects:new Map()}},front={id:1,world,queue:Promise.resolve(),onHud:m=>calls.push(m.kind),onState:()=>{},showError:e=>{throw e;}};
 NetworkFrontend.prototype.receive.call(front,{sessionId:1,kind:'message',message:{kind:'initiative-feedback',sourceId:0xfffffffe,roll:20,modifier:-3}});await front.queue;assert.deepEqual(calls,['apply','initiative-feedback']);assert.equal(world.registry.objects.size,0);
});
