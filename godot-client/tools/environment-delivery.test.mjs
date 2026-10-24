import test from 'node:test';import assert from 'node:assert/strict';
import {EnvironmentDelivery} from './environment-delivery.mjs';
function fixture(){
 const area={fields:{98:0x332211,'9c':0,'a0':0x778899,'a4':25,a8:true,b8:0xffffff,bc:0,c0:0x112233,c4:75,c8:false,d8:true,dc:false,e0:0,104:50,108:45,unclassified:'not exported'}};
 const s={closed:false,areaGeneration:1,world:{areaId:7,time:{timeOfDay:3,transition:2000},module:{minutesPerHour:2},registry:{get:()=>({state:area})}}};
 let active=true,ready=null,time=1000;const sent=[];
 const owner=new EnvironmentDelivery({session:s,connection:2,active:()=>active,ready:()=>ready,send:v=>sent.push(v),now:()=>time});
 return{owner,s,sent,area,setTime:v=>time=v,admit:(transferId=1)=>ready={connection:2,areaId:s.world.areaId,generation:s.areaGeneration,transferId},retire:()=>active=false};
}
test('area preparation elapsed is retained and complete ready scope is required',()=>{
 const f=fixture();f.owner.receive({kind:'client-area'});assert.equal(f.sent.length,0);f.setTime(4500);f.admit();assert.equal(f.owner.flush(),true);
 assert.equal(f.sent[0].state.elapsed,5.5);assert.equal(f.sent[0].transferId,1);assert.equal(f.sent[0].state.fields.a8,true);assert.equal(f.sent[0].state.fields.c8,false);assert.equal(f.sent[0].state.fields.unclassified,undefined);
 assert.equal(f.owner.flush(),false);f.area.fields.a8=false;assert.equal(f.sent[0].state.fields.a8,true);
});
test('hour-only updates do not rewind dawn, and a native period update resets its elapsed clock',()=>{
 const f=fixture();f.admit();f.owner.receive({kind:'client-area'});f.setTime(5000);f.owner.receive({kind:'module-time',changes:{hour:7}});assert.equal(f.sent.length,1);
 f.s.world.time={timeOfDay:4,transition:1250};f.owner.receive({kind:'module-time',changes:{timeOfDay:4,transition:1250}});assert.equal(f.sent[1].state.time.timeOfDay,4);assert.equal(f.sent[1].state.elapsed,1.25);assert.equal(f.sent[1].revision,2);
});
test('old area, generation, connection and retired session cannot publish atmosphere into another world',()=>{
 const f=fixture();f.admit();f.owner.receive({kind:'client-area'});f.s.areaGeneration=2;f.s.world.areaId=8;
 assert.equal(f.owner.flush(),false);f.admit();assert.equal(f.owner.flush(),false);f.owner.receive({kind:'client-area'});assert.equal(f.sent.length,2);
 f.retire();f.owner.receive({kind:'module-time',changes:{timeOfDay:2}});assert.equal(f.owner.flush(),false);assert.equal(f.sent.length,2);
 const g=fixture();g.admit();g.owner.receive({kind:'client-area'});g.s.closed=true;assert.equal(g.owner.flush(),false);
});
test('module settings update resends current atmosphere without resetting the transition time',()=>{
 const f=fixture();f.admit();f.owner.receive({kind:'client-area'});f.setTime(2000);f.s.world.module.minutesPerHour=3;f.owner.receive({kind:'module-info'});
 assert.equal(f.sent[1].state.elapsed,3);assert.equal(f.sent[1].state.minutesPerHour,3);assert.equal(f.owner.flush(),false);
});
