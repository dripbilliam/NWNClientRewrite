import { OBJECT_INVALID } from './game_object_array.js';
import {initializeEffectExpiry,setEffectExpiry,effectHasExpired} from './effect_clock.js';
import {finishEffectApplicationFlag} from './effect_application_flag.js';
import {applySanctuary,removeSanctuary} from './sanctuary_effect.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import {applySkillBuff} from './skill_buff_effect.js';
import { creatureRoot } from './creature_rules.js';
import { setDamageImmunity } from './damage_effect.js';
import {applyAIStateEffect,removeAIStateEffect,applyKnockdown,removeKnockdown} from './knockdown_effect.js';
import {abilityModifier} from './combat_stats.js';
import {sendCombatFeedback} from './combat_broadcast.js';
import {setEffectCreator} from './effect_creator.js';
import {loadGameEffect,savedEffectStorage} from './game_effect_load.js';
import {asNWSObject} from './native_object_cast.js';
import {applyVisualEffect,addLoopingVisual,removeVisualEffect,applyBeamEffect,applyLightEffect} from './visual_effect.js';
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
import {broadcastEffectFloaty,displayFloatyToSelf} from './effect_feedback.js';
import {applyPoison,applyDisease,applyPoisonPayload,applyDiseasePayload,updateAffliction} from './affliction_effect.js';
import {equalEffectValues} from './effect_identity.js';
import {addWorldTimes,compareWorldTimes,subtractWorldTimes,secondsToWorldDelta} from './world_timer.js';
import {applyRegeneration,updateRegeneration} from './regeneration_effect.js';
import {applyHealing,applyResurrection} from './healing_effect.js';
import {applyWounding,applyVampiricRegeneration,applyWoundingTick,updateWounding} from './wounding_effect.js';
import {applyNegativeLevel,removeNegativeLevel,classNegativeLevels,setClassNegativeLevels,creatureLevel,penalizedClassLevel} from './negative_level_effect.js';
import {updateMemorizedSpellSlots} from './spell_book.js';
import {rulesetInt} from './combat_stats.js';
import {intEntry} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';
import {clearPersonalReputation,addPersonalReputation} from './combat_reputation.js';
import {applyAbilityEffect,updateAbilityAttributes} from './ability_effect.js';
import {creatureMaxHitPoints} from './creature_hit_points.js';
import {scriptAbilityModifier} from './ability_modifier_cache.js';
import {applySilence,removeSilence} from './silence_effect.js';
import {applyInvisibility,removeInvisibility} from './invisibility_effect.js';
import {applyConcealment} from './concealment_effect.js';
import {applyBlindness,applyInactiveBlindness,removeBlindness,applyDarkness,removeDarkness,applyVisionFilter,applyVisionSource,removeVisionSource,applyMissChance,applyDeafness} from './vision_effect.js';
import {applyDispel} from './dispel_effect.js';
import {applyDamageShield} from './damage_shield.js';
import {applyAppearEffect} from './appear_effect.js';
import {applyBonusFeat,removeBonusFeat,bonusFeats} from './bonus_feat_effect.js';
import {removeEffectsById,removeEffectRecord,removeEffectTarget,updateEffectList} from './effect_removal.js';
import {trackCasterEffect} from './rest_resources.js';
import {loadRacialFeatList,applyRacialType,removeRacialType} from './racial_effect.js';
import {applyPolymorph,removePolymorph} from './polymorph_effect.js';
import {applyTurnResistance} from './turn_resistance.js';
import {applyStatEffect,removeStatEffect} from './stat_effect.js';
import {applyDamageBuff,applyDamageImmunityBuff,removeDamageBuff} from './damage_buff_effect.js';
import {applyCurse} from './curse_effect.js';
import {applyModifyAttacks,removeModifyAttacks} from './modify_attacks_effect.js';
import {applyEntangle,removeEntangle,applyCutsceneImmobile} from './entangle_effect.js';
import {applyTimeStop,removeTimeStop,applyTimeStopImmunity,removeTimeStopImmunity} from './time_stop_effect.js';
import {activePauseState,addPauseExclusion,removePauseExclusion} from './server_pause.js';
import {applySpellFailure,removeSpellFailure} from './spell_failure_effect.js';

// Mapped Heal, CutsceneGhost and positive attack/AC/save stat effects.
// CGameEffect IDs are uint64, separate from canonical uint32 game-object IDs.
// Store them as hex strings so VM value copies preserve identity without loss.
export class EffectRuntime {
  constructor(session) { this.session = session; this.nextId = 1n;this.racialFeatLists=new WeakMap();this.expiryFinalized=new WeakSet(); }
  polymorphProviders(context){const s=this.session;return{asCreature:o=>o.objectType===5?o:null,dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),
    possessed:o=>Number((o.associateType&65535)===3&&Boolean(s.combat.broadcastProviders().client(o.id))),effects:o=>o.effects,
    create:(...args)=>this.create(...args),copyConstruct:(...args)=>this.copyConstruct(...args),apply:(o,e,loading)=>this.applyNative(e,o.id,context,loading),remove:(o,id)=>this.remove(o.id,id,context),
    transform:(o,form,e,loading)=>s.polymorph.transform(o,form,e,loading,context),untransform:(o,e)=>s.polymorph.restore(o,e,context),
    client:id=>s.combat.broadcastProviders().client(id),notify:(client,objectId,apply,locked)=>s.onCombatMessage({recipientId:client.object.id,type:'polymorph',messageType:12,subtype:1,objectId,apply,locked}),
    time:()=>s.worldTimer.time(),delta:seconds=>secondsToWorldDelta(seconds,s.worldTimer.secondsPerDay),addTime:(a,b)=>addWorldTimes(a,b,s.worldTimer.dayLength),
    setExpiry:setEffectExpiry};}
  async raceFeats(id){
    const table=this.session.characterRules?.racialtypes;if(!table)throw new Error('Native racial effect rules are unavailable');
    const count=table.orderedRows?.length??table.rows.size;
    if(id<0||id>=count)throw new Error(`Native racial effect race ${id} points outside loaded race storage`);
    if(!this.racialFeatLists.has(table))this.racialFeatLists.set(table,new Map());const cache=this.racialFeatLists.get(table);
    if(!cache.has(id))cache.set(id,(async()=>{const name=nativeStringEntry(table,id,'FeatsTable').value;return loadRacialFeatList(name?await this.session.items.table(name):null);})());
    return cache.get(id);
  }
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
      strings:Array(6).fill(''),subtype, durationType: 0, duration: 0, spellId: -1,casterLevel:-1, bypassImmunity: 0, exposed: true,showIcon:1,skipOnLoad:0,expiryDay:0,expiryTime:0,propertyId:'0000000000000000',customTag:'' };
    this.setCreator(effect,creatorId);return effect;
  }
  setCreator(effect,id){
    const s=this.session;
    setEffectCreator(effect,id,{object:id=>s.registry.get(id),asWorld:asNWSObject,
      asAreaEffect:o=>o.objectType===11?o:null,areaEffectCreator:o=>o.nativeAreaEffectCreator330,
      effectSpell:o=>o.objectType===5?o.nativeEffectSpellId774:o.objectType===9?o.nativeEffectSpellId590:o.objectType===11?o.nativeAreaEffectSpellId:-1,
      casterLevel:o=>s.spellBook.casterLevel(o)});return effect;
  }
  loadSaved(data){
    try{return loadGameEffect(savedEffectStorage(),data,{setCreator:(effect,id)=>this.setCreator(effect,id)});}
    catch(error){this.session.report(error,{operation:'native-game-effect-load'});throw error;}
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
  // Base constructor(1) followed by CopyEffect(...,0), as used when vision
  // suppresses blindness. Assignment keeps the fresh destination ID
  // and copies exposure, icon visibility and full payload from the source.
  assignFresh(effect){const id=this.create(0).id;return{...structuredClone(effect),id};}
  // Base constructor(0) + CopyEffect(...,0) restores the source ID instead.
  assignPreservingId(effect){return structuredClone(effect);}
  // CGameEffect copy constructor140423570 clears payload for both flags;
  // the flag controls only whether source icon visibility is inherited.
  copyConstruct(effect,icons=0){const value=structuredClone(effect);
    value.type=0;value.exposed=false;value.showIcon=icons!==0?effect.showIcon:0;value.skipOnLoad=0;value.integers.fill(0);value.floats.fill(0);value.strings=Array(6).fill('');value.vectors=[[0,0,0],[0,0,0]];value.objectIds.fill(OBJECT_INVALID);value.customTag='';delete value.linkLeft;delete value.linkRight;return value;
  }
  visionProviders(){const s=this.session;return{...this.hasteProviders(),assignFresh:e=>this.assignFresh(e),assignPreservingId:e=>this.assignPreservingId(e),effects:o=>o.effects,plot:o=>Number(o.plot),dm:o=>Number(Boolean(o.isDM)),
    floaty:(o,id)=>broadcastEffectFloaty(o,id,{...this.visualProviders(),send:(client,data)=>s.onCombatMessage({recipientId:client.object.id,type:'effectFloaty',data})}),
    inDarkness:o=>Array.from(o.nativeSubareaMembership.view()).some(id=>{const a=s.registry.get(id);return a?.objectType===11&&[36,345].includes(a.nativeAreaEffectId30c);})};}
  linkedProviders(){return{create:(...args)=>this.create(...args),setCreator:(e,id)=>this.setCreator(e,id),apply:(o,e,loading=0)=>this.applyNative(e,o.id,undefined,loading)};}
  hasteProviders(){const s=this.session;return{...this.linkedProviders(),copyConstruct:(...args)=>this.copyConstruct(...args),effects:o=>o.effects,
    dead:o=>Number(s.isDead(o)),creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
    immunity:(...args)=>s.combat.immunity(...args),feedback:(o,code,data)=>sendCombatFeedback(o,code,data,s.combat.broadcastProviders()),
    remove:(o,e)=>this.remove(o.id,e.id),apply:(o,e,loading)=>this.applyNative(e,o.id,undefined,loading)};}
  speedProviders(){const s=this.session;return{...this.hasteProviders(),plot:o=>Number(o.plot),
    setFactor:(o,value)=>setNativeMovementFactor(o,value,s.characterRules??{})};}
  curseProviders(context){const s=this.session;return{...this.hasteProviders(),asCreature:o=>o?.objectType===5?o:null,plot:o=>Number(o.plot),
    apply:(o,e,loading)=>this.applyNative(e,o.id,context,loading),enqueue:(o,id,e)=>s.combat.enqueueEvent(id,e.creatorId,o.id,0,e)};}
  spellFailureProviders(){const s=this.session;return{...this.hasteProviders(),asCreature:o=>o?.objectType===5?o:null,
    updateCombat:o=>s.updateNativeCombatInformation(o)};}
  entangleProviders(){return{...this.enchantmentProviders(),asCreature:o=>o?.objectType===5?o:null};}
  timeStopProviders(){const s=this.session;return{
    pauseState:()=>activePauseState(s.nativeServerPause),worldTimer:()=>s.worldTimer,activeTimer:id=>s.activeTimer(id),
    addExclusion:(id,mask)=>addPauseExclusion(s.nativeServerPause,id,mask),removeExclusion:(id,mask)=>removePauseExclusion(s.nativeServerPause,id,mask),
    togglePause:mask=>s.togglePauseState(mask),effects:o=>o.effects,asCreature:o=>o?.objectType===5?o:null,isDM:o=>Number(o.isDM)};}
  invisibilityProviders(){const s=this.session,list=()=>{const ids=s.module?.nativeInvisibleCreatureIds330;if(!Array.isArray(ids))throw new Error('Native module invisible-creature list is unavailable');return ids;};return{...this.hasteProviders(),
    addInvisible:id=>{const ids=list();if(!ids.includes(id))ids.push(id);},removeInvisible:id=>{const ids=list(),index=ids.indexOf(id);if(index>=0)ids.splice(index,1);}};}
  sanctuaryProviders(){const s=this.session;return{...this.invisibilityProviders(),asCreature:o=>o?.objectType===5?o:null,
    dead:o=>Number(s.isDead(o)),area:o=>{const a=s.registry.get(o.areaId);return a?.objectType===4?a:null;},areaIds:a=>areaSpatialIds(s,a),
    creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},visibility:(o,id)=>o.perception.node(id),
    save:(...args)=>s.combat.savingThrow(...args),pacify:(o,id)=>s.combat.pacify(o,id),index:o=>s.combat.liveInvisibilityIndex(o),removeVisibility:(o,id)=>o.perception.remove(id)};}
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
    score:(o,index)=>{s.refreshCombat(o,{refreshAbilityCaches:false});const score=o.stats.equippedAbilities?.[['Str','Dex','Con','Int','Wis','Cha'][index]];
      if(!Number.isInteger(score))throw new Error('Native current ability score is unavailable');
      return index===1&&(o.nativeField8d4&6)!==6&&(o.nativeField8d4&65535)!==0&&(o.combatMode&255)!==11?3:score;},
    modifier:score=>abilityModifier(score,s.characterRules),maximumHP:o=>creatureMaxHitPoints(creatureRoot(o),scriptAbilityModifier(o,2),s.characterRules,{possessedFamiliar:Boolean(o.isPossessedFamiliar),bonusFeats:bonusFeats(o)}),
    currentBaseHP:o=>o.stats.currentHP,writeBaseHP:(o,n)=>{o.stats.currentHP=n;s.damage.synchronize(o);},
    encumbrance:(...args)=>s.combat.encumbrance(...args),setAnimation:(...args)=>s.combat.setAnimation(...args),
    enqueueDying:o=>s.damage.playerEvent(32,o),closePanels:(o,n)=>s.combat.movementProviders().closePanels(o,n)};}
  retain(object,effect){const active=object.effects??=[],index=active.findIndex(e=>e.type>effect.type);if(index<0)active.push(effect);else active.splice(index,0,effect);}
  statProviders(){return{...this.hasteProviders(),plot:o=>Number(o.plot),armorCache:o=>{
    if(!o.acCache){const cache=o.stats?.combat?.finalBreakdown?.armor?.cache;if(!cache)throw new Error('Native stat effect armor cache is unavailable');o.acCache=structuredClone(cache);}return o.acCache;
  }};}
  damageBuffProviders(){return{...this.hasteProviders(),copyConstruct:(...args)=>this.copyConstruct(...args),plot:o=>Number(o.plot),
    floaty:(o,id)=>broadcastEffectFloaty(o,id,this.visualProvidersWithFloaty()),setImmunity:(o,flags,total)=>setDamageImmunity(o.damageImmunityCache??=Array(32).fill(0),flags,total)};}
  link(left,right,creator){return linkEffects(left,right,creator,this.linkedProviders());}
  subtype(effect,ordinal){return withScriptSubtype(effect,ordinal,this.linkedProviders());}
  applyAtLocation(duration,effect,location,seconds=0){const s=this.session,p={...this.visualProviders(),...this.linkedProviders(),
    visualRadius:id=>nativeFloatEntry(s.characterRules.visualeffects,id,'RADIUS').value,
    send:(client,data)=>s.onCombatMessage({recipientId:client.object.id,type:'areaVisualEffect',data}),
    applyObject:(o,e)=>this.applyNative(e,o.id),areaEffect:(...args)=>s.areaEffects.applyAtPoint(...args)};
    p.applyArea=(area,effect,position,orientation)=>applyAreaEffect(area,effect,position,orientation,p);
    return applyLocationEffect(duration,effect,location,seconds,p);
  }
  afflictionProviders(context){
    const s=this.session,base=this.hasteProviders(),table=kind=>{const value=s.characterRules?.[kind];if(!value)throw new Error(`Native affliction ${kind}.2da is unavailable`);return value;};
    const providers={...base,asCreature:o=>o.objectType===5?o:null,plot:o=>Number(o.plot),tableInt:(kind,id,column)=>intEntry(table(kind),id,column),tableString:(kind,id,column)=>nativeStringEntry(table(kind),id,column),
      roll:(count,sides)=>s.random.dice(count,sides),save:(...args)=>s.combat.savingThrow(...args),
      copyConstruct:(e,icons)=>this.copyConstruct(e,icons),copyAssign:structuredClone,equal:equalEffectValues,
      apply:(o,e,loading)=>this.applyNative(e,o.id,context,loading),enqueue:(o,id,e)=>s.combat.enqueueEvent(id,o.id,o.id,0,e),
      floatySelf:(o,id)=>displayFloatyToSelf(o,id,s.combat.broadcastProviders()),floaty:(o,id)=>broadcastEffectFloaty(o,id,this.visualProvidersWithFloaty()),
      script:(name,o)=>s.runScript(name,o.id),time:()=>s.worldTimer.time(),
      minutesPerHour:()=>{const value=s.module?.nativeMinutesPerHour3b8;if(!Number.isInteger(value))throw new Error('Native module minutes-per-hour BYTE3b8 is unavailable');return value;},
      addTime:(now,delta)=>{const value=addWorldTimes(now,delta,s.worldTimer.dayLength);if(value.status!==0)throw new Error('Native affliction deadline has invalid world time; original output is unwritten');return value;},
      compareTime:(a,b)=>compareWorldTimes(a,b,s.worldTimer.dayLength)};
    providers.poisonPayload=(o,e)=>applyPoisonPayload(o,e,providers);providers.diseasePayload=(o,e,now)=>applyDiseasePayload(o,e,now,providers);return providers;
  }
  visualProvidersWithFloaty(){const s=this.session;return{...this.visualProviders(),send:(client,data)=>s.onCombatMessage({recipientId:client.object.id,type:'effectFloaty',data})};}
  negativeLevelProviders(context){const s=this.session,base=this.hasteProviders(),warning=message=>runtimeDiagnostics.record('spells.native-warning',message,s.diagnosticContext(context?.self));
    const p={...base,asCreature:o=>o.objectType===5?o:null,rule:(name,fallback)=>rulesetInt(s.characterRules,name,fallback),
      copyConstruct:(e,icons)=>this.copyConstruct(e,icons),classCount:o=>creatureRoot(o).ClassList.length&255,classLevel:penalizedClassLevel,
      classNegativeLevels,warning,updateMemorizedSlots:o=>updateMemorizedSpellSlots(o,s.characterRules,s.spellBook.providers(o)),level:(o,penalty)=>creatureLevel(o,penalty,warning),
      apply:(o,e,loading)=>this.applyNative(e,o.id,context,loading),enqueue:(o,id,e)=>s.combat.enqueueEvent(id,e.creatorId,o.id,0,e)};
    p.setClassNegativeLevels=(...args)=>setClassNegativeLevels(...args,p);return p;
  }
  regenerationProviders(context){const s=this.session;return{...this.hasteProviders(),asCreature:o=>o.objectType===5?o:null,
    time:()=>s.worldTimer.time(),subtractTime:(a,b)=>subtractWorldTimes(a,b,s.worldTimer.dayLength),copyConstruct:(e,icons)=>this.copyConstruct(e,icons),
    currentHP:o=>o.objectType===5?o.stats.currentHP:s.hitPoints(o.id,false),maximumHP:o=>s.hitPoints(o.id,true),
    apply:(o,e,loading)=>this.applyNative(e,o.id,context,loading)};}
  woundingProviders(context){const s=this.session,p={...this.regenerationProviders(context),
    damageIndex:flags=>(flags>>>0)<=1?0:31-Math.clz32(flags>>>0),
    blood:o=>nativeStringEntry(s.characterRules.appearance,creatureRoot(o).Appearance_Type&65535,'BLOODCOLR').value,
    enqueue:(id,caller,target,effect)=>s.combat.enqueueEvent(id,caller,target,0,effect),
    warning:message=>runtimeDiagnostics.record('effect.wounding-warning',message,{severity:'warning'})};
    p.tick=(o,e)=>applyWoundingTick(o,e,p);return p;}
  healingProviders(context){const s=this.session;return{...this.regenerationProviders(context),asDoor:o=>o.objectType===10?o:null,asPlaceable:o=>o.objectType===9?o:null,
    feedback:async(o,code,data)=>{await sendCombatFeedback(o,code,data,s.combat.broadcastProviders());
      // Preserve the local HP log while native feedback151 presentation is
      // still diagnosed by the renderer. Only the target emits this adapter.
      if(o.id===data.objectIds?.[0])s.onMessage({type:'heal',id:o.id,amount:data.integers[0],text:`Hit points healed: ${data.integers[0]}`});},
    currentHP:(o,baseOnly)=>o.objectType===5?baseOnly===0?s.hitPoints(o.id,false):o.stats.currentHP:s.hitPoints(o.id,false),
    dying:o=>Number(s.isDying(o)),writeHP:(o,n)=>{if(o.objectType===5){o.stats.currentHP=n;s.damage.synchronize(o);}else o.currentHP=n;},
    clearActions:o=>s.combat.clearActions(o),ambient:o=>recomputeAmbientAnimation(o,{dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),setAnimation:(...args)=>s.combat.setAnimation(...args)}),
    floaty:(o,id)=>broadcastEffectFloaty(o,id,this.visualProvidersWithFloaty()),client:id=>s.combat.broadcastProviders().client(id),
    destroyDeathGUI:client=>s.onCombatMessage({recipientId:client.object.id,type:'destroyDeathGUI',messageType:36,subtype:2}),
    remove:(o,id)=>this.remove(o.id,id,context),encumbrance:(o,n)=>s.combat.encumbrance(o,n)};}
  defenseProviders(){const s=this.session;return{copyConstruct:(...a)=>this.copyConstruct(...a),dead:o=>Number(s.isDead(o)),plot:o=>Number(o.plot),object:id=>s.registry.get(id),
    immunity:(...args)=>s.combat.immunity(...args),resistance:o=>s.combat.spellResistance(o),effects:o=>o.effects,
    setCache:(o,down,value)=>{o[down?'nativeSpellResistanceDecreaseD85':'nativeSpellResistanceIncreaseD84']=value;s.updateNativeCombatInformation(o);},
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
    }
    return this.applyNative(effect,objectId,context);
  }
  // Internal OnApplyEffect children retain equipped/innate duration3/4. Only
  // the NWScript wrapper above normalizes its public duration argument.
  applyNative(value,objectId,context,loading=0,special=0){
    const object=this.session.registry.get(objectId),before=new Set(object?.effects??[]),capturedWorldTime=this.session.worldTimer.time(),finish=()=>{
      const inserted=(object?.effects??[]).filter(effect=>effect.id===value?.id&&!before.has(effect));
      if(object&&inserted.some(effect=>effect.type===value?.type))finishEffectApplicationFlag(object,value,0,special,{remove:(o,id)=>this.remove(o.id,id,context)});
      for(const effect of inserted){
        // Linked children have their own ApplyEffect calls. Their deadlines
        // must not be recomputed by a consuming parent wrapper afterward.
        if(!this.expiryFinalized.has(effect)){initializeEffectExpiry(effect,loading,capturedWorldTime,this.session.worldTimer);this.expiryFinalized.add(effect);}
        trackCasterEffect(object,effect,{object:id=>this.session.registry.get(id),asWorld:asNWSObject});
      }
      if(object&&(value?.type&65535)===40)return finishEffectApplicationFlag(object,value,1,special,{remove:(o,id)=>this.remove(o.id,id,context)});
    };
    const result=this.applyNativeBody(value,objectId,context,loading);if(result?.then)return result.then(async value=>{await finish();return value;});const finalized=finish();if(finalized?.then)return finalized.then(()=>result);return result;
  }
  applyNativeBody(value,objectId,context,loading=0){
    const object = this.session.registry.get(objectId);
    if (!object || !['player', 'creature', 'door', 'placeable', 'item', 'trigger', 'store', 'encounter', 'waypoint','areaOfEffect'].includes(object.kind)) return;
    if (!value?.type) return;
    if([84,86].includes(value.type)){
      const effect=structuredClone(value);return(value.type===84?applyWounding:applyVampiricRegeneration)(object,effect,this.woundingProviders(context),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    }
    if([64,98].includes(value.type)){
      const effect=structuredClone(value),result=(effect.type===64?applyTimeStop:applyTimeStopImmunity)(object,effect,this.timeStopProviders(),loading);
      const finish=consumed=>{if(consumed===0)this.retain(object,effect);};return result?.then?result.then(finish):finish(result);
    }
    if(value.type===91){
      const effect=structuredClone(value);
      if((effect.durationType&7)===1){
        if(!Number.isFinite(effect.duration)||effect.duration<0)throw new Error('Native negative/nonfinite item-property lifetime is unavailable');
      }
      return this.session.items.applyProperty(object,effect).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    }
    if (![94,18,25,92,44,45,77,88,62,63,68,83,82,4,7,5,35,6,81,1,3,8,9,28,29,31,32,36,37,46,47,69,70,71,72,73,74,75,89,76,41,42,59,61,2, 12, 19,20,21, 23, 30,33,34,40,50,51,52,54,65,67, 38, 39, 93, 10, 11, 13, 14, 15, 16, 17, 22, 26, 27, 48, 49, 55, 56].includes(value.type)) throw new Error(`Effect type ${value.type} is not implemented`);
    const effect = structuredClone(value);
    if(effect.type===18)return applyEntangle(object,effect,this.entangleProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===94)return applyCutsceneImmobile(object,effect,this.entangleProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if([25,92].includes(effect.type))return applySpellFailure(object,effect,this.spellFailureProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===44){if(applyModifyAttacks(object,effect,{...this.hasteProviders(),asCreature:o=>o?.objectType===5?o:null},loading)===0)this.retain(object,effect);return;}
    if(effect.type===45)return applyCurse(object,effect,this.curseProviders(context),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if([77,88].includes(effect.type)){if(applyTurnResistance(object,effect,loading,{dead:o=>Number(this.session.isDead(o)),asCreature:o=>o.objectType===5?o:null,rule:(name,fallback)=>rulesetInt(this.session.characterRules,name,fallback)})===0)this.retain(object,effect);return;}
    if(effect.type===63)return applySanctuary(object,effect,this.sanctuaryProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===62)return applyPolymorph(object,effect,this.polymorphProviders(context),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===68)return applyRacialType(object,effect,{asCreature:o=>o.objectType===5?o:null,raceFeats:id=>this.raceFeats(id),copyConstruct:(...args)=>this.copyConstruct(...args),setCreator:(...args)=>this.setCreator(...args),apply:(o,e,loading)=>this.applyNative(e,o.id,context,loading)},loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===35||effect.type===5)return(effect.type===35?applyPoison:applyDisease)(object,effect,this.afflictionProviders(context),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===7)return applyRegeneration(object,effect,this.regenerationProviders(context),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===39)return applyHealing(object,effect,this.healingProviders(context),loading);
    if(effect.type===4)return applyResurrection(object,effect,this.healingProviders(context));
    if(effect.type===82)return applyNegativeLevel(object,effect,this.negativeLevelProviders(context),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===83){if(applyBonusFeat(object,effect)===0){this.retain(object,effect);this.session.refreshCombat(object);}return;}
    if(effect.type===54)return applyLightEffect(object,effect,{asCreature:o=>o.objectType===5?o:null,copyConstruct:e=>this.copyConstruct(e),apply:(o,e,loading)=>this.applyNative(e,o.id,context,loading)},loading).then(consumed=>{
      if(consumed===0)this.retain(object,effect);
      if(object.objectType===5)runtimeDiagnostics.record('effects.light-retained','Native equipped light effect retained for duration visual presentation',{...this.session.diagnosticContext(object.id),effectId:effect.id,visualId:effect.integers[0]},'info');
    });
    if(effect.type===81)return applyAppearEffect(object,effect,{asCreature:o=>o.objectType===5?o:null,clear:o=>this.session.combat.clearActions(o),add:(...a)=>this.session.combat.addAppear(...a)});
    if(effect.type===6)return this.session.lifecycle.applySummon(object,effect,loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===61)return applyDamageShield(object,effect,this.damageBuffProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if(effect.type===51||effect.type===52){const s=this.session;return applyDispel(object,effect,{object:id=>s.registry.get(id),effects:o=>o.effects,
      level:o=>creatureRoot(o).ClassList.reduce((n,c)=>n+(c.ClassLevel&255),0)&255,roll:(...a)=>s.random.dice(...a),spell:id=>s.spellBook.castingSpell(id),
      enqueue:(...a)=>s.combat.enqueueEvent(...a),...s.combat.broadcastProviders()},effect.type===52);}
    if(effect.type===21)return applyDeafness(object,effect,this.visionProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if([69,70,71,72,73,74,75,89].includes(effect.type)){
      const p=this.visionProviders(),run=effect.type===73?applyBlindness(object,effect,this.session.characterRules,p,loading):
        effect.type===74?applyDarkness(object,effect,p,loading):effect.type===69?applyVisionFilter(object,effect,p,loading):
        effect.type===75?applyMissChance(object,effect,p,loading):effect.type===89?applyInactiveBlindness(object,effect,p,loading):
        applyVisionSource(object,effect,p,loading);
      return Promise.resolve(run).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    }
    if(effect.type===32)return applyBeamEffect(object,effect,{...this.linkedProviders(),copyConstruct:(...a)=>this.copyConstruct(...a)},loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
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
    if([10,11,26,27,48,49].includes(effect.type))return applyStatEffect(object,effect,this.statProviders(),loading).then(consumed=>{
      if(consumed===0){this.retain(object,effect);this.session.refreshCombat(object);}
    });
    if([2,12,13,14,16,17].includes(effect.type))return([16,17].includes(effect.type)?applyDamageImmunityBuff:applyDamageBuff)(object,effect,this.damageBuffProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if([8,9].includes(effect.type))return(effect.type===8?applyEnchantment:applyEnchantmentController)(object,effect,this.enchantmentProviders(),loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
    if([1,3,41,42,28,29,59].includes(effect.type)){
      const result=[1,3].includes(effect.type)?applyHasteOrSlow(object,effect,this.hasteProviders(),loading):
        [41,42].includes(effect.type)?applyHasteController(object,effect,this.session.characterRules??{},this.hasteProviders(),loading):
        (effect.type===59?applyAttackCountEffect:applySpeedEffect)(object,effect,this.speedProviders(),loading);
      return result.then(consumed=>{if(consumed===0)this.retain(object,effect);});
    }
    if (effect.type === 38) return this.session.damage.apply(object, effect, context,loading);
    if (effect.type === 19) return this.session.damage.death(object,effect,context,loading);
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
      const active=object.effects??=[],index=active.findIndex(e=>e.type>effect.type);
      if(index<0)active.push(effect);else active.splice(index,0,effect);
    });
    if(effect.type===23){
      applyAIStateEffect(object,effect,this.knockdownProviders());
      const active=object.effects??=[],index=active.findIndex(e=>e.type>effect.type);
      if(index<0)active.push(effect);else active.splice(index,0,effect);
      return;
    }
    if([55,56].includes(effect.type))return applySkillBuff(object,effect,{...this.statProviders(),asCreature:o=>o?.objectType===5?o:null},loading).then(consumed=>{if(consumed===0)this.retain(object,effect);});
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
    if (effect.type === 22) {
      if (object.objectType !== 5 || this.session.isDead(object)) return;
      if (!object.stats?.combat?.saves) throw new Error('Combat effect target stats are not loaded');
      this.retain(object,effect);
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
    const object=this.session.registry.get(objectId);
    return object?removeEffectsById(object,effectId,this.removalProviders(context)):0;
  }
  removeCreator(objectId,creatorId){
    // Equipped-property cleanup adapter: preserve the live cursor when a
    // callback retains a record, rather than retrying it without advancing time.
    const object=this.session.registry.get(objectId);let index=0;
    const step=status=>{if(status!==1)index++;},next=()=>{
      while(index<(object?.effects??[]).length){const effect=object.effects[index];
        if(effect.creatorId!==(creatorId>>>0)){index++;continue;}
        const result=this.removeOne(objectId,effect.id,undefined,effect);
        if(result?.then)return result.then(status=>{step(status);return next();});step(result);
      }
    };return next();
  }
  removalProviders(context){
    const s=this.session;
    const p={object:id=>s.registry.get(id),asWorld:asNWSObject,
      onRemove:(o,e)=>this.onRemove(o,e,context),
      // Current native effect-index consumers derive their indices directly
      // from this same sorted live array. Attribute updates follow erasure.
      afterRemove:(o,e)=>this.afterRemove(o,e),
      removeTarget:(o,id)=>removeEffectTarget(o,id,p)};
    return p;
  }
  removeOne(objectId, effectId, context,effectReference=null) {
    const object = this.session.registry.get(objectId), index = object?.effects?.findIndex(e => effectReference?e===effectReference:e.id === effectId) ?? -1;
    if(index<0)return 0;
    return removeEffectRecord(object,object.effects[index],this.removalProviders(context));
  }
  onRemove(object,effect,context){
    if(effect.type===64)return removeTimeStop(object,effect,this.timeStopProviders());
    if(effect.type===98)return removeTimeStopImmunity(object,effect,this.timeStopProviders());
    if(effect.type===18)return removeEntangle(object,effect,this.entangleProviders());
    if([25,92].includes(effect.type))return removeSpellFailure(object,effect,this.spellFailureProviders());
    if(effect.type===44)return removeModifyAttacks(object,effect,{asCreature:o=>o?.objectType===5?o:null,effects:o=>o.effects});
    if([13,14,16,17].includes(effect.type))return removeDamageBuff(object,effect,this.damageBuffProviders());
    if([10,11,26,27,48,49].includes(effect.type))return removeStatEffect(object,effect,this.statProviders());
    if(effect.type===62)return removePolymorph(object,effect,this.polymorphProviders(context));
    if(effect.type===68)return removeRacialType();
    if(effect.type===91)return this.session.items.removeProperty(object,effect).then(()=>1);
    if(effect.type===15)return this.session.damage.removeTemporary(object,effect,context).then(()=>1);
    if(effect.type===83)return removeBonusFeat(object,effect);
    if(effect.type===82)return removeNegativeLevel(object,effect,this.negativeLevelProviders(context));
    if(effect.type===6)return this.session.lifecycle.removeSummon(object,effect);
    if(effect.type===73)return removeBlindness(object,effect,this.visionProviders());
    if(effect.type===74)return removeDarkness(object,effect,this.visionProviders());
    if([70,71,72].includes(effect.type))return removeVisionSource(object,effect,this.visionProviders());
    if(effect.type===46)return removeSilence(object);
    if(effect.type===47)return removeInvisibility(object,effect,this.invisibilityProviders());
    if(effect.type===63)return removeSanctuary(object,effect,this.sanctuaryProviders());
    if(effect.type===31)return this.session.areaEffects.removeAttached(object,effect).then(()=>1);
    if([8,9].includes(effect.type))return(effect.type===8?removeEnchantment:removeEnchantmentController)(object,effect,this.enchantmentProviders());
    if([1,3].includes(effect.type))return removeHasteOrSlow(object,effect,this.hasteProviders());
    if([41,42].includes(effect.type))return removeHasteController(object,effect);
    if([28,29].includes(effect.type))return removeSpeedEffect(object,effect,this.speedProviders());
    if(effect.type===59)return removeAttackCountEffect(object,effect,this.speedProviders());
    if(effect.type===67)return removeEffectIcon(object,effect);
    if([33,34].includes(effect.type))return removeSpellResistanceEffect(object,effect,this.defenseProviders());
    // These adapters expose lower void/bool helpers; the handler itself
    // returns1 (e.g. OnRemoveVisualEffect140439aa4), independently of success.
    if(effect.type===30)removeVisualEffect(object,effect);
    if(effect.type===23)removeAIStateEffect(object,effect,this.knockdownProviders());
    if(effect.type===20)removeKnockdown(object,effect,this.knockdownProviders());
    if (effect.type === 93 && object.objectType === 5) object.cutsceneGhost = false;
    return 1;
  }
  afterRemove(object,effect){
    if(effect.type===83){this.session.refreshCombat(object);return;}
    if([36,37].includes(effect.type)&&object.objectType===5)return updateAbilityAttributes(object,effect,this.abilityProviders(),0);
    if ([13, 14].includes(effect.type) && object.objectType === 5) object.combatInformationDirty = 1;
    if ([10, 11, 26, 27, 48, 49].includes(effect.type)) {this.session.refreshCombat(object);return;}
    if (effect.type === 22) {
      this.session.refreshCombat(object);
    }
  }
  async update() {
    for (const object of this.session.registry.objects.values()) await this.updateObject(object);
  }
  async updateObject(object,capturedNow) {
    if(!(object.effects?.length))return;
    const clock=this.session.activeTimer(object.id),now=capturedNow??clock.time(),regenerationScratch={day:0,time:0};
    return updateEffectList(object,{poll:(object,effect)=>{
      if(effect.type===7){
        return updateRegeneration(object,effect,now,regenerationScratch,this.regenerationProviders());
      }
      if(effect.type===84)return updateWounding(object,effect,now,regenerationScratch,this.woundingProviders());
      if([5,35].includes(effect.type)){
        return updateAffliction(object,effect,now,this.afflictionProviders());
      }
      // UpdateEffectList uses CompareWorldTimes == 1, strictly AFTER expiry.
      return false;
    },expired:effect=>{
      // GetExpiryTime writes the SAME pass-local pair used by regeneration
      // subtraction. A later failed subtraction retains these output values.
      regenerationScratch.day=effect.expiryDay;regenerationScratch.time=effect.expiryTime;
      return effectHasExpired(effect,now,clock);
    },remove:(object,id)=>this.remove(object.id,id)});
  }
}
