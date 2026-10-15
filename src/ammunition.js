import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native ammunition ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native ammunition provider ${n} is unavailable`);return p[n];};
// These are exact original base-item branches, independent of the 2DA row's
// RangedWeapon flag. Custom row attributes do not change native dispatch.
const classification=base=>[8,11].includes(base)?{slot:2048,base:20}:[6,7].includes(base)?{slot:8192,base:25}:
  base===61?{slot:4096,base:27}:[59,63,31].includes(base)?{slot:16,base}:null;

// GetAmmunitionAvailable1403e3070..1403e3739. Missing automatic equip
// side-effect owners are required providers, not an invented slot assignment.
export async function ammunitionAvailable(actor,requested,p){
  requested=integer(requested,'requested count');
  const weapon=await required(p,'equippedItem')(actor,16);
  if(!weapon)throw new Error('Native ammunition availability called without the required right-hand item');
  if(integer(await required(p,'propertyExists')(weapon,61,0),'unlimited property')!==0)return requested;
  const base=integer(await required(p,'baseItem')(weapon),'base item'),kind=classification(base);
  let available=0;
  if(kind){const item=kind.slot===16?weapon:await p.equippedItem(actor,kind.slot);
    if(item)available=integer(await required(p,'stack')(item),'equipped stack');}
  if(available===0&&kind){
    const slot={value:kind.slot};let index=0;
    for(;;){
      const id=integer(await required(p,'inventoryItemByBase')(actor,kind.base,index),'repository item ID')>>>0;
      if(id===OBJECT_INVALID)break;
      const item=await required(p,'item')(id);if(!item)throw new Error('Native ammunition repository contains an unavailable item');
      if((integer(await required(p,'canEquip')(actor,item,slot,1,0,0,null),'equip eligibility')&255)===1){
        await required(p,'removeRepository')(actor,item,1);
        if((integer(await required(p,'possessor')(item),'item possessor')>>>0)!==(actor.id>>>0))
          await required(p,'setPossessor')(item,actor.id,0,0,0);
        await required(p,'equip')(actor,slot.value,item,1,0,1);
        available=integer(await p.stack(item),'newly equipped stack');break;
      }
      index=(index+1)|0;if(index<0)throw new Error('Native ammunition repository index wraps beyond supported bounds');
    }
  }
  if(available>0&&available<integer(await required(p,'rulesetInt')('AMMUNITION_WARNING_LIMIT',20),'warning limit')){
    const previous=integer(actor.nativeField744,'previous warning count');
    const decrement=integer(await p.rulesetInt('AMMUNITION_WARNING_DECREMENT',5),'warning decrement');
    if(previous>=((available+decrement)|0)){
      actor.nativeField744=available;await required(p,'feedback')(actor,24,{type:0,integers:[available]});
    }
  }
  if(available>requested)return requested;
  if(available===0){
    if(integer(await required(p,'pc')(actor),'PC flag')!==0||integer(await required(p,'possessed')(actor),'possessed familiar')!==0)
      await required(p,'feedback')(actor,25,null);
    else{
      const master=integer(actor.masterId,'master ID')>>>0;
      if(master!==OBJECT_INVALID){const owner=await required(p,'creature')(master);if(owner)await required(p,'feedback')(owner,241,{type:0,objects:[actor.id]});}
    }
  }
  return available;
}

// ResolveAmmunition1403e3b30..1403e3c5d. Capture AI before equipment and
// perform the native (otherwise unused) base-item allocation lookup. Consumption
// is delayed event16 on the captured ITEM, not an immediate stack subtraction.
export async function resolveAmmunition(actor,delay,p){
  delay=integer(delay,'release delay')>>>0;
  const ai=await required(p,'aiMaster')(),weapon=await required(p,'equippedItem')(actor,16);if(!weapon)return;
  const base=integer(await required(p,'baseItem')(weapon),'release base item');await required(p,'baseItemInfo')(base);
  const kind=classification(base);let item=weapon;
  if(kind&&kind.slot!==16){
    if(integer(await required(p,'propertyExists')(weapon,61,0),'release unlimited property')!==0)return;
    item=await p.equippedItem(actor,kind.slot);if(!item)return;
  }
  await required(p,'enqueue')(ai,16,actor.id,item.id,delay,null);
}

// Item EventHandler event16,140467b87..140467c1d. Last units enqueue
// event11; they are not immediately removed or assigned a zero stack.
// Capture possessor BEFORE stack read/queue, then update equipment weight.
export async function consumeAmmunition(item,p){
  const possessor=await required(p,'creature')(integer(await required(p,'possessor')(item),'consume possessor')>>>0);
  const stack=integer(await required(p,'stack')(item),'consume stack');
  if(stack>1)await required(p,'writeStack')(item,(stack-1)|0);
  else await required(p,'enqueue')(await required(p,'aiMaster')(),11,item.id,item.id,0,null);
  if(!possessor)return;
  if(integer(await required(p,'inEquipment')(possessor,item),'equipment membership')!==0){
    const weight=integer(await required(p,'weight')(item),'unit weight');
    possessor.nativeEquippedWeight968=(integer(possessor.nativeEquippedWeight968,'equipped weight')-weight)|0;
  }
  await required(p,'encumbrance')(possessor,1);
}
