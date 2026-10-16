import {OBJECT_INVALID} from './game_object_array.js';
const f=Math.fround;
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native item casting ${name} is unavailable`);return v|0;};
const bits=v=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,v,true);return d.getUint32(0,true);};
const param=(type,value)=>({type,value}),pointParams=point=>point.map(v=>param(2,bits(v)));

// Complete UseItem1403a9f70. Ownership includes exactly one parent bag and
// the compiled associate7/8 bypass. Property55/70/80 remain distinct skill/trap
// paths, not casts. Item spell actions consume their charge in execution.
export async function useItem(actor,itemId,propertyIndex,mode,targetId,point,areaId,consume,p){
 itemId=integer(itemId,'item ID')>>>0;propertyIndex=integer(propertyIndex,'property index')&255;mode=integer(mode,'mode')&255;
 targetId=integer(targetId,'target ID')>>>0;
 const item=p.item(itemId),target=p.object(targetId);if(!item)return 0;
 if((item.possessorId>>>0)!==(actor.id>>>0)&&(((integer(actor.associateType,'associate type')&65535)-7)&65535)>1){
  const parent=p.item(item.possessorId>>>0);if(!parent||(parent.possessorId>>>0)!==(actor.id>>>0))return 0;
 }
 if(await p.canUse(actor,item,0)===0)return 0;
 const property=p.activeProperty(item,propertyIndex);if(!property)return 0;
 const type=integer(property.type,'property type')&65535;
 if(type===15){
  if(integer(property.remaining,'property remaining')===0)return 0;
  if(target&&p.asCreature(target)){const flags=p.visibility(actor,targetId);if(flags!==null&&(flags&12)===4)return 2;}
  const base=p.baseInfo(item),offset=((item.baseItem|0)-49)>>>0,exempt=offset<=55&&((0x80000004000021n>>BigInt(offset))&1n)!==0n;
  if(!exempt){
   if(!base)throw new Error('Native item casting base storage is unavailable');
   if(integer(base.equipableSlots,'equipable slots')!==0&&p.equipped(actor,item)===0){await p.feedback(actor,244);return 0;}
  }
  return p.addCast(actor,{itemId,propertyIndex,mode,position:point.map(f),targetId,location:Number(targetId===OBJECT_INVALID),consume:integer(consume,'resource consumption flag')});
 }
 if(type===70)return p.addTrap(actor,item.id>>>0,29,targetId,point.map(f),integer(areaId,'area ID')>>>0);
 if(type===55||type===80)return p.useSkill(actor,type===55?9:4,0,targetId,point.map(f),integer(areaId,'area ID')>>>0,itemId,propertyIndex);
 return 0;
}

// Complete AddItemCastSpellActions14037f030. Original native XYZ is saved
// for physical action46 parameters before the caller's vector is overwritten
// by a resolved object/carried-item point. The queue is always appended.
export async function addItemCastSpellActions(actor,{itemId,propertyIndex,mode,position,targetId,location,consume},p){
 itemId=integer(itemId,'item ID')>>>0;propertyIndex=integer(propertyIndex,'property index');mode=integer(mode,'mode');targetId=integer(targetId,'target ID')>>>0;
 const item=p.item(itemId);if(!item)return 0;
 actor.spellActionTargetId=actor.nativeTarget740=OBJECT_INVALID;
 if((integer(actor.nativeField89c,'PC field')!==0||p.possessed(actor)!==0)&&integer(actor.nativeField97c,'polymorph field')!==0&&item.baseItem!==49&&item.baseItem!==104)return 0;
 if(!Array.isArray(position)||position.length!==3)throw new Error('Native item casting position storage is unavailable');
 const original=position.map(f);
 if(p.dm(actor)===0&&targetId!==OBJECT_INVALID){
  const target=p.object(targetId);if(!target)return 0;
  const targetArea=p.area(target);position.splice(0,3,...p.position(target).map(f));
  if(targetArea!==p.area(actor)){
   if(target.objectType!==6||targetArea)return 0;
   const targetItem=p.asItem(target);if(!targetItem||(targetItem.possessorId>>>0)!==(actor.id>>>0))return 0;
   p.area(actor);position.splice(0,3,...p.position(actor).map(f));
  }
  if(p.asCreature(target)&&target.id!==actor.id){const flags=p.visibility(actor,targetId);if(flags===null||(flags&12)===4||(flags&17)===16)return 0;}
 }
 const property=p.activeProperty(item,propertyIndex),spellId=property?p.spellIndex(property.subtype&65535):-1,spell=p.spell(spellId);
 if(!spell||!p.area(actor)||integer(actor.nativeFieldEc,'commandability')===0)return 0;
 const area=p.area(actor),range=f(p.range(actor,spell,targetId)),origin=p.position(actor).map(f),delta=position.map((v,i)=>f(v-origin[i]));
 const distance=f(f(f(delta[1]*delta[1])+f(delta[0]*delta[0]))+f(delta[2]*delta[2])),outside=distance>f(range*range);
 const queue=(id,group,params=[])=>p.queue(actor,id,group,params,false);
 let group=65535;
 if(outside){await p.move(actor,group,[...position],area.id,targetId,1,range,0,0,0,0,0,0,0);group=65534;}
 if(targetId!==OBJECT_INVALID){
  await queue(17,group,[param(3,targetId),param(1,1),param(2,bits(range)),param(2,bits(range)),param(1,1)]);
  group=65534;await queue(19,group,[param(3,targetId)]);
 }else{
  await queue(18,group,[...pointParams(original),param(3,area.id),param(3,targetId),param(1,1),param(2,bits(range))]);
  group=65534;await queue(49,group,pointParams(original));
 }
 if(item.baseItem===49||item.baseItem===104)await queue(30,group,[param(2,bits(1))]);
 else await queue(16,group);
 await queue(46,group,[param(3,itemId),param(1,propertyIndex),param(1,mode),param(3,targetId),...pointParams(original),param(1,0),param(1,0),param(1,Number(integer(consume,'resource consumption flag')!==0))]);
 actor.spellActionTargetId=integer(location,'location flag')===0?targetId:p.area(actor).id;return 1;
}
