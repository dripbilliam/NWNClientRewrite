import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {setCustomToken,scriptSetCustomToken,sendSetCustomToken} from '../src/custom_tokens.js';
import {ModuleSession} from '../src/module_session.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-custom-token-observations.json',import.meta.url))),hex=v=>Buffer.from(v).toString('hex');
test('sorted custom-token insertion/replacement and byte ownership match complete native table setter',()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='table')){const c=row.case,state={records:c.initial.map(id=>({id,bytes:Buffer.from(`t${id}`)}))};setCustomToken(state,c.id,Buffer.from(c.value,'hex'));assert.deepEqual(state.records.map(r=>({id:r.id,value:hex(r.bytes)})),row.records,JSON.stringify(c));}
 const state={records:[]},source=Buffer.from('owned');setCustomToken(state,10,source);source.fill(0);assert.equal(Buffer.from(state.records[0].bytes).toString(),'owned');
});
test('script token guards, reserved IDs, pop error contracts and all-client synchronization match original wrapper',async()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='script')){const c=row.case,state={records:c.initial.map(id=>({id,bytes:Buffer.from(`t${id}`)}))},calls=[];
  if(!c.popInt||!c.popString){assert.equal(row.result,0xfffffd82);assert.deepEqual(row.calls,[]);continue;}
  await scriptSetCustomToken(c.id,Buffer.from(c.value,'hex'),{set:(id,value)=>setCustomToken(state,id,value),players:()=>[100,101].slice(0,c.count),object:id=>id===101&&c.missingViewer?null:{},send:(client,id,value)=>{calls.push(['send',client,id>>>0,hex(value)]);return c.sendResult;}});
  assert.equal(row.result,0);assert.deepEqual(calls,row.calls);assert.deepEqual(state.records.map(r=>({id:r.id,value:hex(r.bytes)})),row.records);
 }
});
test('custom-token packet coordinator matches original size, INT/string order, NUL normalization and failure propagation',async()=>{
 for(const row of native.rows.filter(r=>r.case.mode==='packet')){const c=row.case,calls=[],result=await sendSetCustomToken({},100,c.id,Buffer.from(c.value,'hex'),{create:(_m,...args)=>calls.push(['create',...args]),writeInt:(_m,id,bits)=>calls.push(['int',id>>>0,bits]),writeString:(_m,bytes,bits)=>calls.push(['string',hex(bytes),bits]),payload:()=>({status:c.payloadStatus,data:new Uint8Array(23),length:23}),send:(_m,id,major,minor,_bytes,length)=>{calls.push(['transport',id,major,minor,length]);return c.sendResult;}});assert.equal(result>>>0,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));}
 assert.equal(native.rows.length,975);
});
test('live server/client token bodies preserve aliases, embedded NULs and canonical object allocation',async()=>{
 const s=new ModuleSession(null),a=s.register('player','token-player',{stats:{currentHP:10,maxHP:10},authored:{}});s.player=a;const client=s.combat.broadcastProviders().client(a.id),cursor=s.registry.nextObjectId[0];
 await s.commands.SetCustomToken([42,'A\0B']);assert.deepEqual([...s.talkTable.tokens.records[0].bytes],[65,0,66]);assert.deepEqual([...s.talkTable.tokensForClient(client).records[0].bytes],[65,0,66]);
 await s.commands.SetCustomToken([42,'€\x80']);assert.deepEqual([...s.talkTable.tokens.records[0].bytes],[128,128]);assert.deepEqual([...s.talkTable.tokensForClient(client).records[0].bytes],[128,128]);
 await s.commands.SetCustomToken([9,'reserved']);assert.deepEqual(s.talkTable.tokens.records.map(r=>r.id),[42]);assert.equal(s.registry.nextObjectId[0],cursor);
});
