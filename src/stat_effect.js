const at=(e,i)=>(e.integers[i]??0)|0;
const i8=n=>(n<<24)>>24;
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native stat effect provider ${n} is unavailable`);return p[n](...args);};
async function icon(actor,effect,id,p,loading){const child=call(p,'copyConstruct',effect,1);child.type=67;child.integers[0]=id;await call(p,'apply',actor,child,loading);}
// Full registered attack10/11, save26/27 and AC48/49 application owners.
// AC mutates signed BYTE caches after applying the icon. No blanket dead gate:
// the native gate applies only during loading and admits duration types3/4.
export async function applyStatEffect(actor,effect,p,loading=0){
  if(actor.objectType!==5)return 1;
  if(loading!==0&&call(p,'dead',actor)!==0&&![3,4].includes(effect.durationType&7))return 1;
  const ac=[48,49].includes(effect.type),down=[11,27,49].includes(effect.type),amount=at(effect,ac?1:0);
  if(down&&effect.type!==11){
    const source=call(p,'creature',effect.creatorId>>>0);
    if(effect.bypassImmunity===0&&await call(p,'immunity',actor,effect.type===49?23:25,source,1)!==0)return 1;
  }
  if(amount<1||down&&call(p,'plot',actor)!==0)return 1;
  if(effect.type===11){const source=call(p,'creature',effect.creatorId>>>0);if(effect.bypassImmunity===0&&await call(p,'immunity',actor,20,source,1)!==0)return 1;}
  if(!ac)actor.combatInformationDirty=1;
  const id=ac?(down?36:35):[10,11].includes(effect.type)?(down?30:29):down?40:({1:103,2:102,3:104}[at(effect,1)]??39);
  await icon(actor,effect,id,p,loading);
  if(ac&&at(effect,2)===28&&at(effect,3)===0&&at(effect,4)===0&&at(effect,5)===4103){
    const category=at(effect,0),cache=call(p,'armorCache',actor)[down?'down':'up'];
    if(category===0)cache[0]=i8(cache[0]+amount);
    else if(category>=1&&category<=4){
      if(!down&&i8(cache[category])>0)await call(p,'feedback',actor,188+category,null);
      if(i8(cache[category])<amount)cache[category]=i8(amount);
    }
  }
  return 0;
}
// Removal occurs BEFORE erase. Both AC signs start at the shared first48/49
// WORD index; a leading opposite sign therefore stops the native scan.
// Decrease intentionally omits the parent damage gate and candidate alignment
// gates that the increase owner tests. Preserve those original differences.
export function removeStatEffect(actor,effect,p){
  if(actor.objectType!==5)return 1;
  if(![48,49].includes(effect.type)){actor.combatInformationDirty=1;return 1;}
  const down=effect.type===49;
  if(at(effect,2)!==28||at(effect,3)!==0||at(effect,4)!==0||!down&&at(effect,5)!==4103)return 1;
  const category=at(effect,0),cache=call(p,'armorCache',actor)[down?'down':'up'];
  if(category===0){cache[0]=i8(cache[0]-at(effect,1));return 1;}
  const effects=call(p,'effects',actor),first=effects.findIndex(e=>e.type===48||e.type===49);let maximum=0;
  if(first>=0)for(let i=first&65535;i<effects.length;i++){
    const e=effects[i];if(e.type!==effect.type)break;
    if(e!==effect&&at(e,0)===category&&at(e,2)===28&&at(e,5)===4103&&(down||at(e,3)===0&&at(e,4)===0)&&maximum<at(e,1))maximum=at(e,1);
  }
  if(category>=1&&category<=4)cache[category]=i8(maximum);
  return 1;
}
