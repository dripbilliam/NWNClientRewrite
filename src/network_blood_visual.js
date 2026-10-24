import * as THREE from 'three';
import {selectClientBloodVisual,clientBloodSlot,clientBloodQuaternion} from './client_blood_visual.js';
import {modelAnimationTime} from './model_animation_query.js';
import {nativeStringEntry} from './spell_metadata.js';
import {intEntry} from './combat_stats.js';
const f=Math.fround,BASIS=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),INVERSE=BASIS.clone().invert();

// Native creature178/180/188 blood models, separate from canonical game
// effects and type11 area visuals. Slots survive clip completion until reuse.
export class NetworkBloodVisual{
 constructor(scene){this.scene=scene;this.owners=new Map();this.closed=false;}
 current(e){const s=this.scene;return!this.closed&&!s.closed&&!e.removed&&s.objects.get(e.actor.id)===e.binding&&s.world.registry.get(e.actor.id)===e.actor&&!e.actor.replicationRemoved&&e.actor.areaId===s.world.areaId;}
 destroy(e){if(!e||e.removed)return;e.removed=true;if(e.model){this.scene.poses.forgetAttachment(e.model);this.scene.visuals.destroyModel(e.model);e.model=null;}}
 receive(actor,source,record){const s=this.scene,b=s.objects.get(actor.id);if(this.closed||s.closed||!b)return 0;
  try{
   const state=b.combat,modelName=selectClientBloodVisual(actor,record,{
    // CNWCObject761760 initializes28=0 and18/20 empty; later render-effect
    // overrides remain owned by their separately diagnosed effect services.
    kind:()=>state?.bloodKind28??0,violence:()=>s.gore(),blood:o=>nativeStringEntry(s.tables.appearance,o.appearance.appearance,'BLOODCOLR').value,
    maximum:o=>{const maximum=o.replicated.hitPoints?.maximum;if(!Number.isInteger(maximum))throw new Error('Native maximum HP for blood selection is unavailable');return maximum;},
    whiteOverride:()=>Boolean(state?.bloodOverrides18?.at(-1)),lowViolence:id=>intEntry(s.tables.visualeffects,id,'LowViolence'),modelName:id=>nativeStringEntry(s.tables.visualeffects,id,'Imp_Impact_Node').value,
    warning:reason=>s.combat.failure(actor,reason==='missing-blood'?'Native appearance has no blood type':'Native blood violence setting is unknown','network.scene-blood-warning')
   });if(modelName===null)return 0;
   let owner=this.owners.get(actor.id);if(owner?.binding!==b){if(owner)this.remove(actor.id);owner={actor,binding:b,slots:[null,null,null]};this.owners.set(actor.id,owner);}
   const index=clientBloodSlot(owner.slots,{playInfo:e=>e.model?modelAnimationTime(e.model.animator.nativePlayback?.runsE0??[],'impact'):0,destroy:e=>this.destroy(e)});if(index<0)return 1;
   const nativePosition=o=>{const p=s.objects.get(o.id)?.wrapper.position;if(!p)throw new Error('Native blood direction source pose is unavailable');return[p.x,-p.z,p.y].map(f);},from=nativePosition(source),to=nativePosition(actor),direction=from.map((v,i)=>f(v-to[i])),facing=s.motion.objects.get(actor.id)?.orientation;
   if(!facing)throw new Error('Native blood defender facing is unavailable');
   const weapon=s.combat.weapon(actor,record.weaponAttackType),weaponType=weapon?intEntry(s.tables.baseitems,weapon.baseItem,'WeaponType').value:null,quaternion=clientBloodQuaternion(facing,direction,state?.visual??actor.replicated.animation??0,weaponType);
   if(!quaternion.every(Number.isFinite))throw new Error('Native blood orientation produced nonfinite coordinates');
   const e={actor,binding:b,index,modelName,quaternion,model:null,removed:false};owner.slots[index]=e;e.ready=this.load(e);return 1;
  }catch(error){s.combat.failure(actor,error.message,'network.scene-blood-failed');return 0;}
 }
 async load(e){const s=this.scene;try{
  if(!e.modelName)throw new Error('Native blood model reference is empty');const asset=await s.visuals.asset(e.modelName);if(!this.current(e))return;
  const model=e.model=s.visuals.createModel(asset,e.modelName),parent=s.poses.modelHandle(e.binding.wrapper);
  if(!parent||!s.poses.setParent(model,parent,'impact',3))throw new Error('Native blood impact attachment node is unavailable');
  const [w,x,y,z]=e.quaternion;model.root.quaternion.copy(BASIS).multiply(new THREE.Quaternion(x,y,z,w)).multiply(INVERSE);model.root.updateWorldMatrix(true,true);
  if(!model.animator.playNative('impact',{speed:1,flags:1,time:0}))throw new Error('Native blood impact clip is unavailable');
  s.combat.event({kind:'blood-visual',objectId:e.actor.id,model:e.modelName,slot:e.index,quaternion:e.quaternion});
 }catch(error){this.destroy(e);s.combat.failure(e.actor,error.message,'network.scene-blood-failed');}finally{if(!e.model){const owner=this.owners.get(e.actor.id);if(owner?.slots[e.index]===e)owner.slots[e.index]=null;}}}
 update(delta){for(const owner of [...this.owners.values()]){
  if(!this.current({actor:owner.actor,binding:owner.binding})){this.remove(owner.actor.id);continue;}
  for(const e of owner.slots)if(e?.model&&!e.removed)try{e.model.animator.update(delta);e.model.references?.update(delta);}catch(error){this.destroy(e);owner.slots[e.index]=null;this.scene.combat.failure(e.actor,error.message,'network.scene-blood-failed');}
 }}
 remove(id){const owner=this.owners.get(id);if(!owner)return;this.owners.delete(id);for(const e of owner.slots)this.destroy(e);}
 dispose(){this.closed=true;for(const id of this.owners.keys())this.remove(id);}
 snapshot(){return[...this.owners.values()].map(o=>({id:o.actor.id,slots:o.slots.map(e=>e?{model:e.modelName,ready:Boolean(e.model),time:e.model?modelAnimationTime(e.model.animator.nativePlayback?.runsE0??[],'impact'):null,quaternion:e.quaternion}:null)}));}
}
