import {rulesetInt} from './combat_stats.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native damaged casting ${n} is unavailable`);return v|0;};
const call=(p,n,...a)=>{if(typeof p[n]!=='function')throw new Error(`Native damaged casting provider ${n} is unavailable`);return p[n](...a);};
// OnApplyDamage140428e6c..140429188, after DoDamage and before history,
// shield reflection and OnDamaged. The native check uses base spell level,
// without adding metamagic or domain level, and consumes with meta/domain0.
export async function checkDamagedCasting(o,creator,amount,rules,p,loading=0){
 if(![15,16].includes(o.animationState))return;
 const spell=call(p,'spell',o.nativeSpellId218);if(!spell||spell.useConcentration!==1)return;
 const roll=integer(await call(p,'roll',1,20),'roll')&65535,rank=(integer(await call(p,'skill',o,1,creator,0),'rank')<<24)>>24,index=o.nativeSpellClass22c&255;
 let level=spell.innate&255;
 if(index!==255){level=call(p,'level',o,spell.id,index)&255;if(level===255){const master=call(p,'spell',spell.master);if(master)level=call(p,'level',o,master.id,index)&255;if(level===255)level=spell.innate&255;}}
 const dc=Math.max(1,(level+rulesetInt(rules,'CONCENTRATION_BASE_DC',10)+integer(amount,'damage'))|0),success=((rank+roll)|0)>=dc;
 if(!success){
  await call(p,'deleteCurrent',o);await call(p,'animation',o,14);
  await call(p,'consume',o,o.nativeSpellId218,o.nativeSpellClass22c&255,0,0,255);await call(p,'feedback',o,72);
  const visual=call(p,'create',30,o.id,[(spell.conjureAnimation&65535)===2?292:293]);visual.durationType=0;await call(p,'apply',o,visual,loading);
 }
 await call(p,'message',o,{objects:{0:o.id>>>0},integers:{0:270,1:roll,2:rank>>>0,3:dc>>>0,4:0,5:Number(success)}});
}
