import {OBJECT_INVALID} from './game_object_array.js';
import {addObjectAction,actionParameter} from './object_actions.js';
import {receiveSpellInput} from './spell_input.js';
import {receiveSpellLikeInput,addSpellTalentOnObject,addSpellTalentAtLocation} from './spell_like_input.js';
import {addCastSpellActions,computeSpellRange,loadSpellRanges,spellActionPending} from './spell_queue.js';
import {executeOrdinaryCast} from './spell_cast_action.js';
import {executeItemCast,clearItemCast} from './item_cast_action.js';
import {castSpellAndImpact} from './spell_cast_impact.js';
import {startSpellRound,removeSpellActions} from './spell_round.js';
import {decrementRoundLength} from './combat_round.js';
import {setRoundPaused,setPauseTimer} from './combat_timing.js';
import {checkCastConcentration,checkSpellReleaseFailure,spellFailure,castReleaseLineOfSight} from './spell_release.js';
import {spellLikeReady,spellLikeCasterLevel,memorizedReadyCount} from './spell_book.js';
import {commandCastSpell} from './spell_cast_request.js';
import {savingThrowSpell} from './spell_metadata.js';
import {sendCombatFeedback,broadcastSkillData} from './combat_broadcast.js';
import {manageObjectActions} from './object_actions.js';
import {manageCreatureActivities} from './combat_attack_preparation.js';
import {addMoveToPointBack} from './movement_actions.js';
import {facePointAction} from './facing_actions.js';
import {subtractWorldTimes} from './reputation.js';
import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {broadcastOrdinarySpellCast,broadcastCounterspellData} from './spell_cast_broadcast.js';
import {conversionSlots,spellsOfLevelReady,conversionBaseLevel,consumeConvertedSpell,classAllowsConversion} from './spell_conversion.js';
import {removeCounterspellRoundActions,countCounterspellers,selectCounterspell,validateCounterspell,counterspellPoolProviders,cancelCounterspellReactions,removeCounterspeller} from './spell_counterspell.js';
import {addCounterspellActions,executeCounterspellAction,clearCounterspellAction} from './counterspell_actions.js';
import {addMoveToPointFront,addPathfindingWaitFront} from './movement_actions.js';
import {broadcastCombatState} from './combat_broadcast.js';
import {broadcastSafeProjectile} from './safe_projectile.js';
import {talentSpell,spellStringEntry} from './spell_metadata.js';
import {itemActiveUsesLeft} from './item_presentation_state.js';
import {scriptAppearanceType} from './creature_appearance_state.js';

const f=Math.fround,native=v=>[v[0],-v[2],v[1]].map(f),render=v=>[v[0],v[2],f(-v[1])];
const bits=v=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,v,true);return d.getInt32(0,true);};

// Local-authority binding for the mapped ordinary casting owners. All spell
// definitions and scripts come from the session's active resource resolver.
export class SpellRuntime{
  constructor(session){this.session=session;}
  feedback(o,code){return sendCombatFeedback(o,code,null,this.session.combat.broadcastProviders());}
  omission(o,code,message,detail={}){runtimeDiagnostics.record(code,message,{...this.session.diagnosticContext(o.id),...detail});}
  ranges(o){return loadSpellRanges(this.session.characterRules,{warning:message=>this.omission(o,'rules.spell-range-unavailable',message)});}
  counterProviders(actor){
    const s=this.session,c=s.combat;
    const p={range:this.ranges(actor)[4],area:o=>{const a=s.registry.get(o.areaId);return a?.objectType===4?a:null;},
      creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},position:o=>native(o.position),
      ids:a=>{if(!a.nativeSpatial)throw new Error('Native counterspell spatial list is unavailable');return a.nativeSpatial.view();},
      ready:(o,index,id)=>memorizedReadyCount(o,index,id,255,s.characterRules,s.spellBook.providers(o)),
      uses:(o,index,id)=>s.spellBook.uses(o,id,index,0,0),level:(id,type)=>s.spellBook.level(id,type),
      validate:(o,id,index,level)=>validateCounterspell(o,id,index,level,counterspellPoolProviders()),
      head:o=>o.objectActionState.list.head?.action??null,clear:o=>c.clearActions(o),
      queue:(o,id,group,params,front)=>addObjectAction(o.objectActionState,id,group,params,front),
      dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),activityManager:(o,n)=>manageCreatureActivities(o,n,(...a)=>s.skills.clearActivity(...a)),
      broadcastState:o=>broadcastCombatState(o,c.broadcastProviders()),initiative:o=>s.damage.initiative(o),
      lock:o=>o.lockOrientationId,setLock:(...a)=>c.setLock(...a),setMode:(...a)=>c.setCombatMode(...a),feedback:(...a)=>this.feedback(...a),setAnimation:(...a)=>c.setAnimation(...a),
      remove:removeCounterspeller,
      moveFront:(o,group,point,...args)=>addMoveToPointFront(o,group,render(point),...args,0,0,0,0,0,0,0,{setLock:(...a)=>c.setLock(...a)}),
      waitFront:(o,group)=>addPathfindingWaitFront(o,group,{client:id=>c.broadcastProviders().client(id)})};
    p.readyCount=(o,index,id)=>p.ready(o,index,id).count;return p;
  }
  addCounter(o,id){return addCounterspellActions(o,id,this.counterProviders(o));}
  executeCounter(o,node){return executeCounterspellAction(o,node,this.counterProviders(o));}
  clearCounter(o,node,head){return clearCounterspellAction(o,node,head,this.counterProviders(o));}
  script(ordinal,args,frame){
    const s=this.session,location=ordinal===234||ordinal===502,forced=ordinal===501||ordinal===502;
    const [spellId,target,meta=255,cheat=0]=args;
    const position=location?target?.position:[0,0,0];
    if(location&&(!position||position.length!==3))throw new Error('Native cast script location is unavailable');
    return commandCastSpell({ordinal,argc:args.length,self:frame.self,spellId,targetId:location?OBJECT_INVALID:target,position,
      metamagic:meta,cheat,domainLevel:location?(args[8]??0):(args[4]??0),path:forced?(args[2]??0):location?(args[4]??0):(args[5]??0),
      instant:location?(args[5]??0):(args[6]??0),classType:location?(args[6]??-1):(args[7]??-1),spontaneous:location?(args[7]??0):(args[8]??0),executionContext:1},
    {spellCount:s.characterRules.spells.orderedRows.length,object:id=>s.registry.get(id)??null,creature:o=>o.objectType===5?o:null,placeable:o=>o.objectType===9?o:null,
      classes:o=>creatureRoot(o).ClassList.map(c=>c.Class&255),casterClass:type=>intEntry(s.characterRules.classes,type,'SpellCaster').value,
      memorizes:type=>intEntry(s.characterRules.classes,type,'MemorizesSpells').value,uses:(...a)=>s.spellBook.uses(...a),
      readyCount:(o,index,id)=>memorizedReadyCount(o,index,id,255,s.characterRules,s.spellBook.providers(o)),
      abilityReady:spellLikeReady,abilityCasterLevel:spellLikeCasterLevel,spell:id=>s.spellBook.castingSpell(id),level:(...a)=>s.spellBook.level(...a),
      slotMetamagic:(o,index,level,slot)=>{
        if(index===254)return 0;
        if(index>=creatureRoot(o).ClassList.length)return 255;
        if(level>=10){s.spellBook.warning(o,'nSpellLevel < CNWSPELL_NUM_LEVELS');return 255;}
        return o.nativeTalentClasses[index].memorized[level][slot]?.metamagic??255;
      },addCreatureCast:(o,a)=>this.add(o,{spellId:a[0],classIndex:a[1],domainLevel:a[2],metamagic:a[3],spontaneous:a[4],position:a.slice(5,8),
        targetId:a[8],location:a[9],front:a[10],cheat:a[11],path:a[12],instant:a[13],featId:a[15],casterLevel:a[16]}),
      addPlaceableCast:()=>{throw new Error('Native placeable cast action is not implemented');}});
  }
  async input(request){
    const s=this.session,c=s.combat;
    return receiveSpellInput(s.player,request,{spell:id=>s.spellBook.castingSpell(id),uses:(...a)=>s.spellBook.uses(...a),feedback:(...a)=>this.feedback(...a),
      actionManager:(o,n)=>manageObjectActions(o,n,{hasClient:o=>Boolean(c.broadcastProviders().client(o.id)),clearActions:o=>c.clearActions(o)}),
      classAllowsConversion:(o,index)=>classAllowsConversion(o,index,s.characterRules),
      level:(o,id,index)=>s.spellBook.level(id,creatureRoot(o).ClassList[index]?.Class??255),metamagicCost:mask=>s.spellBook.metamagicCost(mask),slots:conversionSlots,
      addCast:(o,r)=>this.add(o,r)});
  }
  async inputLike(request){
    const s=this.session,c=s.combat;
    const p={creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},position:o=>native(o.position),area:o=>s.registry.get(o.areaId)??null,addCast:(o,r)=>this.add(o,r)};
    const point=request.position??[0,0,0];let byte=0,axis=0;
    const flags=(request.targetId!==OBJECT_INVALID?1:0)|(request.location!==0?2:0);
    return receiveSpellLikeInput(null,{clientObject:()=>s.player,asCreature:o=>o?.objectType===5?o:null,stats:o=>o.stats??null,overflow:()=>0,underflow:()=>0,
      readDword:()=>request.spellId,readByte:()=>byte++===0?request.casterLevel:flags,readObjectId:()=>request.targetId,readFloat:()=>point[axis++],
      spell:id=>s.spellBook.castingSpell(id),feedback:(...a)=>this.feedback(...a),
      actionManager:(o,n)=>manageObjectActions(o,n,{hasClient:o=>Boolean(c.broadcastProviders().client(o.id)),clearActions:o=>c.clearActions(o)}),
      onObject:(...a)=>addSpellTalentOnObject(...a,p),atLocation:(...a)=>addSpellTalentAtLocation(...a,p)});
  }
  add(o,request){
    const s=this.session,c=s.combat,ranges=this.ranges(o),area=o=>s.registry.get(o.areaId)??null;
    return addCastSpellActions(o,request,{object:id=>s.registry.get(id)??null,asCreature:o=>o.objectType===5?o:null,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      area,position:o=>native(o.position),possessor:o=>o.possessorId,dm:o=>Number(Boolean(o.isDM)),visibility:(o,id)=>o.perception?.get(id)??null,
      spell:id=>s.spellBook.castingSpell(id),uses:(...a)=>s.spellBook.uses(...a),abilityReady:spellLikeReady,feedback:(...a)=>this.feedback(...a),
      range:(o,spell,id)=>computeSpellRange(o,spell.range,id,{ranges,personalSpace:o=>o.nativePathInfo.field4,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;}}),
      queue:(o,id,group,params,front)=>addObjectAction(o.objectActionState,id,group,params,front),setLock:(...a)=>c.setLock(...a),
      move:(o,group,point,...a)=>addMoveToPointBack(o,group,render(point),...a,{setLock:(...a)=>c.setLock(...a)})});
  }
  preflight(o,node){}
  itemActionProviders(){
    const s=this.session,c=s.combat;
    return {...s.items.castProviders(),activityManager:(o,n)=>manageCreatureActivities(o,n,(...a)=>s.skills.clearActivity(...a)),
      dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),worldTime:()=>{
        if((s.nativeActivePauseFlags??0)!==0)throw new Error('Native item casting exclusion timer is unavailable');return s.worldTimer.time();},
      elapsed:(now,then)=>{const result=subtractWorldTimes(now,then,s.worldTimer.dayLength);if(result.status!==0)throw new Error('Native item casting elapsed time is unavailable');return result.milliseconds;},
      propertyInt:(id,column)=>{if(!s.characterRules.iprp_spells)throw new Error('Native item casting iprp_spells metadata is unavailable');return intEntry(s.characterRules.iprp_spells,id,column).value;},
      subRadialCount:spell=>talentSpell(s.characterRules,spell.id).children.length,
      subRadialSpell:(spell,index)=>{const children=talentSpell(s.characterRules,spell.id).children;
        if(index<children.length)return children[index];c.warning(s.player,'CNWSpell::GetSubRadialSpell(): Requested subradial spell index is outside of valid range....Returning -1');return -1;},
      modelType:o=>{if(!s.characterRules.appearance)throw new Error('Native item casting appearance table is unavailable');return spellStringEntry(s.characterRules.appearance,scriptAppearanceType(o),'MODELTYPE');},
      playerCharacter:o=>Number(o.nativeField89c!==0||(o.associateType&65535)===3&&Boolean(c.broadcastProviders().client(o.id))),difficulty:n=>s.getDifficultyOption(n),
      opportunity:(...a)=>c.opportunityAttack(...a),startRound:(o,n)=>startSpellRound(o.combatRound,n),decrementRound:(o,n,b)=>decrementRoundLength(o.combatRound,n,Boolean(b)),
      pause:(o,v,id)=>setRoundPaused(o.combatRound,v,id),pauseTimer:(o,n,v)=>setPauseTimer(o.combatRound,n,v),
      removeRoundSpell:o=>this.removeRoundSpell(o),pendingEquipment:o=>c.processPending(o),removeSpellActions:o=>removeSpellActions(o.combatRound),
      setAnimation:(...a)=>c.setAnimation(...a),setLock:(...a)=>c.setLock(...a),usesLeft:itemActiveUsesLeft,propertyCount:i=>i.activeProperties.length,
      setCharges:(...a)=>s.items.setCharges(...a),activeChanged:(...a)=>s.items.activeChanged(...a),projectileTime:(...a)=>c.spellProjectileTime(...a),enqueue:(...a)=>c.enqueueEvent(...a),
      impact:(...a)=>castSpellAndImpact(...a,{spell:id=>s.spellBook.castingSpell(id),enqueue:(...a)=>c.enqueueEvent(...a),
        creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},spellName:id=>intEntry(s.characterRules.spells,id,'Name').value,
        broadcast:(o,spell)=>this.omission(o,'spell.impact-broadcast-unimplemented','Native spell release presentation broadcast is not implemented',{spellId:spell.id}),
        projectile:(o,spell)=>this.omission(o,'spell.projectile-presentation-unimplemented','Native spell projectile presentation is not implemented',{spellId:spell.id})})};
  }
  executeItem(o,node){return executeItemCast(o,node,this.session.characterRules,this.itemActionProviders());}
  clearItem(o,node,head){return clearItemCast(o,node,head,this.itemActionProviders());}
  elapsed(o){
    const s=this.session,state=o.objectActionState;
    if((s.nativeActivePauseFlags??0)!==0)throw new Error('Native casting exclusion timer is not implemented');
    const result=subtractWorldTimes(s.worldTimer.time(),{day:state.startDay,time:state.startTime},s.worldTimer.dayLength);
    if(result.status!==0)throw new Error('Native casting elapsed time is unavailable');return result.milliseconds;
  }
  removeRoundSpell(o){return removeCounterspellRoundActions(o,{creature:id=>{const a=this.session.registry.get(id);return a?.objectType===5?a:null;},
    pending:a=>spellActionPending(a.combatRound),remove:a=>removeSpellActions(a.combatRound)});}
  async clear(o,node,head){
    if(node.nativeField9c===0)return 0;
    o.spellActionTargetId=o.nativeTarget740=OBJECT_INVALID;removeSpellActions(o.combatRound);o.nativeField81c=0;
    this.session.combat.setAnimation(o,0);await this.session.combat.processPending(o);
    if(o.lockOrientationId!==OBJECT_INVALID)this.session.combat.setLock(o,OBJECT_INVALID);
    if(Number(head)===1)o.objectActionState.startDay=o.objectActionState.startTime=0;return 1;
  }
  async release(o,spell,index,meta,automatic,options){
    const s=this.session,c=s.combat,rules=s.characterRules;
    const p={setAnimation:(...a)=>c.setAnimation(...a),setLock:(...a)=>c.setLock(...a),feedback:(...a)=>this.feedback(...a),
      counterFailure:(o,code)=>cancelCounterspellReactions(o,code,{...p,creature:id=>{const a=s.registry.get(id);return a?.objectType===5?a:null;}}),
      effects:o=>o.effects,hasFeat:(o,id)=>c.hasFeat(o,id),roll:(count,sides)=>s.random.dice(count,sides),skill:(...a)=>c.skill(...a),
      nearestEnemy:(...a)=>c.targetProviders().nearestEnemy(...a),skillName:id=>intEntry(rules.skills,id,'Name').value,
      skillMessage:(o,data)=>broadcastSkillData(o,data,c.broadcastProviders()),
      failureVisual:async(o,id)=>{const effect=s.effects.create(30,o.id,[id]);await s.effects.applyNative(effect,o.id);},
      level:(o,spell,index,domain,meta)=>{
        const cls=creatureRoot(o).ClassList[index&255]?.Class??255;
        let level=domain&255;if(domain===0)level=s.spellBook.level(spell.id,cls)&255;
        if(level===255){const master=s.spellBook.castingSpell(spell.master);if(master)level=s.spellBook.level(master.id,cls)&255;if(level===255)level=spell.innate;}
        return(level+s.spellBook.metamagicCost(meta&255))&255;
      },arcaneClass:(o,index)=>intEntry(rules.classes,creatureRoot(o).ClassList[index]?.Class??255,'Arcane').value,
      school:spell=>savingThrowSpell(rules,spell.id).school,spellFailure};
    return await checkCastConcentration(o,spell,index,options.domain,meta,options.defensive,rules,p,options)&&
      await checkSpellReleaseFailure(o,spell,index,meta,automatic,rules,p,options);
  }
  execute(o,node){
    const s=this.session,c=s.combat;
    const conversion={spell:id=>s.spellBook.castingSpell(id),level:(o,id,index)=>s.spellBook.level(id,creatureRoot(o).ClassList[index]?.Class??255),
      slots:conversionSlots,metamagicCost:mask=>s.spellBook.metamagicCost(mask),consume:(...a)=>s.spellBook.consume(...a)};
    return executeOrdinaryCast(o,node,s.characterRules,{preflight:(...a)=>this.preflight(...a),dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),
      removeRoundSpell:o=>this.removeRoundSpell(o),pendingEquipment:o=>c.processPending(o),setLock:(...a)=>c.setLock(...a),
      facePoint:(o,point)=>facePointAction(o,{parameterTypes:new Uint32Array([2,2,2]),parameterData:point.map(bits)},c.facingProviders()),
      spell:id=>s.spellBook.castingSpell(id),areaId:o=>o.areaId,uses:(...a)=>s.spellBook.uses(...a),
      levelReady:(o,spell,index,domain)=>spellsOfLevelReady(o,index,conversionBaseLevel(o,spell,index,domain,conversion)),
      consumeConverted:(...a)=>consumeConvertedSpell(...a,conversion),components:(...a)=>s.spellBook.components(...a),feedback:(...a)=>this.feedback(...a),
      remainingFeatUses:(...a)=>c.remainingUses(...a),decrementFeatUses:(...a)=>c.decrementUses(...a),equipped:(o,slot)=>s.equipmentSlot(o,slot),
      object:id=>s.registry.get(id)??null,creature:id=>{const a=s.registry.get(id);return a?.objectType===5?a:null;},targetGate:(o,t)=>!(t?.objectType===5&&t.isDM&&!o.isDM),
      activityManager:(o,n)=>manageCreatureActivities(o,n,(...a)=>s.skills.clearActivity(...a)),
      automaticQuicken:(...a)=>s.spellBook.automaticQuicken(...a),hasFeat:(o,id)=>c.hasFeat(o,id),opportunity:(...a)=>c.opportunityAttack(...a),
      broadcast:(o,id,index,feat)=>{const counter=this.counterProviders(o);return broadcastOrdinarySpellCast(o,s.spellBook.castingSpell(id),s.characterRules,{
        area:o=>s.registry.get(o.areaId),ids:a=>{if(!a.nativeSpatial)throw new Error('Native cast broadcast area list is unavailable');return a.nativeSpatial.view();},
        creature:id=>{const v=s.registry.get(id);return v?.objectType===5?v:null;},range:this.ranges(o)[4],
        visibility:(o,id)=>o.perception?.get(id)??null,skill:(...a)=>c.skill(...a),roll:(...a)=>s.random.dice(...a),...c.broadcastProviders(),
        counterCount:(o,spell)=>countCounterspellers(o,spell,s.characterRules,counter),
        selectCounter:(...a)=>selectCounterspell(...a,s.characterRules,counter)},index,feat);},
      startRound:(o,length)=>startSpellRound(o.combatRound,length),decrementRound:(o,n,bleed)=>decrementRoundLength(o.combatRound,n,Boolean(bleed)),
      pause:(o,v,id)=>setRoundPaused(o.combatRound,v,id),pauseTimer:(o,n,v)=>setPauseTimer(o.combatRound,n,v),elapsed:o=>this.elapsed(o),
      setAnimation:(...a)=>c.setAnimation(...a),lineOfSight:(o,target,point)=>{
        const area=s.registry.get(o.areaId);if(!area?.nativeGeometry)throw new Error('Native cast area LOS is unavailable');
        return castReleaseLineOfSight(o,target,point,{position:a=>native(a.position),asObject:a=>a.objectType>=5&&a.objectType<=14,
          asItem:a=>a.objectType===6,area:a=>s.registry.get(a.areaId)??null,possessor:a=>a.possessorId,
          lineOfSight:(from,to,sourceId,targetId,transparent)=>area.nativeGeometry.lineOfSight(from,to,[0,0,0],{id:OBJECT_INVALID},sourceId,targetId,transparent)});
      },consume:(...a)=>s.spellBook.consume(...a),releaseChecks:(...a)=>this.release(...a),projectileTime:(...a)=>c.spellProjectileTime(...a),
      counterSpellPending:o=>spellActionPending(o.combatRound),removeCounterSpellAction:o=>removeSpellActions(o.combatRound),
      fakeImpact:(o,id,point,targetId,path)=>{
        const target=s.registry.get(targetId),to=target&&target.objectType>=5&&target.objectType<=14?native(target.position):o.nativeSpellPoint208;
        if(!Array.isArray(to))throw new Error('Native fake cast destination is unavailable');
        return broadcastSafeProjectile(o,{sourceId:o.id,targetId,from:native(o.position),to:[...to],duration:o.nativeSpellProjectileTime220,
          appearance:path!==0?7:6,flags:id,result:0,deflection:path},c.projectileProviders());
      },
      impact:(...a)=>castSpellAndImpact(...a,{spell:id=>s.spellBook.castingSpell(id),enqueue:(...a)=>c.enqueueEvent(...a),
        creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},spellName:id=>intEntry(s.characterRules.spells,id,'Name').value,
        counterBroadcast:(o,spell,data)=>broadcastCounterspellData(o,spell,data,s.characterRules,{...this.counterProviders(o),
          skill:(...a)=>c.skill(...a),random:()=>s.random.next(),...c.broadcastProviders()}),
        broadcast:(o,spell)=>this.omission(o,'spell.impact-broadcast-unimplemented','Native spell release presentation broadcast is not implemented',{spellId:spell.id}),
        projectile:(o,spell)=>this.omission(o,'spell.projectile-presentation-unimplemented','Native spell projectile presentation is not implemented',{spellId:spell.id})}),
      setCombatState:(...a)=>c.setCombatState(...a)});
  }
}
