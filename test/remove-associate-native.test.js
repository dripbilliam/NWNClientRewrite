import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {removeAssociate} from '../src/summon_associate.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

test('associate removal matches native faction, possession, physical-list and GUI branches',async()=>{
 const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-remove-associate-observations.json',import.meta.url)));
 for(const row of native.rows){
  const c=row.case,calls=[],actor={id:99,factionId:7,associateIds:c.ids===null?null:[...(c.ids??[])],nativeField914:17},
   target={id:100,associateType:c.type??4,masterId:99,originalFactionId:9,nativeOriginalFactionCC:11,nativeField540:c.open??0},client={id:99,open:c.inventoryOpen??0};
  await removeAssociate(actor,100,{
   message:()=>{calls.push(['message']);return c.message===false?null:{};},creature:id=>{calls.push(['creature',id]);return c.exists===false?null:target;},
   faction:id=>{calls.push(['faction',id>>>0]);return c.faction===false?null:{id:7};},defaultFaction:()=>({id:1}),addFactionMember:(f,id,n)=>calls.push(['member',f.id,id,n]),
   feedback:(_o,code,data)=>calls.push(['feedback',code,data.objects[0]]),setType:(o,type)=>{calls.push(['type',type]);o.associateType=type;o.masterId=OBJECT_INVALID;},
   setMaster:(o,id)=>{calls.push(['master',id]);o.masterId=id;},warning:()=>{throw new Error('Unexpected native warning');},
   client:id=>{calls.push(['client',id]);return c.client===false?null:client;},sheet:()=>c.sheet===false?null:{},setDisplayed:(_o,id)=>calls.push(['display',id]),
   notPermitted:(_m,cl,id)=>calls.push(['notPermitted',cl.id,id]),inventoryOpen:cl=>cl.open,inventoryOwner:()=>c.inventoryOwner??100,
   inventoryStatus:(_m,_cl,value,id)=>calls.push(['inventoryStatus',value,id]),setInventoryOpen:(cl,a,b)=>{calls.push(['inventoryOpen',a,b]);cl.open=a;}});
  const label=JSON.stringify(c);assert.deepEqual(calls,row.calls,label);assert.deepEqual(actor.associateIds??[],row.ids,label);assert.equal(target.associateType,row.type,label);
  assert.equal(target.masterId,row.master,label);assert.equal(target.nativeOriginalFactionCC,row.original,label);assert.equal(actor.nativeField914,row.field914,label);assert.equal(client.open,row.inventoryOpen,label);
 }
});
