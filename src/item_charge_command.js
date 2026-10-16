const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item charge command ${n} is unavailable`);return v|0;};
// ExecuteCommandGetItemCharges1405281d0 returns raw INT388, or zero when
// the canonical lookup is not an item. Stack pop/push belong to the VM.
export function getScriptItemCharges(id,p){const item=p.item(integer(id,'item ID')>>>0);return item?integer(item.charges,'charges'):0;}
// ExecuteCommandSetItemCharges140542250. Depleted nonplot items are queued
// for immediate event11 WITHOUT first rewriting their charges/readiness.
export async function setScriptItemCharges(id,value,self,p){
 const item=p.item(integer(id,'item ID')>>>0);if(!item)return 0;
 value=Math.max(0,Math.min(250,integer(value,'charge value')));
 if(integer(item.plot,'plot flag')===0&&value<=0){await p.enqueue(11,integer(self,'script self')>>>0,item.id>>>0,0,null);return 0;}
 await p.setCharges(item,value,1);await p.activeChanged(item,0);return 0;
}
