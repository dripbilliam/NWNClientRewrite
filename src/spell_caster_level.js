import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
import {nativeFloatEntry} from './movement_rate.js';
const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native caster level ${n} is unavailable`);return v|0;};
const required=(p,n)=>{if(typeof p?.[n]!=='function')throw new Error(`Native caster level provider ${n} is unavailable`);return p[n];};
const classes=o=>{const list=creatureRoot(o)?.ClassList;if(!Array.isArray(list))throw new Error('Native caster class storage is unavailable');return list.slice(0,list.length&255);};
// GetIsClass140402dc0 returns the first physical class slot, or255.
export function nativeClassIndex(o,type){type=integer(type,'class type')&255;const index=classes(o).findIndex(c=>(integer(c.Class,'class type')&255)===type);return index<0?255:index;}
// GetClassLevel1403fa4f0 takes a slot INDEX, not class TYPE. +25e is the
// same negative-level BYTE already owned as skillPenaltyByte. Multipliers
// use unpenalized level for admission, then scale the penalized level.
export function nativeClassLevel(o,index,penalty,multiplier,rules){
  index=integer(index,'class slot')&255;const c=classes(o)[index];if(!c)return 0;
  const raw=integer(c.ClassLevel,'class level')&255,level=raw-(integer(penalty,'penalty flag')!==0?(integer(c.skillPenaltyByte,'class penalty')&255):0);
  if(level<0)return 0;
  if(integer(multiplier,'multiplier flag')!==0){
    if(!rules.classes)throw new Error('Native caster class rules are unavailable');
    const id=integer(c.Class,'class type')&255;
    if(intEntry(rules.classes,id,'SpellCaster').value!==0){
      const min=intEntry(rules.classes,id,'MinCastingLevel');
      if(!min.found)throw new Error('Native class minimum casting level reads uninitialized loader storage');
      if(raw>=min.value){
        const scale=nativeFloatEntry(rules.classes,id,'CLMultiplier');
        if(!scale.found)throw new Error('Native class caster multiplier reads uninitialized loader storage');
        const result=Math.fround(Math.fround(level)*scale.value);
        return(Number.isFinite(result)&&result>=-2147483648&&result<2147483648?Math.trunc(result):-2147483648)&255;
      }
    }
  }
  return level&255;
}
// GetFeatSourceClass140401b30 scans current total levels (BYTE) and the
// first retained level-up record whose WORD feat list contains this feat.
export function nativeFeatSourceClass(o,feat,warning=()=>{}){
  feat=integer(feat,'feat')&65535;const list=classes(o);
  if(!list.length)warning('Your character has no class! What are you doing?');
  const count=list.reduce((sum,c)=>sum+(integer(c.ClassLevel,'history class level')&255),0)&255,history=creatureRoot(o).LvlStatList??[];
  for(let i=0;i<count;i++){
    const entry=history[i];
    if(entry?.FeatList?.some(f=>(integer(f.Feat,'history feat')&65535)===feat))return integer(entry.LvlStatClass,'history source class')&255;
  }
  return 255;
}
// CNWSObject GetCasterLevel140494ee0. The missing-ability254 path retains
//255 if spell lookup also fails. Valid fallback spell yields10 for every
// possible Innate BYTE (the original max/min sequence is deliberately kept).
export function casterLevel(actor,p){
  let missing=0;
  if(required(p,'asAreaOfEffect')(actor))return integer(actor.nativeCasterLevel344,'area-effect level');
  if(required(p,'asCreature')(actor)){
    if(integer(actor.nativeCasterOverride820,'override flag')!==0)return integer(actor.nativeCasterOverride824,'override value');
    const id=integer(actor.nativeSpellId218,'current spell');
    if(integer(actor.nativeEquipmentLock97c,'equipment override')!==0&&[actor.nativeSpellOverride9e8,actor.nativeSpellOverride9ec,actor.nativeSpellOverride9f0].some(v=>integer(v,'override spell')===id)){
      const effects=required(p,'effects')(actor);
      for(const effect of effects){if((integer(effect.type,'effect type')&65535)!==62)continue;
        const level=integer(required(p,'effectInteger')(effect,7),'effect level');if(level>0)return level;break;}
      return required(p,'classLevel')(actor,0,0,0)&255;
    }
    const index=integer(actor.nativeSpellClass22c,'current class')&255;
    if(index===255){
      const feat=integer(actor.nativeSpellFeat23c,'current feat')&65535;
      if(feat!==65535){const type=required(p,'featSource')(actor,feat)&255,slot=required(p,'classIndex')(actor,type)&255;
        if(slot!==255)return required(p,'classLevel')(actor,slot,1,0)&255;}
    }else if(index===254){const level=required(p,'abilityLevel')(actor,id)&255;if(level!==255)return level;missing=255;}
    else return required(p,'classLevel')(actor,index,1,1)&255;
  }else if(!required(p,'asPlaceable')(actor))return 0;
  const spell=required(p,'spell')(integer(actor.nativeSpellId218,'fallback spell'));
  return spell?Math.min(10,Math.max(10,integer(spell.innate,'innate')&255)*2-1):missing;
}
