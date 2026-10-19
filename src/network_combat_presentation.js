import {ClientAnimationQueue} from './client_animation_queue.js';
import {playClientAttack,clientAttackHit,advanceClientAnimationCountdown} from './client_attack_playback.js';
import {selectClientAttackAnimation} from './client_combat_animation.js';
import {nativeAnimationName} from './native_animation.js';
import {clientAnimationCategory} from './client_body_transition.js';
import {nativeFloatEntry} from './movement_rate.js';
import {intEntry} from './combat_stats.js';
import {NativeRandom} from './native_random.js';
import {WorldTimer} from './world_timer.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {clientObjectAnimationName} from './client_object_animation.js';
import {networkCastReleaseBase,clientCastAnimationCue} from './network_cast_animation.js';
import {clientMovementCue} from './network_movement_cue.js';
const f=Math.fround;

// Rendering-only client owner. Canonical objects, HP, equipment, paths, attack
// outcomes and action queues belong to the server. This RNG selects cosmetic
// clip variants/barks; it never rolls damage, saves or other gameplay outcomes.
export class NetworkCombatPresentation {
 constructor({world,bindings,tables,pose,context,report,random=new NativeRandom(1),microseconds=null}){
  Object.assign(this,{world,bindings,tables,pose,context,report,random});this.seconds=0;this.lastTick=0;this.events=[];this.animators=new Map();
  this.timer=new WorldTimer(microseconds??(()=>BigInt(Math.trunc(this.seconds*1e6))));this.timer.setTime(0,0);this.lastTick=Number(this.timer.counter/1000n);
 }
 binding(o){return this.bindings.get(o.id);}
 object(id){const o=this.world.registry.get(id);return o&&!o.replicationRemoved&&o.areaId===this.world.areaId?o:null;}
 bind(o,b){
  const animator=b.models[0]?.animator;if(!animator)return null;
  const context=o.objectType===5?this.context(o,this.tables,b.bodyType):{fieldDE:0,fieldDD:0,fieldDF:0,fieldE0:0,fieldE8:0,fieldEC:0};
  const base=o.objectType===5?0:o.replicated?.animation??0;
  const state=b.combat={context,side:0,queue:new ClientAnimationQueue(this.timer.dayLength),base,visual:base,speed:1,current:null,action:{type:0,sourceId:OBJECT_INVALID,targetId:OBJECT_INVALID},pending:null,failures:new Set()};
  this.animators.set(animator,state);
  if(o.objectType===5&&animator.eventDispatcher)state.hitListener=animator.eventDispatcher.add('hit',()=>{
   if(this.object(o.id)!==o)return;
   this.event({kind:'hit',objectId:o.id,animation:state.visual,targetId:state.action.targetId});
   try{if(state.action.type===1)clientAttackHit(state.action,this.providers());}catch(error){this.failure(o,error.message);}
  });
  return state;
 }
 unbind(b){const animator=b.models[0]?.animator,state=b.combat;this.animators.delete(animator);if(state?.hitListener&&animator.eventDispatcher){const list=animator.eventDispatcher.listeners,index=list.indexOf(state.hitListener);if(index>=0)list.splice(index,1);}state?.queue.clear();}
 ensure(o){const b=this.binding(o);if(!b)return null;return b.combat??this.bind(o,b);}
 failure(o,message,code='network.scene-combat-unhandled'){
  const state=this.binding(o)?.combat,key=code+':'+message;if(state?.failures.has(key))return;state?.failures.add(key);this.report(code,message,{objectId:o.id});
 }
 event(value){this.events.push({...value,at:this.seconds});if(this.events.length>100)this.events.shift();}
 equipped(o,slot){return o.appearance?.equipment?.find(e=>e.slot===slot)?.item??null;}
 weapon(o,type){return this.equipped(o,({1:16,2:32,3:16384,4:32768,5:65536,6:16})[type]);}
 info(item){const entry=name=>intEntry(this.tables.baseitems,item.baseItem,name).value;return{weaponType:entry('WeaponType'),weaponWield:entry('WeaponWield'),weaponSize:entry('WeaponSize'),slashLeft:entry('%AnimSlashL'),slashRight:entry('%AnimSlashR')};}
 facade(o){const pose=this.pose(o);if(!pose)throw new Error('Native combat presentation pose is unavailable');return{id:o.id,objectType:o.objectType,position:pose.position};}
 select(o,record){
  const state=this.ensure(o);if(!state)throw new Error('Native attacker model is unavailable');
  const appearance=(actor,column)=>nativeFloatEntry(this.tables.appearance,actor.appearance.appearance,column);
  const source={...this.facade(o),side:state.side},original=proxy=>this.object(proxy.id);
  const animation=selectClientAttackAnimation(source,9,record,{
   context:()=>state.context,target:id=>{const target=this.object(id);return target?this.facade(target):null;},
   setBaseAnimation:(_actor,id)=>this.base(o,id),
   baseAnimation:proxy=>this.binding(proxy)?.combat?.base??original(proxy)?.replicated?.animation??0,
   lockTarget:proxy=>original(proxy)?.replicated?.facingTarget??OBJECT_INVALID,
   orientation:proxy=>{const angle=this.pose(original(proxy)).rotation;return[-Math.sin(angle),0,-Math.cos(angle)];},
   targetHeight:proxy=>{const actor=original(proxy),row=this.tables.appearance.rows.get(actor.appearance.appearance),key=Object.keys(row??{}).find(k=>k.toLowerCase()==='targetheight');return row?.[key]==='L'?'L':'';},
   hasMonkClass:()=>{if(!o.replicated.stats?.classes)throw new Error('Native animation class list is unavailable');return Number(o.replicated.stats.classes.some(c=>c.id===5));},
   equipped:(_actor,slot)=>this.equipped(o,slot),baseItem:i=>i.baseItem,attackWeapon:(_actor,type)=>this.weapon(o,type),baseInfo:i=>this.info(i),random:()=>this.random.next(),
   hitDistance:proxy=>appearance(original(proxy),'HITDIST').value,
   preferredDistance:(_actor,type)=>{const weapon=this.weapon(o,type);if(!weapon||((weapon.baseItem-69)>>>0)<4)return appearance(o,'PREFATCKDIST').value;
    let value=nativeFloatEntry(this.tables.baseitems,weapon.baseItem,'PrefAttackDist').value;if(state.context.fieldDE===1){const scale=appearance(o,'WEAPONSCALE');if(scale.found)value=f(value*scale.value);}return value;}
  });state.side=source.side;state.attackType=source.attackType;return animation;
 }
 clip(o,animation){const b=this.binding(o),state=this.ensure(o);if(!b||!state)throw new Error('Native combat model binding is unavailable');const name=o.objectType===5?nativeAnimationName(animation,state.context):clientObjectAnimationName(o.objectType,animation),animator=b.models[0].animator,clip=animator.model.animations.find(c=>c.name===name);if(!clip)throw new Error(`Native animation ${animation} requires unavailable clip ${name}`);return{animator,name,clip};}
 insert(o,cue){const state=this.ensure(o);if(!state){this.failure(o,'Native reaction model is unavailable');return;}this.timer.snapshot();state.queue.insert(cue,this.timer.time());}
 movementCue(o,request){try{const {clip}=this.clip(o,request.animation);this.insert(o,clientMovementCue(request,clip.length,o.replicated.animationSpeed??1));}catch(error){this.failure(o,error.message,'network.scene-movement-cue-unavailable');}}
 end(o){const state=this.ensure(o);if(!state)return;state.current=null;state.visual=state.base;}
 providers(){return{
  object:id=>this.object(id),currentAnimation:o=>this.ensure(o)?.visual??o.replicated?.animation??0,bodyType:o=>this.binding(o)?.bodyType??0,
  prepareWeapon:o=>this.failure(o,'Native attack wield/effect preparation is not connected','network.scene-weapon-effect-unhandled'),
  stopModelMotion:o=>this.failure(o,'Native moving-melee model-motion cancellation is not connected','network.scene-model-motion-unhandled'),
  pendingAttack:(o,record)=>{this.ensure(o).pending=record;},selectAttack:(o,r)=>this.select(o,r),
  animationLength:(o,id)=>f(this.clip(o,id).clip.length*1000),insert:(o,cue)=>this.insert(o,cue),random:()=>this.random.next(),
  bark:o=>this.failure(o,'Native combat bark audio is not connected','network.scene-combat-audio-unhandled'),
  sound:o=>this.failure(o,'Native attack sound scheduling is not connected','network.scene-combat-audio-unhandled'),
  isDoorOrPlaceable:o=>[9,10].includes(o.objectType),hitPoints:o=>o.replicated?.hitPoints?.current,
  unhandled:(message,o)=>this.failure(o,message),playReaction:(o,id)=>{const length=f(this.clip(o,id).clip.length*1000),speed=o.objectType===9?1:o.replicated.animationSpeed??1;this.insert(o,{animation:id,duration:Math.trunc(speed===0?length:length/Math.abs(speed))>>>0,speed,record:null,delay:0});},
  abortOnParry:o=>intEntry(this.tables.appearance,o.appearance.appearance,'ABORTONPARRY').value,
  weaponEffect:o=>this.failure(o,'Native weapon impact/cessation effects are not connected','network.scene-weapon-effect-unhandled'),
  hasModel:(_o,id)=>{throw new Error(`Native attached-model query ${id} for parry abort is not connected`);},
  endAnimation:o=>this.end(o),hasParryWeapon:o=>Boolean([16,16384,32768,65536].some(slot=>this.equipped(o,slot))),
  parryEffect:o=>this.failure(o,'Native parry effect presentation is not connected','network.scene-combat-effect-unhandled'),
  impactEffect:o=>this.failure(o,'Native damage impact effect presentation is not connected','network.scene-combat-effect-unhandled'),
  playAttack:(o,r)=>playClientAttack(o,r,this.providers())
 };}
 receive(events){
  for(const event of events)if(event.action==='cast-animation'){const o=this.object(event.id);if(!o||o.objectType!==5)continue;try{this.base(o,event.animation);const length=f(this.clip(o,event.animation).clip.length*1000);this.insert(o,clientCastAnimationCue(event.animation,length,structuredClone(event.record)));}catch(error){this.failure(o,error.message,'network.scene-cast-animation-unhandled');}}
  for(const event of events){if(event.action!=='attack-animation')continue;const o=this.object(event.id);if(!o||o.objectType!==5)continue;
   try{if(!this.ensure(o))throw new Error('Native attacker model is unavailable');const records=event.records.map(r=>({...r,next:null}));for(let i=0;i+1<records.length;i++)records[i].next=records[i+1];this.providers().sound(o,records[0],1);playClientAttack(o,records[0],this.providers());}
   catch(error){this.failure(o,error.message);}
  }
 }
 base(o,animation){
  const state=this.ensure(o);if(!state)return false;
  const castBase=networkCastReleaseBase(animation);if(castBase!==null){state.base=castBase;return true;}
  if(animation===9)return true;
  state.base=animation;
  if([2,3,4,5,6,7,8,24,25].includes(animation)){state.queue.clear();state.current=null;state.visual=animation;state.speed=o.replicated.animationSpeed??1;return false;}
  if(state.pending&&[0,1].includes(animation)){const record=state.pending;state.pending=null;state.visual=animation;playClientAttack(o,record,this.providers());return true;}
  if(state.current||state.queue.count)return true;
  state.visual=animation;state.speed=o.replicated.animationSpeed??1;return false;
 }
 observeObjectBase(o,animation){
  const state=this.binding(o)?.combat;if(!state||clientAnimationCategory(o.objectType,animation)!==1||state.base===animation)return;
  // SetBaseAnimation764300 clears queued actions on a changed looping base
  // (the creature0/1 exception belongs to base()). Existing door transitions
  // remain owned by the door bridge; never restore its obsolete closed pose.
  state.queue.clear();state.current=null;state.base=state.visual=animation;state.speed=o.replicated.animationSpeed??1;
 }
 play(o,animation,speed,loop){
  if(!Number.isFinite(speed)||speed<=0)throw new Error('Native nonpositive/nonfinite combat model playback is not connected');
  const {animator,name}=this.clip(o,animation),state=this.ensure(o);if(!animator.play(name,{loop}))throw new Error('Native combat clip could not start');state.visual=animation;state.speed=speed;
  this.event({kind:'play',objectId:o.id,animation,clip:name,speed,loop});
 }
 update(delta){
  this.seconds+=delta;this.timer.snapshot();const tick=Number(this.timer.counter/1000n),elapsed=tick-this.lastTick;this.lastTick=tick;this.frameMilliseconds=elapsed;this.frames=(this.frames??0)+1;
  for(const [id,b]of this.bindings){const state=b.combat,o=this.object(id);if(!state||!o)continue;
   try{
    if(state.current){const countdown=advanceClientAnimationCountdown(state.current.remaining,elapsed);state.current.remaining=countdown.remaining;if(countdown.expired){state.current=null;this.play(o,state.base,o.replicated.animationSpeed??1,clientAnimationCategory(o.objectType,state.base)===1);}}
    if(clientAnimationCategory(o.objectType,state.visual)!==1)continue;
    const cue=state.queue.next(this.timer.time());if(!cue.ready)continue;
    if((cue.duration|0)<0)this.event({kind:'overdue',objectId:o.id,animation:cue.animation,unsignedDuration:cue.duration,signedDuration:cue.duration|0});
    if(cue.record?.type===4)state.action=cue.record;
    else if(cue.record&&((cue.animation>=200&&cue.animation<=205)||(cue.animation>=263&&cue.animation<=265)))Object.assign(state.action,cue.record);
    this.play(o,cue.animation,cue.speed,false);state.current={remaining:cue.duration|0};state.queue.remove();
   }catch(error){state.queue.clear();state.current=null;this.failure(o,error.message);}
  }
 }
 speedFor(animator){return this.animators.get(animator)?.speed??1;}
 snapshot(){return{frames:this.frames??0,frameMilliseconds:this.frameMilliseconds??0,events:this.events.map(e=>({...e})),actors:[...this.bindings].filter(([,b])=>b.combat).map(([id,b])=>({id,animation:b.combat.visual,pending:b.combat.queue.count,remaining:b.combat.current?.remaining??null,deferred:Boolean(b.combat.pending)}))};}
}
