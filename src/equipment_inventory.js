import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native equipment ${name} is unavailable`);return v|0;};

// CNWSInventory1404627f0, GetArraySlotFromSlotFlag1404629b0. Exactly
// one of18 slot flags is accepted; combined masks are not a priority scan.
export class EquipmentInventory {
  constructor(warning){this.ids=Array(18).fill(OBJECT_INVALID);this.warning=warning;}
  index(flag){
    flag=integer(flag,'slot flag')>>>0;
    for(let i=0;i<18;i++)if(flag===(1<<i))return i;
    if(typeof this.warning!=='function')throw new Error('Native equipment invalid-slot warning is unavailable');
    this.warning('Invalid equipment slot flag');return 18;
  }
  // GetItemInSlot140462bd0 uses canonical lookup; stored stale IDs remain
  // stored while a query returns null. No alternate character/item IDs.
  get(flag,itemById){const index=this.index(flag);return index<18?itemById(this.ids[index])??null:null;}
  put(flag,item){const index=this.index(flag);if(index<18)this.ids[index]=integer(item?.id,'item ID')>>>0;}
  contains(item){
    if(!item){if(typeof this.warning!=='function')throw new Error('Native equipment null-item warning is unavailable');this.warning('Null equipment item');return 0;}
    return Number(this.ids.includes(integer(item.id,'item ID')>>>0));
  }
  slot(item){const index=this.ids.indexOf(integer(item?.id,'item ID')>>>0);return index<0?0:1<<index;}
  // RemoveItem140462c80 clears only the first matching physical slot.
  remove(item){const index=this.ids.indexOf(integer(item?.id,'item ID')>>>0);if(index<0)return 0;this.ids[index]=OBJECT_INVALID;return 1;}
}
