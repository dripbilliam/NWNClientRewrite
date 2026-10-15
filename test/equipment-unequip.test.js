import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runUnequip,canUnequipWeapon,processPendingEquipment,addRoundUnequipAction,addUnequipActions,executeUnequipAction,clearUnequipAction,scriptEquipItem,scriptUnequipItem} from '../src/equipment_unequip.js';
import {createObjectAction} from '../src/object_actions.js';
import {repositoryPage} from '../src/item_repository.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-unequip-observations.json',import.meta.url)));
const controls=JSON.parse(readFileSync(new URL('../backups/animations/native-unequip-action-observations.json',import.meta.url)));
test('script equipment requests match original unsigned slots, casts and exact native arguments',async()=>{
  const rows=JSON.parse(readFileSync(new URL('../backups/animations/native-script-equipment-observations.json',import.meta.url))).rows;
  for(const row of rows){const c=row.case,calls=[],p={creature:id=>{calls.push(['creature',id]);return c.selfExists?{id}:null;},item:id=>{calls.push(['item',id]);return c.itemExists?{id}:null;},addEquip:(o,item,...args)=>calls.push(['equip',o.id,item.id,...args]),addUnequip:(o,item,...args)=>calls.push(['unequip',o.id,item.id,...args])};
    if(c.mode==='equip')await scriptEquipItem(77,99,c.slot,p);else await scriptUnequipItem(77,99,p);
    assert.deepEqual(calls,row.calls,JSON.stringify(c));
  }
});
test('repository page matches original byte truncation and unsigned boundary division',()=>{
  for(const row of controls.pages)assert.equal(repositoryPage(row,row.x,row.y),row.result,JSON.stringify(row));
  assert.throws(()=>repositoryPage({width:10,boundary:0},0,0),/divide by zero/);
});
test('unequip requests match native gate, recipient, armor rejection and five raw typed queue parameters',async()=>{
  for(const row of controls.requests){const c=row.case,calls=[],o={id:77,nativeFieldEc:c.gate,nativeField700:c.combat,combatRound:{started:c.started,paused:c.paused}},client=c.client?{}:null;
    const result=await addUnequipActions(o,{id:99},88,255,254,c.front,c.force,c.playerId,{client:()=>client,messageAvailable:()=>c.message,equipped:()=>c.armor?{id:99}:null,cancel:(_client,...args)=>calls.push(['cancel',...args]),feedback:(_o,code)=>calls.push(['feedback',code]),roundUnequip:(_o,...args)=>calls.push(['round',...args]),queue:(_o,id,params,mode)=>calls.push(['queue',mode,id,65535,params.map(p=>[p.type,p.value>>>0])])});
    assert.deepEqual({result,calls},{result:row.result,calls:row.calls},JSON.stringify(c));
  }
});
test('round unequip matches native rescaling, duplicate tail write and unconditional front insertion',async()=>{
  for(const row of controls.rounds){const c=row.case,calls=[],r={started:c.started,paused:c.paused,length:6000,timer:240,overlap:0,actions:structuredClone(c.actions)},o={combatRound:r};
    await addRoundUnequipAction(o,99,88,255,254,{item:()=>c.exists?{id:99}:null,canUnequip:()=>{calls.push(['gate']);return c.allowed;}});
    const keys=['time','duration','count','nativeActionType','targetId','followTarget','repositoryId','repositoryX','repositoryY'];
    assert.deepEqual({calls,actions:r.actions.map(a=>Object.fromEntries(keys.map(k=>[k,a[k]]))),timer:r.timer,length:r.length},{calls:row.calls,actions:row.actions,timer:row.timer,length:row.length},JSON.stringify(c));
  }
});
test('unequip action matches native familiar gate, raw short-node reads and pause/death/cancellation ordering',async()=>{
  for(const row of controls.ai){const c=row.case,calls=[],o={id:77,associateType:c.associate},node=createObjectAction(11,0);Object.assign(node,{parameterCount:c.count});node.parameterData.splice(0,5,99,88,255,254,c.playerId);
    const result=await executeUnequipAction(o,node,{controlled:()=>{calls.push(['controlled']);return c.controlled;},associatesCanInteract:()=>{calls.push(['interact']);return c.interact;},feedback:(_o,code)=>calls.push(['feedback',code]),activityManager:(_o,n)=>calls.push(['activity',n]),pauseState:()=>{calls.push(['pause']);return c.pause;},exclusion:()=>{calls.push(['exclusion']);return c.exclusion;},dead:()=>{calls.push(['dead']);return c.dead;},dying:()=>{calls.push(['dying']);return c.dying;},runUnequip:(_o,...args)=>{calls.push(['run',...args]);return c.runResult;},client:()=>c.client?{}:null,messageAvailable:()=>c.message,cancel:(_client,...args)=>calls.push(['cancel',...args])});
    assert.deepEqual({result,calls},{result:row.result,calls:row.calls},JSON.stringify(c));
  }
});
test('unequip cancellation matches original client feedback, lock and exact-one timestamp reset',async()=>{
  for(const row of controls.clear){const c=row.case,calls=[],o={id:77,lockOrientationId:c.lock,objectActionState:{startDay:5,startTime:6}},node=createObjectAction(11,0);node.nativeField9c=c.cancelFlag;node.parameterData[0]=99;
    const result=await clearUnequipAction(o,node,c.head,{client:()=>c.client?{}:null,messageAvailable:()=>c.message,cancel:(_client,...args)=>calls.push(['cancel',...args]),setLock:(_o,id)=>calls.push(['lock',id])});
    assert.deepEqual({result,calls,startDay:o.objectActionState.startDay,startTime:o.objectActionState.startTime},{result:row.result,calls:row.calls,startDay:row.startDay,startTime:row.startTime},JSON.stringify(c));
  }
});
test('RunUnequip matches original ownership, raw fitting flags, transfer, promotion, page and message order',async()=>{
  for(const row of oracle.rows){
    const c=row.case,calls=[],o={id:77},client=c.client?{}:null,gui={field8:c.guiOpen,fieldC:0},repo={},destRepo={},other={id:89},bag={id:88,possessorId:c.bagOwner??77},items=new Map([99,100,101].map(id=>[id,{id,possessorId:c.owner,repositoryX:1,repositoryY:2}]));
    const slots=new Map(Object.entries(c.slots??{16:99,32:101}).map(([slot,id])=>[Number(slot),items.get(id)]));
    const p={client:id=>{calls.push(['client',id]);return client;},inventoryGUI:()=>gui,messageAvailable:()=>{calls.push(['message']);return c.message;},
      item:id=>{calls.push(['item',id]);return id===88?c.bag?bag:null:c.exists?items.get(id)??null:null;},
      creature:id=>{calls.push(['creature',id]);return c.other?other:null;},repository:a=>a===o?c.repo?repo:null:destRepo,
      cancel:(_client,...args)=>calls.push(['cancel',...args]),inEquipment:(_o,item)=>{calls.push(['inEquipment',item.id]);return c.inEquipment;},
      canUnequip:(_o,item)=>{calls.push(['gate',item.id]);return c.gate;},unequip:(_o,item,...flags)=>{calls.push(['unequip',item.id,...flags]);for(const [slot,value] of slots)if(value===item)slots.delete(slot);return c.unequipResult??1;},
      addItem:(r,ref,...flags)=>{calls.push(['add',r===repo?'self':'destination',ref.item.id,...flags]);ref.item=items.get(c.replacedId);ref.item.repositoryX=9;ref.item.repositoryY=13;return c.placed;},
      acquire:(_o,ref,...flags)=>{calls.push(['acquire',ref.item.id,...flags]);ref.item=items.get(c.replacedId);ref.item.repositoryX=9;ref.item.repositoryY=13;return c.placed;},
      removeItem:(_o,item,...flags)=>calls.push(['removeItem',item.id,...flags]),drop:(_o,item)=>{calls.push(['area']);calls.push(['drop',item.id]);},
      equipped:(_o,slot)=>{calls.push(['slot',slot]);return slots.get(slot)??null;},equip:(_o,slot,item,...flags)=>{calls.push(['equip',slot,item.id,...flags]);slots.set(slot,item);},
      setPossessor:(item,id,...flags)=>{calls.push(['possessor',item.id,id,...flags]);item.possessorId=id;},
      page:(_r,x,y)=>{calls.push(['page',x,y]);return c.page;},selectPanel:(_client,g,page)=>{calls.push(['select',page]);calls.push(['setPanel',page]);g.fieldC=page;},
      unequippedMessage:(_client,...args)=>calls.push(['unequipped',...args]),equippedMessage:(_client,...args)=>calls.push(['equipped',...args])};
    const result=await runUnequip(o,99,c.destination,255,254,c.flag,c.playerId,p);
    assert.deepEqual({result,calls,slots:Object.fromEntries([...slots].map(([slot,item])=>[slot,item.id])),panel:gui.fieldC},{result:row.result,calls:row.calls,slots:row.slots,panel:row.panel},JSON.stringify(c));
  }
});
test('pending equipment conversion matches native tail order, head eligibility and rejected-request disposal',async()=>{
  for(const row of oracle.pending){
    const c=row.case,calls=[],actions=c.actions.map((a,index)=>({index,nativeActionType:a.type,targetId:a.target,time:c.pending?0:100,equipmentSlot:16,repositoryId:88,repositoryX:255,repositoryY:254})),o={combatRound:{timer:0,actions}};
    await processPendingEquipment(o,{item:id=>{calls.push(['item',id]);return c.exists&&[99,100,101].includes(id)?{id}:null;},addEquip:(_o,item,...args)=>{calls.push(['addEquip',item.id,...args]);return c.requestResult;},addUnequip:(_o,item,...args)=>{calls.push(['addUnequip',item.id,...args]);return c.requestResult;},dispose:a=>calls.push(['dispose',a.index])});
    assert.deepEqual({calls,remaining:o.combatRound.actions.map(a=>a.index)},{calls:row.calls.filter(call=>!['pending','previous','remove'].includes(call[0])),remaining:row.remaining},JSON.stringify(c));
  }
});
test('unequip eligibility matches original BYTE weapon type, exact-one locks and client selection clearing',async()=>{
  for(const row of oracle.eligibility){
    const c=row.case,calls=[],o={id:77,nativeEquipmentLock97c:c.lock,nativeField868:c.locks[0],nativeField86c:c.locks[1],nativeField870:c.locks[2]},items=new Map([99,100,101].map(id=>[id,{id,base:id}])),selected=[0,0];
    const result=await canUnequipWeapon(o,items.get(99),{equipped:(_o,slot)=>{calls.push(['slot',slot]);return items.get(c.slots[slot])??null;},baseInfo:item=>{calls.push(['base',item.base]);return{weaponType:c.weaponType};},client:id=>{calls.push(['client',id]);return c.client?{}:null;},clearWeaponSelection:()=>{selected.fill(0x7f000000);}});
    assert.deepEqual({result,calls,selected},{result:row.result,calls:row.calls,selected:row.selected},JSON.stringify(c));
  }
});
