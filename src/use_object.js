import {OBJECT_INVALID} from './game_object_array.js';
import {addObjectAction,actionParameter} from './object_actions.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native use-object ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native use-object provider ${n} is unavailable`);return p[n];};
const f=Math.fround,bits=value=>{const v=new DataView(new ArrayBuffer(4));v.setFloat32(0,value,true);return v.getInt32(0,true);};

// AddUseObjectAction1404ab5b0. Target plus two separate zero INT slots;
// execution reuses the latter as a timer and phase, not immutable arguments.
export function addUseObjectAction(actor,targetId){
 targetId=integer(targetId,'target ID')>>>0;if(integer(actor.nativeFieldEc,'commandable')===0)return 0;
 addObjectAction(actor.objectActionState,40,65535,[{type:3,value:targetId},{type:1,value:0},{type:1,value:0}]);return 1;
}

// ExecuteCommandActionInteractObject14050dec0: placeable lookup BEFORE
// source creature lookup, no area check. VM argument/error codec is separate.
export async function scriptInteractObject(self,targetId,p){
 const target=await required(p,'placeable')(integer(targetId,'script target ID')>>>0);if(!target)return;
 const actor=await required(p,'creature')(integer(self,'script self ID')>>>0);if(actor)await required(p,'addUse')(actor,target.id);
}

// Full decoded client input subtype11 at1404531b0 (branch453acb..3ba9).
// Unlike item casting, this branch has no area-ID gate. Acceptance1 ignores
// AddUseObjectAction's return. A nonzero popup flag writes retained field4;
// only exact notification1 queues script event42 BEFORE ActionManager2.
export async function receiveUseObjectInput(client,p){
 const object=required(p,'clientObject')(client);let actor=object?required(p,'asCreature')(object):null;
 if(actor&&integer(actor.nativeField8ac,'creature field8ac')!==0)actor=null;
 if(integer(required(p,'overflow')(),'entry overflow')!==0)return 0;
 const targetId=integer(required(p,'readObjectId')(),'input target ID')>>>0,popup=integer(required(p,'readBool')(),'popup flag'),notify=integer(p.readBool(),'notification flag');
 if(integer(p.overflow(),'target overflow')!==0||integer(required(p,'underflow')(),'target underflow')!==0||!actor)return 0;
 if(notify===1)await required(p,'event')(10,actor.id,targetId,{type:42});
 if(popup!==0)required(p,'primary')(client).openInventory.field4=1;
 await required(p,'actionManager')(actor,2);await required(p,'addUse')(actor,targetId);return 1;
}

// Placeable EventHandler script25 ->4b33f9 and42 ->4b3417. Both test
// Useable264 at delivery, write the caller, then invoke index12/15(flag0).
export async function receivePlaceableUseEvent(object,caller,payload,p){
 const type=integer(payload.type,'placeable script type')&65535;caller=integer(caller,'script caller')>>>0;
 if(![25,42].includes(type))throw new Error('Native placeable use/click script event is unavailable');
 if(integer(required(p,'usable')(object),'usable')===0)return;
 if(type===25){object.nativeLastUsedBy528=caller;object.lastUsedBy=caller;object.eventObjects.used=caller;}
 else{object.nativeLastClicking52c=caller;object.eventObjects.clicking=caller;}
 await required(p,'runEventScript')(object,type===25?12:15,0);
}

// Full AIActionUseObject1404a9790..1404aa8c3 (instrumentation excluded).
// Points at this boundary are native XYZ. No actor-death check is invented;
// target dead/dying checks and the special lootable-corpse exception are exact1.
export async function executeUseObjectAction(actor,node,p){
 if(integer(node.parameterData[2],'phase')!==0)return (integer(await required(p,'timer')(),'timer')>>>0)<(integer(node.parameterData[1],'deadline')>>>0)?1:2;
 let targetId=actionParameter(node,0)>>>0,lookup=await required(p,'lookup')(targetId);
 if(lookup.status!==0)return 3;
 if(!lookup.object)throw new Error('Native UseObject dereferences a null successful lookup');
 let target=required(p,'asObject')(lookup.object);if(!target)return 3;let allowDead=0;
 if(target.objectType===5){const corpse=required(p,'asCreature')(target);
  if(corpse&&integer(corpse.nativeLootable4e8,'lootable')===1&&(await required(p,'dead')(corpse)===1||await required(p,'dying')(corpse)===1)){
   const bag=await required(p,'object')(integer(corpse.nativeBodyBagId4f0,'corpse bag ID')>>>0);
   if(bag){target=required(p,'asObject')(bag);targetId=corpse.nativeBodyBagId4f0>>>0;if(!target)throw new Error('Native corpse bag object cast is null');}
   else{
    if(required(p,'asCreature')(actor)&&await required(p,'inUseRange')(p.asCreature(actor),targetId,0,0)!==0){
     await required(p,'feedback')(p.asCreature(actor),247,null);corpse.nativeLootable4e8=0;corpse.nativeSelectableWhenDeadF8=0;return 3;
    }
    allowDead=1;
   }
  }
 }
 if((await required(p,'dead')(target)===1||await required(p,'dying')(target)===1)&&allowDead===0)return 3;
 if(await required(p,'area')(target)&&required(p,'asCreature')(actor)){
  const creature=p.asCreature(actor);await required(p,'activityManager')(creature,2);await required(p,'activity')(creature,8,0);
  const targetPoint=[...required(p,'position')(target)];
  if(await p.inUseRange(creature,targetId,0,0)===0){
   const out={point:[0,0,0],range:0};await required(p,'useRange')(creature,targetId,out);
   const group=node.groupId&65535;
   await required(p,'queue')(actor,40,group,[{type:3,value:targetId},{type:1,value:0},{type:1,value:0}],true);
   await p.queue(actor,49,group,targetPoint.map(value=>({type:2,value:bits(value)})),true);
   await p.queue(actor,17,group,[{type:3,value:targetId},{type:1,value:1},{type:2,value:bits(out.range)},{type:2,value:bits(f(f(out.range)+f(.1)))},{type:1,value:1}],true);
   await required(p,'moveFront')(creature,group,out.point,actor.areaId,targetId,1,out.range,0,0,0,0,0,0,1);return 2;
  }
 }
 await required(p,'setLock')(actor,targetId);
 if(target.objectType===9){
  const placeable=required(p,'asPlaceable')(target);if(!placeable)throw new Error('Native UseObject placeable cast is null');
  if(integer(required(p,'usable')(placeable),'usable')===0)return 3;
  if(integer(required(p,'trapped')(placeable),'trap flag')!==0&&integer(required(p,'trapActive')(placeable),'active trap')!==0&&p.asCreature(actor)){
   const relation={value:0},rep=await required(p,'reputation')(placeable,actor.id,relation,0);
   if(rep<90&&integer(required(p,'trapFaction')(placeable),'trap faction')!==integer(required(p,'creatureFaction')(p.asCreature(actor)),'creature faction')){
    await required(p,'event')(10,actor.id,targetId,{type:26});return 3;
   }
  }
  if(integer(required(p,'hasInventory')(placeable),'HasInventory')!==0){
   if(p.asCreature(actor)&&await required(p,'possessed')(p.asCreature(actor))===1&&await required(p,'associatesCanInteract')()===0){
    await p.feedback(p.asCreature(actor),181,null);return 3;
   }
   const client=await required(p,'client')(actor.id);
   if(p.asCreature(actor)&&await required(p,'playerCharacter')(p.asCreature(actor))===1&&(integer(placeable.nativeBodyBagSource510,'bag source ID')>>>0)!==OBJECT_INVALID&&await required(p,'itemCount')(placeable,1)===0&&client){
    if((integer(required(p,'primary')(client).openInventory.id,'current container ID')>>>0)!==targetId){await p.feedback(p.asCreature(actor),247,null);return 3;}
   }
   if(integer(required(p,'locked')(placeable),'locked')!==0){
    if(p.asCreature(actor)&&await required(p,'evaluateLock')(p.asCreature(actor),placeable,0)===0){
     await p.feedback(p.asCreature(actor),13,{objects:[placeable.id]});await required(p,'failedOpenInformAssociates')(p.asCreature(actor));
    }else if(client){
     if((integer(p.primary(client).openInventory.id,'current container ID')>>>0)!==targetId)await required(p,'openPlaceable')(placeable,actor.id);
     else await required(p,'closePlaceable')(placeable,actor.id,1);
    }else await required(p,'animation')(actor,75);
   }else if(client){
    if((integer(p.primary(client).openInventory.id,'current container ID')>>>0)!==targetId){
     const corpseId=integer(placeable.nativeBodyBagSource510,'bag source ID')>>>0;
     if(corpseId!==OBJECT_INVALID){lookup=await p.lookup(corpseId);
      if(lookup.status===0){if(!lookup.object)throw new Error('Native body-bag source lookup is null');const corpse=p.asCreature(lookup.object);
       if(corpse){let left=1,right=1;
        if(required(p,'hasEquipment')(corpse)){const rightItem=required(p,'equipment')(corpse,16);if(rightItem&&integer(rightItem.droppable,'right droppable')===0)right=0;
         const leftItem=p.equipment(corpse,32);if(leftItem&&integer(leftItem.droppable,'left droppable')===0)left=0;
        }
        await required(p,'corpseEquipmentMessage')(corpse.id,left,right);await required(p,'destroyEquippedItems')(corpse);
       }
      }
     }
     await required(p,'openPlaceable')(placeable,actor.id);
    }else await required(p,'closePlaceable')(placeable,actor.id,1);
   }else await required(p,'animation')(actor,75);
  }
  await required(p,'event')(10,actor.id,targetId,{type:25});
 }else if(target.objectType===6){
  const item=required(p,'asItem')(target);if(!item)throw new Error('Native UseObject item cast is null');
  const base=required(p,'baseInfo')(item);if(!base)throw new Error('Native UseObject item base rules are null');
  if(integer(base.container,'container flag')!==0){const client=await required(p,'client')(actor.id);if(client){
   const gui=(integer(item.possessorId,'item possessor')>>>0)===(actor.id>>>0)?required(p,'primary')(client):required(p,'alternate')(client);
   if((integer(gui.openInventory.id,'current container ID')>>>0)!==targetId)await required(p,'openItem')(item,actor.id);
   else await required(p,'closeItem')(item,actor.id,1);
  }}
 }
 node.parameterData[2]=1;node.parameterData[1]=((integer(await required(p,'timer')(),'timer')>>>0)+500)>>>0;return 1;
}

// DestroyEquippedItems14038a7a0: all18 physical slots, nonzero droppable;
// direct destructors leave the native slot IDs stale until other owners clear.
export async function destroyDroppableEquipment(actor,p){
 if(!required(p,'hasEquipment')(actor))return;
 for(let n=0;n<18;n++){const item=required(p,'equipment')(actor,1<<n);if(item&&integer(item.droppable,'droppable')!==0)await required(p,'destroy')(item,1);}
}
