import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native ActionUseItem ${n} is unavailable`);return v|0;};
const propertyId=value=>{if(typeof value!=='string'||! /^[0-9a-f]{16}$/.test(value))throw new Error('Native ActionUseItem uint64 property ID storage is unavailable');return value;};

// Complete ExecuteCommandActionUseItem14050f190..14050f471 (910/911).
// Typed-pop failure returns -639, distinct from normal no-op/UseItem rejection.
// Property identity is the uint64 property ID, never the effect handle or type.
// The two local structure scopes release in reverse order on every exit.
export async function scriptUseItem(ordinal,self,p){
 let read=p.pop('object');if(!read.ok)return -639;
 const itemId=integer(read.value,'item ID')>>>0;
 read=p.pop('itemproperty');if(!read.ok)return -639;
 const handle=read.value;let location=null;
 try{
  let targetId=OBJECT_INVALID;
  if(ordinal===910){read=p.pop('object');if(!read.ok)return -639;targetId=integer(read.value,'target ID')>>>0;}
  else if(ordinal===911){read=p.pop('location');if(!read.ok)return -639;location=read.value;}
  read=p.pop('int');if(!read.ok)return -639;const variant=integer(read.value,'variant')&255;
  read=p.pop('int');if(!read.ok)return -639;const consume=integer(read.value,'consumption flag');
  const actor=p.creature(integer(self,'self ID')>>>0);if(!actor)return 0;
  const item=p.item(itemId);if(!item)return 0;
  const count=integer(p.activeCount(item),'active property count');
  for(let index=0;index<count;index++){
   const prop=p.activeProperty(item,index);
   if(propertyId(prop?.propertyId)!==propertyId(handle?.propertyId))continue;
   let areaId=OBJECT_INVALID;
   if(p.area(actor)){const area=p.area(actor);if(!area)throw new Error('Native ActionUseItem actor area disappeared during lookup');areaId=integer(area.id,'actor area ID')>>>0;}
   let point=[0,0,0];
   if(location){if(!Array.isArray(location.position)||location.position.length!==3||!location.position.every(v=>typeof v==='number'))throw new Error('Native ActionUseItem location point storage is unavailable');point=location.position.map(Math.fround);}
   await p.use(actor,itemId,index&255,variant,targetId,point,areaId,consume);break;
  }
  return 0;
 }finally{p.release('location',location);p.release('itemproperty',handle);}
}
