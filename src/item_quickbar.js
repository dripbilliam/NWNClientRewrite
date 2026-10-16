import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item quickbar ${n} is unavailable`);return v|0;};
const shield=base=>[14,15,56,57].includes(base|0);

// Client GetRelativeWeaponSize1408012d0: unlike the server owner this does
// not clamp differences to -10. The table helper's status is not tested.
export function clientRelativeWeaponSize(actor,item,p){
 if(item.baseItem===111)return 0;
 const size=integer(p.sizeCategory(actor).value,'appearance size'),base=p.baseInfo(item);
 if(!base)throw new Error('Native client relative weapon size dereferences missing base storage');
 return((integer(base.weaponSize,'weapon size')&255)-size)|0;
}

// Client wield classification1407fdb10; result is AL, not the whole RAX.
export function clientItemWield(actor,item,p){
 const base=p.baseInfo(item);if(!base)return 0;
 if(item.baseItem===57){const size=p.sizeCategory(actor);return size.status===0?0:Number(integer(size.value,'appearance size')>=3);}
 if([14,15,56].includes(item.baseItem))return 1;
 if((integer(base.weaponType,'weapon type')&255)===0)return 0;
 const relative=clientRelativeWeaponSize(actor,item,p);
 if((integer(base.weaponWield,'weapon wield')&255)!==0)return [6,7,8,11].includes(item.baseItem)?0:2;
 return Number(((relative+2)>>>0)<=2);
}

// Quickbar count updater14086bef0. Omitted callbacks are intentional: some
// properties leave the previous count/enabled state alone. GUI clear owns the
// initial empty count/enabled state. Low WORD display differs from INT test.
export function updateItemQuickbarCount(button,p){
 const item=p.item(button.itemId);if(!item)return;
 const base=p.baseInfo(item);if(!base)return;
 const index=button.intParam&65535,property=p.property(item,index);
 const stack=()=>{p.text(button,String(integer(item.stackSize,'stack size')&65535));p.enable(button,Number(item.stackSize>0));};
 if(!property){if((integer(base.stacking,'maximum stack')&65535)>1)stack();return;}
 const type=property.type&65535;
 if(type===15){
  const cost=property.costValue&65535;
  if(cost===7||cost===13){p.text(button,'*');return;}
  if(cost!==1){const uses=index<8?integer(p.cachedUses(item,index),'cached uses')&65535:0;p.text(button,String(uses));p.enable(button,Number(uses!==0));return;}
  const currentBase=p.baseInfo(item);if(!currentBase)return;
  if(currentBase.equipableSlots!==0&&(currentBase.stacking&65535)<2){p.text(button,'');p.enable(button,1);return;}
  stack();return;
 }
 if([55,70,80].includes(type))stack();
}

// Configure item button140867760. Client registry, cached CanUseItem flag,
// owned icons, clear/count/animation/widget notification are explicit lower
// boundaries. Does not serialize GUI pointer layout into creature QBList.
export function configureItemQuickbar(button,id,packed,force,p){
 id=integer(id,'item ID')>>>0;packed=integer(packed,'packed property');force=integer(force,'force');
 const actor=p.controlled();if(!actor)return false;
 let item=p.item(id);if(!item)return false;
 if(integer(item.identified,'identified flag')===0){p.feedback(97);return false;}
 const base=p.baseInfo(item);
 if(!base||force===0&&integer(p.canUse(item),'client CanUseItem flag')===0||base.container===0&&base.equipableSlots===0&&item.activeProperties.length<1){p.feedback(23);return false;}
 let paired=false;
 if(button.type===1&&button.secondaryItemId===OBJECT_INVALID&&(button.intParam&65535)===255&&(packed&255)===255&&id!==button.itemId){
  const previous=p.item(button.itemId);
  if(previous){
   const oldBase=p.baseInfo(previous);if(!oldBase)return false;
   const oldWield=p.wield(actor,previous)&255;
   if(oldWield!==0){
    const newWield=p.wield(actor,item)&255;
    if(newWield!==0&&(oldWield===2?newWield!==2&&shield(item.baseItem):newWield!==2||shield(previous.baseItem))){
     const normal=(oldBase.equipableSlots&16)!==0&&(base.equipableSlots&32)!==0,
      swapped=!normal&&(oldBase.equipableSlots&32)!==0&&(base.equipableSlots&16)!==0;
     if(normal||swapped){
      button.secondaryItemId=swapped?button.itemId:id;if(swapped)button.itemId=id;
      item=p.item(button.itemId);const second=p.item(button.secondaryItemId);
      if(item&&second){p.destroyIcon(button);p.icons(button,p.itemIcon(item),p.itemIcon(second));}
      paired=true;
     }
    }
   }
  }
 }
 if(!paired){
  p.clear(button);Object.assign(button,{type:1,itemId:id,secondaryItemId:OBJECT_INVALID,intParam:packed});
  if((packed&255)===255){
   if((((integer(base.qbBehaviour,'QBBehaviour')&255)-1)&255)<=1){
    for(let i=0;i<item.activeProperties.length;i++){
     const spellId=p.propertySpell(item,i);if((spellId|0)===-1)continue;
     const spell=p.spell(spellId>>>0);if(!spell)continue;
     button.intParam=(i|((spell.children.length&255)>0?0:0xff0000))|0;break;
    }
   }else if(base.equipableSlots===0&&item.activeProperties.length>0)button.intParam=0xff0000;
  }
  const index=button.intParam&255,variant=(button.intParam>>>16)&255;
  let spell=p.spell(p.propertySpell(item,index)>>>0);
  if(spell&&variant!==255&&(spell.children.length&255)>0)spell=p.spell(p.subRadialSpell(spell,variant)>>>0);
  if(!spell||[49,54,75,104].includes(item.baseItem))p.icons(button,p.itemIcon(item),null);
  else{const icon=p.createSpellIcon(spell);try{p.icons(button,icon,p.itemIcon(item));}finally{p.releaseSpellIcon(icon);}}
  p.refreshCount(button);
 }
 let animation=null;
 if(p.equippedOwner(item)&&p.equippedOwner(item).id===p.controlledId()){
  const second=p.item(button.secondaryItemId);
  if(!second||p.equippedOwner(second)&&p.equippedOwner(second).id===p.controlledId())animation='qbEquip';
 }
 p.animation(button,animation);p.notify(button);return true;
}
