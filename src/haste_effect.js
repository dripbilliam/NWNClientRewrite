import {rulesetInt} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native haste effect ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native haste effect provider ${n} is unavailable`);return p[n](...args);};
const clamp=n=>Math.max(-1,Math.min(1,n));
function balance(rows){let n=0;for(const e of rows){const type=integer(e.type,'stored type')&65535;if(type===1)n=(n+1)|0;else if(type===3)n=(n-1)|0;else if(type>3)break;}return n;}
async function transition(actor,effect,p,removing,loading){
  const rows=call(p,'effects',actor),count=balance(rows),before=clamp(count),after=clamp((count+(effect.type===1?removing?-1:1:removing?1:-1))|0);
  if(before===after)return;
  if(before!==0){const type=before>0?41:42;for(const e of rows){if(e.type>type)break;if(e.type===type){await call(p,'remove',actor,e);break;}}return;}
  const controller=call(p,'create',after>0?41:42,0x7f000000,[],8);controller.durationType=4;controller.exposed=false;controller.showIcon=integer(effect.showIcon,'icon visibility');
  if(!removing)controller.spellId=integer(effect.spellId,'spell'); // removal's native constructor keeps-1.
  await call(p,'apply',actor,controller,removing?0:loading);
}
// OnApplyHasteOrSlow14042dba0, before sorted insertion. Slow alone checks
// immunity9, emitting source then victim146. Top effects and hidden controllers
// have distinct IDs, so balancing/removal must run before erasing the top record.
export async function applyHasteOrSlow(actor,effect,p,loading=0){
  if(loading!==0&&actor&&call(p,'dead',actor)!==0&&! [3,4].includes(effect.durationType&7))return 1;
  if(actor.objectType!==5)return 0;
  const source=call(p,'creature',integer(effect.creatorId,'creator')>>>0);
  if(effect.type!==1&&integer(effect.bypassImmunity,'immunity override')===0&&await call(p,'immunity',actor,9,source,1)!==0){
    const data={objectIds:[actor.id>>>0]};if(source)await call(p,'feedback',source,146,structuredClone(data));await call(p,'feedback',actor,146,data);return 1;
  }
  await transition(actor,effect,p,false,loading);return 0;
}
export async function removeHasteOrSlow(actor,effect,p){if(actor.objectType===5)await transition(actor,effect,p,true,0);return 1;}
async function child(actor,parent,type,values,copyIcons,p,loading){
  const effect=call(p,'copyConstruct',parent,copyIcons);effect.type=type;for(const [index,value] of values)effect.integers[index]=value|0;
  await call(p,'apply',actor,effect,loading);
}
// OnApplyHasteInternal14042d950 and OnApplySlowInternal1404333c0.
// Copies retain controller ID; non-icon copies hide icon visibility. Active
// HASTE_* parameters supplement the otherwise native fixed Slow data.
export async function applyHasteController(actor,effect,rules,p,loading=0){
  if(actor.objectType!==5)return 0;
  if(effect.type===41){
    if(rulesetInt(rules,'HASTE_MOVEMENT_SPEED_INCREASE_BONUS',150)>100)await child(actor,effect,28,[[0,rulesetInt(rules,'HASTE_MOVEMENT_SPEED_INCREASE_BONUS',150)]],0,p,loading);
    if(rulesetInt(rules,'HASTE_DODGE_AC_INCREASE_AMOUNT',4)>0)await child(actor,effect,48,[[0,0],[1,rulesetInt(rules,'HASTE_DODGE_AC_INCREASE_AMOUNT',4)],[2,28],[5,4103]],0,p,loading);
    actor.nativeHaste760=1;actor.nativeSlow764=0;
    await child(actor,effect,67,[[0,25]],1,p,loading);
  }else{
    await child(actor,effect,29,[[0,50]],0,p,loading);
    await child(actor,effect,49,[[0,0],[1,2],[2,28],[5,4103]],0,p,loading);
    await child(actor,effect,11,[[0,2],[1,0],[2,28]],0,p,loading);
    await child(actor,effect,27,[[0,2],[1,2],[3,28]],0,p,loading);
    await child(actor,effect,59,[[0,0]],0,p,loading);
    actor.nativeHaste760=0;actor.nativeSlow764=1;
    await child(actor,effect,67,[[0,26]],1,p,loading);
  }
  return 0;
}
export function removeHasteController(actor,effect){if(actor.objectType===5)actor[effect.type===41?'nativeHaste760':'nativeSlow764']=0;return 1;}
