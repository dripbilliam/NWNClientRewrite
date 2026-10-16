import {creatureRoot} from './creature_rules.js';
import {abilityModifierCells} from './ability_modifier_cache.js';

const names=['Str','Dex','Con','Int','Wis','Cha'];
const integer=(value,name)=>{if(!Number.isInteger(value))throw new Error(`Native base-ability ${name} is unavailable`);return value|0;};
const call=(p,name,...args)=>{if(typeof p?.[name]!=='function')throw new Error(`Native base-ability provider ${name} is unavailable`);return p[name](...args);};
const short=value=>(integer(value,'HP')<<16)>>16;

// Stats SetSTRBase1404167d0/DEX140415530/CON1404152a0/INT140415aa0/
// WIS140416e70/CHA140415260. GFF-backed base bytes remain canonical;
// current racial/class/effect modifiers belong to the ordinary score getters.
export function setBaseAbility(actor,ability,value,adjustHP,p){
 ability=integer(ability,'selector');if(ability<0||ability>=6)throw new Error('Native base-ability selector is invalid');
 const root=creatureRoot(actor);if(!root)throw new Error('Native base-ability creature stats are unavailable');
 root[names[ability]]=integer(value,'value')&255;adjustHP=integer(adjustHP,'HP adjustment');
 // CON writes its base first, then queries the old maximum using the OLD
 // modifier cache. Only exactly1 adjusts HP; no death/dying events here.
 const oldMaximum=ability===2&&adjustHP===1?short(call(p,'maximumHP',actor,1)):0;
 const score=integer(call(p,'score',actor,ability),'current score')&255;
 actor[abilityModifierCells[ability]]=integer(call(p,'modifier',score),'modifier')&255;
 if(ability===0){const pending=call(p,'encumbrance',actor,1);if(pending?.then)return pending.then(()=>{});}
 else if(ability===2&&adjustHP===1){
  const current=short(call(p,'currentBaseHP',actor,1)),maximum=short(call(p,'maximumHP',actor,1));
  call(p,'writeBaseHP',actor,(current+(maximum-oldMaximum))|0);
 }else if(ability>=3)actor.nativeField544=1;
}
