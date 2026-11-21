import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {addEquipItemActions,addRoundEquipAction,executeEquipAction,clearEquipAction,runEquip} from '../src/equipment_actions.js';
import {createObjectAction,setActionParameter} from '../src/object_actions.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-equipment-action-observations.json',import.meta.url)));
test('queued equip cancellation matches original client messages, lock cleanup and exact-one head timestamps',async()=>{
  for(const row of oracle.clear){const c=row.case,calls=[],o={id:77,lockOrientationId:c.lock,objectActionState:{startDay:5,startTime:6}},node=createObjectAction(8,0);
    node.nativeField9c=c.cancelFlag;node.parameterData[0]=99;node.parameterData[1]=c.slot;
    const result=await clearEquipAction(o,node,c.head,{messageAvailable:()=>c.message,client:()=>c.client?{}:null,cancel:(_client,...args)=>calls.push(['cancel',...args]),setLock:(_o,id)=>calls.push(['lock',id])});
    assert.deepEqual({result,calls,startDay:o.objectActionState.startDay,startTime:o.objectActionState.startTime},{result:row.result,calls:row.calls,startDay:row.startDay,startTime:row.startTime},JSON.stringify(c));
  }
});
test('equipment requests preserve native rejection, front/after-front and combat-round queue boundaries',async()=>{
  for(const row of oracle.requests){const c=row.case,calls=[],o={id:77,nativeFieldEc:c.gate,nativeField700:c.combat,combatRound:{started:c.started,paused:c.paused}},client=c.client?{}:null;
    const result=await addEquipItemActions(o,{id:99},c.slot,c.front,c.force,c.playerId,{client:()=>client,messageAvailable:()=>c.message,
      cancel:(_client,...args)=>calls.push(['cancel',...args]),feedback:(_o,code)=>calls.push(['feedback',code]),roundEquip:(_o,...args)=>calls.push(['round',...args]),
      queue:(_o,id,params,mode)=>calls.push(['queue',mode,id,65535,params.map(p=>[p.type,p.value>>>0])])});
    assert.deepEqual({result,calls},{result:row.result,calls:row.calls},JSON.stringify(c));
  }
});
test('RunEquip matches original owned-item replacement, native merge return, mode gates and message order',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-run-equip-observations.json',import.meta.url))).rows;
  for(const row of rows){const c=row.case,calls=[],o={id:77,combatMode:c.mode},items=new Map([99,100,101].map(id=>[id,{id,objectType:6,possessorId:77}])),slots=new Map(Object.entries(c.slots).map(([slot,id])=>[Number(slot),items.get(id)]));
    const p={client:()=>c.client?{}:null,messageAvailable:()=>c.message,item:id=>c.exists?items.get(id)??null:null,repository:()=>({}),
      cancel:(_client,...args)=>calls.push(['cancel',...args]),canEquip:(_o,item,ref,...args)=>{calls.push(['gate',item.id,ref.slot,...args.slice(0,3),Boolean(args[3])]);ref.slot=c.resolvedSlot;return c.allowed;},
      equipped:(_o,slot)=>slots.get(slot)??null,baseInfo:()=>({stacking:c.stacking,ranged:c.ranged}),merge:(a,b)=>{calls.push(['merge',a.id,b.id]);return c.merge;},
      remove:(_r,i)=>{calls.push(['remove',i.id]);return 1;},destroy:i=>calls.push(['destroy',i.id,1]),
      unequip:(_o,i,...flags)=>{calls.push(['unequip',i.id,...flags]);for(const [slot,item] of slots)if(item===i)slots.delete(slot);return 1;},
      stash:(_o,ref,...flags)=>{calls.push(['stash',ref.item.id,...flags]);return 1;},contains:(_r,i,n)=>{calls.push(['contains',i.id,n]);return c.contains;},
      equip:(_o,slot,i,...flags)=>{calls.push(['equip',slot,i.id,...flags]);slots.set(slot,i);return 1;},equippedMessage:(_client,...args)=>calls.push(['equipped-message',...args]),
      monkWeapon:()=>c.monk,hasFeat:(_o,id)=>{calls.push(['feat',id]);return id===899?c.feat899:c.feat866;},relativeSize:(_o,i)=>{calls.push(['size',i.id]);return c.size;},
      setCombatMode:(_o,mode,flag)=>{calls.push(['mode',mode,flag]);o.combatMode=mode;}};
    const result=await runEquip(o,99,c.slot,c.playerId,p);
    assert.deepEqual({result,calls,mode:o.combatMode,slots:Object.fromEntries([...slots].map(([slot,i])=>[slot,i.id]))},{result:row.result,calls:row.calls,mode:row.mode,slots:row.slots},JSON.stringify(c));
  }
});
test('round equip actions match original identity replacement, insertion and actual native rescaling',async()=>{
  for(const row of oracle.rounds){const c=row.case,calls=[],r={started:c.started,paused:c.paused,length:c.length,timer:240,overlap:0,actions:structuredClone(c.actions)},o={id:77,nativeStatsIsPCb0:c.pc,combatRound:r};
    const original=r.actions.find(a=>a.nativeActionType===6&&(a.equipmentSlot===c.slot||a.targetId===99));
    await addRoundEquipAction(o,99,c.slot,{item:()=>c.itemExists?{}:null,messageAvailable:()=>c.message,possessed:()=>c.possessed,
      roundCancel:(_o,...args)=>calls.push(['cancel',...args])});
    const expectedCalls=row.calls.filter(a=>a[0]!=='insert');assert.deepEqual(calls,expectedCalls,JSON.stringify(c));
    const actions=r.actions.map(({time,duration,nativeActionType,targetId,followTarget,count,equipmentSlot})=>({time,duration,nativeActionType,targetId,followTarget,count,equipmentSlot}));
    assert.deepEqual({actions,timer:r.timer,length:r.length},{actions:row.actions,timer:row.timer,length:row.length},JSON.stringify(c));
    if(original&&c.itemExists&&c.started!==0)assert.ok(r.actions.includes(original));
  }
});
test('AI equip action matches native malformed, pause, death, result and encumbrance order',async()=>{
  for(const row of oracle.ai){const c=row.case,calls=[],o={id:77},node=createObjectAction(8,0);setActionParameter(node,0,3,99);setActionParameter(node,1,1,c.slot);setActionParameter(node,2,3,c.playerId);node.parameterCount=c.parameterCount;
    const result=await executeEquipAction(o,node,{activityManager:(_o,n)=>calls.push(['activity',n]),pauseState:n=>{calls.push(['pause',n]);return c.pause;},
      exclusion:id=>{calls.push(['exclusion',id]);return c.exclusion;},dead:()=>{calls.push(['dead']);return c.dead;},dying:()=>{calls.push(['dying']);return c.dying;},
      runEquip:(_o,...args)=>{calls.push(['run',...args]);return c.runResult;},encumbrance:(_o,n)=>calls.push(['encumbrance',n]),client:()=>c.client?{}:null,messageAvailable:()=>c.message,cancel:(_client,...args)=>calls.push(['cancel',...args])});
    assert.deepEqual({result,calls},{result:row.result,calls:row.calls},JSON.stringify(c));
  }
});
