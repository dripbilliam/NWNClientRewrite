import {nativeAnimationName,importedAnimationOverrides} from './native_animation.js';
import {clientAttackAnimationRecord,selectClientMeleeAnimation,clientWeaponAnimationClass} from './client_combat_animation.js';
import {NativeRandom} from './native_random.js';
import {intEntry} from './combat_stats.js';
import {nativeFloatEntry} from './movement_rate.js';
import {creatureRoot} from './creature_rules.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {clientBodyTransition,clientAnimationCategory} from './client_body_transition.js';

// Local render bridge. Client animation state belongs to these bindings, not
// the canonical server object or its action queue. No presentation draw changes
// the authoritative RNG. Original client/server thread interleaving and network
// serialization remain separate validation, not claimed by this adapter.
export class CreatureAnimationPresentation {
  constructor({object,rules,now,report,project=()=>null,random=new NativeRandom(1)}){
    Object.assign(this,{object,rules,now,report,project,random});this.bindings=new Map();this.pending=[];this.events=[];
  }
  clear(){for(const b of this.bindings.values())b.animator.presentationOwned=false;this.bindings.clear();this.pending=[];}
  bind(actor,animator,render){
    if(!animator)return;
    if(this.object(actor.id)!==actor||actor.objectType!==5)throw new Error('Creature animation binding requires a canonical creature');
    if(typeof actor.modelType!=='string'){this.report('Creature animation MODELTYPE is unavailable',{objectId:actor.id});return;}
    // Appearance MODELTYPE P/F uses assembled-body clips; simple models use
    // the c-prefixed native branch. Model lookup uses active module appearance.
    const context={fieldDD:0,fieldDE:Number(actor.modelType.includes('P')||actor.modelType.includes('F')),fieldDF:0,fieldE0:0,fieldE8:0,fieldEC:0};
    const b={id:actor.id,actor,animator,render,context,side:0,lastBase:null,transitions:[],position:[...actor.position],orientation:[...actor.orientation],current:null,failures:new Set()};
    animator.presentationOwned=true;this.bindings.set(actor.id,b);this.refreshWeapon(b);
  }
  baseInfo(item){
    if(!item)return null;const rules=this.rules(),base=item.authored?.BaseItem;
    if(!Number.isInteger(base)||!rules.baseitems)throw new Error('Client animation baseitems ownership is unavailable');
    const rows=rules.baseitems.orderedRows??[...rules.baseitems.rows.values()];if(base<0||base>=rows.length)return null;
    const entry=column=>intEntry(rules.baseitems,base,column).value;
    return {weaponWield:entry('WeaponWield')&255,weaponType:entry('WeaponType')&255,weaponSize:entry('WeaponSize')&255,
      slashLeft:entry('%AnimSlashL')&255,slashRight:entry('%AnimSlashR')&255};
  }
  equipped(actor,slot){
    if(actor.nativeInventoryImported)return actor.nativeEquipment.get(slot,id=>{const item=this.object(id);return item?.objectType===6?item:null;});
    return (actor.inventory??[]).map(id=>this.object(id)).find(item=>item?.equipmentSlot===slot)??null;
  }
  refreshWeapon(b){
    clientWeaponAnimationClass(b.actor,{context:()=>b.context,equipped:(o,slot)=>this.equipped(o,slot),baseInfo:i=>this.baseInfo(i),
      weaponSize:(o,i)=>i.authored.BaseItem===111?0:this.baseInfo(i).weaponSize-intEntry(this.rules().appearance,creatureRoot(o).Appearance_Type&65535,'SIZECATEGORY').value,
      warning:message=>this.failure(b,message)});
  }
  attackWeapon(actor,type){return this.equipped(actor,({1:16,2:32,3:16384,4:32768,5:65536,6:16})[type]);}
  providers(b){
    const appearance=(o,column)=>nativeFloatEntry(this.rules().appearance,creatureRoot(o).Appearance_Type&65535,column);
    return {context:()=>b.context,target:id=>this.object(id),baseAnimation:o=>o.animationState,
      lockTarget:o=>o.lockOrientationId,orientation:o=>o.orientation,
      targetHeight:o=>{
        const rows=this.rules().appearance.orderedRows??[...this.rules().appearance.rows.values()],row=rows[creatureRoot(o).Appearance_Type&65535];
        const key=Object.keys(row??{}).find(k=>k.toLowerCase()==='targetheight');return row?.[key]==='L'?'L':'';
      },
      hasMonkClass:()=>Number((creatureRoot(b.actor).ClassList??[]).some(c=>(c.Class&255)===5)),
      equipped:(_o,slot)=>this.equipped(b.actor,slot),baseItem:i=>i.authored.BaseItem,
      attackWeapon:(_o,type)=>this.attackWeapon(b.actor,type),baseInfo:i=>this.baseInfo(i),random:()=>this.random.next(),
      hitDistance:o=>appearance(o,'HITDIST').value,
      preferredDistance:(_o,type)=>{
        const weapon=this.attackWeapon(b.actor,type);
        if(!weapon||((weapon.authored.BaseItem-69)>>>0)<4)return appearance(b.actor,'PREFATCKDIST').value;
        let distance=nativeFloatEntry(this.rules().baseitems,weapon.authored.BaseItem,'PrefAttackDist').value;
        if(b.context.fieldDE===1){const scale=appearance(b.actor,'weaponscale');if(scale.found)distance=Math.fround(distance*scale.value);}
        return distance;
      }};
  }
  receive(message){
    if(![5,6].includes(message.type)||!message.attack)return false;
    const [actorId,targetId]=message.data.objects,b=this.bindings.get(actorId);
    if(!b)return false;
    try{
      this.refreshWeapon(b);const record=clientAttackAnimationRecord(message.attack,targetId),at=this.now();
      const local={id:actorId,position:b.actor.position,side:b.side};
      let id;
      if(record.ranged!==0){id=200;if(b.side===2){b.side=1;b.context.fieldE0=1;}}
      else{id=selectClientMeleeAnimation(local,record,this.providers(b));b.side=local.side;}
      this.pending.push({id:actorId,animation:id,at,duration:record.duration});
      if(record.ranged!==0&&record.reaction===12)this.failure(b,'Native ranged parry travel animation262 is not connected');
      else if(record.reaction>1)this.pending.push({id:targetId,animation:record.reaction,at:at+record.reactionDelay,duration:record.reactionDuration});
      return true;
    }catch(error){this.failure(b,error.message);return false;}
  }
  failure(b,message){if(!b.failures.has(message)){b.failures.add(message);this.report(message,{objectId:b.id,model:b.animator.model.modelName});}}
  play(b,id,at,duration=null,loop=false){
    const overrides=importedAnimationOverrides(creatureRoot(b.actor));
    const name=nativeAnimationName(id,b.context,overrides);if(!name){this.failure(b,`Native animation ${id} selects an empty clip name`);return;}
    const clip=b.animator.model.animations.find(a=>a.name===name);
    if(!clip){this.failure(b,`Native animation ${id} requires unavailable clip ${name}`);return;}
    const speed=b.actor.nativeAnimationSpeedDC??1;
    if(!Number.isFinite(speed)||speed<=0){this.failure(b,'Native nonpositive animation-speed playback is not connected');return;}
    if(!b.animator.play(name,{loop}))return;
    b.animator.presentationPreview=false;
    b.current={id,name,at,duration:duration??clip.length*1000/speed,loop};
    this.events.push({objectId:b.id,animation:id,clip:name,at,duration:b.current.duration});if(this.events.length>100)this.events.shift();
  }
  bodyTransition(b,previous,base,now){
    const calls=clientBodyTransition(previous,base);
    if(calls===null){this.failure(b,`Native base transition ${previous} to ${base} is not connected`);return false;}
    if(!calls.length)return false;
    this.pending=this.pending.filter(p=>p.id!==b.id);b.transitions=[];
    for(const call of calls){
      b.transitions.push({animation:call.animation,duration:call.reaction?([219,220,221,222].includes(call.animation)?1000:null):null});
      if(call.reaction)b.transitions.push({animation:call.reaction,duration:call.reactionDuration});
    }
    const cue=b.transitions.shift();this.play(b,cue.animation,now,cue.duration,false);return true;
  }
  update(){
    const now=this.now(),due=this.pending.filter(p=>p.at<=now);this.pending=this.pending.filter(p=>p.at>now);
    for(const cue of due){
      const b=this.bindings.get(cue.id);if(!b||this.object(cue.id)!==b.actor||[6,8].includes(b.actor.animationState))continue;
      try{this.play(b,cue.animation,cue.at,cue.duration,false);}catch(error){this.failure(b,error.message);}
    }
    for(const b of this.bindings.values()){
      if(this.object(b.id)!==b.actor)continue;
      if(b.animator.presentationPreview&&b.actor.animationState<=1)continue;
      try{
        const actor=b.actor,base=actor.animationState&65535,dead=[6,8].includes(base);
        if(b.lastBase!==base){
          const previous=b.lastBase;b.lastBase=base;
          // An actor first loaded in a body pose starts in that pose. Live
          // base changes use the mapped native transition, without mutating
          // its server animation or running death again.
          const transitioned=previous!==null&&this.bodyTransition(b,previous,base,now);
          if(!transitioned&&(dead||base!==9&&(!b.current||b.current.loop)))this.play(b,base,now,null,this.baseLoops(base));
        }
        if(b.current&&!b.current.loop&&now-b.current.at>=b.current.duration){
          const end=b.current.at+b.current.duration,cue=b.transitions.shift();
          if(cue)this.play(b,cue.animation,end,cue.duration,false);
          else if(b.current.id!==base)this.play(b,base===9?1:base,end,null,this.baseLoops(base));
        }
        if(b.current){
          const current=b.current,length=b.animator.clip.length,elapsed=Math.max(0,now-current.at);
          const raw=current.duration>0?elapsed/current.duration*length:length,time=current.loop&&length>0?raw%length:Math.min(raw,length);
          b.animator.time=time;b.animator.apply(b.animator.clip,time);b.animator.playing=current.loop||raw<length;
        }
        const target=this.object(actor.lockOrientationId),changed=actor.orientation.some((v,i)=>v!==b.orientation[i]);
        if(target&&target.areaId===actor.areaId||changed){
          const direction=target&&target.areaId===actor.areaId?target.position.map((v,i)=>v-actor.position[i]):actor.orientation;
          if(direction[0]!==0||direction[2]!==0){const bearing=-Math.atan2(direction[0],-direction[2]);b.render.rotation.y=bearing+(actor.kind==='player'?Math.PI:0);}
          b.orientation=[...actor.orientation];
        }
        b.position=[...actor.position];
      }catch(error){this.failure(b,error.message);}
    }
  }
  baseLoops(base){return ![5,6,7,8,9].includes(base)&&(clientAnimationCategory(5,base)===1||[2,3,4].includes(base));}
  snapshot(){return{pending:this.pending.length,events:this.events,actors:[...this.bindings.values()].map(b=>({id:b.id,tag:b.actor.tag,model:b.animator.model.modelName,
    base:b.actor.animationState,hp:b.actor.stats?.currentHP,encounterId:b.actor.nativeField948,attackTargetId:b.actor.attackTargetId,position:b.actor.position.slice(),
    clip:b.current?.name??'',animation:b.current?.id,time:b.animator.time,screen:this.project(b.render),failures:[...b.failures]}))};}
}
