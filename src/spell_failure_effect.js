const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell failure effect ${n} is unavailable`);return v|0;};
const call=(p,n,...a)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spell failure effect provider ${n} is unavailable`);return p[n](...a);};
const at=(e,i)=>integer(e.integers?.[i],`integer${i}`),type=e=>integer(e.type,'type')&65535;
const byteSign=n=>(n<<24)>>24;
export function spellFailureEffect(args,creator,p){
  const amount=integer(args[0],'constructor amount'),school=integer(args[1],'constructor school'),kind=args.length>2?integer(args[2],'constructor kind'):0;
  return kind===0?call(p,'create',92,creator,[amount,school],8):kind===1?call(p,'create',25,creator,[amount],8):call(p,'invalid');
}
export function missChanceEffect(amount,kind,creator,p){
  amount=integer(amount,'miss chance');kind=integer(kind,'miss kind');
  return amount>0&&amount<=100?call(p,'create',75,creator,[amount,kind===1?2:kind===2?3:0],8):call(p,'invalid');
}
function dirty(object,p){if(call(p,'asCreature',object))call(p,'asCreature',object).nativeEncumbranceDirty53c=1;}
// SetSpellFailure416ae0 admits only school BYTE0..8. A raw selector such as256
// remains distinct in stacking comparisons, but writes school0 after narrowing.
export function setSpellFailure(actor,school,value){
  school=integer(school,'school')&255;value=integer(value,'cache value')&255;if(school>=9)return;
  if(!Array.isArray(actor.nativeSpellFailuresD7b)||actor.nativeSpellFailuresD7b.length!==9)throw new Error('Native nine-school failure cache is unavailable');actor.nativeSpellFailuresD7b[school]=value;
}
// Complete OnApplySpellFailure433700 / OnApplyArcaneSpellFailure427330.
export async function applySpellFailure(object,effect,p,loading=0){
  if(loading!==0&&object&&call(p,'dead',object)!==0&&![3,4].includes(effect.durationType&7))return 1;
  if(!call(p,'asCreature',object))return 0;
  const actor=call(p,'asCreature',object);if(!effect)return 0;
  if(type(effect)===25){
    dirty(object,p);const total=(at(effect,0)+byteSign(integer(actor.nativeArcaneEffectD78,'arcane cache')))|0;
    actor.nativeArcaneEffectD78=Math.max(-100,Math.min(100,total))&255;await call(p,'updateCombat',actor);return 0;
  }
  let total=at(effect,0);const school=at(effect,1),owner=call(p,'asCreature',object);
  for(const e of call(p,'effects',owner)){const t=type(e);if(t>92)break;if(t===92&&at(e,1)===school)total=(total+at(e,0))|0;}
  setSpellFailure(actor,at(effect,1),Math.max(0,Math.min(100,total)));dirty(object,p);
  const icon=call(p,'copyConstruct',effect,1);icon.type=67;icon.integers[0]=110;await call(p,'apply',object,icon,loading);return 0;
}
// Arcane removal excludes POINTER identity; school failure excludes all records
// sharing the removed uint64 ID. Neither one subtracts from a saturated cache.
export async function removeSpellFailure(object,effect,p,arcane=effect?.type===25){
  if(!call(p,'asCreature',object))return 1;
  const actor=call(p,'asCreature',object);let total=0;
  if(arcane){
    if(effect)for(const e of call(p,'effects',actor)){const t=type(e);if(t>25)break;if(t===25&&e!==effect)total=(total+at(e,0))|0;}
    dirty(object,p);actor.nativeArcaneEffectD78=Math.max(-100,Math.min(100,total))&255;await call(p,'updateCombat',actor);return 1;
  }
  if(!effect)return 1;
  const school=at(effect,1),owner=call(p,'asCreature',object);
  for(const e of call(p,'effects',owner)){const t=type(e);if(t>92)break;if(e.id!==effect.id&&t===92&&at(e,1)===school)total=(total+at(e,0))|0;}
  setSpellFailure(actor,at(effect,1),Math.max(0,Math.min(100,total)));dirty(object,p);return 1;
}
