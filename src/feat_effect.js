import {featInfo} from './feat_uses.js';
import {intEntry} from './combat_stats.js';

// GetHasFeatEffectApplied140495480 matches effect.spellId (+1c), without
// filtering effect type, duration, exposure or creator. LoadFeatInfo1402a98e9
// writes SpellId only on a successful cell; CNWFeat ctor retains -1 otherwise.
export function hasFeatEffectApplied(object,feat,rules){
  if(!Number.isInteger(feat))throw new Error('Native feat-effect ID is unavailable');
  feat&=65535;if(!featInfo(rules,feat))return 0;
  const entry=intEntry(rules.feat,feat,'SpellId'),spell=entry.found?entry.value:-1;
  if(spell===-1)return 0;
  if(!Array.isArray(object.effects))throw new Error('Native feat-effect pool is unavailable');
  for(const effect of object.effects){
    if(!Number.isInteger(effect.spellId))throw new Error('Native feat-effect spell ID is unavailable');
    if((effect.spellId|0)===spell)return 1;
  }
  return 0;
}

// HasSpellEffectApplied140495f80: DWORD comparison, INVALID -1 never matches.
export function hasSpellEffectApplied(object,spell){
  if(!Number.isInteger(spell))throw new Error('Native spell-effect ID is unavailable');spell>>>=0;
  if(spell===0xffffffff)return 0;
  if(!Array.isArray(object.effects))throw new Error('Native spell-effect pool is unavailable');
  for(const effect of object.effects){if(!Number.isInteger(effect.spellId))throw new Error('Native spell-effect spell ID is unavailable');if((effect.spellId>>>0)===spell)return 1;}
  return 0;
}
