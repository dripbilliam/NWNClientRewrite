import {intEntry} from './combat_stats.js';
import {itemProperties} from './combat_on_hit.js';
import {itemArmorClass} from './combat_modifiers.js';
import {nativeFloatEntry} from './movement_rate.js';
const f=Math.fround,cvtt=n=>Number.isFinite(n)&&n>=-2147483648&&n<2147483648?Math.trunc(n):-2147483648;
const required=(p,n)=>{if(typeof p[n]!=='function')throw new Error(`Native weight provider ${n} is unavailable`);return p[n];};
const integer=(n,label)=>{if(!Number.isInteger(n))throw new Error(`Native weight ${label} is unavailable`);return n|0;};

// ComputeWeight140466660..140466902. Cached unit mass in tenth pounds;
// only passive property11 (minimum multiplier) /81 (summed added mass).
export function computeItemUnitWeight(item,rules){
  if(!rules.baseitems)throw new Error('Native weight baseitems table is unavailable');
  const record={data:item.authored,temporaryProperties:item.temporaryProperties},base=integer(item.authored?.BaseItem,'base item');
  const model=intEntry(rules.baseitems,base,'ModelType');if(!model.found)throw new Error('Native weight model type is unavailable');
  if((model.value&255)===3&&!rules.armor)throw new Error('Native armor weight table is unavailable');
  const weight=(model.value&255)===3?intEntry(rules.armor,itemArmorClass(record,rules),'WEIGHT'):intEntry(rules.baseitems,base,'TenthLBS');
  if(!weight.found)throw new Error('Native unit weight table scratch value is unavailable');
  let multiplier=f(1),added=0;
  for(const property of itemProperties(record,false)){
    if((property.PropertyName&65535)===11){
      const table=rules.itemCosts?.get(property.CostTable&255);if(!table)throw new Error('Native reduced weight cost table is unavailable');
      const entry=nativeFloatEntry(table,property.CostValue&65535,'Value');if(entry.found)multiplier=f(Math.min(entry.value,multiplier));
    }else if((property.PropertyName&65535)===81){
      if(!rules.iprp_weightinc)throw new Error('Native increased weight table is unavailable');
      const entry=intEntry(rules.iprp_weightinc,property.CostValue&255,'Value');if(entry.found)added=(added+entry.value)|0;
    }
  }
  item.nativeUnitWeight45c=cvtt(f(f((weight.value+added)|0)*multiplier));return item.nativeUnitWeight45c;
}

// GetWeight1404692e0..140469327. Bags add contents once; ordinary
// items multiply unit weight by stack only when signed stack>1.
export async function getItemWeight(item,p){
  const repository=await required(p,'repository')(item),unit=integer(await required(p,'unitWeight')(item),'cached unit mass');
  if(repository)return ((await required(p,'contents')(repository))+unit)|0;
  const stack=integer(await required(p,'stack')(item),'stack');return stack>1?Math.imul(unit,stack):unit;
}

// CItemRepository::CalculateContentsWeight140465310. Owner property32
// chooses the FIRST active/passive property and fixed active cost-table15.
// Apply reduction separately to each child with FLOAT subtraction then CVTT;
// nested container contents are queried twice in that native branch.
export async function calculateContentsWeight(repo,p,ancestors=new Set()){
  if(!repo)throw new Error('Native contents weight repository is unavailable');
  if(ancestors.has(repo))throw new Error('Native contents weight container cycle is unavailable');
  const path=new Set(ancestors);path.add(repo);let total=0;
  for(let node=required(p,'first')(repo);node;){
    const id=required(p,'nodeId')(node),item=id===null?null:required(p,'item')(id);
    if(!item){required(p,'warning')('CalculateContentsWeight: pItem');node=required(p,'next')(repo,node);continue;}
    const owner=required(p,'item')(integer(repo.ownerId,'repository owner')>>>0),property=owner?required(p,'weightReduction')(owner):null;
    const nested=required(p,'repository')(item),unit=integer(required(p,'unitWeight')(item),'cached unit mass'),stack=integer(required(p,'stack')(item),'stack');
    let weight;
    if(property){
      const reduction=f(await required(p,'reductionValue')(integer(property.costValue,'reduction row')&65535));
      let first,second;
      if(nested){first=((await required(p,'contents')(nested,path))+unit)|0;second=((await required(p,'contents')(nested,path))+unit)|0;}
      else first=second=stack>1?Math.imul(unit,stack):unit;
      weight=cvtt(f(f(first)-f(f(second)*reduction)));
    }else weight=nested?((await required(p,'contents')(nested,path))+unit)|0:stack>1?Math.imul(unit,stack):unit;
    node=required(p,'next')(repo,node);total=(total+weight)|0;
  }
  return total;
}

// UpdateEncumbranceState1403db1e0..1403db49f. Client/master lookup
// precedes thresholds; non-PC/non-henchman only refresh dirty total mass.
export async function updateEncumbrance(actor,feedback,rules,p){
  const pc=integer(await required(p,'pc')(actor),'PC flag');
  if(pc===0&&((actor.associateType&65535)!==1||(actor.masterId>>>0)===0x7f000000)){
    if(integer(actor.nativeWeightDirty96c,'dirty flag')!==0)actor.nativeTotalWeight978=integer(await required(p,'totalWeight')(actor),'total carried mass');
    return;
  }
  let client=await required(p,'client')(actor.id);if(!client)client=await p.client(actor.masterId);if(!client)return;
  if(!rules.encumbrance)throw new Error('Native encumbrance table is unavailable');
  const strength=integer(await required(p,'strength')(actor),'cached strength')&255;
  const normal=intEntry(rules.encumbrance,strength,'Normal'),heavy=intEntry(rules.encumbrance,strength,'Heavy');
  if(!normal.found||!heavy.found)throw new Error('Native encumbrance threshold scratch values are unavailable');
  actor.nativeTotalWeight978=integer(await required(p,'totalWeight')(actor),'total carried mass');
  const old=integer(actor.nativeEncumbrance970,'previous encumbrance'),state=actor.nativeTotalWeight978>heavy.value?2:Number(actor.nativeTotalWeight978>normal.value);
  actor.nativeEncumbrance970=state;
  if(old!==state)await required(p,'movementRate')(actor);
  if(pc!==0&&feedback!==0&&await required(p,'dm')(actor)===0){
    const send=code=>required(p,'feedback')(actor,code,null,client);
    if(old===0&&state===2){await send(8);await send(9);}
    else if(old===0&&state===1||old===2&&state===1)await send(8);
    else if(old===1&&state===2)await send(9);
  }
}
