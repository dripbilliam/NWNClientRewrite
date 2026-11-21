import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {scriptVoiceChat,sendQuickChatMessage} from '../src/quick_chat.js';
test('voice-chat command and recipients match original lookup, range, WORD and delivery-result behavior',async()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-quick-chat-observations.json',import.meta.url)));
 for(const row of native.rows){
  const c=row.case,calls=[],area={},other={},actor={id:99,position:[0,0,0]},clients=(c.viewers??[{}, {}, {}]).map((v,i)=>({id:1000+i,view:v})),areaOf=n=>n===1?area:n===2?other:null;
  if(c.operation==='command')await scriptVoiceChat(99,c.code,c.target,{
   creature:id=>{calls.push(['creature',id]);return c.exists?actor:null;},message:()=>{calls.push(['message']);return c.message?{}:null;},quickChat:(_m,id,code)=>calls.push(['quickChat',id,code])});
  else{
   let sent=0;const result=await sendQuickChatMessage(99,c.code,{
    object:id=>{calls.push(['objectArray'],['object',id]);return c.exists?actor:null;},
    asCreature:()=>{calls.push(['asCreature']);return c.creature?actor:null;},
    area:o=>{calls.push(['area',o===actor?99:100+o.index]);return areaOf(o===actor?c.area:o.entry.area??1);},
    players:()=>{calls.push(['players']);return clients;},clientObject:client=>{const index=clients.indexOf(client);calls.push(['clientObject',index]);
      const v=client.view,p=v.position??[1,0,0];return v.missing?null:{index,entry:v,position:[p[0],p[2],-p[1]]};},
    send:(client,id,code)=>{calls.push(['packet',[['objectId',id],['word',code]]]);if(!c.build)return 0;calls.push(['send',client.id,22,0]);return c.results[sent++];}});
   assert.equal(result,row.result,JSON.stringify(c));
  }
  assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
});
