import { endCombatRoundAsync, startCombatRoundAsync, initialAttackCombatStep, weaponAttackType, offhandAttack, addAttackOfOpportunity, addParryAttack, addParryIndex } from './combat_round.js';
import { actionPending, updateRoundTimer } from './combat_timing.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { desiredAttackRange, maximumAttackRange } from './combat_range.js';
import { dispatchAttackRoundAction } from './combat_action.js';
import { addAttackRequest } from './combat_request.js';
import { addObjectAction, computeAIState, runObjectActions, spellOrHealActionQueued, clearObjectActions, removeObjectActionGroup, manageObjectActions } from './object_actions.js';
import { evaluateAttackEligibility } from './attack_eligibility.js';
import { weaponRule, currentAttackWeapon } from './combat_weapon.js';
import { setCreatureAnimation, setCreatureCombatState, setLockOrientation, changeAttackTarget, clearCreatureAttackAction, clearCreatureMovementAction, clearCreatureCombatMode } from './combat_lifecycle.js';
import { resolveMeleeGroup, resolveRangedGroup, signalMeleeDamage, signalRangedDamage } from './combat_strike.js';
import { resolveMeleeAnimations } from './combat_animation.js';
import { receiveAttackEvent } from './combat_events.js';
import { resolveStrikeDamage, resolvePostStrikeDamage } from './combat_damage_resolution.js';
import { abilityModifier } from './combat_stats.js';
import { creatureRoot } from './creature_rules.js';
import { isFlatFooted, creatureClassLevel, criticalProfile } from './combat_weapon.js';
import { skillRank, effectiveSkillRank, canUseSkill } from './skill_rank.js';
import { resolveSituationalModifiers, resolveCachedSpecialAttacks } from './combat_strike_preparation.js';
import { resolveStrikeRoll } from './combat_roll_resolution.js';
import { getFlanked, resolvePrecisionAttack } from './combat_sneak.js';
import { effectImmunity } from './effect_immunity.js';
import { resolveDefensiveEffects } from './combat_defense.js';
import { savingThrowRoll, savingThrowWithoutEffects } from './combat_saving_throw.js';
import { savingThrowEffectBonus, skillEffectBonus, itemArmorClass } from './combat_modifiers.js';
import { creatureAlignment } from './creature_rules.js';
import { getBlind } from './perception.js';
import { hasNativeFeat, featUses, highestFeat, initializeFeatUses } from './feat_uses.js';
import { broadcastCombatState, broadcastBattleCry, broadcastAttackData, broadcastSavingThrow, broadcastSkillData, sendCombatFeedback, receiveCombatFeedback, setExcitedState, removeCombatInvisibility } from './combat_broadcast.js';
import { rulesetInt, intEntry } from './combat_stats.js';
import { broadcastOpportunityAttack, hasCombatInvisibility } from './combat_opportunity.js';
import { areaObjectsByX, areaSpatialIds, firstAreaSpatialIndex } from './nearest_objects.js';
import { OBJECT_INVALID } from './game_object_array.js';
import { classSkillUsable } from './skill_caches.js';
import { invisibleVersus } from './combat_visibility.js';
import { attackModifierVersus,favoredEnemyBonus } from './attack_modifier.js';
import { armorClassVersus, creatureSize } from './combat_context.js';
import { attackDamageFlags } from './damage_weapon.js';
import { savingThrowSpell } from './spell_metadata.js';
import { resolveOnHitProperties, resolveItemOnHitSpells, resolveOnHitVisuals } from './combat_on_hit.js';
import { attackResultDoesDamage } from './combat_strike.js';
import { advanceExcitedDuration, advanceCombatStateTimers } from './combat_frame.js';
import { weaponEffective } from './combat_weapon_effectiveness.js';
import { addPersonalReputation,adjustFactionReputation,adjustCombatReputations,reputationAdjustments } from './combat_reputation.js';
import { executeAttackAction } from './combat_attack_action.js';
import { prepareAndResolveAttack,associateId,manageCreatureActivities } from './combat_attack_preparation.js';
import { setCombatMode,setCombatActivity } from './combat_mode.js';
import { doCombatStep,prepareCombatStep,applyCombatStep } from './combat_step.js';
import { noCreaturesOnLine } from './creature_line.js';
import { nativeAsinf, nativeAtan2f, nativeCosf, nativeSinf } from './native_math.js';
import { NativeIdList } from './native_id_list.js';
import { queueAttackApproach, executeWait, checkMoveRadius, checkInterArea } from './movement_actions.js';
import { attackClearLine, nearestEnemy, newCombatTarget } from './combat_target.js';
import { getUseRange, isInUseRange } from './use_range.js';
import { executeMoveToPoint } from './move_to_point.js';
import { plotPath } from './path_plot.js';
import { walkPath,walkDistance,testWalkDistance } from './path_walk.js';
import { movementRate } from './movement_rate.js';
import { intersectSubareas,intersectSubareaPolygon } from './subareas.js';
import { testSafeLocationPoint } from './safe_location.js';
import { createLocalClientPanelState,autoClosePanels } from './client_panels.js';
import { plotGridPath } from './path_grid.js';
import { smoothPath } from './path_smoothing.js';
import { creatureBumpable } from './creature_bump.js';
import { spotDetection,listenDetection,stealthDetection,updateCreaturePerception,updateVisibleList } from './perception_detection.js';
import { clearHostileActionsVersus } from './combat_hostile.js';
import { receivePerceptionEvent } from './perception_events.js';
import { spawnHeartbeatPerception,cleanPersonalReputations,cleanInvitationLists } from './creature_heartbeat.js';

// Partial local AI frame adapter. It advances round timing before effect
// expiry. Native AI levels, perception, movement and strike dispatch remain
// separate required providers, not implicitly successful operations.
export class CombatRuntime {
  constructor(session) { this.session = session; }
  async updateSpawnHeartbeat(actor,frame=1,providers={}){
    const s=this.session,p={dayLength:s.worldTimer.dayLength,activeTime:()=>s.worldTimer.time(),worldTime:()=>s.worldTimer.time(),
      random:()=>s.random.next(),dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),pc:o=>Number(o.isPC),
      possessed:o=>Number(o.isPossessedFamiliar??false),rulesetInt:(name,value)=>rulesetInt(s.characterRules,name,value),
      creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},area:o=>s.registry.get(o.areaId)??null,
      client:id=>this.broadcastProviders().client(id),updateVisibility:o=>this.updateVisibility(o),
      runEvent:(o,index)=>s.damage.runEvent(o,o.scripts?.[index===8?'spawn':'heartbeat']),
      cleanReputations:o=>cleanPersonalReputations(o,p),cleanInvitations:(o,force)=>cleanInvitationLists(o,force,p),
      feedback:(...args)=>sendCombatFeedback(...args,this.broadcastProviders()),
      clearActions:o=>this.clearActions(o),enqueue:(...args)=>this.enqueueEvent(...args),
      setAILevel:(o,level)=>s.aiMaster.setLevel(o,level),
      tile:(area,position)=>area.nativeGeometry.tileAt([position[0],Math.fround(-position[2])]),
      // Automap presentation is a recorded omission. It must not abort the
      // combat/perception timestamp refresh or silently claim explored data.
      updateAutoMap:o=>runtimeDiagnostics.record('combat.automap-unimplemented','Native UpdateAutoMap data lifecycle is not implemented',s.diagnosticContext(o.id)),
      controlScript:(o,type)=>this.unsupported(o,`Native control script ${type} lookup is not implemented`),
      removeDomination:o=>this.unsupported(o,'Native associate RemoveDomination is not implemented'),
      setAssociateType:o=>this.unsupported(o,'Native SetAssociateType lifecycle is not implemented'),
      setMasterId:o=>this.unsupported(o,'Native SetMasterId lifecycle is not implemented'),...providers};
    try{return await spawnHeartbeatPerception(actor,frame,p);}
    catch(error){s.report(error,s.diagnosticContext(actor.id));throw error;}
  }
  async updateBeforeTimer(actor){
    // AIUpdate14037c4c6..14037c541. Promotions precede spawn/heartbeat.
    const s=this.session,master=s.registry.get(actor.masterId);
    if(actor.masterId!==OBJECT_INVALID&&actor.nativeAILevel7c!==3&&master?.objectType===5&&Number(master.isPC)===1)s.aiMaster.setLevel(actor,3);
    if((Number(actor.isPC)===1||Number(actor.isDM)===1)&&actor.nativeAILevel7c!==4)s.aiMaster.setLevel(actor,4);
    return this.updateSpawnHeartbeat(actor,1);
  }
  perceptionProviders(providers={}){
    const s=this.session;
    return{area:o=>s.registry.get(o.areaId)??null,dm:o=>Number(Boolean(o.isDM)),hasFeat:(o,id)=>this.hasFeat(o,id),
      skillRank:(...args)=>this.skill(...args),worldTime:()=>s.worldTimer.time(),dayLength:s.worldTimer.dayLength,
      rollDice:(count,sides)=>s.random.dice(count,sides),client:o=>this.broadcastProviders().client(o.id),
      favoredEnemyBonus:(o,t)=>favoredEnemyBonus(o,t,s.characterRules),rulesetInt:(name,value)=>rulesetInt(s.characterRules,name,value),
      creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},object:id=>{const o=s.registry.get(id);return o&&o.objectType>=5&&o.objectType<=14?o:null;},
      itemInSlot:(o,slot)=>s.registry.get((o.inventory??[]).find(id=>s.registry.get(id)?.equipmentSlot===slot))??null,
      visibility:(o,id)=>this.visibility(o,id),visualTypes:o=>o.nativeVisualTypes160,timeOfDay:()=>s.module?.nativeTimeOfDay3d4,
      invisibleCreatureIds:()=>s.module?.nativeInvisibleCreatureIds330,
      invisible:(...args)=>this.invisible(...args),clearHostileActions:(o,t)=>this.clearHostileActions(o,t),
      enqueue:(...args)=>this.enqueueEvent(...args),
      dead:o=>Number(s.isDead(o)),pc:o=>Number(o.isPC),controlled:o=>Number(this.broadcastProviders().client(o.id)!==null),
      spatial:area=>area.nativeSpatial,markPerceptionWork:()=>{s.nativeAIFieldB0=1;},
      updatePerception:(...args)=>this.updatePerception(...args),
      lineOfSight:(area,...args)=>{if(!area?.nativeGeometry?.lineOfSight)throw new Error('Native perception area LOS is unavailable');return area.nativeGeometry.lineOfSight(...args);},
      ...providers};
  }
  async detectStealth(actor,target,clear,out,retained=0,providers={}){
    const p=this.perceptionProviders(providers);
    p.listen??=(...args)=>listenDetection(...args,p);p.spot??=(...args)=>spotDetection(...args,p);
    try{return await stealthDetection(actor,target,clear,out,retained,p);}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  async updatePerception(actor,target,force=0,providers={}){
    const p=this.perceptionProviders(providers);
    p.stealthDetection??=(...args)=>this.detectStealth(...args,p);
    try{return await updateCreaturePerception(actor,target,force,p);}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  async clearHostileActions(actor,target,providers={}){
    try{return await clearHostileActionsVersus(actor,target,{removeGroup:(o,id)=>removeObjectActionGroup(o,id,{clearAction:(...args)=>this.clearAction(...args)}),...providers});}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  async updateVisibility(actor,providers={}){
    try{return await updateVisibleList(actor,this.perceptionProviders(providers));}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  reputationMutationProviders(){
    const s=this.session;
    return{table:s.factionTable,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      worldTime:()=>s.worldTimer.time(),client:id=>this.broadcastProviders().client(id)};
  }
  async adjustReputations(targetId,actorId,operation){
    const s=this.session,mutation=this.reputationMutationProviders();
    return adjustCombatReputations(targetId,actorId,operation,{
      ...mutation,dm:o=>Number(Boolean(o.isDM)),area:o=>s.registry.get(o.areaId)??null,
      firstByX:(area,x)=>firstAreaSpatialIndex(s,area,x),
      areaIds:area=>areaSpatialIds(s,area),dead:o=>Number(s.isDead(o)),
      visibility:(o,id)=>o.perception?.get(id)??null,reputation:(o,id)=>s.reputation(o,s.registry.get(id)),
      adjustments:op=>reputationAdjustments(s.characterRules.repadjust)[op],
      npcFaction:o=>{if(!s.factionTable)throw new Error('Native faction manager is unavailable');return Number(s.factionTable.isNPC(o.factionId));},
      personal:(...args)=>addPersonalReputation(...args,mutation),faction:(...args)=>adjustFactionReputation(...args,mutation)});
  }
  async clearAttackActivity(actor,bit,value){
    if(value!==0||![1,2,8].includes(bit))this.unsupported(actor,`Native SetActivity(${bit},${value}) is not implemented`);
    if((actor.lockedActivities&bit)===bit)return;
    if(!(actor.activities&bit))return;
    if(bit===1&&actor.nativeField6ed!==0||bit===2&&actor.nativeField6ec!==0)
      this.unsupported(actor,'Native stealth/detect change requires movement-rate effect lifecycle');
    if(bit===8&&actor.counterSpellTargetId!==OBJECT_INVALID)
      this.unsupported(actor,'Native counterspell removal lifecycle is not implemented');
    actor.activities=(actor.activities&~bit)>>>0;
    if(bit===8)this.setLock(actor,OBJECT_INVALID);
  }
  async resolveAttack(actor,targetId,count,duration,providers={}){
    const s=this.session,creature=id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;};
    try{return await prepareAndResolveAttack(actor,targetId,count,duration,{
      object:id=>s.registry.get(id)??null,creature,setAnimation:(o,state)=>this.setAnimation(o,state),
      reputations:(...args)=>this.adjustReputations(...args),associateId:(o,t,n)=>associateId(o,t,n,creature),
      client:id=>this.broadcastProviders().client(id),unpossess:o=>this.unsupported(o,'Native familiar unpossession is not implemented'),
      associateCommand:(o,code)=>this.unsupported(o,`Native ReceiveAssociateCommand ${code} is not implemented`),
      removeEffect:o=>this.unsupported(o,'Native type8 charm/domination removal side effects are not implemented'),
      activityManager:(o,request)=>manageCreatureActivities(o,request,(...args)=>this.clearAttackActivity(...args)),
      ranged:o=>this.rangedEquipped(o),rangedAttack:(...args)=>this.resolveRanged(...args),meleeAttack:(...args)=>this.resolveMelee(...args),...providers});}
    catch(error){s.report(error,s.diagnosticContext(actor.id));throw error;}
  }
  async executeAttack(actor,node,providers={}){
    try{return await executeAttackAction(actor,node,{
      evaluate:(o,id)=>this.evaluateAttack(o,id),setAnimation:(o,state)=>this.setAnimation(o,state),
      changeTarget:(o,n,id)=>this.changeTarget(o,n,id),
      approach:(o,n,e)=>queueAttackApproach(o,n,e,{
        object:id=>this.session.registry.get(id),changeTarget:(...args)=>this.changeTarget(...args),
        newTarget:(actor,id)=>this.newTarget(actor,id),
        feedback:(actor,code)=>sendCombatFeedback(actor,code,null,this.broadcastProviders()),ranged:o=>this.rangedEquipped(o),
        setLock:(...args)=>this.setLock(...args),
      }),
      startRound:(o,id)=>this.startRound(o,id),
      dispatch:(o,id,valid,n)=>{
        let preparedStep;const stepProviders=this.combatStepProviders();
        return this.dispatchAttack(o,id,valid,{
        setAnimation:(o,state)=>this.setAnimation(o,state),face:(o,id)=>this.setLock(o,id),
        resolveAttack:(...args)=>this.resolveAttack(...args),changeTarget:(o,id)=>this.changeTarget(o,n,id),
        preflightRoundAction:async(o,action,type,id)=>{
          if([4,5].includes(type))preparedStep=await prepareCombatStep(o,Number(type===4),action.duration|0,id,stepProviders);
        },
        combatStep:o=>applyCombatStep(o,preparedStep,stepProviders),
        // Unavailable equipment and skip callbacks stay absent so preflight
        // preserves their due record before the native dequeue boundary.
        weaponAttackType:o=>weaponAttackType(o.combatRound,this.session.equippedItems(o),this.session.random),
        });},
      newTarget:(o,id)=>this.newTarget(o,id),...providers});}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  hasFeat(object,id) { return hasNativeFeat(object,id,o=>itemArmorClass(this.session.equippedItems(o).find(i=>i.slot===2),this.session.characterRules)); }
  featProviders(object) {
    return {hasFeat:(o,id)=>this.hasFeat(o,id),isDM:o=>Number(Boolean(o.isDM||creatureRoot(o).IsDM)),
      charismaModifier:o=>abilityModifier(o.stats.equippedAbilities.Cha,this.session.characterRules),
      warning:message=>this.warning(object,message)};
  }
  initializeFeatUses(object) { return initializeFeatUses(object,this.session.characterRules,this.featProviders(object)); }
  remainingUses(object,id) { return featUses(object,id,this.session.characterRules,this.featProviders(object)); }
  totalUses(object,id) { return featUses(object,id,this.session.characterRules,this.featProviders(object),false); }
  highestFeat(object,id) { return highestFeat(object,id,this.session.characterRules,this.featProviders(object)); }
  decrementUses(object,id) {
    if(!object.featUsePool)throw new Error('Native feat-use pool is unavailable');
    object.featUsePool.decrement(id);
  }
  enqueueEvent(eventId, callerId, targetId, milliseconds, payload) {
    if (![eventId, callerId, targetId, milliseconds].every(Number.isInteger)) throw new Error('Native combat event metadata is unavailable');
    return this.session.scheduler.enqueueMilliseconds(targetId >>> 0,
      { type: 'combatAI', eventId: eventId >>> 0, callerId: callerId >>> 0, payload }, milliseconds >>> 0);
  }
  async receiveAttack(target, callerId, data, providers = {}) {
    const session = this.session;
    try { return await receiveAttackEvent(target, callerId, data, {
      creature: id => session.registry.get(id)?.objectType === 5 ? session.registry.get(id) : null,
      equippedItem: (a, slot) => session.registry.get((a.inventory ?? []).find(id => session.registry.get(id)?.equipmentSlot === slot)) ?? null,
      initiative: a => session.damage.initiative(a), isDead: a => Number(session.isDead(a)),
      broadcastAttack:(t,a,d)=>broadcastAttackData(t,a,callerId,d,this.broadcastProviders()),
      broadcastState:a=>broadcastCombatState(a,this.broadcastProviders()),
      setLastHostile:(o,id)=>session.damage.setLastHostile(o,{id}),
      removeInvisibility:a=>this.removeInvisibility(a),associateCommand:(a,code)=>this.associateCommand(a,code),
      associateScripts:()=>rulesetInt(session.characterRules,'ALL_ASSOCIATES_RUN_SCRIPTS',0),
      requestAttack:(...args)=>this.requestAttack(...args),
      runAttacked: a => session.damage.runEvent(a, a.scripts?.attacked), ...providers
    }); }
    catch (error) { session.report(error, session.diagnosticContext(target.id)); throw error; }
  }
  async dispatchEvent(target, event) {
    // Creature event 5 at 0x14038e51e..0x14038e565. Other combat event
    // handlers remain explicit; never infer completion from a known ID.
    if (event.eventId === 5) {
      if (target.objectType !== 5) this.unsupported(target, 'Native noncreature combat effect event handler is unavailable');
      if (event.payload?.type === 40) this.unsupported(target, 'Native special effect event flag +180 is not implemented');
      if (event.payload) await this.session.effects.apply(0, event.payload, target.id);
    } else if(event.eventId===10){
      if(target.objectType!==5)this.unsupported(target,'Native noncreature perception event handler is unavailable');
      await receivePerceptionEvent(target,event.payload,{pc:o=>Number(o.isPC),scriptName:o=>o.scripts?.perception??'',
        runScript:async o=>{const name=o.scripts?.perception;if(name)await this.session.vm.run(await this.session.program(name),o.id);}});
    } else if(event.eventId===15){
      if(target.objectType!==5)this.unsupported(target,'Native noncreature attack event handler is unavailable');
      await this.receiveAttack(target,event.callerId,event.payload);
    } else if(event.eventId===22){
      if(target.objectType!==5)this.unsupported(target,'Native noncreature combat feedback handler is unavailable');
      await receiveCombatFeedback(target,event.callerId,event.payload,{
        creature:id=>this.session.registry.get(id)?.objectType===5?this.session.registry.get(id):null,
        savingThrow:(o,d)=>broadcastSavingThrow(o,d,this.broadcastProviders()),feedback:(o,code,d)=>sendCombatFeedback(o,code,d,this.broadcastProviders())});
    } else if(event.eventId===19)this.unsupported(target,'Native combat AI event 19 spell-impact handler is not implemented');
    else if(event.eventId===20){
      if(target.objectType!==5)this.unsupported(target,'Native noncreature opportunity attack handler is unavailable');
      // Payload is a raw object ID cast to void*, not an allocated record.
      const id=event.payload===null||event.payload===undefined||event.payload===0?OBJECT_INVALID:event.payload;
      await this.opportunityAttack(target,id,0);
    }
    else this.unsupported(target, `Native combat AI event ${event.eventId} is not implemented`);
  }
  broadcastProviders(){
    const s=this.session;
    const client=id=>{
      if(!s.player||s.player.id!==id||!s.player.stats)return null;
      if(s.nativeLocalClient?.object!==s.player)s.nativeLocalClient=createLocalClientPanelState(s.player);
      return s.nativeLocalClient;
    };
    return{client,clients:()=>{const local=client(s.player?.id);return local?[local]:[];},
      members:o=>{if(!Number.isInteger(o.factionId))throw new Error('Native combat faction is unavailable');return[...s.registry.objects.values()].filter(t=>t.objectType===5&&t.factionId===o.factionId).map(t=>t.id);},
      faction:o=>o.factionId,dm:o=>Number(Boolean(o.isDM)),ownerId:o=>o.masterId,
      send:(c,type,data,attack)=>s.onCombatMessage({recipientId:c.object.id,type,data,attack}),
      excited:(o,state)=>setExcitedState(o,state,s.characterRules,{client,area:o=>s.registry.get(o.areaId)??null,
        restController:a=>a.restController??null,nearestEnemy:()=>{throw new Error('Native rest enemy query is unavailable');},cancelRest:()=>{throw new Error('Native rest controller interruption is unavailable');}})};
  }
  async associateCommand(actor,code){
    if(!Array.isArray(actor.associateIds))throw new Error('Native associate list is unavailable');
    for(const id of actor.associateIds){const associate=this.session.registry.get(id);
      if(associate?.objectType===5)this.unsupported(associate,`Native ReceiveAssociateCommand ${code} is not implemented`);}
  }
  liveInvisibilityIndex(actor){
    const effects=actor.effects??[];
    if(effects.some((e,i)=>i&&e.type<effects[i-1].type))throw new Error('Native live effect ordering is unavailable');
    const index=effects.findIndex(e=>e.type>=47);return index<0?effects.length:index;
  }
  async invisible(actor,observer,feedback=0,providers={}){
    const s=this.session;
    return invisibleVersus(actor,observer,feedback,{
      creature:o=>o.objectType===5?o:null,effects:o=>o.effects??[],index:o=>this.liveInvisibilityIndex(o),
      reaction:(o,id)=>s.aiReaction(o,id),visibility:(o,id)=>o.perception?.get(id)??null,
      savingThrow:(...args)=>this.savingThrow(...args),addVisibility:(o,...args)=>o.perception.add(...args),
      pacify:o=>this.unsupported(o,'Native Sanctuary PacifyCreature lifecycle is not implemented'),...providers});
  }
  visibility(actor,id){
    if(!actor.perception)throw new Error('Native visibility list is unavailable');
    const flags=actor.perception.get(id);
    if(flags!==undefined&&!Number.isInteger(flags))throw new Error('Native visibility flags are unavailable');
    return{present:flags!==undefined,seen:flags!==undefined&&(flags&1)!==0};
  }
  rangedEquipped(actor){
    return Number((weaponRule(this.session.equippedItems(actor).find(i=>i.slot===16),this.session.characterRules,'RangedWeapon')&255)!==0);
  }
  async attackModifier(actor,target,data){
    const s=this.session,items=s.equippedItems(actor),targetItems=target?s.equippedItems(target):[];
    // This build actually calls GetInvisible(this, this->AsObject(), 0) at
    // 1403f813f..1403f8155. Do not replace that self observer with the defender.
    return attackModifierVersus(actor,target,s.characterRules,items,{
      round:actor.combatRound,attack:data,targetItems,areaFlags:s.registry.get(actor.areaId)?.flags??0,
      visibility:target?this.visibility(actor,target.id):null,attackerInvisible:target?await this.invisible(actor,actor)!==0:false,
      flanking:target?getFlanked(actor,target,(o,id)=>this.hasFeat(o,id))!==0:false,
      targetMeleeReach:target&&data.ranged!==0?maximumAttackRange(target,actor,s.characterRules,targetItems).distance:undefined,
      targetBlind:target?getBlind(target)!==0:false,targetRanged:target?this.rangedEquipped(target)!==0:false,
      hasFeat:(o,id)=>this.hasFeat(o,id),limit:s.combatLimits?.attack??20
    }).total;
  }
  async armorClass(target,actor,data){
    const s=this.session,items=s.equippedItems(actor),profile=attackDamageFlags(items,s.characterRules,data);
    for(const warning of profile.warnings)this.warning(actor,warning.reason);
    return armorClassVersus(target,actor,s.characterRules,s.equippedItems(target),{
      ranged:data.ranged!==0,attackType:data.attackType,damageFlags:profile.flags,
      flatFooted:isFlatFooted(target),visibility:this.visibility(target,actor.id),
      attackerInvisible:await this.invisible(actor,target)!==0,hasFeat:(o,id)=>this.hasFeat(o,id)
    }).total;
  }
  async opportunityAttack(actor,id,movement,providers={}){
    const s=this.session;
    try{return await broadcastOpportunityAttack(actor,id,movement,{
      markAI:value=>{s.nativeAIFieldB4=value;},
      areaCreatureIds:o=>{const area=s.registry.get(o.areaId);return area?areaObjectsByX(s,area).map(t=>t.id):null;},
      creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},visibility:(o,id)=>o.perception?.get(id)??null,
      dead:o=>Number(s.isDead(o)),maximumRange:(a,t)=>maximumAttackRange(a,t,s.characterRules,s.equippedItems(a)).distance,
      spellOrHealQueued:spellOrHealActionQueued,
      ranged:o=>Number((weaponRule(s.equippedItems(o).find(i=>i.slot===16),s.characterRules,'RangedWeapon')&255)!==0),
      reaction:(o,id)=>s.aiReaction(o,id),invisible:o=>hasCombatInvisibility(o.effects??[],this.liveInvisibilityIndex(o)),
      skillRank:(o,skill,t,base)=>this.skill(o,skill,t,base),random:s.random,
      broadcastSkill:(o,data)=>broadcastSkillData(o,data,this.broadcastProviders()),
      requestAttack:(...args)=>this.requestAttack(...args),addAttack:addAttackOfOpportunity,...providers
    });}catch(error){s.report(error,s.diagnosticContext(actor.id));throw error;}
  }
  async removeInvisibility(actor){
    return removeCombatInvisibility(actor,{effects:o=>o.effects??[],index:o=>this.liveInvisibilityIndex(o),
      integer:(e,index)=>e.integers?.[index]??0,remove:o=>this.unsupported(o,'Native type47/63 removal side effects are not implemented')});
  }
  warning(actor, message) { runtimeDiagnostics.record('combat.action-warning', message, this.session.diagnosticContext(actor.id)); }
  strikeProviders(actor, providers) {
    const session = this.session;
    return { weaponAttackType: a => weaponAttackType(a.combatRound, session.equippedItems(a), session.random),
      situational:(a,t,data)=>resolveSituationalModifiers(a,t,data,session.characterRules),
      cachedSpecial:a=>resolveCachedSpecialAttacks(a,message=>this.warning(a,message)),
      attackRoll:(a,t)=>this.resolveRoll(a,t),damage:(a,t)=>this.resolveDamage(a,t),postDamage:(a,t)=>this.resolvePostDamage(a,t),
      setAnimation: (a, state) => this.setAnimation(a, state),
      warning: message => this.warning(actor, message), ...providers };
  }
  damageStageProviders(actor, providers) {
    const session = this.session;
    return { creature:o=>o.objectType===5?o:null,hitPoints:o=>session.hitPoints(o.id,false),
      hasFeat:(o,id)=>this.hasFeat(o,id),remainingUses:(o,id)=>this.remainingUses(o,id),decrementUses:(o,id)=>this.decrementUses(o,id),
      offhand:o=>offhandAttack(o.combatRound),flatFooted:o=>Number(isFlatFooted(o)),
      damageRoll:(o,t,options)=>session.damage.roll(o,t,o.combatRound.attacks[Math.min(o.combatRound.currentAttack & 255,49)],
        {offhand:options.offhand!==0,critical:options.critical!==0,sneak:options.sneak!==0,death:options.death!==0,maximize:options.maximize!==0}),
      classLevel:creatureClassLevel,level:o=>o.stats.level & 255,
      position:o=>[o.position[0],-o.position[2],o.position[1]],
      abilityModifier:(o,ability)=>abilityModifier(o.stats.equippedAbilities[ability],session.characterRules),
      immortal:o=>o.immortal??creatureRoot(o)?.IsImmortal??0,
      attackWeapon:(o,hand)=>currentAttackWeapon(session.equippedItems(o),session.characterRules,hand,
        ()=>weaponAttackType(o.combatRound,session.equippedItems(o),session.random)),
      rangedEquipped:o=>Number((weaponRule(session.equippedItems(o).find(i=>i.slot===16),session.characterRules,'RangedWeapon')&255)!==0),
      energyBonus:(o,t,data)=>session.damage.effectBonus(o,t,data,{energy:true}),random:session.random,
      savingThrow:(...args)=>this.savingThrow(...args),effectImmunity:(...args)=>this.immunity(...args),
      deathAttack:o=>this.unsupported(o,'Native ApplyOnHitDeathAttack is not implemented'),
      onHit:(o,t,offhand,critical)=>resolveOnHitProperties(o,t,session.equippedItems(o),session.characterRules,offhand,critical,{
        applyProperty:(a,t,item,property)=>this.unsupported(a,`Native on-hit property ${property.PropertyName&65535} on item ${item.id} is not implemented`)}),
      itemCastSpell:(o,t)=>resolveItemOnHitSpells(o,t,session.equippedItems(o),t.objectType===5?session.equippedItems(t):[],session.characterRules,{
        castSpell:(a,t,item)=>this.unsupported(a,`Native on-hit spell from item ${item.id} is not implemented`)}),
      onHitVisuals:o=>resolveOnHitVisuals(o,session.characterRules,{effect:(...args)=>session.effects.create(...args)}),
      effect:(...args)=>session.effects.create(...args),
      devastatingCritical:(o,item)=>{
        if(!item)return this.hasFeat(o,506);
        const table=session.characterRules.baseitems,row=table?.orderedRows?.[item.data.BaseItem]??table?.rows?.get(item.data.BaseItem);
        if(!row)return this.hasFeat(o,506);
        const entry=intEntry(table,item.data.BaseItem,'EpicWeaponDevastatingCriticalFeat');
        if(!entry.found)throw new Error('Native weapon devastating critical feat loader default is unavailable');
        return this.hasFeat(o,entry.value&65535);
      },
      unarmed:o=>Number(!session.equippedItems(o).find(i=>i.slot===16)),
      newTarget:(o,id)=>this.newTarget(o,id),
      circleKick:()=>this.unsupported(actor,'Native Circle Kick round insertion is not implemented'),
      cleave:()=>this.unsupported(actor,'Native cleave round insertion is not implemented'),
      weaponEffective:(o,id,offhand)=>this.weaponEffective(o,id,offhand),
      message:(type,fields)=>({type,...fields}),warning:message=>this.warning(actor,message),...providers };
  }
  async resolveDamage(actor,target,providers) {
    try { return await resolveStrikeDamage(actor,target,this.session.characterRules,this.damageStageProviders(actor,providers)); }
    catch(error) { this.session.report(error,this.session.diagnosticContext(actor.id));throw error; }
  }
  async resolvePostDamage(actor,target,providers) {
    try { return await resolvePostStrikeDamage(actor,target,this.session.characterRules,this.damageStageProviders(actor,providers)); }
    catch(error) { this.session.report(error,this.session.diagnosticContext(actor.id));throw error; }
  }
  async weaponEffective(actor,targetId,offhand){
    const s=this.session;
    try{return await weaponEffective(actor,targetId,offhand,s.equippedItems(actor),s.characterRules,{
      object:id=>s.registry.get(id)??null,asObject:o=>o.objectType>=5&&o.objectType<=14?o:null,
      weaponAttackType:o=>weaponAttackType(o.combatRound,s.equippedItems(o),s.random),
      damageRoll:(o,t,hand)=>s.damage.roll(o,t,o.combatRound.attacks[Math.min(o.combatRound.currentAttack&255,49)],
        {offhand:hand!==0,critical:false,sneak:false,death:false,maximize:true}),
      elemental:async(o,t)=>(await s.damage.effectBonus(o,t,o.combatRound.attacks[Math.min(o.combatRound.currentAttack&255,49)],
        {energy:true,maximize:true,critical:false,offhand:false})).total});}
    catch(error){s.report(error,s.diagnosticContext(actor.id));throw error;}
  }
  async resolveRoll(actor,target,providers) {
    const session=this.session;
    try { return await resolveStrikeRoll(actor,target,session.characterRules,{
      offhand:a=>offhandAttack(a.combatRound),creature:o=>o.objectType===5?o:null,random:session.random,
      rangedEquipped:o=>Number((weaponRule(session.equippedItems(o).find(i=>i.slot===16),session.characterRules,'RangedWeapon')&255)!==0),
      skillRank:(o,skill,versus,base)=>this.skill(o,skill,versus,base),
      attackModifier:(a,t,d)=>this.attackModifier(a,t,d),armorClass:(t,a,d)=>this.armorClass(t,a,d),
      defensive:(a,t,hit,d)=>this.resolveDefense(a,t,hit,d),parryAttack:addParryAttack,parryIndex:addParryIndex,
      criticalThreat:(o,offhand)=>criticalProfile(o,session.equippedItems(o),session.characterRules,offhand!==0).threat,
      sneak:(a,t)=>this.resolvePrecision('sneak',a,t),death:(a,t)=>this.resolvePrecision('death',a,t),
      effectImmunity:(...args)=>this.immunity(...args),
      difficulty:option=>session.getDifficultyOption(option),message:(type,fields)=>({type,...fields}),
      warning:message=>this.warning(actor,message),...providers
    }); } catch(error) { session.report(error,session.diagnosticContext(actor.id));throw error; }
  }
  immunity(object,category,versus,includeFeats=1) {
    const root=creatureRoot(object),source=versus?creatureRoot(versus):null;
    return Number(effectImmunity({...root,FeatList:object.stats.feats.map(Feat=>({Feat}))},
      [...(object.itemCombatEffects?.effects??[]),...(object.effects??[])],category,source,{includeFeats:includeFeats!==0,plot:Boolean(object.plot)}));
  }
  async resolvePrecision(kind,actor,target,providers) {
    const session=this.session,hasFeat=(o,feat)=>this.hasFeat(o,feat);
    try{return await resolvePrecisionAttack(kind,actor,target,session.characterRules,{
      hasFeat,visibility:(o,id)=>o.perception.get(id)??null,flatFooted:o=>Number(isFlatFooted(o)),
      flanked:(a,t)=>getFlanked(a,t,hasFeat),classes:o=>creatureRoot(o).ClassList,
      effectImmunity:(...args)=>this.immunity(...args),message:(type,fields)=>({type,...fields}),
      warning:message=>this.warning(actor,message),...providers
    });}catch(error){session.report(error,session.diagnosticContext(actor.id));throw error;}
  }
  async resolveDefense(actor,target,wouldHit,data,providers) {
    const session=this.session;
    try{return await resolveDefensiveEffects(actor,target,wouldHit,data,session.characterRules,{
      effects:o=>[...(o.itemCombatEffects?.effects??[]),...(o.effects??[])].sort((a,b)=>a.type-b.type),
      hasFeat:(o,feat)=>this.hasFeat(o,feat),flatFooted:o=>Number(isFlatFooted(o)),random:session.random,
      equippedItem:(o,slot)=>session.equippedItems(o).find(i=>i.slot===slot)??null,
      rangedWeapon:i=>weaponRule(i,session.characterRules,'RangedWeapon')&255,
      relativeWeaponSize:(o,i)=>{const difference=(weaponRule(i,session.characterRules,'WeaponSize')&255)-creatureSize(o,session.characterRules);return difference>=-2&&difference<=1?difference:-10;},
      savingThrow:(...args)=>this.savingThrow(...args),...providers
    });}catch(error){session.report(error,session.diagnosticContext(actor.id));throw error;}
  }
  async savingThrow(actor,save,dc,category,versusId,feedback,feat,attackFeedback,providers) {
    const session=this.session;
    try{return await savingThrowRoll(actor,save,dc,category,versusId,feedback,feat,attackFeedback,session.characterRules,{
      baseSave:savingThrowWithoutEffects,getObject:id=>session.registry.get(id)??null,
      asObject:o=>o.objectType>=5&&o.objectType<=14?o:null,
      areaEffect:o=>o.objectType===11?o:null,
      spellId:o=>{if(!Number.isInteger(o.lastSpellId))throw new Error('Native object last spell field +184 is unavailable');return o.lastSpellId|0;},
      spell:id=>savingThrowSpell(session.characterRules,id),
      trapSource:o=>['placeable','door','trigger'].includes(o.kind)?{kind:o.kind,flag:session.commands.GetIsTrapped([o.id])}:null,
      autoFail:()=>Number(session.naturalOnesFailSavingThrows),
      client:o=>this.broadcastProviders().client(o.id),
      broadcast:(o,data)=>broadcastSavingThrow(o,data,this.broadcastProviders()),
      getCreature:id=>{const o=session.registry.get(id);return o?.objectType===5?o:null;},
      creature:o=>o.objectType===5?o:null,
      effectBonus:(o,s,c,t)=>savingThrowEffectBonus(creatureRoot(o),[...(o.itemCombatEffects?.effects??[]),...(o.effects??[])],this.effectItemSources(),s,
        {saveType:c,target:this.effectSubject(t),limit:session.combatLimits?.saves??20}).total,
      hasFeat:(o,id)=>this.hasFeat(o,id),classLevel:creatureClassLevel,
      canUseSkill:(o,skill)=>this.canUseSkill(o,skill),
      skillRank:(o,s,t,base)=>this.skill(o,s,t,base),
      bonusLimit:()=>session.combatLimits?.saves??20,
      immunityTable:()=>{if(session.characterRules.savingthrowtypes===undefined)throw new Error('Native save immunity table state is unavailable');return session.characterRules.savingthrowtypes;},
      effectImmunity:(...args)=>this.immunity(...args),random:session.random,message:(type,fields)=>({type,...fields}),
      warning:message=>this.warning(actor,message),...providers
    });}catch(error){session.report(error,session.diagnosticContext(actor.id));throw error;}
  }
  skillProviders(providers) {
    const session=this.session;
    return{isDM:o=>Number(Boolean(o.isDM||creatureRoot(o).IsDM)),
      rawRank:(o,s)=>{const rank=o.stats?.skills?.[s]??creatureRoot(o).SkillList?.[s]?.Rank??0;if(!Number.isInteger(rank))throw new Error('Native raw skill rank is unavailable');return rank;},
      baseRank:(o,s)=>skillRank(o,s,session.characterRules,true),
      blind:getBlind,
      effectBonus:(o,s,t)=>skillEffectBonus([...(o.itemCombatEffects?.effects??[]),...(o.effects??[])],this.effectItemSources(),s,
        {target:this.effectSubject(t),limit:session.combatLimits?.skills??50}).total,
      abilityModifier:(o,a)=>abilityModifier(o.stats.equippedAbilities[['Str','Dex','Con','Int','Wis','Cha'][a]],session.characterRules),
      hasFeat:(o,f)=>this.hasFeat(o,f),area:o=>session.registry.get(o.areaId)??null,
      armorPenalties:o=>{if(!Array.isArray(o.skillArmorPenalties))throw new Error('Native skill armor penalty caches are unavailable');return o.skillArmorPenalties;},
      classPenalties:o=>creatureRoot(o).ClassList.map(c=>{if(!Number.isInteger(c.skillPenaltyByte))throw new Error('Native live class skill penalty is unavailable');return c.skillPenaltyByte;}),
      classSkillUsable:(c,s)=>classSkillUsable(session.characterRules,c,s,message=>this.warning(session.player??{id:OBJECT_INVALID},message)),
      classes:o=>creatureRoot(o).ClassList,...providers};
  }
  effectItemSources() {
    // GetTotalEffectBonus resolves the creator as ANY live item, not just
    // an item still equipped on this creature after the effect was applied.
    return [...this.session.registry.objects.values()].filter(o=>o.objectType===6).map(o=>({id:o.id}));
  }
  effectSubject(target) {
    if(target?.objectType===11){
      if(!Number.isInteger(target.creatorId))throw new Error('Native area-effect creator is unavailable');
      target=this.session.registry.get(target.creatorId>>>0);
    }
    return target?.objectType===5?creatureAlignment(creatureRoot(target)):null;
  }
  async skill(object,skill,versus,baseOnly,providers) {
    try{return await effectiveSkillRank(object,skill,versus,baseOnly,this.session.characterRules,this.skillProviders(providers));}
    catch(error){this.session.report(error,this.session.diagnosticContext(object.id));throw error;}
  }
  async canUseSkill(object,skill,providers) {
    try{return await canUseSkill(object,skill,this.session.characterRules,this.skillProviders(providers));}
    catch(error){this.session.report(error,this.session.diagnosticContext(object.id));throw error;}
  }
  async resolveMelee(actor, target, count, duration, providers = {}) {
    try { return await resolveMeleeGroup(actor, target, count, duration, this.strikeProviders(actor, {
      specialAttack:(a,i,size,t,d)=>this.resolveMeleeSpecial(a,i,size,t,d),
      signal:(a,t,size)=>this.signalMelee(a,t,size),
      animations: (a, index, size, t, d, record) => resolveMeleeAnimations(a, index, size, t, d, record, {
        animationRandom: this.session.random, getLock: t => t.objectType === 5 ? t.lockOrientationId : 0x7f000000,
        rangedEquipped: t => Number((weaponRule(this.session.equippedItems(t).find(i => i.slot === 16), this.session.characterRules, 'RangedWeapon') & 255) !== 0)
      }), ...providers
    })); }
    catch (error) { this.session.report(error, this.session.diagnosticContext(actor.id)); throw error; }
  }
  async resolveMeleeSpecial(actor,index,count,target,duration){
    const data=actor.combatRound.attacks[Math.min(actor.combatRound.currentAttack&255,49)];
    // ResolveMeleeSpecialAttack 1403e6660 first uses the normal roll/damage/
    // animation path. IDs65002/65003 fall through without an extra feat effect.
    if(![65002,65003].includes(data.attackType))this.unsupported(actor,`Native melee special attack ${data.attackType} is not implemented`);
    await this.resolveRoll(actor,target);
    if(attackResultDoesDamage(data.result)){await this.resolveDamage(actor,target);await this.resolvePostDamage(actor,target);}
    await resolveMeleeAnimations(actor,index,count,target,duration,data,{
      animationRandom:this.session.random,getLock:t=>t.objectType===5?t.lockOrientationId:OBJECT_INVALID,
      rangedEquipped:t=>this.rangedEquipped(t)});
  }
  async resolveRanged(actor, target, count, duration, providers) {
    try { return await resolveRangedGroup(actor, target, count, duration, this.strikeProviders(actor, providers)); }
    catch (error) { this.session.report(error, this.session.diagnosticContext(actor.id)); throw error; }
  }
  signalProviders(actor, providers) {
    const session = this.session;
    return { warning: message => this.warning(actor, message), hasFeat: (a, feat) => this.hasFeat(a,feat),
      attackWeapon: (a, type) => currentAttackWeapon(session.equippedItems(a), session.characterRules, type,
        ()=>weaponAttackType(a.combatRound,session.equippedItems(a),session.random)),
      difficulty: option => session.getDifficultyOption(option),
      enqueue: (...args) => this.enqueueEvent(...args),
      messageType: message => {
        if(!Number.isInteger(message.type))throw new Error('Native combat message type is unavailable');
        return message.type|0;
      },
      messageInteger: (message,index) => {
        const value=message.integers?.[index]??0;
        if(!Number.isInteger(value))throw new Error('Native combat message integer is unavailable');
        return value|0;
      },
      createDamageEffect: (id, values) => session.effects.create(38, id, values, 0), ...providers };
  }
  async signalMelee(actor, target, count, providers) {
    try { return await signalMeleeDamage(actor, target, count, this.signalProviders(actor, providers)); }
    catch (error) { this.session.report(error, this.session.diagnosticContext(actor.id)); throw error; }
  }
  async signalRanged(actor, target, count, providers) {
    try { return await signalRangedDamage(actor, target, count, this.signalProviders(actor, providers)); }
    catch (error) { this.session.report(error, this.session.diagnosticContext(actor.id)); throw error; }
  }
  setAnimation(actor, state) { return setCreatureAnimation(actor, state); }
  setCombatState(actor, state) { return setCreatureCombatState(actor, state); }
  async clearCombatMode(actor, providers = {}) {
    try {
      if(!providers.removeEffect)this.preflightClearCombatMode(actor);
      return await clearCreatureCombatMode(actor, { warning: message => this.warning(actor, message),
        defensiveCasting:(o,value)=>{o.nativeField6ee=Number(value);},...providers });
    }
    catch (error) { this.session.report(error, this.session.diagnosticContext(actor.id)); throw error; }
  }
  async setCombatMode(actor,mode,force=0,providers={}){
    const s=this.session,rules=s.characterRules;
    const stancePreflight=(o,requested)=>{
      this.preflightClearCombatMode(o);
      if(requested===11)this.unsupported(o,'Native defensive stance activation effect is not implemented');
      const willClearAll=requested>0&&requested<11&&!(o.lockedActivities&({1:0x1000,2:0x400,3:0x800,4:0x2000,5:0x4000,6:0x8000,7:0x10000,8:0x20000,9:0x40000,10:0x80000}[requested]));
      if(willClearAll&&(o.activities&0x100000)&&!(o.lockedActivities&0x100000)&&o.effects?.some(e=>e.type===95))
        this.unsupported(o,'Native defensive stance effect removal lifecycle is not implemented');
    };
    try{return await setCombatMode(actor,mode,force,{
      item:(o,slot)=>s.equippedItems(o).find(i=>i.slot===slot)??null,
      ranged:i=>weaponRule(i,rules,'RangedWeapon')&255,monkWeapon:i=>weaponRule(i,rules,'IsMonkWeapon'),
      classIndex:(o,id)=>{const index=creatureRoot(o).ClassList.findIndex(c=>c.Class===id);return index<0?255:index;},
      relativeSize:(o,i)=>{const size=(weaponRule(i,rules,'WeaponSize')&255)-creatureSize(o,rules);return size>=-2&&size<=1?size:-10;},
      hasFeat:(o,id)=>this.hasFeat(o,id),feedback:(o,code)=>sendCombatFeedback(o,code,null,this.broadcastProviders()),
      preflight:stancePreflight,warning:message=>this.warning(actor,message),remainingUses:(o,id)=>this.remainingUses(o,id),decrementUses:(o,id)=>this.decrementUses(o,id),
      activity:(o,mask,value)=>setCombatActivity(o,mask,value,{
        defensiveCasting:(o,value)=>{o.nativeField6ee=Number(value);},
        applyStance:o=>this.unsupported(o,'Native defensive stance activation effect is not implemented'),
        removeStance:o=>this.unsupported(o,'Native defensive stance effect removal lifecycle is not implemented')}),...providers});}
    catch(error){s.report(error,s.diagnosticContext(actor.id));throw error;}
  }
  preflightClearCombatMode(actor){
    if(actor.combatMode===11&&(actor.activities&0x100000)&&!(actor.lockedActivities&0x100000)&&actor.effects?.some(e=>e.type===95))
      this.unsupported(actor,'Native defensive stance effect removal lifecycle is not implemented');
  }
  setLock(actor, id) { return setLockOrientation(actor, id, target => this.session.registry.get(target) ?? null); }
  preflightPending(actor) {
    const round = actor.combatRound;
    if (actionPending(round) && round.actions.some(a => [6, 7].includes(a.nativeActionType) && this.session.registry.get(a.targetId)?.objectType === 6))
      throw new Error('Pending combat equipment actions are not implemented');
  }
  async changeTarget(actor, node, id, providers = {}) {
    try { return await changeAttackTarget(actor, node, id, { setLock: (a, target) => this.setLock(a, target),
      stickyModes:()=>Number(this.session.stickyCombatModes),preflightClearCombatMode:a=>this.preflightClearCombatMode(a),
      clearCombatMode:a=>this.clearCombatMode(a),...providers }); }
    catch (error) { this.session.report(error, this.session.diagnosticContext(actor.id)); throw error; }
  }
  async clearAttackAction(actor, node, isHead, providers = {}) {
    try { return await clearCreatureAttackAction(actor, node, isHead, {
      preflight: a => this.preflightPending(a), processPending: a => this.preflightPending(a),
      setLock: (a, target) => this.setLock(a, target), ...providers
    }); }
    catch (error) { this.session.report(error, this.session.diagnosticContext(actor.id)); throw error; }
  }
  async clearActions(actor,providers={}){
    try{return await clearObjectActions(actor,{
      clearAction:(...args)=>this.clearAction(...args),
      resetPath:o=>{if(!o.nativePathInfo?.resetAtEnd)throw new Error('Native path reset is unavailable');o.nativePathInfo.resetAtEnd();},
      ...providers});}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  clearAction(actor,node,head){
    return [1,17,19,30].includes(node.actionId)?clearCreatureMovementAction(actor,node,head,{
      messageAvailable:()=>true,setLock:(...args)=>this.setLock(...args)
    }):this.clearAttackAction(actor,node,head);
  }
  async requestAttack(object, targetId, passive, clear, front, providers) {
    try {
      // This maps the request boundary. Draining the resulting action still
      // requires AI attack eligibility, perception, approach and dispatch.
      const session = this.session;
      return await addAttackRequest(object, targetId, passive, clear, front, {
        computeAIState,
        visibilityFlags: (actor, id) => actor.perception?.get(id) ?? null,
        getObject: id => session.registry.get(id) ?? null,
        aiReaction: (actor, id) => session.aiReaction(actor, id),
        asCreature: target => target.objectType === 5 ? target : null,
        isDM: target => Number(Boolean(target.isDM)), getDead: target => Number(session.isDead(target)),
        getCreature: id => { const target = session.registry.get(id); return target?.objectType === 5 ? target : null; },
        getDoor: id => { const target = session.registry.get(id); return target?.objectType === 10 ? target : null; },
        enqueueAction: (actor, id, group, type, target, front) => addObjectAction(actor.objectActionState, id, group, [{ type, value: target }], front),
        resolveInitiative: actor => session.damage.initiative(actor), random: session.random,
        feedback:(o,code)=>sendCombatFeedback(o,code,null,this.broadcastProviders()),
        clearActions:o=>this.clearActions(o),
        actionManager:(o,request)=>manageObjectActions(o,request,{
          hasClient:o=>Boolean(this.broadcastProviders().client(o.id)),clearActions:o=>this.clearActions(o)}),
        broadcastAssociateCommand:(o,code)=>this.associateCommand(o,code),
        broadcastCombatState:o=>broadcastCombatState(o,this.broadcastProviders()),
        broadcastBattleCry:o=>broadcastBattleCry(o,{...this.broadcastProviders(),random:session.random,
          areaIds:o=>{const area=session.registry.get(o.areaId);return area?areaObjectsByX(session,area).map(t=>t.id):null;},
          voice:(client,id,code)=>runtimeDiagnostics.record('combat.voice-unimplemented',
            'Native battle-cry recipient and voice selected; voice playback is not implemented',
            {...session.diagnosticContext(id),recipientId:client.object.id,voiceCode:code})}),
        doorFieldFC:o=>this.unsupported(o,'Native attack door field +FC is not mapped'),
        enqueueDoorEvent:()=>this.unsupported(object,'Native attack door event34 is not implemented'),
        ...providers
      });
    } catch (error) {
      this.session.report(error, this.session.diagnosticContext(object.id));
      throw error;
    }
  }
  async runActions(object, day, time, startedAt, providers={}) {
    const microseconds=()=>BigInt(Math.trunc(performance.now()*1000));
    try { return await runObjectActions(object, day, time, startedAt??microseconds(), {
      microseconds,
      preflight:async(o,node)=>{
        if(o.objectType!==5||![1,12,17,19,30].includes(node.actionId))this.unsupported(o,`Native live action ${node.actionId} dispatch is not implemented`);
        if(node.actionId===1){const area=this.session.registry.get(o.areaId);if(area)await this.combatStepProviders().preflightMovement(o,area);}
      },
      dispatch:(o,node)=>{
        const p={...this.useRangeProviders(),dead:o=>Number(this.session.isDead(o)),dying:o=>Number(this.session.isDying(o)),
          worldTime:()=>this.session.worldTimer.time(),dayLength:this.session.worldTimer.dayLength,
          asCreature:o=>o.objectType===5?o:null,moduleArea:id=>this.session.registry.get(id)??null,
          useRange:(...args)=>this.useRange(...args),inUseRange:(...args)=>this.inUseRange(...args),
          setLock:(...args)=>this.setLock(...args),client:id=>this.broadcastProviders().client(id)};
        return node.actionId===1?this.executeMove(o,node):node.actionId===30?executeWait(o,node,p):node.actionId===17?checkMoveRadius(o,node,p):
          node.actionId===19?checkInterArea(o,node,p):this.executeAttack(o,node);
      },
      lastAction:(o,id)=>{this.session.nativeAIFieldBC=id&65535;},
      completed:o=>{if(o.lockOrientationId!==OBJECT_INVALID)this.setLock(o,OBJECT_INVALID);},
      overflow:o=>{
        const count=o.objectActionState.list.count,effects=o.effects?.length??0;
        if(count>75)this.warning(o,`Native RunActions action-list warning: ${count} actions exceeds 75`);
        if(count>500)this.unsupported(o,'Native RunActions oversized action-list cleanup is not implemented');
        if(effects>500)this.warning(o,`Native RunActions effect-list warning: ${effects} effects exceeds 500`);
        if(effects>1000)this.unsupported(o,'Native RunActions oversized effect-list cleanup is not implemented');
      },...providers }); }
    catch (error) { this.session.report(error, this.session.diagnosticContext(object.id)); throw error; }
  }
  async evaluateAttack(object, targetId, providers) {
    const session = this.session, rules = session.characterRules;
    try {
      return await evaluateAttackEligibility(object, targetId, {
        getArea: target => session.registry.get(target.areaId) ?? null,
        getDead: target => Number(session.isDead(target)), getDying: target => Number(session.isDying(target)),
        getObject: id => session.registry.get(id) ?? null,
        asObject: target => {
          if ([5, 9, 10].includes(target.objectType)) return target;
          throw new Error(`Native attack object cast for ${target.kind} is unavailable`);
        },
        asCreature: target => target.objectType === 5 ? target : null,
        visibilityFlags: (actor, id) => actor.perception?.get(id) ?? null,
        maximumRange: (actor, id) => maximumAttackRange(actor, session.registry.get(id), rules, session.equippedItems(actor)).distance,
        desiredRange: (actor, id) => {
          const result = desiredAttackRange(actor, session.registry.get(id), rules, session.equippedItems(actor));
          for (const message of result.warnings) runtimeDiagnostics.record('combat.attack-range-warning', message, session.diagnosticContext(actor.id));
          return result.distance;
        },
        useRange:async(actor,id,point)=>{const out={point,range:0};await this.useRange(actor,id,out);return out.point;},
        // GetRangeWeaponEquipped +18 is RangedWeapon, unlike MaxAttackRange's
        // AmmunitionType branch. They are intentionally independent queries.
        rangedEquipped: actor => Number((weaponRule(session.equippedItems(actor).find(i => i.slot === 16), rules, 'RangedWeapon') & 255) !== 0),
        lineOfSight: (area, from, to, sourceId, targetId, ranged) => {
          if (!area.nativeGeometry) throw new Error('Native attack eligibility provider lineOfSight is unavailable');
          const native = point => [Math.fround(point[0]), Math.fround(-point[2]), Math.fround(point[1])];
          return area.nativeGeometry.lineOfSight(native(from), native(to), [0, 0, 0], { id: OBJECT_INVALID }, sourceId, targetId, ranged);
        },
        meleeSpatialQuery:(area,from,to,path)=>this.creatureLine(area,from,to,path,1,0,null,1),
        ...providers
      });
    } catch (error) { session.report(error, session.diagnosticContext(object.id)); throw error; }
  }
  lineOfSight(area,from,to,sourceId,targetId,transparent){
    if(!area?.nativeGeometry)throw new Error('Native attack eligibility provider lineOfSight is unavailable');
    const native=point=>[Math.fround(point[0]),Math.fround(-point[2]),Math.fround(point[1])];
    return area.nativeGeometry.lineOfSight(native(from),native(to),[0,0,0],{id:OBJECT_INVALID},sourceId,targetId,transparent);
  }
  targetProviders(providers={}){
    const s=this.session;
    return {area:o=>s.registry.get(o.areaId)??null,object:id=>s.registry.get(id)??null,
      asObject:o=>o.objectType>=5&&o.objectType<=14?o:null,asCreature:o=>o.objectType===5?o:null,
      areaIds:area=>{if(!area.nativeSpatial)throw new Error('Native target ordered area storage is unavailable');return area.nativeSpatial.view();},
      reaction:(o,id)=>s.aiReaction(o,id),dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),
      visibility:(o,id)=>{if(!o.perception)throw new Error('Native target visibility list is unavailable');return o.perception.get(id)??null;},
      ranged:o=>this.rangedEquipped(o),lineOfSight:(...args)=>this.lineOfSight(...args),creatureLine:(...args)=>this.creatureLine(...args),
      clearLine:(...args)=>attackClearLine(...args,this.targetProviders(providers)),
      maximumRange:(o,id,force,short)=>maximumAttackRange(o,s.registry.get(id),s.characterRules,s.equippedItems(o),
        {forceCreatureRange:Boolean(force),shortRanged:Boolean(short)}).distance,
      nearestEnemy:(...args)=>nearestEnemy(...args,this.targetProviders(providers)),...providers};
  }
  async newTarget(actor,id,providers={}){
    try{return await newCombatTarget(actor,id,this.targetProviders(providers));}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  useRangeProviders(providers={}){
    const s=this.session;
    return {object:id=>s.registry.get(id)??null,asObject:o=>o.objectType>=5&&o.objectType<=14?o:null,
      area:o=>s.registry.get(o.areaId)??null,lineOfSight:(...args)=>this.lineOfSight(...args),...providers};
  }
  async useRange(actor,id,out,providers={}){
    try{return await getUseRange(actor,id,out,this.useRangeProviders(providers));}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  async inUseRange(actor,id,extra,transparent,providers={}){
    try{return await isInUseRange(actor,id,extra,transparent,this.useRangeProviders(providers));}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  movementProviders(providers={}){
    const s=this.session,geometry=area=>{if(!area?.nativeGeometry)throw new Error('Native movement area geometry is unavailable');return area.nativeGeometry;};
    const native=point=>[Math.fround(point[0]),Math.fround(-point[2]),Math.fround(point[1])];
    const subareas={object:id=>s.registry.get(id)??null,
      lineTrigger:(o,a,b)=>intersectSubareaPolygon(o,a,b,Boolean(s.registry.get(o.areaId))),
      lineEncounter:(o,a,b)=>intersectSubareaPolygon(o,a,b,Boolean(s.registry.get(o.areaId)))};
    const base={...this.useRangeProviders(),...this.combatStepProviders(),
      dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),hasModule:()=>Boolean(s.module),
      client:id=>this.broadcastProviders().client(id),setLock:(...args)=>this.setLock(...args),
      height:(area,point)=>geometry(area).height(native(point)),
      rate:(o,run)=>movementRate(o,run,s.characterRules,{
        hasFeat:(o,id)=>this.hasFeat(o,id),monkAbilities:o=>{
          const value=o.stats?.combat?.finalBreakdown?.armor?.monkAbilities;
          if(typeof value!=='boolean')throw new Error('Native monk abilities are unavailable');return Number(value);
        }}),
      polygons:(area,from,to,...args)=>geometry(area).detailedPolygons([from[0],-from[1]],[to[0],-to[1]],...args),
      creatureLine:(...args)=>this.creatureLine(...args),
      crossings:(area,from,to,ids)=>intersectSubareas(area,from,to,ids,subareas),
      setOrientation:(o,value)=>{if(!o.orientation)throw new Error('Native movement orientation storage is unavailable');for(let i=0;i<3;i++)o.orientation[i]=Math.fround(value[i]);},
      activityManager:(o,request)=>manageCreatureActivities(o,request,(actor,mask,value)=>setCombatActivity(actor,mask,value,{
        defensiveCasting:(o,value)=>{o.nativeField6ee=Number(value);},
        applyStance:o=>this.unsupported(o,'Native defensive stance activation effect is not implemented'),
        removeStance:o=>this.unsupported(o,'Native defensive stance effect removal lifecycle is not implemented')})),
      closePanels:(o,flag)=>autoClosePanels(o,flag,{
        client:id=>this.broadcastProviders().client(id),object:id=>s.registry.get(id)??null,
        clientObject:client=>client.object,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},talkRange:()=>10,
      }),
      safePoint:(area,point,path,flag)=>testSafeLocationPoint(area,native(point),path,flag,{
        ...geometry(area).providers(),tileAt:(_area,point)=>geometry(area).tileAt(point),
        polygons:(_area,...args)=>geometry(area).detailedPolygons(...args),
        creatureLine:(area,from,to,...args)=>this.creatureLine(area,[from[0],-from[1]],[to[0],-to[1]],...args)}),
      ...providers};
    return {...base,
      plot:(path,budget)=>plotPath(path,budget,{...base,
        area:id=>s.registry.get(id)??null,directLine:base.testDirectLine,
        creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
        aiLevel:o=>o.nativeAILevel7c,pathfindingLevel:()=>{
          if(!s.module)throw new Error('Native module pathfinding level is unavailable');return s.module.nativePathfindingLevel464;
        },
        gridPlot:(area,path,budget,force)=>plotGridPath(area,path,budget,force,{
          directLine:base.testDirectLine,microseconds:()=>BigInt(Math.trunc(performance.now()*1000)),
          markGridAI:value=>{s.nativeAIFieldAC=value;},smooth:(area,path)=>smoothPath(area,path,{directLine:base.testDirectLine}),...providers}),
        resetInterTile:path=>path.resetInterTile(),resetGrid:path=>path.resetGrid(),markAI:value=>{s.nativeAIFieldA8=value;},...providers}),
      walk:(o,group)=>walkPath(o,group,this.movementProviders(providers)),
      walkDistance:(...args)=>walkDistance(...args,this.movementProviders(providers)),
      testDistance:(...args)=>testWalkDistance(...args,this.movementProviders(providers)),
      creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      door:id=>{const o=s.registry.get(id);return o?.objectType===10?o:null;},...providers};
  }
  async executeMove(actor,node,providers={}){
    try{return await executeMoveToPoint(actor,node,this.movementProviders(providers));}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  async dispatchAttack(object, targetId, targetValid, providers) {
    try {
      const result = await dispatchAttackRoundAction(object, targetId, targetValid, providers);
      if (result.warning) runtimeDiagnostics.record('combat.action-warning', result.warning, this.session.diagnosticContext(object.id));
      return result;
    } catch (error) {
      this.session.report(error, this.session.diagnosticContext(object.id));
      throw error;
    }
  }
  ranges(object, target, options) {
    try {
      const items = this.session.equippedItems(object), rules = this.session.characterRules;
      const desired = desiredAttackRange(object, target, rules, items, options?.forceCreatureRange);
      const maximum = maximumAttackRange(object, target, rules, items, options);
      for (const message of desired.warnings) runtimeDiagnostics.record('combat.attack-range-warning', message, this.session.diagnosticContext(object.id));
      return { desired: desired.distance, maximum: maximum.distance };
    } catch (error) {
      this.session.report(error, this.session.diagnosticContext(object.id));
      throw error;
    }
  }
  async startRound(actor,targetId,providers={}){
    const s=this.session;
    try{return await startCombatRoundAsync(actor.combatRound,actor,targetId,s.equippedItems(actor),s.characterRules,s.random,{
      preflight:o=>{
        if(o.pendingCombatMode===11)this.unsupported(o,'Native pending defensive stance activation effect is not implemented');
        if(o.pendingCombatMode){this.preflightClearCombatMode(o);
          if((o.activities&0x100000)&&!(o.lockedActivities&0x100000)&&o.effects?.some(e=>e.type===95))
            this.unsupported(o,'Native pending mode requires defensive stance effect removal lifecycle');}
      },
      setCombatMode:(...args)=>this.setCombatMode(...args),
      initialCombatStep:(o,id)=>initialAttackCombatStep(o,id,{
        object:id=>s.registry.get(id)??null,dead:t=>Number(s.isDead(t)),dying:t=>Number(s.isDying(t)),
        ranged:o=>this.rangedEquipped(o),desiredRange:(o,id)=>{
          const result=desiredAttackRange(o,s.registry.get(id),s.characterRules,s.equippedItems(o));
          for(const message of result.warnings)this.warning(o,message);return result.distance;}}),
      broadcastState:o=>broadcastCombatState(o,this.broadcastProviders()),setLock:(o,id)=>this.setLock(o,id),...providers});}
    catch(error){s.report(error,s.diagnosticContext(actor.id));throw error;}
  }
  combatStepProviders(providers={}){
    const s=this.session;
    return {object:id=>s.registry.get(id)??null,asObject:o=>o.objectType>4?o:null,
      asCreature:o=>o.objectType===5?o:null,area:o=>s.registry.get(o.areaId)??null,
      ranged:o=>this.rangedEquipped(o),desiredRange:(o,id,force)=>desiredAttackRange(o,s.registry.get(id),s.characterRules,s.equippedItems(o),Boolean(force)).distance,
      maximumRange:(o,id,force,short)=>maximumAttackRange(o,s.registry.get(id),s.characterRules,s.equippedItems(o),{forceCreatureRange:Boolean(force),shortRanged:Boolean(short)}).distance,
      asin:nativeAsinf,atan2:nativeAtan2f,cos:nativeCosf,sin:nativeSinf,
      preflightMovement:async(actor,area)=>{
        try {
        if(!area.nativeGeometry?.directLine)throw new Error('Native combat step provider testDirectLine is unavailable');
        if(!area.nativeSpatial||area.nativeSpatial.indexOf(actor.id)<0)throw new Error('Native combat step spatial membership is unavailable');
        if(!(area.nativeSubareas instanceof NativeIdList)||!(actor.nativeSubareaMembership instanceof NativeIdList)||!(actor.nativeFollowingAOEs instanceof NativeIdList))
          throw new Error('Native combat step subarea membership is unavailable');
        // Native LoadArea supplies these resources before AI starts. Our lazy
        // loader resolves them before the due-action dequeue/RNG boundary.
        await area.nativeGeometry.objects.load();
        for(let y=0;y<area.height;y++)for(let x=0;x<area.width;x++)await area.nativeGeometry.tile(x,y);
        } catch(error) {
          // Resource errors may already be recorded with tile/area context.
          // Retain the requesting actor too, despite shared-error deduplication.
          runtimeDiagnostics.error(error,'combat.movement-preflight-failed',s.diagnosticContext(actor.id));throw error;
        }
      },
      testDirectLine:(area,from,to,radius,height,flag)=>area.nativeGeometry.directLine(
        [Math.fround(from[0]),Math.fround(-from[2])],[Math.fround(to[0]),Math.fround(-to[2])],radius,height,flag,
        (a,start,end,...args)=>this.creatureLine(a,[start[0],-start[1]],[end[0],-end[1]],...args)),
      updateSubareas:(...args)=>s.updateSubareasOnMove(...args),setPosition:(...args)=>s.setPosition(...args),
      random:()=>s.random.next(),setAnimation:(o,state)=>this.setAnimation(o,state),...providers};
  }
  async creatureLine(area,from,to,path,segment,bump,output,targetOverlap,providers={}){
    const s=this.session,creature=id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;};
    return noCreaturesOnLine(area,from[0],-from[1],to[0],-to[1],path,segment,bump,output,targetOverlap,{
      creature,areaIds:area=>areaSpatialIds(s,area),
      firstByX:(area,x)=>firstAreaSpatialIndex(s,area,x),
      dm:o=>Number((o.associateType&65535)===0&&Boolean(this.broadcastProviders().client(o.id))&&Boolean(o.isDM)),dmBody:o=>o.nativeStatsFieldBC,
      collision788:o=>o.nativeCollisionFlag788,ghost:o=>Number(o.cutsceneGhost),pc:o=>o.reputationPCFlag,
      possessedFamiliar:o=>Number(o.associateType===3&&Boolean(this.broadcastProviders().client(o.id))),
      bumpable:(o,target)=>creatureBumpable(o,target,{
        associates:o=>o.associateIds,reputation:(o,id)=>s.reputation(o,s.registry.get(id)),
        pc:o=>o.reputationPCFlag,possessedFamiliar:o=>Number((o.associateType&65535)===3&&Boolean(this.broadcastProviders().client(o.id)))}),
      radius:o=>{if(!o.nativePathInfo)throw new Error('Native candidate path information is unavailable');return o.nativePathInfo.field8;},
      visibility:(o,id)=>o.perception?.get(id)??null,dead:o=>Number(s.isDead(o)),...providers});
  }
  async combatStep(actor,step,duration,targetId,providers={}){
    try{return await doCombatStep(actor,Number(step),duration,targetId,this.combatStepProviders(providers));}
    catch(error){this.session.report(error,this.session.diagnosticContext(actor.id));throw error;}
  }
  unsupported(object, message) {
    runtimeDiagnostics.record('combat.lifecycle-unimplemented', message, this.session.diagnosticContext(object.id));
    throw new Error(message);
  }
  async endRound(object) {
    const session = this.session, round = object.combatRound;
    await endCombatRoundAsync(round, object, session.characterRules, {
      processPending: () => {
        // ProcessPendingCombatActions checks the HEAD, then traverses from
        // the tail and converts all valid equip/unequip actions. Preserve
        // unavailable operations instead of silently deleting them.
        if (actionPending(round) && round.actions.some(a => [6, 7].includes(a.nativeActionType) && session.registry.get(a.targetId)?.objectType === 6))
          this.unsupported(object, 'Pending combat equipment actions are not implemented');
      },
      isDead: actor => session.isDead(actor),
      roundEnd: actor => {
        const name = actor.scripts?.roundEnd ?? '';
        if ((actor.isPC || actor.isPossessedFamiliar) && name === 'default') return;
        return session.damage.runEvent(actor, name);
      }
    });
  }
  async updateTimer(object, milliseconds) {
    await updateRoundTimer(object, milliseconds, {
      endRound: actor => this.endRound(actor),
      isDead: actor => this.session.isDead(actor), isDying: actor => this.session.isDying(actor),
      setAnimation: (actor, state) => {
        this.setAnimation(actor, state);
        runtimeDiagnostics.record('combat.presentation-unimplemented', 'Combat pause ended; native animation state set, clip routing remains unimplemented',
          { ...this.session.diagnosticContext(actor.id), animationState: state });
      }
    });
  }
  async updateExcited(object,milliseconds){
    await advanceExcitedDuration(object,milliseconds,{expired:o=>{
      const client=this.broadcastProviders().client(o.id),area=this.session.registry.get(o.areaId);
      if(client&&area?.restController)this.unsupported(o,'Native excited-expiry rest-controller notification is not implemented');
    }});
  }
  async updateAfterEffects(object,milliseconds){
    // Area timer ownership, height and trap checks remain separate work. The
    // local world clock supplies the day/time of this mapped action boundary.
    const now=this.session.worldTimer.time();
    // Local frame adapter supplies +d4. Exact area/AI-level elapsed-time
    // selection in AIUpdate remains separate from this mapped action owner.
    object.nativeFrameElapsedD4=milliseconds>>>0;
    await this.runActions(object,now.day,now.time);
    computeAIState(object);
    await advanceCombatStateTimers(object,milliseconds,{
      dead:o=>Number(this.session.isDead(o)),heartbeat:o=>this.session.damage.runEvent(o,o.scripts?.heartbeat),
      hasFeat:(o,id)=>this.hasFeat(o,id),opportunity:(...args)=>this.opportunityAttack(...args)});
  }
}
