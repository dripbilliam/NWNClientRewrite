import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native CopyItem ${n} is unavailable`);return v|0;};

async function placeCopiedItem(source,targetId,ref,creatureFeedback,p){
 if(targetId===OBJECT_INVALID&&(targetId=integer(source.possessorId,'source possessor')>>>0)===OBJECT_INVALID){
  const point=p.position(source);await p.addToArea(ref.item,p.area(source),...point,1);
 }else{
  const target=p.object(targetId);
  if(target&&p.asWorld(target)){
   let acquired=0;
   if(p.asCreature(target))acquired=await p.acquireCreature(p.asCreature(target),ref,OBJECT_INVALID,OBJECT_INVALID,255,255,0,creatureFeedback);
   else if(p.asPlaceable(target))acquired=await p.acquirePlaceable(p.asPlaceable(target),ref,OBJECT_INVALID,255,255,1);
   else if(p.asItem(target))acquired=await p.acquireContainer(p.asItem(target),ref,OBJECT_INVALID,255,255,1);
   else if(p.asStore(target))acquired=await p.acquireStore(p.asStore(target),ref.item,0,255,255);
   if(acquired===0){const point=p.position(p.asWorld(target));await p.addToArea(ref.item,p.area(p.asWorld(target)),...point,1);}
  }
 }
}

// Complete ExecuteCommandCopyItem140512600..1405128e5. VM status and the
// pushed OBJECT_ID are separate, as are mutable acquisition pointers and IDs.
export async function scriptCopyItem(argc,p){
 let read=p.pop('object');if(!read.ok)return -639;const sourceId=integer(read.value,'source ID')>>>0;
 let targetId=OBJECT_INVALID,variables=0;
 if(argc>1){read=p.pop('object');if(!read.ok)return -639;targetId=integer(read.value,'target ID')>>>0;}
 if(argc>2){read=p.pop('int');if(!read.ok)return -639;variables=integer(read.value,'copy variables');}
 let result=OBJECT_INVALID;const source=p.item(sourceId);
 if(source){
  const ref={item:await p.construct()};
  if(await p.copy(ref.item,source,Number(variables!==0))===0){if(ref.item)await p.destroy(ref.item,1);}
  else{
   await p.setPossessor(ref.item,OBJECT_INVALID,0,0,0);
   await placeCopiedItem(source,targetId,ref,1,p);
   if(ref.item)result=integer(ref.item.id,'result ID')>>>0;
  }
 }
 return p.push(result)?0:-638;
}

// Complete ExecuteCommandCopyItemAndModify1405128f0..1405134a6. The
// original appearance owner is separate; placement uses the original possessor
// with creature feedback0, unlike CopyItem's feedback1 and explicit target.
export async function scriptCopyItemAndModify(argc,p){
 const values=[];for(const type of['object','int','int','int',...(argc>4?['int']:[])]){const read=p.pop(type);if(!read.ok)return -639;values.push(integer(read.value,'argument'));}
 const[sourceId,type,index,value,variables=0]=values;let result=OBJECT_INVALID;
 if(type>4)await p.warning(0x6680);
 if((sourceId>>>0)!==OBJECT_INVALID&&type<=4){const source=p.item(sourceId>>>0);if(source){
  const ref={item:await p.construct()};
  if(await p.copy(ref.item,source,Number(variables!==0))===0){if(ref.item)await p.destroy(ref.item,1);}
  else if(!await p.modify(ref.item,source,type,index,value)){if(ref.item)await p.destroy(ref.item,1);}
  else{
   await p.setPossessor(ref.item,OBJECT_INVALID,0,0,0);await placeCopiedItem(source,OBJECT_INVALID,ref,0,p);
   if(!ref.item)throw new Error('Native CopyItemAndModify dereferences a null result after acquisition');result=integer(ref.item.id,'result ID')>>>0;
  }
 }}
 return p.push(result)?0:-638;
}
