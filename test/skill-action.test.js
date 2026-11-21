import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {executePickpocket,usePickpocketSkill} from '../src/skill_action.js';
import {createObjectActionState,createObjectAction,setActionParameter} from '../src/object_actions.js';
const INVALID=0x7f000000;

test('skill request guards, passive no-ops and pickpocket queue admission match full native UseSkill',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-pickpocket-observations.json',import.meta.url)));
  assert.equal(capture.requests.length,896);
  for(const row of capture.requests){const c=row.case,calls=[],o={id:11,objectType:5,nativeField771:c.actorState,nativeFieldEc:c.commandable,areaId:33,nativeSkillTimers878:new Uint32Array(28),objectActionState:createObjectActionState()},
    victim={id:22,objectType:c.targetType,masterId:c.master,areaId:c.victimArea};o.nativeSkillTimers878[13]=c.timer;let can=0;
    const result=await usePickpocketSkill(o,c.skill,0,c.target,[0,0,0],33,INVALID,0,{
      canUseSkill:(_o,id)=>{const value=c.can[Math.min(can++,1)];calls.push(['can',id,value]);return value;},
      feedback:(o,code,data)=>calls.push(['feedback',o.id,code,data??{}]),object:()=>c.present?(c.target===11?o:victim):null,
      hostileSkill:()=>c.hostile,reaction:()=>c.reaction,actionManager:(_o,v)=>calls.push(['manager',v]),isDM:()=>c.dm,
    });
    // Native AddAction was a captured substitute; verify its parameters plus
    // the already independently mapped first group allocation (FFFF -> 0).
    for(const n of o.objectActionState.list){assert.equal(n.groupId,0);calls.push(['add',n.actionId,65535,Array.from(n.parameterTypes).slice(0,n.parameterCount).map((type,k)=>({type,value:type===3?n.parameterData[k]>>>0:n.parameterData[k]}))]);}
    assert.deepEqual({result,calls},{result:row.result,calls:row.calls},JSON.stringify(c));
  }
});

test('pickpocket owner matches full native detection, transfer, feedback, RNG, queue and cooldown observations',async()=>{
  const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-pickpocket-observations.json',import.meta.url)));
  assert.equal(capture.observations.length,486);
  for(const row of capture.observations){
    const c=row.case,calls=[],actor={id:11,areaId:33,nativePickpocketStage830:c.stage,nativePickpocketDetected834:c.detected,nativeSkillTimers878:new Uint32Array(28),objectActionState:createObjectActionState()},
      victim={id:22,nativeField771:c.victimState,nativeField8d4:c.word,nativeGold898:c.gold};
    actor.nativeSkillTimers878[13]=c.timer;
    const items=(c.items??[]).map((i,k)=>({id:100+k,pickpocketable:i.pick??0,cursed:i.cursed??0,identified:i.identified??0,stolen:i.stolen??0,base:{container:i.container??0}}));
    const insert=actor.objectActionState.list.insert.bind(actor.objectActionState.list);
    actor.objectActionState.list.insert=(n,front)=>{calls.push(['front',n.actionId,n.groupId,Array.from(n.parameterTypes).slice(0,n.parameterCount).map((type,k)=>({type,value:type===3?n.parameterData[k]>>>0:n.parameterData[k]}))]);return insert(n,front);};
    const n=createObjectAction(54,7);setActionParameter(n,0,3,22);setActionParameter(n,1,1,c.approach);let roll=0;
    const result=await executePickpocket(actor,n,{
      dead:()=>c.dead,dying:()=>c.dying,activityManager:(_o,v)=>calls.push(['activity',v]),creature:()=>c.present?victim:null,
      feedback:(o,v,data)=>calls.push(['feedback',o.id,v,data??{}]),inUseRange:()=>c.range,useRange:(_o,_id,out)=>Object.assign(out,{point:[1,2,3],range:1.5}),
      moveFront:(_o,group,_point,_area,target,run)=>calls.push(['move',group,target,run]),rank:o=>o===actor?c.rank:c.spot,reaction:()=>c.reaction,
      rule:(_name,fallback)=>{calls.push(['rule',fallback]);return fallback;},dice:(n,d)=>{const value=c.rolls[roll++];calls.push(['dice',n,d,value]);return value;},
      broadcastSkill:(o,data)=>calls.push(['broadcast',o.id,data]),reputations:(...a)=>calls.push(['reputations',...a]),associate:(o,...a)=>{calls.push(['associate',o.id,...a]);return INVALID;},
      clearActivities:(_o,mask)=>calls.push(['clear',mask]),repository:o=>o===victim?(c.items===null?null:{ids:()=>items.map(i=>i.id),length:items.length}):{ids:()=>[],length:0},
      item:id=>items.find(i=>i.id===id),baseInfo:i=>i.base,random:()=>{calls.push(['random',c.random]);return c.random;},
      acquire:(_o,ref,...a)=>{calls.push(['acquire',ref.item.id,...a]);return c.acquire;},
      removeGold:(o,...a)=>calls.push(['removeGold',o.id,...a]),addGold:(o,...a)=>calls.push(['addGold',o.id,...a]),
      event:(source,target,type,objects,integers)=>calls.push(['event',source,target,type,{integers,objects}]),
    });
    const actual={result,stage:actor.nativePickpocketStage830,detected:actor.nativePickpocketDetected834,timer:actor.nativeSkillTimers878[13],stolen:items.map(i=>i.stolen),calls};
    assert.deepEqual(actual,{result:row.result,stage:row.stage,detected:row.detected,timer:row.timer,stolen:row.stolen,calls:row.calls},JSON.stringify(c));
  }
});

test('unmapped admitted skills remain explicit and pickpocket requires its native timer owner',async()=>{
  const o={id:1,nativeField771:0},p={canUseSkill:()=>1,object:()=>({objectType:9}),feedback:()=>{}};
  await assert.rejects(()=>usePickpocketSkill(o,4,0,2,[0,0,0],3,INVALID,0,p),/admitted skill 4/);
  await assert.rejects(()=>usePickpocketSkill(o,13,0,2,[0,0,0],3,INVALID,0,p),/timer storage/);
});
