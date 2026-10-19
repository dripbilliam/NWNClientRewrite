// G/Q client7b4390. The leading quickbar index/type bytes are read and ignored
// by the original receiver; they never assign a button. Item IDs remain in the
// client namespace. Stack/property counters are authoritative server values.
export function readQuickbarItemUses(r){
 const count=r.readByte();if(count>Math.floor((r.byteSize40-r.byteCursor44)/9))throw new Error('Invalid native quickbar item-use count');
 const entries=[];for(let i=0;i<count;i++)entries.push({index:r.readByte(),type:r.readByte(),id:r.readObjectIdClient(),propertyIndex:r.readByte(),count:r.readWord()});
 return{action:'item-use-counts',entries};
}

// Client83d580/83ef60/83f190. This is replicated UI/item state, not the server
// item-charge/cache functions. A daily/charge use WORD is not a stack size.
export function applyClientItemUses(item,entry){
 const index=entry.propertyIndex&255,property=item.properties?.[index],count=entry.count&65535;
 if(!property||property.costValue===1||property.type===80||property.type===55){item.stackSize=count;item.field454=count;return'stack';}
 return applyClientPropertyUses(item,index,count);
}
// The active-item reader76bd30 calls this setter directly, regardless of the
// property cost. Unchanged counter bits leave the existing WORDs untouched.
export function applyClientPropertyUses(item,index,count){
 if(index>=8)return'ignored';
 item.propertyUses??=Array.from({length:8},(_,i)=>item.field351?.[i]??0);item.propertyUses[index]=count;
 if(item.selectedProperty===undefined)item.selectedProperty=item.properties.findIndex(p=>p.type===15);
 if(index===item.selectedProperty&&count===0){const next=item.properties.findIndex((p,i)=>i<8&&p.type===15&&item.propertyUses[i]!==0);item.selectedProperty=next<0?255:next;}
 return'property';
}

export function mergeNetworkItem(previous,incoming){
 const item={...previous,...structuredClone(incoming)};
 if(Object.hasOwn(incoming,'field454'))item.stackSize=incoming.field454;
 if(!incoming.field351)return item;
 item.propertyUses=Array.from({length:8},(_,i)=>previous?.propertyUses?.[i]??previous?.field351?.[i]??0);
 item.selectedProperty=previous?.selectedProperty??255;
 for(const [i,p]of (item.properties??[]).entries()){
  if(p.type===15&&item.selectedProperty===255)item.selectedProperty=i;
  p.remaining=1;
 }
 for(let i=0;i<8;i++)if(incoming.reserved&(1<<i)){
  applyClientPropertyUses(item,i,incoming.field351[i]);
  if(item.properties?.[i])item.properties[i].remaining=Number(Boolean(incoming.field350&(1<<i)));
 }
 return item;
}
