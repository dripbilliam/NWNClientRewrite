const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native effect icon ${n} is unavailable`);return v|0;};
const list=o=>{const p=o.nativeEffectIcons778;if(!p||!Array.isArray(p.records)||!Number.isInteger(p.capacity)||p.capacity<p.records.length)throw new Error('Native effect icon list is unavailable');return p;};
// OnApplyEffectIcon14042d010. One record per matching raw INT→WORD icon,
// retention flag uses duration!=EQUIPPED3. Reset integer1 on admitted apply.
export function applyEffectIcon(actor,effect){
  if(actor?.objectType!==5||((integer(effect.durationType,'duration type')&7)!==3&&integer(effect.showIcon,'visibility')===0))return 1;
  effect.integers[1]=0;const id=integer(effect.integers[0],'ID'),permanent=Number((effect.durationType&7)!==3),pool=list(actor);
  const existing=pool.records.find(r=>r.iconId===id);
  if(existing){existing.state=0;if(existing.permanent===0&&permanent!==0)existing.permanent=1;return 0;}
  if(pool.records.length===pool.capacity)pool.capacity=pool.capacity===0?16:Math.imul(pool.capacity,2);
  pool.records.push({iconId:id&65535,state:0,permanent});
  if(id===20)actor.nativeFlag8b0=1;else if(id===21)actor.nativeFlag8b4=1;return 0;
}
// OnRemoveEffectIcon140436940 scans remaining type67 records before erase;
// counters combine with AND, permanency with OR. Pool search runs backwards.
export function removeEffectIcon(actor,effect){
  if(actor?.objectType!==5)return 1;
  const id=integer(effect.integers?.[0],'ID'),pool=list(actor);let found=false,state=1,permanent=0;
  for(const e of actor.effects){const type=integer(e.type,'effect type')&65535;if(type>67)break;
    if(type!==67||e===effect||integer(e.integers?.[0],'remaining ID')!==id)continue;
    found=true;state&=integer(e.integers?.[1],'remaining state');permanent|=Number((integer(e.durationType,'remaining duration')&7)!==3);
  }
  for(let i=pool.records.length-1;i>=0;i--)if(pool.records[i].iconId===id){
    if(found){pool.records[i].state=state;pool.records[i].permanent=permanent;}
    else{pool.records.splice(i,1);if(id===20)actor.nativeFlag8b0=0;else if(id===21)actor.nativeFlag8b4=0;}
    break;
  }
  return 1;
}
