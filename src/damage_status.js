const call=(p,n,...a)=>{if(typeof p[n]!=='function')throw new Error(`Native damage status provider ${n} is unavailable`);return p[n](...a);};
const integer=(e,i)=>{const n=e.integers?.[i]??0;if(!Number.isInteger(n))throw new Error('Native damage status effect integer is unavailable');return n|0;};
// RemoveCharmEffectsByFactionID14039e0d0..14039e2d6. Scan the live list,
// apply source reputation immediately, then remove collected IDs in order.
export async function removeCharmEffectsByFaction(actor,faction,adjustment,p){
 if(!call(p,'arrayAvailable'))return 0;const ids=[];
 for(let i=0;i<actor.effects.length;i++){
  const e=actor.effects[i];if((e.type&65535)!==8||(e.durationType&7)!==1||![1,7].includes(integer(e,0)))continue;
  const object=call(p,'object',e.creatorId>>>0),source=object?call(p,'creature',object):null;if(!source||(call(p,'faction',source)|0)!==(faction|0))continue;
  if((adjustment|0)!==0)await call(p,'reputation',source,actor.id>>>0,adjustment|0,1,Math.fround(180));
  // The native owner has a fixed16-ID stack buffer. Its overflow is undefined;
  // preserve the defined prefix and diagnose rather than corrupting storage.
  if(ids.length===16)throw new Error('Native charm-removal 16-effect stack capacity exceeded');const current=actor.effects[i];if(!current)throw new Error('Native charm list entry became unavailable during reputation mutation');ids.push(current.id);
 }
 for(const id of ids)await call(p,'remove',actor,id);return Number(ids.length>0);
}
// RemoveSleepEffects14039eb90..14039ecab. The list is type sorted; removal
// restarts at zero. A protected sleep gets one damage callback grace, then its
// integer1 marker is cleared in a second scan rather than removing it now.
export async function removeSleepEffects(actor,p){
 let protectedSleep=false;
 for(let index=0;index<actor.effects.length;){
  const e=actor.effects[index];if((e.type&65535)>8)break;
  if((e.type&65535)===8&&integer(e,0)===9){
   if(integer(e,1)===1){protectedSleep=true;index++;}
   else{await call(p,'remove',actor,e.id);if(actor.effects.includes(e))throw new Error('Native sleep removal did not remove its live effect');index=0;}
  }else index++;
 }
 if(protectedSleep)for(let index=0;index<actor.effects.length;index++){const e=actor.effects[index];if((e.type&65535)>8)return;if((e.type&65535)===8&&integer(e,0)===9&&integer(e,1)===1)e.integers[1]=0;}
}
