import {rulesetInt} from './combat_stats.js';
import {serverObjectIdForClient} from './client_projectile_message.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native client cast ${n} is unavailable`);return v|0;};
export const hasClientCastFields=animation=>{const short=(animation<<16)>>16;return((short-15)&65535)<6||short===61;};

// Server creature update4ebfec..4ec1b0: the sound flag starts with metamagic
// bit16 and then checks Automatic Silent with strict level<cap. Unlike cast
// admission this owner adds neither domain level nor metamagic slot cost.
export function clientCastSoundSuppression(actor,rules,p){
 let silent=(integer(actor.nativeSpellMetamagic22d,'metamagic')&255)>>>4&1;
 const spell=p.spell(integer(actor.nativeSpellId218,'spell ID'));if(!spell)return silent;
 const type=()=>integer(p.classType(actor,integer(actor.nativeSpellClass22c,'class index')&255),'class type')&255;
 let level=integer(p.level(spell,type()),'spell level')&255;
 if(level===255){const master=p.spell(integer(spell.master,'master'));if(master)level=integer(p.level(master,type()),'master level')&255;if(level===255)level=integer(spell.innate,'innate')&255;}
 for(const [feat,key,fallback]of [[860,'EPIC_AUTOMATIC_LESSER_SILENT_LEVEL_CAP',4],[861,'EPIC_AUTOMATIC_SILENT_LEVEL_CAP',7],[862,'EPIC_AUTOMATIC_GREATER_SILENT_LEVEL_CAP',10]])if(integer(p.hasFeat(actor,feat),'feat result')!==0&&level<rulesetInt(rules,key,fallback))return 1;
 return silent;
}
export function localClientCastFields(actor,rules,p){
 if(!hasClientCastFields(actor.animationState))return[];
 return[{type:'dword',value:integer(actor.nativeSpellId218,'spell ID')>>>0},{type:'object',value:serverObjectIdForClient(integer(actor.nativeSpellTarget818,'caster item')>>>0)},{type:'bool',value:clientCastSoundSuppression(actor,rules,p)}];
}
// Client incoming update782e68..782ed3. Read/overflow even if the source
// object is absent. A failed guard leaves all three original cells untouched.
export function readClientCastFields(state,animation,p){
 if(!hasClientCastFields(animation))return true;
 const id=p.dword(32)>>>0,item=p.objectId()>>>0,suppressed=p.bool()|0;
 if(p.overflow()!==0)return false;
 if(state){state.spellId=id|0;state.spellItemId=item;state.suppressSound=suppressed;}return true;
}
export function clientCastFieldReader(fields){
 let index=0,failed=0;const read=type=>{const f=fields[index++];if(!f||f.type!==type){failed=1;return 0;}return f.value;};
 return{dword:()=>read('dword'),objectId:()=>read('object'),bool:()=>read('bool'),overflow:()=>failed};
}
