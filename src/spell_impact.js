import {OBJECT_INVALID} from './game_object_array.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native spell impact ${n} is unavailable`);return v|0;};
const call=(p,n,...args)=>{if(typeof p?.[n]!=='function')throw new Error(`Native spell impact provider ${n} is unavailable`);return p[n](...args);};
const vector=(v,n)=>{if(!Array.isArray(v)||v.length!==3||!v.every(Number.isFinite))throw new Error(`Native spell impact ${n} vector is unavailable`);return v.map(Math.fround);};

// Creature EventHandler14038edb0..14038f06d, event8 and item-on-hit19.
// The latter restores the interrupted current context; ordinary8 retains it.
// A payload is owned by this event, while target IDs resolve at dispatch time.
export async function receiveCreatureSpellImpact(actor,eventId,callerId,data,p){
  eventId=integer(eventId,'event ID')>>>0;if(eventId!==8&&eventId!==19)throw new Error('Native spell impact event is unavailable');
  if(!data||integer(data.casterId,'payload caster')>>>0!==(callerId>>>0))return;
  const saved=eventId===19?{nativeSpellId218:actor.nativeSpellId218,nativeSpellTarget214:actor.nativeSpellTarget214,
    nativeSpellPoint208:vector(actor.nativeSpellPoint208,'saved target'),nativeSpellTarget818:actor.nativeSpellTarget818,
    nativeSpellFeat23c:actor.nativeSpellFeat23c,nativeCasterOverride820:actor.nativeCasterOverride820,nativeCasterOverride824:actor.nativeCasterOverride824}:null;
  actor.nativeSpellId218=integer(data.spellId,'payload spell');actor.nativeSpellTarget214=integer(data.targetId,'payload target')>>>0;
  actor.nativeSpellPoint208=vector(data.position,'payload target');actor.nativeSpellTarget818=integer(data.itemId,'payload item')>>>0;
  actor.nativeSpellFeat23c=integer(data.featId,'payload feat')&65535;
  if(actor.nativeSpellTarget214!==OBJECT_INVALID){
    const target=call(p,'object',actor.nativeSpellTarget214);
    if(target&&(integer(target.objectType,'target type')&255)>4&&call(p,'area',target)===call(p,'area',actor))actor.nativeSpellPoint208=vector(call(p,'position',target),'resolved target');
  }
  await call(p,'setEffectSpell',actor,actor.nativeSpellId218);actor.lastSpellId=actor.nativeSpellId218;
  try{
    if(eventId===19){actor.nativeCasterOverride820=1;actor.nativeCasterOverride824=integer(data.casterLevel,'item caster level');await call(p,'projectileTime',actor,0);}
    await call(p,'runScript',data.script,actor.id,1,0);
  }finally{
    await call(p,'setEffectSpell',actor,-1);actor.lastSpellId=-1;actor.nativeCasterOverride820=0;actor.nativeCasterOverride824=-1;
    if(saved)Object.assign(actor,saved);
  }
}
