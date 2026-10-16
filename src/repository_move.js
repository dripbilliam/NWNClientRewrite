import {OBJECT_INVALID as INVALID} from './game_object_array.js';
import {addObjectAction,actionParameter} from './object_actions.js';
import {clearCreatureMovementAction} from './combat_lifecycle.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native repository action ${n} is unavailable`);return v|0;};
const id=(v,n)=>integer(v,n)>>>0;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native repository action provider ${n} is unavailable`);return p[n];};
const cast=(p,n,o)=>{const value=required(p,n)(o);if(!value)throw new Error(`Native repository move dereferences null ${n}`);return value;};

// AddRepositoryMoveActions140380090. Unlike ground pickup, no area gate.
export function addRepositoryMoveAction(actor,item,destination,x,y){
 const itemId=id(item.id,'item ID');if(integer(actor.nativeFieldEc,'commandable')===0)return 0;
 addObjectAction(actor.objectActionState,13,65535,[{type:3,value:itemId},{type:3,value:id(destination,'destination')},{type:6,value:integer(x,'x')},{type:6,value:integer(y,'y')}]);return 1;
}

// ClearAction13: optional RepositoryMoveCancel precedes the shared lock/time
// tail. It does not undo a completed transfer or mutate repository ownership.
export async function clearRepositoryMoveAction(actor,node,head,p){
 if(node.nativeField9c===0)return 0;
 const message=await required(p,'message')(),client=await required(p,'client')(actor.id);
 if(client&&message)await required(p,'cancel')(client,id(actionParameter(node,0),'item ID'),0);
 return clearCreatureMovementAction(actor,node,head,{messageAvailable:()=>message,setLock:required(p,'setLock')});
}

// Full decoded InventoryMessage140455f50 subtype9. Initial overflow precedes
// reads; controlled lookup is repeated. Add failure emits RepositoryMoveCancel.
export async function receiveRepositoryMoveInput(client,p){
 if(integer(required(p,'overflow')(),'entry overflow')!==0)return 0;
 const itemId=id(required(p,'readObjectId')(),'item ID'),destination=id(p.readObjectId(),'destination'),x=integer(required(p,'readByte')(),'x')&255,y=integer(p.readByte(),'y')&255;
 if(integer(p.overflow(),'payload overflow')!==0||integer(required(p,'underflow')(),'underflow')!==0)return 0;
 if(await required(p,'clientObject')(client)){
  const object=await p.clientObject(client);if(!object)throw new Error('Native repository input dereferences null controlled object');
  const actor=required(p,'asCreature')(object);if(actor){const lookup=await required(p,'lookup')(itemId);
   if(lookup.status===0){if(!lookup.object)throw new Error('Native repository input dereferences null successful lookup');const item=required(p,'asItem')(lookup.object);
    if(item){await required(p,'actionManager')(actor,2);if(await required(p,'add')(actor,item,destination,x,y)!==0)return 1;}
   }
  }
 }
 await required(p,'message')();await required(p,'cancel')(client,itemId,0);return 0;
}

// Full AIActionRepositoryMove1403c9960..3ca886 (instrumentation excluded).
// UI state never substitutes for repository identity or direct item possession.
export async function executeRepositoryMove(actor,node,p){
 if((integer(actor.associateType,'associate type')&65535)===3&&await required(p,'controlled')(actor.id)!==0&&await required(p,'associatesCanInteract')()===0){await required(p,'feedback')(actor,173);return 3;}
 if(await required(p,'dead')(actor)===1||await required(p,'dying')(actor)===1)return 3;
 await required(p,'activityManager')(actor,2);
 const itemId=id(actionParameter(node,0),'item ID'),destination=id(actionParameter(node,1),'destination'),x=integer(actionParameter(node,2),'x')&255,y=integer(actionParameter(node,3),'y')&255;
 const message=await required(p,'message')(),client=await required(p,'client')(actor.id),dm=client?await required(p,'dm')(client)!==0:false;
 const ref={item:await required(p,'item')(itemId)};
 const cancel=async(flag=0)=>{if(client&&message)await required(p,'cancel')(client,itemId,flag);return 3;};
 if(!ref.item)return cancel();if(!client)return 3;
 if(id(ref.item.possessorId,'possessor')===INVALID)return cancel();
 let targetRepo=null,gui=null,other=null,fromExternal=0,toExternal=0;
 if(destination!==INVALID){const target=await required(p,'object')(destination);
  if(target){
   if(target.objectType===6){const bag=cast(p,'asItem',target);targetRepo=required(p,'repository')(bag);toExternal=1;
    if(id(ref.item.possessorId,'possessor')!==id(bag.id,'bag ID')){
     const owner=id(bag.possessorId,'bag possessor');let invalid=false;
     if(owner===INVALID)invalid=id(ref.item.possessorId,'possessor')!==id(actor.id,'actor ID');
     else if(owner!==id(actor.id,'actor ID')){const alternate=required(p,'alternate')(client);
      if(owner===id(alternate.ownerId,'alternate character')){gui=alternate;other=await required(p,'creature')(owner);}else invalid=true;}
     const base=required(p,'baseInfo')(ref.item);if(!base)throw new Error('Native repository move dereferences null incoming base rules');
     if(integer(base.container,'incoming Container')!==0){const bagBase=p.baseInfo(bag);if(!bagBase)throw new Error('Native repository move dereferences null bag rules');if(integer(bagBase.container,'bag Container')!==0)return cancel();}
     if(invalid)return cancel();
    }
   }else if(target.objectType===9){const placeable=cast(p,'asPlaceable',target);targetRepo=p.repository(placeable);toExternal=1;const owner=id(ref.item.possessorId,'possessor');
    if(owner!==id(placeable.id,'placeable ID')&&(owner===INVALID||owner!==id(actor.id,'actor ID')&&owner!==id(p.alternate(client).ownerId,'alternate character'))){
     const source=await p.object(owner);if(!source||(source.objectType&255)<=4)return cancel();
     if(!required(p,'asItem')(source))return cancel();const bag=cast(p,'asItem',source);if(id(bag.possessorId,'bag possessor')===INVALID)return cancel();
     if(id(cast(p,'asItem',source).possessorId,'bag possessor')!==id(p.alternate(client).ownerId,'alternate character'))return cancel();
    }
   }else if(target.objectType===5){const creature=cast(p,'asCreature',target);targetRepo=p.repository(creature);const alternate=p.alternate(client);
    if(id(target.id,'target ID')===id(alternate.ownerId,'alternate character')){gui=alternate;other=creature;}
    else if(id(target.id,'target ID')===id(actor.id,'actor ID'))gui=required(p,'primary')(client);else return cancel();
   }
  }
 }
 let sourceRepo;const sourceId=id(ref.item.possessorId,'possessor');
 if(sourceId===id(actor.id,'actor ID'))sourceRepo=p.repository(actor);
 else{const source=await p.object(sourceId);if(!source)return cancel();
  if(source.objectType===6){const bag=cast(p,'asItem',source),owner=id(bag.possessorId,'bag possessor');
   if(owner===id(actor.id,'actor ID')||owner===INVALID)sourceRepo=p.repository(bag);
   else{if(owner!==id(p.alternate(client).ownerId,'alternate character'))return cancel();sourceRepo=p.repository(bag);other=await p.creature(owner);}
  }else if(source.objectType===9){sourceRepo=p.repository(cast(p,'asPlaceable',source));fromExternal=1;}
  else if(source.objectType===5&&id(p.alternate(client).ownerId,'alternate character')===id(source.id,'source creature')){sourceRepo=p.repository(cast(p,'asCreature',source));fromExternal=1;other=cast(p,'asCreature',source);}
  else return cancel();
 }
 if(!sourceRepo)return cancel();targetRepo??=p.repository(actor);gui??=p.primary(client);
 if(await required(p,'contains')(sourceRepo,ref.item,0)!==1)return cancel();
 const selectPage=async item=>{const page=integer(await required(p,'page')(p.repository(actor),integer(item.repositoryX,'repository X')&255,integer(item.repositoryY,'repository Y')&255),'page')&255;
  if(integer(gui.field8,'GUI open')!==0&&page!==(integer(gui.fieldC,'GUI panel')&255)){
   if(!message)return false;await required(p,'selectPanelMessage')(client,page);await required(p,'setPanel')(gui,client,page);
  }return true;};
 if(sourceRepo===targetRepo){if(await required(p,'move')(targetRepo,ref.item,x,y)===0)return cancel();
  if(!await selectPage(ref.item))return 2;if(message)await required(p,'moved')(client,itemId,0);return 2;}
 if(integer(ref.item.cursed,'cursed')!==0&&!dm){
  if(await required(p,'playerCharacter')(actor)!==0||id(actor.masterId,'master ID')!==INVALID){
   if(await p.playerCharacter(actor)!==0)await p.feedback(actor,246);
   return cancel(id(gui.ownerId,'GUI character')!==id(actor.id,'actor ID')&&id(gui.ownerId,'GUI character')!==INVALID?1:0);
  }
 }
 const base=required(p,'baseInfo')(ref.item);if(!base)throw new Error('Native repository move dereferences null item base rules');
 if(integer(base.container,'Container')!==0)await required(p,'closeItem')(ref.item,actor.id,1);
 const oldX=integer(ref.item.repositoryX,'repository X')&255,oldY=integer(ref.item.repositoryY,'repository Y')&255;
 await required(p,'remove')(sourceRepo,ref.item);const quantity=integer(ref.item.stackSize,'stack size');
 if(await required(p,'addItem')(targetRepo,ref,x,y,0,fromExternal)===0){
  await p.addItem(sourceRepo,ref,oldX,oldY,0,0);if(toExternal!==0)await p.feedback(actor,212);
  await required(p,'encumbrance')(actor,1);if(other)await p.encumbrance(other,1);return cancel();
 }
 let sendMoved=true;
 if(destination===INVALID){if(ref.item){await required(p,'setPossessor')(ref.item,actor.id,1,1,quantity);sendMoved=await selectPage(ref.item);}}
 else if(ref.item)await required(p,'setPossessor')(ref.item,destination,1,1,quantity);
 if(sendMoved&&message)await p.moved(client,itemId,0);
 await p.encumbrance(actor,1);if(other)await p.encumbrance(other,1);return 2;
}
