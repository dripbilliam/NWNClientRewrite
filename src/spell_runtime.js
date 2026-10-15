import {OBJECT_INVALID} from './game_object_array.js';
import {addObjectAction,actionParameter} from './object_actions.js';
import {receiveSpellInput} from './spell_input.js';
import {addCastSpellActions,computeSpellRange,loadSpellRanges,spellActionPending} from './spell_queue.js';
import {executeOrdinaryCast} from './spell_cast_action.js';
import {castSpellAndImpact} from './spell_cast_impact.js';
import {startSpellRound,removeSpellActions} from './spell_round.js';
import {decrementRoundLength} from './combat_round.js';
import {setRoundPaused,setPauseTimer} from './combat_timing.js';
import {checkCastConcentration,checkSpellReleaseFailure,spellFailure} from './spell_release.js';
import {spellLikeReady} from './spell_book.js';
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
import {broadcastOrdinarySpellCast} from './spell_cast_broadcast.js';

const f=Math.fround,native=v=>[v[0],-v[2],v[1]].map(f),render=v=>[v[0],v[2],f(-v[1])];
const bits=v=>{const d=new DataView(new ArrayBuffer(4));d.setFloat32(0,v,true);return d.getInt32(0,true);};

// Local-authority binding for the mapped ordinary casting owners. All spell
// definitions and scripts come from the session's active resource resolver.
export class SpellRuntime{
  constructor(session){this.session=session;}
  feedback(o,code){return sendCombatFeedback(o,code,null,this.session.combat.broadcastProviders());}
  omission(o,code,message,detail={}){runtimeDiagnostics.record(code,message,{...this.session.diagnosticContext(o.id),...detail});}
  async input(request){
    const s=this.session,c=s.combat;
    return receiveSpellInput(s.player,request,{spell:id=>s.spellBook.castingSpell(id),uses:(...a)=>s.spellBook.uses(...a),feedback:(...a)=>this.feedback(...a),
      actionManager:(o,n)=>manageObjectActions(o,n,{hasClient:o=>Boolean(c.broadcastProviders().client(o.id)),clearActions:o=>c.clearActions(o)}),
      addCast:(o,r)=>this.add(o,r)});
  }
  add(o,request){
    const s=this.session,c=s.combat,ranges=loadSpellRanges(s.characterRules),area=o=>s.registry.get(o.areaId)??null;
    return addCastSpellActions(o,request,{object:id=>s.registry.get(id)??null,asCreature:o=>o.objectType===5?o:null,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      area,position:o=>native(o.position),possessor:o=>o.possessorId,dm:o=>Number(Boolean(o.isDM)),visibility:(o,id)=>o.perception?.get(id)??null,
      spell:id=>s.spellBook.castingSpell(id),uses:(...a)=>s.spellBook.uses(...a),abilityReady:spellLikeReady,feedback:(...a)=>this.feedback(...a),
      range:(o,spell,id)=>computeSpellRange(o,spell.range,id,{ranges,personalSpace:o=>o.nativePathInfo.field4,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;}}),
      queue:(o,id,group,params,front)=>addObjectAction(o.objectActionState,id,group,params,front),setLock:(...a)=>c.setLock(...a),
      move:(o,group,point,...a)=>addMoveToPointBack(o,group,render(point),...a,{setLock:(...a)=>c.setLock(...a)})});
  }
  preflight(o,node){
    if(actionParameter(node,4)!==0||actionParameter(node,10)!==-1)throw new Error('Native special/spontaneous cast action is not implemented');
    const s=this.session;
    // Counterspell resolution mutates other casters' round actions. Never
    // replace that lifecycle with a successful ordinary cast.
    for(const candidate of s.registry.objects.values())if(candidate.objectType===5&&candidate.areaId===o.areaId&&candidate.combatMode===4&&candidate.counterSpellTargetId===o.id)
      throw new Error('Native counterspell resolution is not implemented');
  }
  elapsed(o){
    const s=this.session,state=o.objectActionState;
    if((s.nativeActivePauseFlags??0)!==0)throw new Error('Native casting exclusion timer is not implemented');
    const result=subtractWorldTimes(s.worldTimer.time(),{day:state.startDay,time:state.startTime},s.worldTimer.dayLength);
    if(result.status!==0)throw new Error('Native casting elapsed time is unavailable');return result.milliseconds;
  }
  removeRoundSpell(o){if(spellActionPending(o.combatRound)===1)removeSpellActions(o.combatRound);}
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
    return executeOrdinaryCast(o,node,s.characterRules,{preflight:(...a)=>this.preflight(...a),dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),
      removeRoundSpell:o=>this.removeRoundSpell(o),pendingEquipment:o=>c.processPending(o),setLock:(...a)=>c.setLock(...a),
      facePoint:(o,point)=>facePointAction(o,{parameterTypes:new Uint32Array([2,2,2]),parameterData:point.map(bits)},c.facingProviders()),
      spell:id=>s.spellBook.castingSpell(id),areaId:o=>o.areaId,uses:(...a)=>s.spellBook.uses(...a),
      levelReady:()=>{throw new Error('Native spontaneous level-ready selection is not implemented');},components:(...a)=>s.spellBook.components(...a),feedback:(...a)=>this.feedback(...a),
      object:id=>s.registry.get(id)??null,targetGate:(o,t)=>!(t?.objectType===5&&t.isDM&&!o.isDM),
      activityManager:(o,n)=>manageCreatureActivities(o,n,(...a)=>s.skills.clearActivity(...a)),
      automaticQuicken:(...a)=>s.spellBook.automaticQuicken(...a),hasFeat:(o,id)=>c.hasFeat(o,id),opportunity:(...a)=>c.opportunityAttack(...a),
      broadcast:(o,id)=>broadcastOrdinarySpellCast(o,s.spellBook.castingSpell(id),s.characterRules,{
        area:o=>s.registry.get(o.areaId),ids:a=>{if(!a.nativeSpatial)throw new Error('Native cast broadcast area list is unavailable');return a.nativeSpatial.view();},
        creature:id=>{const v=s.registry.get(id);return v?.objectType===5?v:null;},range:loadSpellRanges(s.characterRules)[4],
        visibility:(o,id)=>o.perception?.get(id)??null,skill:(...a)=>c.skill(...a),roll:(...a)=>s.random.dice(...a),...c.broadcastProviders()}),
      startRound:(o,length)=>startSpellRound(o.combatRound,length),decrementRound:(o,n,bleed)=>decrementRoundLength(o.combatRound,n,Boolean(bleed)),
      pause:(o,v,id)=>setRoundPaused(o.combatRound,v,id),pauseTimer:(o,n,v)=>setPauseTimer(o.combatRound,n,v),elapsed:o=>this.elapsed(o),
      setAnimation:(...a)=>c.setAnimation(...a),lineOfSight:(o,target,point)=>{
        const from=native(o.position),to=target?native(target.position):point.slice();from[2]=f(from[2]+1);to[2]=f(to[2]+1);
        const area=s.registry.get(o.areaId);if(!area?.nativeGeometry)throw new Error('Native cast area LOS is unavailable');
        return area.nativeGeometry.lineOfSight(from,to,[0,0,0],{id:OBJECT_INVALID},o.id,target?.id??OBJECT_INVALID,1);
      },consume:(...a)=>s.spellBook.consume(...a),releaseChecks:(...a)=>this.release(...a),projectileTime:(...a)=>c.spellProjectileTime(...a),
      impact:(...a)=>castSpellAndImpact(...a,{spell:id=>s.spellBook.castingSpell(id),enqueue:(...a)=>c.enqueueEvent(...a),
        broadcast:(o,spell)=>this.omission(o,'spell.impact-broadcast-unimplemented','Native spell release presentation broadcast is not implemented',{spellId:spell.id}),
        projectile:(o,spell)=>this.omission(o,'spell.projectile-presentation-unimplemented','Native spell projectile presentation is not implemented',{spellId:spell.id})}),
      setCombatState:(...a)=>c.setCombatState(...a)});
  }
}
