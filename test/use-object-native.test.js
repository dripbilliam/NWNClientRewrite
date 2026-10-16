import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {addUseObjectAction,executeUseObjectAction,destroyDroppableEquipment,receivePlaceableUseEvent} from '../src/use_object.js';
import {createObjectAction,createObjectActionState} from '../src/object_actions.js';
import {clearCreatureMovementAction} from '../src/combat_lifecycle.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-use-object-observations.json',import.meta.url)));
test('UseObject request matches original commandable gate, three raw slots, group and ignored lower return',()=>{
 for(const row of data.requests){const c=row.case,o={nativeFieldEc:c.commandable,objectActionState:createObjectActionState()},result=addUseObjectAction(o,c.targetId),calls=[];
  for(const node of o.objectActionState.list)calls.push(['back',node.actionId,65535,Array.from({length:node.parameterCount},(_,n)=>[node.parameterTypes[n],node.parameterData[n]])]);
  assert.equal(result,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));
 }
 assert.equal(data.requests.length,48);
});
test('full UseObject execution matches original lookup/corpse/range/approach/trap/lock/GUI/event and timer flow',async()=>{
 for(const row of data.rows){
  const c=row.case,calls=[],actor={id:99,areaId:88,role:'actor'},target={id:100,areaId:88,role:'target',objectType:c.type,nativeLootable4e8:c.lootable??0,nativeBodyBagId4f0:200,nativeSelectableWhenDeadF8:1,nativeBodyBagSource510:c.sourceId,possessorId:c.possessor??99},bag={id:200,areaId:88,role:'bag',objectType:9,nativeBodyBagSource510:c.sourceId},linked={id:300,role:'linked'},node=createObjectAction(40,c.group??66);
  node.parameterTypes.set([3,1,1]);node.parameterCount=3;node.parameterData[0]=100;node.parameterData[1]=c.deadline??0;node.parameterData[2]=c.phase??0;let rangeIndex=0,lock=OBJECT_INVALID;
  const p={
   lookup:id=>{calls.push(['lookup',id]);return{status:id===100?c.lookupStatus:c.linkedStatus??0,object:id===100?target:linked};},object:id=>{calls.push(['object',id]);return c.bagPresent?bag:null;},
   asObject:o=>{calls.push(['asObject',o.role]);return c.asObject===false?null:o;},asCreature:o=>{calls.push(['asCreature',o.role]);return(o===actor?c.actorCreature:o===linked?c.linkedCreature??true:o===target?c.type===5:false)?o:null;},
   asPlaceable:o=>{calls.push(['asPlaceable',o.role]);return o;},asItem:o=>{calls.push(['asItem',o.role]);return o;},
   dead:o=>{calls.push(['dead',o.role]);return c.dead;},dying:o=>{calls.push(['dying',o.role]);return c.dying;},area:o=>{calls.push(['area',o.role]);return c.area?{}:null;},
   position:o=>o===bag?[2,3,4]:[1,2,3],inUseRange:(_o,id,range,flag)=>{calls.push(['inRange',id,range,flag]);const values=c.ranges??[c.inRange];return values[Math.min(rangeIndex++,values.length-1)];},
   useRange:(_o,id,out)=>{calls.push(['range',id]);out.point=[9,8,7];out.range=c.range;return c.rangeResult??1;},
   activityManager:(o,n)=>calls.push(['manage',o.role,n]),activity:(o,...args)=>calls.push(['activity',o.role,...args]),
   queue:(_o,id,group,params,front)=>calls.push([front?'front':'back',id,group,params.map(p=>[p.type,p.value|0])]),moveFront:(_o,...args)=>calls.push(['move',...args]),setLock:(_o,id)=>{lock=id;calls.push(['lock',id]);},
   usable:()=>c.usable,trapped:()=>c.trapped,trapActive:()=>c.active,trapFaction:()=>c.trapFaction,creatureFaction:()=>c.actorFaction,
   reputation:(o,id,out,flag)=>{calls.push(['reputation',o.role,id,flag]);out.value=777;return c.reputation;},
   hasInventory:()=>c.hasInventory,possessed:o=>{calls.push(['possessed',o.role]);return c.possessed;},associatesCanInteract:()=>{calls.push(['associates']);return c.associates;},
   client:id=>{calls.push(['client',id]);return c.client?{}:null;},primary:()=>({openInventory:{id:c.primaryId??OBJECT_INVALID}}),alternate:()=>({openInventory:{id:c.alternateId??OBJECT_INVALID}}),playerCharacter:o=>{calls.push(['player',o.role]);return c.pc;},
   itemCount:(o,flag)=>{calls.push(['count',o.role,flag]);return c.itemCount;},locked:()=>c.locked,evaluateLock:(_o,target,flag)=>{calls.push(['evaluateLock',target.role,flag]);return c.evaluate;},
   feedback:(o,code,value)=>calls.push(['feedback',o.role,code,value?.objects??null]),failedOpenInformAssociates:o=>calls.push(['failedInform',o.role]),
   openPlaceable:(o,id)=>calls.push(['openPlaceable',o.role,id]),closePlaceable:(o,...args)=>calls.push(['closePlaceable',o.role,...args]),openItem:(o,id)=>calls.push(['openItem',o.role,id]),closeItem:(o,...args)=>calls.push(['closeItem',o.role,...args]),animation:(o,id)=>calls.push(['animation',o.role,id]),
   hasEquipment:()=>c.hasEquipment??true,equipment:(_o,slot)=>{calls.push(['equipment',slot]);const value=(slot===16?c.right:c.left)??null;return value===null?null:{droppable:value};},corpseEquipmentMessage:(...args)=>calls.push(['corpseMessage',...args]),destroyEquippedItems:o=>calls.push(['destroyEquipment',o.role]),
   baseInfo:()=>{calls.push(['baseInfo',7]);return{container:c.container??0};},event:(id,caller,target,payload)=>calls.push(['event',id,caller,target,payload.type]),timer:()=>{calls.push(['timer',0]);return c.now;},
  };
  const result=await executeUseObjectAction(actor,node,p),label=JSON.stringify(c);assert.equal(result,row.result,label);assert.deepEqual(calls,row.calls,label);assert.equal(node.parameterData[2],row.phase,label);assert.equal(node.parameterData[1]>>>0,row.deadline,label);assert.equal(target.nativeLootable4e8,row.lootable,label);assert.equal(target.nativeSelectableWhenDeadF8,row.selectable,label);assert.equal(lock,row.lock,label);
 }
 assert.equal(data.rows.length,1233);
});
test('UseObject cancellation matches original shared-tail lock/time cleanup without inventing private effects',async()=>{
 for(const row of data.clears){const c=row.case,calls=[],o={lockOrientationId:c.lock,objectActionState:{startDay:10,startTime:2345}},node={actionId:40,nativeField9c:c.ready};let lock=c.lock;
  const result=await clearCreatureMovementAction(o,node,c.head,{messageAvailable:()=>{calls.push(['message']);return c.message;},setLock:(_o,id)=>{lock=id;calls.push(['lock',id]);}});
  assert.equal(result,row.result);assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.equal(lock,row.lock);assert.deepEqual([o.objectActionState.startDay,o.objectActionState.startTime],row.start);
 }
 assert.equal(data.clears.length,36);
});
test('DestroyEquippedItems matches original18 live physical slots and nonzero droppable destructor ordering',async()=>{
 for(const row of data.equipment){const c=row.case,calls=[];await destroyDroppableEquipment({}, {hasEquipment:()=>c.hasEquipment,equipment:(_o,slot)=>{calls.push(['equipment',slot]);const index=Math.log2(slot),value=c.equipment[index];return value===null?null:{index,droppable:value};},destroy:(o,flag)=>calls.push(['destroy',o.index,flag])});assert.deepEqual(calls,row.calls,JSON.stringify(c));}
 assert.equal(data.equipment.length,12);
});
test('placeable OnUsed and OnClick delivery matches original Useable gate, WORD selector, caller cells and script slots',async()=>{
 for(const row of data.events){const c=row.case,calls=[],o={eventObjects:{},nativeLastUsedBy528:OBJECT_INVALID,nativeLastClicking52c:OBJECT_INVALID};
  await receivePlaceableUseEvent(o,c.caller,{type:c.event},{usable:()=>c.usable,runEventScript:(_o,...args)=>calls.push(['script','actor',...args])});
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual([o.nativeLastUsedBy528,o.nativeLastClicking52c],row.eventFields);
  if(c.usable!==0)assert.equal(o.eventObjects[(c.event&65535)===25?'used':'clicking'],c.caller);
 }
 assert.equal(data.events.length,48);
});
