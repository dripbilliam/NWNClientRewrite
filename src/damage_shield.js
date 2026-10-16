import {highestDamageTypeFlag} from './damage_effect.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native damage-shield ${n} is unavailable`);return v|0;};
const call=(p,n,...a)=>{if(typeof p[n]!=='function')throw new Error(`Native damage-shield provider ${n} is unavailable`);return p[n](...a);};
// ExecuteCommandEffectDamageShield140519760. The die value is a physical
// IPRP_DAMAGECOST row, not a number of sides or a spell-specific roll.
export function damageShieldIntegers(base,die,flags,damageTypeCount){
 base=integer(base,'base');die=integer(die,'dice row');flags=integer(flags,'damage flags');
 if((base>>>0)>10000)base=1;if(flags<0||(flags>>>0)>highestDamageTypeFlag(damageTypeCount))flags=8;return[base,die,flags];
}
// OnApplyDamageShield14042a4c0; shared-ID icon49 and no creature-only gate.
export async function applyDamageShield(o,e,p,loading=0){
 if(loading!==0&&call(p,'dead',o)!==0&&![3,4].includes(e.durationType&7))return 1;
 const icon=call(p,'copyConstruct',e,1);icon.type=67;icon.integers[0]=49;await call(p,'apply',o,icon,loading);return 0;
}
// ResolveDamageShields1403e4c50 reads the live sorted effect array after each
// recursively applied damage/visual pair. Its damage is unprocessed, so it
// cannot trigger another shield under OnApplyDamage's processed-only gate.
export async function resolveDamageShields(o,attacker,p){
 if(!attacker)return;
 for(let index=0;index<call(p,'effects',o).length;index++){
  const e=call(p,'effects',o)[index];if(e.type>61)break;if(e.type!==61)continue;
  const [base,row,flags]=e.integers.map((v,i)=>integer(v,`integer${i}`)),count=integer(call(p,'dice',row,'NumDice'),'dice count'),sides=integer(call(p,'dice',row,'Die'),'die');
  const amount=((count!==0?(integer(await call(p,'roll',count&255,sides&255),'roll')&65535):sides)+base)|0;
  const damageIndex=flags>1?31-Math.clz32(flags):0,visualId=integer(call(p,'visual',damageIndex),'visual ID');
  const ints=Array(39).fill(0);ints.fill(-1,0,32);ints[damageIndex]=amount;ints[33]=1000;ints[34]=flags;
  const damage=call(p,'create',38,o.id,ints);damage.durationType=0;await call(p,'apply',attacker,damage,0);
  const visual=call(p,'create',30,o.id,[visualId]);visual.durationType=0;await call(p,'apply',attacker,visual,0);
 }
}
