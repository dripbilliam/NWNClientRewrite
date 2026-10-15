import { OBJECT_INVALID } from './game_object_array.js';
import { equipmentCombatEffects } from './combat_modifiers.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { effectImmunity } from './effect_immunity.js';
import { creatureRoot } from './creature_rules.js';
import { setDamageImmunity, damageImmunityTotal } from './damage_effect.js';
import {applyAIStateEffect,removeAIStateEffect,applyKnockdown,removeKnockdown} from './knockdown_effect.js';
import {abilityModifier} from './combat_stats.js';
import {sendCombatFeedback} from './combat_broadcast.js';
import {setEffectCreator} from './effect_creator.js';
import {applyVisualEffect,addLoopingVisual,removeVisualEffect} from './visual_effect.js';
import {deathVisualType} from './death_effects.js';
import {areaSpatialIds,firstAreaSpatialIndex} from './nearest_objects.js';
import {linkEffects,applyLinkedEffect,withScriptSubtype} from './linked_effect.js';
import {applySpellResistanceEffect,removeSpellResistanceEffect,applySpellProtectionEffect} from './spell_defense_effect.js';
import {applyEffectIcon,removeEffectIcon} from './effect_icon.js';
import {applyLocationEffect,applyAreaEffect} from './location_effect.js';
import {nativeFloatEntry,setNativeMovementFactor} from './movement_rate.js';
import {applyHasteOrSlow,removeHasteOrSlow,applyHasteController,removeHasteController} from './haste_effect.js';
import {applySpeedEffect,removeSpeedEffect,applyAttackCountEffect,removeAttackCountEffect} from './speed_effect.js';
import {applyEnchantment,removeEnchantment,applyEnchantmentController,removeEnchantmentController} from './enchantment_effect.js';
import {recomputeAmbientAnimation} from './combat_lifecycle.js';
import {broadcastEffectFloaty} from './effect_feedback.js';
import {clearPersonalReputation,addPersonalReputation} from './combat_reputation.js';
import {applyAbilityEffect,updateAbilityAttributes} from './ability_effect.js';
import {creatureMaxHitPoints} from './creature_hit_points.js';
import {scriptAbilityModifier} from './ability_modifier_cache.js';
import {applySilence,removeSilence} from './silence_effect.js';
import {applyInvisibility,removeInvisibility} from './invisibility_effect.js';
import {applyConcealment} from './concealment_effect.js';

// Mapped Heal, CutsceneGhost and positive attack/AC/save stat effects.
// CGameEffect IDs are uint64, separate from canonical uint32 game-object IDs.
// Store them as hex strings so VM value copies preserve identity without loss.
export class EffectRuntime {
  constructor(session) { this.session = session; this.nextId = 1n; }
  knockdownProviders(){
    const s=this.session;
    return {object:id=>s.registry.get(id),dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),
      immunity:(...args)=>s.combat.immunity(...args),feedback:(o,code,data)=>sendCombatFeedback(o,code,data,s.combat.broadcastProviders()),
      clearActions:o=>s.combat.clearActions(o),setAnimation:(o,id)=>s.combat.setAnimation(o,id),
      applyLinked:(o,e)=>this.applyNative(e,o.id),
      refreshDex:o=>{
        const flags=o.nativeField8d4&65535;
        const dex=(flags&6)!==6&&flags!==0&&(o.combatMode&255)!==11?3:o.stats?.equippedAbilities?.Dex;
        if(!Number.isInteger(dex))throw new Error('Native AI-state effect DEX score provider is unavailable');
        o.nativeDexModifierD3b=abilityModifier(dex&255,s.characterRules??{})&255;
      }};
  }
  create(type, creatorId = OBJECT_INVALID, integers = [], subtype = 0) {
    const id = this.nextId.toString(16).padStart(16, '0'); this.nextId = BigInt.asUintN(64, this.nextId + 1n);
    // CGameEffect ctor1404234c4..1404234e6 allocates eight zero INTs.
    // Owners such as damage/item properties can supply a larger integer list.
    const storage=Array(Math.max(8,integers.length)).fill(0);integers.forEach((v,i)=>{storage[i]=v|0;});
    const effect={ id, type, creatorId:OBJECT_INVALID, integers:storage,floats:Array(4).fill(0),vectors:[[0,0,0],[0,0,0]],objectIds:Array(4).fill(OBJECT_INVALID),
      subtype, durationType: 0, duration: 0, spellId: -1,casterLevel:-1, bypassImmunity: 0, exposed: true,showIcon:1,expiryDay:0,expiryTime:0,propertyId:'0000000000000000',customTag:'' };
    this.setCreator(effect,creatorId);return effect;
  }
  setCreator(effect,id){
    const s=this.session;
    setEffectCreator(effect,id,{object:id=>s.registry.get(id),asWorld:o=>o.objectType>=5&&o.objectType<=14?o:null,
      asAreaEffect:o=>o.objectType===11?o:null,areaEffectCreator:o=>o.nativeAreaEffectCreator330,
      effectSpell:o=>o.objectType===5?o.nativeEffectSpellId774:o.objectType===9?o.nativeEffectSpellId590:o.objectType===11?o.nativeAreaEffectSpellId:-1,
      casterLevel:o=>s.spellBook.casterLevel(o)});return effect;
  }
  visualProviders(){
    const s=this.session;
    return{plot:o=>Number(o.plot),position:o=>[o.position[0],-o.position[2],o.position[1]],
      visualType:id=>deathVisualType(s.characterRules.visualeffects,id),area:o=>s.registry.get(o.areaId)??null,
      addLoop:(...args)=>addLoopingVisual(...args),firstByX:(area,x)=>firstAreaSpatialIndex(s,area,x),areaIds:area=>areaSpatialIds(s,area),object:id=>s.registry.get(id),
      client:id=>s.combat.broadcastProviders().client(id),send:(client,data)=>s.onCombatMessage({recipientId:client.object.id,type:'visualEffect',data}),
      missPoint:()=>{throw new Error('Native visual ComputeMissedLocation owner is unavailable');}};
  }
  invalid() { return this.create(0); }
  copy(effect,icons=0){const value=structuredClone(effect);value.exposed=false;value.showIcon=icons?effect.showIcon:0;return value;}
  linkedProviders(){return{create:(...args)=>this.create(...args),setCreator:(e,id)=>this.setCreator(e,id),apply:(o,e,loading=0)=>this.applyNative(e,o.id,undefined,loading)};}
  hasteProviders(){const s=this.session;return{...this.linkedProviders(),copy:(...args)=>this.copy(...args),effects:o=>o.effects,
    dead:o=>Number(s.isDead(o)),creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
    immunity:(...args)=>s.combat.immunity(...args),feedback:(o,code,data)=>sendCombatFeedback(o,code,data,s.combat.broadcastProviders()),
    remove:(o,e)=>this.remove(o.id,e.id),apply:(o,e,loading)=>this.applyNative(e,o.id,undefined,loading)};}
  speedProviders(){const s=this.session;return{...this.hasteProviders(),plot:o=>Number(o.plot),
    setFactor:(o,value)=>setNativeMovementFactor(o,value,s.characterRules??{})};}
  invisibilityProviders(){const s=this.session,list=()=>{const ids=s.module?.nativeInvisibleCreatureIds330;if(!Array.isArray(ids))throw new Error('Native module invisible-creature list is unavailable');return ids;};return{...this.hasteProviders(),
    addInvisible:id=>{const ids=list();if(!ids.includes(id))ids.push(id);},removeInvisible:id=>{const ids=list(),index=ids.indexOf(id);if(index>=0)ids.splice(index,1);}};}
  enchantmentProviders(){const s=this.session,base=this.hasteProviders();return{...base,plot:o=>Number(o.plot),statsPC:o=>o.nativeStatsIsPCb0,
    clearActions:o=>s.combat.clearActions(o),ambient:o=>recomputeAmbientAnimation(o,{dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),setAnimation:(...args)=>s.combat.setAnimation(...args)}),
    floaty:(o,id)=>broadcastEffectFloaty(o,id,{...this.visualProviders(),send:(client,data)=>s.onCombatMessage({recipientId:client.object.id,type:'effectFloaty',data})}),
    setLastHostile:(o,id,force)=>s.damage.setLastHostile(o,{id},force),clearPersonal:(o,id)=>clearPersonalReputation(o,id,base),
    addPersonal:(...args)=>addPersonalReputation(...args,s.combat.reputationMutationProviders()),
    dominate:()=>{throw new Error('Native AddAssociate/possession domination lifecycle is unavailable');},
    removeDomination:()=>{throw new Error('Native RemoveDomination lifecycle is unavailable');},
    refreshObservers:async o=>{const area=s.registry.get(o.areaId);if(!area)return;for(const id of areaSpatialIds(s,area)){
      const other=s.registry.get(id);if(other?.objectType!==5||other.id===o.id)continue;other.perception.remove(o.id);await s.combat.updatePerception(other,o,0);
    }},possessed:o=>Number((o.associateType&65535)===3&&Boolean(s.combat.broadcastProviders().client(o.id))),
    clearVisible:o=>o.perception.clear(),updateVisible:o=>s.combat.updateVisibility(o)};}
  abilityProviders(){const s=this.session;return{...this.hasteProviders(),dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),plot:o=>Number(o.plot),
    score:(o,index)=>{s.refreshCombat(o);const score=o.stats.equippedAbilities?.[['Str','Dex','Con','Int','Wis','Cha'][index]];
      if(!Number.isInteger(score))throw new Error('Native current ability score is unavailable');
      return index===1&&(o.nativeField8d4&6)!==6&&(o.nativeField8d4&65535)!==0&&(o.combatMode&255)!==11?3:score;},
    modifier:score=>abilityModifier(score,s.characterRules),maximumHP:o=>creatureMaxHitPoints(creatureRoot(o),scriptAbilityModifier(o,2),s.characterRules,{possessedFamiliar:Boolean(o.isPossessedFamiliar)}),
    currentBaseHP:o=>o.stats.currentHP,writeBaseHP:(o,n)=>{o.stats.currentHP=n;s.damage.synchronize(o);},
    encumbrance:(...args)=>s.combat.encumbrance(...args),setAnimation:(...args)=>s.combat.setAnimation(...args),
    enqueueDying:o=>s.damage.playerEvent(32,o),closePanels:(o,n)=>s.combat.movementProviders().closePanels(o,n)};}
  retain(object,effect){const active=object.effects??=[],index=active.findIndex(e=>e.type>effect.type);if(index<0)active.push(effect);else active.splice(index,0,effect);}
  link(left,right,creator){return linkEffects(left,right,creator,this.linkedProviders());}
  subtype(effect,ordinal){return withScriptSubtype(effect,ordinal,this.linkedProviders());}
  applyAtLocation(duration,effect,location,seconds=0){const s=this.session,p={...this.visualProviders(),...this.linkedProviders(),
    visualRadius:id=>nativeFloatEntry(s.characterRules.visualeffects,id,'RADIUS').value,
    send:(client,data)=>s.onCombatMessage({recipientId:client.object.id,type:'areaVisualEffect',data}),
    applyObject:(o,e)=>this.applyNative(e,o.id),areaEffect:(...args)=>s.areaEffects.applyAtPoint(...args)};
    p.applyArea=(area,effect,position,orientation)=>applyAreaEffect(area,effect,position,orientation,p);
    return applyLocationEffect(duration,effect,location,seconds,p);
  }
  defenseProviders(){const s=this.session;return{dead:o=>Number(s.isDead(o)),plot:o=>Number(o.plot),object:id=>s.registry.get(id),
    immunity:(...args)=>s.combat.immunity(...args),resistance:o=>s.combat.spellResistance(o),effects:o=>o.effects,
    setCache:(o,down,value)=>{o[down?'nativeSpellResistanceDecreaseD85':'nativeSpellResistanceIncreaseD84']=value;
      runtimeDiagnostics.record('combat.frame-stat-refresh-unimplemented','Resistance cache setter written; synchronous RecomputeCombatInformation1404171e0 remains unavailable',s.diagnosticContext(o.id));},
    applyIcon:(o,e,loading=0)=>this.applyNative(e,o.id,undefined,loading)};}
  valid(effect) { return Number(Boolean(effect?.type && effect.exposed && [1, 2].includes(effect.durationType))); }
  enumerate(objectId, first = false) {
    const object = this.session.registry.get(objectId);
    if (!object) return this.invalid();
    if (object.authored?.EffectList?.length) throw new Error('Saved active effect import is not implemented');
    if (first) object.effectCursor = 0;
    const effects = object.effects ?? [];
    for (let i = object.effectCursor ?? 0; i < effects.length; i++) {
      const effect = effects[i];
      if (effect.exposed && [1, 2].includes(effect.durationType)) {
        object.effectCursor = (i + 1) & 0xffff;
        return structuredClone(effect);
      }
    }
    object.effectCursor = 0;
    return this.invalid();
  }
  apply(durationType, value, objectId, seconds = 0, context) {
    if(!value?.type)return;
    const effect=structuredClone(value);
    effect.durationType=durationType===0?0:durationType===1?1:2;
    if(effect.durationType===1){
      if(!Number.isFinite(seconds)||seconds<0)throw new Error('Negative/nonfinite temporary effect duration is not implemented');
      effect.duration=Math.fround(seconds);
      effect.expires=this.session.scheduler.time+Math.trunc(Math.fround(effect.duration*1000));
    }
    return this.applyNative(effect,objectId,context);
  }
  // Internal OnApplyEffect children retain equipped/innate duration3/4. Only
  // the NWScript wrapper above normalizes its public duration argument.
  applyNative(value,objectId,context,loading=0){
    const object = this.session.registry.get(objectId);
    if (!object || !['player', 'creature', 'door', 'placeable', 'item', 'trigger', 'store', 'encounter', 'waypoint','areaOfEffect'].includes(object.kind)) return;
    if (!value?.type) return;
    if (![1,3,8,9,28,29,31,36,37,46,47,76,41,42,59,2, 12, 19,20, 23, 30,33,34,40,50,65,67, 38, 39, 93, 10, 11, 13, 14, 15, 16, 17, 22, 26, 27, 48, 49, 55, 56].includes(value.type)) throw new Error(`Effect type ${value.type} is not implemented`);
    const effect = structuredClone(value);
    if(effect.durationType===1&&effect.expires===undefined)effect.expires=this.session.scheduler.time+Math.trunc(Math.fround(effect.duration*1000));
    if(effect.type===31)return this.session.areaEffects.applyAttached(object,effect,loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===46)return applySilence(object,effect,this.speedProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===47)return applyInvisibility(object,effect,this.invisibilityProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===76)return applyConcealment(object,effect,this.hasteProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if([36,37].includes(effect.type)){
      if(object.objectType===5&&!object.stats?.combat?.saves)throw new Error('Native ability effect target combat stats are unavailable');
      return applyAbilityEffect(object,effect,this.abilityProviders(),loading).then(async consumed=>{
        if(consumed===0){this.retain(object,effect);await updateAbilityAttributes(object,effect,this.abilityProviders(),loading);}
      });
    }
    if([8,9].includes(effect.type))return(effect.type===8?applyEnchantment:applyEnchantmentController)(object,effect,this.enchantmentProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if([1,3,41,42,28,29,59].includes(effect.type)){
      const result=[1,3].includes(effect.type)?applyHasteOrSlow(object,effect,this.hasteProviders(),loading):
        [41,42].includes(effect.type)?applyHasteController(object,effect,this.session.characterRules??{},this.hasteProviders(),loading):
        (effect.type===59?applyAttackCountEffect:applySpeedEffect)(object,effect,this.speedProviders(),loading);
      return result.then(consumed=>{if(consumed===0)this.retain(object,effect);});
    }
    if (effect.type === 38) return this.session.damage.apply(object, effect, context);
    if (effect.type === 19) return this.session.damage.death(object,effect,context);
    if(effect.type===40)return applyLinkedEffect(object,effect,this.linkedProviders(),loading);
    if(effect.type===67){if(applyEffectIcon(object,effect)!==0)return;const active=object.effects??=[],index=active.findIndex(e=>e.type>67);if(index<0)active.push(effect);else active.splice(index,0,effect);return;}
    if([33,34,50,65].includes(effect.type))return([33,34].includes(effect.type)?applySpellResistanceEffect:applySpellProtectionEffect)(object,effect,this.defenseProviders(),loading).then(consumed=>{
      if(consumed!==0)return;const active=object.effects??=[],index=active.findIndex(e=>e.type>effect.type);if(index<0)active.push(effect);else active.splice(index,0,effect);
    });
    if(effect.type===30)return applyVisualEffect(object,effect,this.visualProviders()).then(consumed=>{
      if(consumed!==0)return;const active=object.effects??=[],index=active.findIndex(e=>e.type>30);
      if(index<0)active.push(effect);else active.splice(index,0,effect);
    });
    if(effect.type===20)return applyKnockdown(object,effect,this.knockdownProviders(),loading).then(consumed=>{
      if(consumed!==0)return;
      if(effect.durationType===1)effect.expires=this.session.scheduler.time+Math.trunc(Math.fround(effect.duration*1000));
      const active=object.effects??=[],index=active.findIndex(e=>e.type>effect.type);
      if(index<0)active.push(effect);else active.splice(index,0,effect);
    });
    if(effect.type===23){
      applyAIStateEffect(object,effect,this.knockdownProviders());
      const active=object.effects??=[],index=active.findIndex(e=>e.type>effect.type);
      if(index<0)active.push(effect);else active.splice(index,0,effect);
      return;
    }
    if([55,56].includes(effect.type)) {
      // OnApplySkillIncrease/Decrease 0x1404332d0/0x140433190. These
      // handlers admit magnitude zero and retain only creature records.
      if(object.objectType!==5||this.session.isDead(object)||(effect.integers[1]|0)<0)return;
      if(effect.type===56){
        const source=this.session.registry.get(effect.creatorId);
        if(object.plot||!effect.bypassImmunity&&effectImmunity(creatureRoot(object),
          [...(object.itemCombatEffects?.effects??[]),...(object.effects??[])],27,
          source?.objectType===5?creatureRoot(source):null,{plot:Boolean(object.plot)}))return;
      }
      const active=object.effects??=[],index=active.findIndex(e=>e.type>effect.type);
      if(index<0)active.push(effect);else active.splice(index,0,effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented','Skill modifier applied; native linked type-67 effect icons 43/44 are not implemented',
        {...this.session.diagnosticContext(object.id),effectId:effect.id,effectType:effect.type,creatorId:effect.creatorId});
      return;
    }
    if ([13, 14].includes(effect.type)) {
      if (this.session.isDead(object) || effect.type === 14 && object.objectType !== 5) return;
      if (effect.type === 14 && !effect.bypassImmunity) {
        const source = this.session.registry.get(effect.creatorId);
        if (effectImmunity(creatureRoot(object), [...(object.itemCombatEffects?.effects ?? []), ...(object.effects ?? [])],
          21, source?.objectType === 5 ? creatureRoot(source) : null, { plot: Boolean(object.plot) })) return;
      }
      if (object.objectType === 5) object.combatInformationDirty = 1;
      const active = object.effects ??= [], index = active.findIndex(e => e.type > effect.type);
      if (index < 0) active.push(effect); else active.splice(index, 0, effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Damage bonus/penalty applied; native linked effect icons are not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type });
      return;
    }
    if ([2, 12].includes(effect.type)) {
      // Native handlers retain these records without a dead/amount gate.
      const active = object.effects ??= [], index = active.findIndex(e => e.type > effect.type);
      if (index < 0) active.push(effect); else active.splice(index, 0, effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Damage mitigation applied; native linked icon/floaty presentation is not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type });
      return;
    }
    if (effect.type === 15) {
      if (object.objectType !== 5 || this.session.isDead(object)) return;
      const state = this.session.damage.health(object);
      state.temporaryHP = ((((state.temporaryHP << 16) >> 16) + (effect.integers[0] | 0)) | 0);
      const active = object.effects ??= [], index = active.findIndex(e => e.type > effect.type);
      if (index < 0) active.push(effect); else active.splice(index, 0, effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Temporary hit points applied; native linked icon/floaty presentation is not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type });
      return;
    }
    if (effect.type === 39) {
      // OnApplyHeal consumes the effect even if passed TEMPORARY/PERMANENT.
      if (object.objectType === 5 && this.session.isDead(object)) return;
      if (!['player', 'creature', 'door', 'placeable'].includes(object.kind)) return;
      const current = object.objectType === 5 ? (object.stats.currentHP << 16) >> 16 : this.session.hitPoints(objectId, false), maximum = this.session.hitPoints(objectId, true);
      const amount = Math.min(effect.integers[0] | 0, maximum - current);
      if (object.objectType === 5) {
        object.stats.currentHP = (current + amount) | 0;
        this.session.damage.synchronize(object);
        runtimeDiagnostics.record('combat.lifecycle-unimplemented', 'Heal applied; dying recovery, negative-level removal, native feedback and encumbrance updates are not implemented',
          { ...this.session.diagnosticContext(object.id), effectId: effect.id });
      }
      else object.currentHP = current + amount;
      this.session.onMessage({ type: 'heal', id: objectId, creatorId: effect.creatorId, amount, text: `Hit points healed: ${amount}` });
      return;
    }
    if ([16, 17].includes(effect.type)) {
      if (this.session.isDead(object) || (effect.integers[1] | 0) < 0) return;
      if (effect.type === 17) {
        if (object.plot) return;
        const source = this.session.registry.get(effect.creatorId);
        if (object.objectType === 5 && !effect.bypassImmunity && effectImmunity(creatureRoot(object),
          [...(object.itemCombatEffects?.effects ?? []), ...(object.effects ?? [])], 22,
          source?.objectType === 5 ? creatureRoot(source) : null, { plot: Boolean(object.plot) })) return;
      }
      const active = object.effects ??= [], flags = effect.integers[0] >>> 0;
      const total = damageImmunityTotal([...(object.itemCombatEffects?.effects ?? []), ...active, effect], flags);
      setDamageImmunity(object.damageImmunityCache ??= Array(32).fill(0), flags, total);
      const index = active.findIndex(e => e.type > effect.type);
      if (index < 0) active.push(effect); else active.splice(index, 0, effect);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Damage immunity applied; native linked effect icons are not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type, creatorId: effect.creatorId });
      return;
    }
    if ([10, 11, 22, 26, 27, 48, 49].includes(effect.type)) {
      if (object.objectType !== 5 || this.session.isDead(object)) return;
      if (effect.type !== 22 && (effect.integers[[48, 49].includes(effect.type) ? 1 : 0] | 0) < 1) return;
      if (!object.stats?.combat?.saves) throw new Error('Combat effect target stats are not loaded');
      if ([11, 27, 49].includes(effect.type)) {
        const source = this.session.registry.get(effect.creatorId);
        if (object.plot || !effect.bypassImmunity && effectImmunity(creatureRoot(object),
          [...(object.itemCombatEffects?.effects ?? []), ...(object.effects ?? [])],
          { 11: 20, 27: 25, 49: 23 }[effect.type], source?.objectType === 5 ? creatureRoot(source) : null, { plot: Boolean(object.plot) })) return;
      }
      const cache = structuredClone(object.acCache ?? object.stats.combat.finalBreakdown.armor.cache);
      if ([48, 49].includes(effect.type)) {
        const [category, amount, race, law, good, damage] = effect.integers;
        const sign = effect.type === 48 ? 'up' : 'down';
        if (race === 28 && !law && !good && damage === 4103) {
          if (!category) cache[sign][0] = ((cache[sign][0] + amount) << 24) >> 24;
          else if (cache[sign][category] < amount) cache[sign][category] = (amount << 24) >> 24;
        }
      }
      const effects = object.effects ??= [];
      const index = effects.findIndex(e => e.type > effect.type);
      if (index < 0) effects.push(effect); else effects.splice(index, 0, effect);
      object.acCache = cache;
      this.session.refreshCombat(object);
      runtimeDiagnostics.record('effects.presentation-unimplemented', 'Combat stat effect applied; native effect icons and feedback are not implemented',
        { ...this.session.diagnosticContext(object.id), effectId: effect.id, effectType: effect.type, creatorId: effect.creatorId });
      return;
    }
    // Native first application sets the creature's ghost flag. A duplicate is
    // consumed rather than stacked; non-creatures retain the effect, no flag.
    if (object.objectType === 5) {
      if (object.cutsceneGhost) return;
      object.cutsceneGhost = true;
    }
    const effects = object.effects ??= [];
    const index = effects.findIndex(e => e.type > effect.type);
    if (index < 0) effects.push(effect); else effects.splice(index, 0, effect);
  }
  requestRemoval(objectId, value, creatorId) {
    const object = this.session.registry.get(objectId);
    let effect;
    for (const record of object?.effects ?? []) if (record.id === value?.id) { record.exposed = false; effect = record; }
    if (!effect) return;
    // RemoveEffect hides the live record immediately; deletion is an AI event.
    // Already returned VM copies retain their previous validity flags.
    this.session.scheduler.enqueue(objectId, { type: 'removeEffect', effectId: effect.id, creatorId });
  }
  remove(objectId, effectId, context) {
    // RemoveEffectById140498280 walks the LIVE array and removes every
    // matching uint64 ID, including hidden linked records. It invokes the
    // removal callback before erasing; callbacks can themselves purge effects.
    const object=this.session.registry.get(objectId);
    const next=()=>{
      while(object?.effects?.some(e=>e.id===effectId)){
        const result=this.removeOne(objectId,effectId,context);
        if(result?.then)return result.then(next);
      }
    };
    return next();
  }
  removeOne(objectId, effectId, context) {
    const object = this.session.registry.get(objectId), index = object?.effects?.findIndex(e => e.id === effectId) ?? -1;
    if (index < 0) return;
    if (object.effects[index].type === 15) {
      // RemoveEffectById 0x140498280 invokes OnEffectRemoved BEFORE deleting
      // the record. A nested death handler can remove it first; requery by ID.
      const effect = object.effects[index];
      return this.session.damage.removeTemporary(object, effect, context).then(() => {
        const liveIndex = object.effects.indexOf(effect);
        if (liveIndex >= 0) object.effects.splice(liveIndex, 1);
      });
    }
    const effect=object.effects[index];
    if(effect.type===46)removeSilence(object);
    if(effect.type===47)removeInvisibility(object,effect,this.invisibilityProviders());
    if(effect.type===31)return this.session.areaEffects.removeAttached(object,effect).then(()=>{const live=object.effects.indexOf(effect);if(live>=0)object.effects.splice(live,1);});
    if([8,9].includes(effect.type))return(effect.type===8?removeEnchantment:removeEnchantmentController)(object,effect,this.enchantmentProviders()).then(()=>{
      const live=object.effects.indexOf(effect);if(live>=0)object.effects.splice(live,1);
    });
    if([1,3].includes(effect.type))return removeHasteOrSlow(object,effect,this.hasteProviders()).then(()=>{
      const live=object.effects.indexOf(effect);if(live>=0)object.effects.splice(live,1);
    });
    if([41,42].includes(effect.type))removeHasteController(object,effect);
    if([28,29].includes(effect.type))removeSpeedEffect(object,effect,this.speedProviders());
    if(effect.type===59)removeAttackCountEffect(object,effect,this.speedProviders());
    if(effect.type===67)removeEffectIcon(object,effect);
    if([33,34].includes(effect.type))removeSpellResistanceEffect(object,effect,this.defenseProviders());
    if(effect.type===30)removeVisualEffect(object,effect);
    if(effect.type===23)removeAIStateEffect(object,effect,this.knockdownProviders());
    if(effect.type===20)removeKnockdown(object,effect,this.knockdownProviders());
    const liveIndex=object.effects.indexOf(effect);if(liveIndex>=0)object.effects.splice(liveIndex,1);
    if([36,37].includes(effect.type)&&object.objectType===5)return updateAbilityAttributes(object,effect,this.abilityProviders(),0);
    if ([13, 14].includes(effect.type) && object.objectType === 5) object.combatInformationDirty = 1;
    if ([16, 17].includes(effect.type)) setDamageImmunity(object.damageImmunityCache, effect.integers[0],
      damageImmunityTotal([...(object.itemCombatEffects?.effects ?? []), ...object.effects], effect.integers[0]));
    if (effect.type === 93 && object.objectType === 5) object.cutsceneGhost = false;
    if ([10, 11, 22, 26, 27, 48, 49].includes(effect.type)) {
      if ([48, 49].includes(effect.type)) {
        const [category, amount, race, law, good, damage] = effect.integers;
        const sign = effect.type === 48 ? 'up' : 'down';
        if (race === 28 && !law && !good && damage === 4103) {
          if (!category) object.acCache[sign][0] = ((object.acCache[sign][0] - amount) << 24) >> 24;
          else {
            const items = (object.inventory ?? []).map(id => this.session.registry.get(id)).filter(i => i?.equipmentSlot)
              .map(i => ({ id: i.id, slot: i.equipmentSlot, data: i.authored }));
            const remaining = [...(object.itemCombatEffects ?? equipmentCombatEffects(items, this.session.characterRules, { root: creatureRoot(object) })).effects, ...object.effects]
              .filter(e => e.type === effect.type && e.integers[0] === category && e.integers[2] === 28 && !e.integers[3] && !e.integers[4] && e.integers[5] === 4103);
            object.acCache[sign][category] = (Math.max(0, ...remaining.map(e => e.integers[1])) << 24) >> 24;
          }
        }
      }
      this.session.refreshCombat(object);
    }
  }
  async update() {
    for (const object of this.session.registry.objects.values()) await this.updateObject(object);
  }
  async updateObject(object) {
    for (const effect of [...(object.effects ?? [])]) {
      // UpdateEffectList uses CompareWorldTimes == 1, strictly AFTER expiry.
      if (effect.durationType === 1 && this.session.scheduler.time > effect.expires) {
        const result = this.remove(object.id, effect.id);
        if (result?.then) await result;
      }
    }
  }
}
